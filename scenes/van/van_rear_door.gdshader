// Rear door leaf skin. The cabin face is a stamped steel inner skin: a pressed frame with
// oval lightening holes that show the darker outer skin behind, pressed ribs, worn paint and
// grime. The street face is plain outer paint, the rim is the bare cut edge. The mesh is the
// left leaf in hinge-local metres (the right leaf is the same mesh under scale.x -1), so every
// pattern is laid out in model-space metres. Detail comes from grime.gdshaderinc, no bitmaps.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/shaders/grime.gdshaderinc"

uniform float leaf_width_m = 2.378;
uniform float leaf_height_m = 3.38;
uniform vec4 paint_color : source_color = vec4(0.17, 0.165, 0.15, 1.0);
uniform vec4 outer_paint_color : source_color = vec4(0.08, 0.085, 0.08, 1.0);
uniform vec4 bare_steel_color : source_color = vec4(0.26, 0.26, 0.25, 1.0);
uniform vec4 hole_dark_color : source_color = vec4(0.03, 0.03, 0.028, 1.0);
uniform vec4 rust_color : source_color = vec4(0.09, 0.045, 0.025, 1.0);
uniform vec4 stain_color : source_color = vec4(0.04, 0.035, 0.03, 1.0);
uniform vec4 lower_holes_rect = vec4(0.45, -1.30, 1.95, -0.90);
uniform int lower_hole_count = 3;
uniform float hole_gap_m = 0.09;
uniform float hole_radius_m = 0.13;
uniform vec4 upper_slot_rect = vec4(0.70, 1.17, 2.00, 1.31);
uniform float flange_m = 0.04;
uniform float panel_margin_m = 0.07;
uniform float bump_strength = 0.35;
uniform float roughness_paint = 0.86;
uniform float roughness_bare = 0.78;
uniform float metallic_paint = 0.12;
uniform float metallic_bare = 0.28;

varying vec3 v_pos;
varying vec3 v_nrm;

float rrect_sd(vec2 p, vec2 c, vec2 half_size, float r) {
	vec2 q = abs(p - c) - (half_size - vec2(r));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Signed distance to the nearest hole; rc = (cx, cy, half w, half h), rad = corner radius.
float hole_sdf(vec2 p, out vec4 rc, out float rad) {
	float count = float(max(lower_hole_count, 1));
	float w = (lower_holes_rect.z - lower_holes_rect.x - (count - 1.0) * hole_gap_m) / count;
	float idx = clamp(floor((p.x - lower_holes_rect.x + hole_gap_m * 0.5) / (w + hole_gap_m)),
			0.0, count - 1.0);
	vec2 lc = vec2(lower_holes_rect.x + w * 0.5 + idx * (w + hole_gap_m),
			(lower_holes_rect.y + lower_holes_rect.w) * 0.5);
	vec2 lh = vec2(w * 0.5, (lower_holes_rect.w - lower_holes_rect.y) * 0.5);
	float lr = min(hole_radius_m, min(lh.x, lh.y));
	vec2 sc = (upper_slot_rect.xy + upper_slot_rect.zw) * 0.5;
	vec2 sh = (upper_slot_rect.zw - upper_slot_rect.xy) * 0.5;
	float d_low = rrect_sd(p, lc, lh, lr);
	float d_slot = rrect_sd(p, sc, sh, sh.y);
	bool low = d_low < d_slot;
	rc = low ? vec4(lc, lh) : vec4(sc, sh);
	rad = low ? lr : sh.y;
	return min(d_low, d_slot);
}

// Signed distance to the raised stamped panel around each hole group.
float panel_sdf(vec2 p) {
	vec2 lc = (lower_holes_rect.xy + lower_holes_rect.zw) * 0.5;
	vec2 lh = (lower_holes_rect.zw - lower_holes_rect.xy) * 0.5 + vec2(panel_margin_m);
	vec2 sc = (upper_slot_rect.xy + upper_slot_rect.zw) * 0.5;
	vec2 sh = (upper_slot_rect.zw - upper_slot_rect.xy) * 0.5 + vec2(panel_margin_m);
	return min(rrect_sd(p, lc, lh, hole_radius_m + panel_margin_m),
			rrect_sd(p, sc, sh, sh.y));
}

// 0..1 mask of the shallow pressed ribs (two horizontal, one on the hinge stile).
float rib_mask(vec2 p) {
	float h1 = 1.0 - smoothstep(0.01, 0.02, abs(p.y + 0.72));
	float h2 = 1.0 - smoothstep(0.01, 0.02, abs(p.y - 1.08));
	float v = (1.0 - smoothstep(0.01, 0.02, abs(p.x - 0.12)))
			* smoothstep(-0.62, -0.58, p.y) * (1.0 - smoothstep(0.98, 1.02, p.y));
	return max(max(h1, h2), v);
}

// Height of the stamping in metres: raised panels, flanges bevelled into the holes, ribs.
float height_at(vec2 p) {
	vec4 rc;
	float rad;
	float d = hole_sdf(p, rc, rad);
	float h = 0.014 * smoothstep(0.0, 0.02, -panel_sdf(p));
	h -= 0.014 * (1.0 - smoothstep(0.0, flange_m, d));
	h -= 0.007 * rib_mask(p);
	return h;
}

// Dark streaks running down from the bottom edge of a hole spanning x0..x1.
float streak(vec2 p, float x0, float x1, float y0) {
	float below = y0 - p.y;
	float len = mix(0.1, 0.4, noise21(vec2(p.x * 9.0 + 3.0, 7.0)));
	float col = smoothstep(0.5, 0.65, noise21(vec2(p.x * 16.0, 1.0)));
	float span = smoothstep(x0, x0 + 0.05, p.x) * (1.0 - smoothstep(x1 - 0.05, x1, p.x));
	return smoothstep(0.0, 0.01, below) * (1.0 - smoothstep(0.0, len, below)) * col * span;
}

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	vec2 p = v_pos.xy;
	// Fine patterns fade to their average before they reach about two screen pixels.
	float fw = max(fwidth(p.x), fwidth(p.y));
	float grit_vis = 1.0 - smoothstep(0.02, 0.05, fw);
	float rib_vis = 1.0 - smoothstep(0.04, 0.10, fw);
	float grit = (fbm(p * 10.0) - 0.47) * 0.2 * grit_vis;
	float bottom = -leaf_height_m * 0.4527;
	float kick = (1.0 - smoothstep(-1.29, -1.21, p.y))
			* smoothstep(0.35, 0.6, fbm(p * 12.0 + vec2(5.0, 2.0)));
	float rough = roughness_paint;
	float metal = metallic_paint;
	vec3 col;

	if (v_nrm.z < -0.5) {
		vec4 rc;
		float rad;
		float d = hole_sdf(p, rc, rad);
		float dpm = panel_sdf(p);

		// Structure: flange tone, then the dark line at the base of the panel bevel.
		float ft = step(0.0, d) * (1.0 - step(flange_m, d)) * clamp(d / flange_m, 0.0, 1.0);
		col = paint_color.rgb * mix(0.9, 1.15, smoothstep(0.3, 0.7, ft));
		col *= 1.0 - 0.1 * smoothstep(0.85, 1.0, p.x / leaf_width_m);
		col *= 1.0 - 0.2 * smoothstep(0.0, 0.004, dpm) * (1.0 - smoothstep(0.016, 0.02, dpm));
		col *= 1.0 - 0.08 * rib_mask(p);

		// Grime, in order: grit, wear, streaks, rust, oil, edge dirt.
		col *= 1.0 + grit;
		float flange_top = step(0.0, d) * (1.0 - step(flange_m, d)) * smoothstep(0.5, 1.0, ft);
		float bevel = 1.0 - smoothstep(0.0, 0.012, abs(dpm + 0.01));
		float wear = clamp(flange_top + bevel + kick, 0.0, 1.0)
				* smoothstep(0.4, 0.65, fbm(p * 14.0 + vec2(1.7, 9.2)));
		col = mix(col, bare_steel_color.rgb, wear);
		float lw = (lower_holes_rect.z - lower_holes_rect.x
				- float(max(lower_hole_count, 1) - 1) * hole_gap_m) / float(max(lower_hole_count, 1));
		float idx = clamp(floor((p.x - lower_holes_rect.x + hole_gap_m * 0.5) / (lw + hole_gap_m)),
				0.0, float(lower_hole_count) - 1.0);
		float lx0 = lower_holes_rect.x + idx * (lw + hole_gap_m);
		float stain = max(streak(p, lx0, lx0 + lw, lower_holes_rect.y),
				streak(p, upper_slot_rect.x, upper_slot_rect.z, upper_slot_rect.y));
		col = mix(col, stain_color.rgb, stain * 0.8);
		float low_edge = 1.0 - smoothstep(0.0, 0.12, d);
		float low_strip = 1.0 - smoothstep(0.0, 0.08, p.y - bottom);
		float rust = clamp(low_edge * 0.8 + low_strip, 0.0, 1.0)
				* smoothstep(0.5, 0.72, fbm(p * 7.0 + vec2(8.3, 1.1)));
		col = mix(col, rust_color.rgb, rust * 0.85);
		float oil = smoothstep(0.7, 0.8, fbm(p * 3.0 + vec2(3.3, 6.6))) * 0.5;
		col = mix(col, stain_color.rgb, oil);
		float edge = (1.0 - smoothstep(0.0, 0.03, d - flange_m)) * step(flange_m, d)
				+ (1.0 - smoothstep(0.0, 0.03, dpm)) * step(0.0, dpm);
		col *= 1.0 - 0.3 * clamp(edge, 0.0, 1.0);

		// Inside a hole: the outer skin 6 cm behind, ribbed, shadowed by the inner lip.
		float rt = 2.0 * smoothstep(0.35, 0.65, abs(fract(p.x / 0.25) - 0.5) * 2.0) - 1.0;
		float lip = min((rc.y + rc.w) - p.y, p.x - (rc.x - rc.z));
		vec3 hole = hole_dark_color.rgb * (1.0 + 0.15 * rt * rib_vis)
				* mix(0.4, 1.0, smoothstep(0.0, 0.06, lip));
		float inside = 1.0 - smoothstep(-0.004, 0.004, d);
		col = mix(col, hole, inside);
		rough = mix(roughness_paint, roughness_bare, wear);
		rough = mix(rough, 0.92, max(max(rust, stain * 0.8), oil));
		rough = mix(rough, 0.9, inside);
		metal = mix(metallic_paint, metallic_bare, wear);

		// Bump from the height gradient by central differences at 5 mm.
		float e = 0.005;
		vec2 g = vec2(height_at(p + vec2(e, 0.0)) - height_at(p - vec2(e, 0.0)),
				height_at(p + vec2(0.0, e)) - height_at(p - vec2(0.0, e))) / (2.0 * e);
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * MODEL_MATRIX * vec4(-g.x, -g.y, 0.0, 0.0)).xyz
				* bump_strength);
	} else if (v_nrm.z > 0.5) {
		col = outer_paint_color.rgb * (1.0 + grit);
		float blot = smoothstep(0.62, 0.78, fbm(p * 2.5 + vec2(4.4, 0.7)));
		col = mix(col, rust_color.rgb, blot * 0.7);
		col = mix(col, bare_steel_color.rgb * 0.6, kick * 0.5);
		rough = mix(roughness_paint, 0.92, blot);
		metal = mix(metallic_paint, metallic_bare, kick * 0.5);
	} else {
		float worn = smoothstep(0.45, 0.7, fbm(p * 6.0 + vec2(2.0, 5.0)));
		col = bare_steel_color.rgb * 0.7 * (1.0 + grit * 1.5);
		col = mix(col, rust_color.rgb, worn * 0.5);
		rough = roughness_bare;
		metal = metallic_bare;
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.78, 0.95);
	METALLIC = clamp(metal, 0.0, 0.3);
}
