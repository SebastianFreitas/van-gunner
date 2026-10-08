// Rear door leaf: faded van paint over steel. The street face is dull faded paint, chipped at the
// leaf edges, with rust bleeding down from the holes and seams; the cabin face is bare primer-grey
// steel. The mesh builders tag every vertex (COLOR.r = tag / 8, see rear_door_skin.gd), so no face
// is guessed from its normal or depth and sloped relief keeps its meaning:
// 0 street paint, 1 cabin primer, 2 cut edge / rim (bare steel), 3 relief crest (wear),
// 4 relief valley (rust and grime collect), 5 cavity behind the holes (dark).
// The mesh is the left leaf in hinge-local metres (the right leaf mirrors it), so every pattern is
// laid out in model-space metres. Detail comes from grime.gdshaderinc, no bitmaps.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/shaders/grime.gdshaderinc"

// Leaf size and floor line in hinge-local metres, set by the builder.
uniform float leaf_width_m = 1.0;
uniform float leaf_bottom_y = 0.0;
uniform vec4 paint_color : source_color = vec4(0.17, 0.19, 0.185, 1.0);
uniform vec4 primer_color : source_color = vec4(0.2, 0.2, 0.195, 1.0);
uniform vec4 bare_steel_color : source_color = vec4(0.26, 0.26, 0.25, 1.0);
uniform vec4 hole_dark_color : source_color = vec4(0.03, 0.03, 0.028, 1.0);
uniform vec4 rust_color : source_color = vec4(0.09, 0.045, 0.025, 1.0);
uniform vec4 stain_color : source_color = vec4(0.04, 0.035, 0.03, 1.0);
uniform float roughness_paint = 0.86;
uniform float roughness_bare = 0.78;
uniform float metallic_paint = 0.12;
uniform float metallic_bare = 0.28;

varying vec3 v_pos;
varying flat float v_tag;
varying flat float v_street;

void vertex() {
	v_pos = VERTEX;
	v_tag = floor(COLOR.r * 8.0 + 0.5);
	v_street = NORMAL.z > 0.0 ? 1.0 : 0.0;
}

void fragment() {
	vec2 p = v_pos.xy;
	int tag = int(v_tag);
	float fw = max(fwidth(p.x), fwidth(p.y));
	float grit_vis = 1.0 - smoothstep(0.02, 0.05, fw);
	float grit = (fbm(p * 10.0) - 0.47) * 0.2 * grit_vis;
	// Nearness to the leaf's hinge, seam and floor edges, where paint wears first.
	float edge_d = min(min(p.x, leaf_width_m - p.x), p.y - leaf_bottom_y);
	float edge = 1.0 - smoothstep(0.0, 0.35, edge_d);
	float low = 1.0 - smoothstep(0.0, 1.0, p.y - leaf_bottom_y);
	// Rust runs down in streaks: noise stretched along y.
	float streak = smoothstep(0.5, 0.75, fbm(vec2(p.x * 22.0, p.y * 2.2) + vec2(3.1, 0.4)));
	float blot = smoothstep(0.55, 0.75, fbm(p * 3.0 + vec2(4.4, 0.7)));
	float rough = roughness_paint;
	float metal = metallic_paint;
	vec3 col;

	if (tag == 5) {
		col = hole_dark_color.rgb * (1.0 + grit);
		rough = 0.9;
	} else if (tag == 0) {
		// Street paint: faded, mottled, chipped at the edges, rust streaks from the seams.
		col = paint_color.rgb * (1.0 + grit);
		col *= 1.0 + 0.3 * smoothstep(0.62, 0.74, fbm(p * 24.0 + vec2(1.3, 8.8)));
		float chip = edge * smoothstep(0.5, 0.68, fbm(p * 18.0 + vec2(6.1, 3.4)));
		col = mix(col, bare_steel_color.rgb * 0.6, chip * 0.8);
		float rust = clamp(streak * (0.25 + edge + low * 0.5) + blot * 0.35, 0.0, 1.0);
		col = mix(col, rust_color.rgb, rust * 0.7);
		rough = mix(roughness_paint, 0.92, max(rust, blot));
		metal = mix(metallic_paint, metallic_bare, chip * 0.5);
	} else if (tag == 1) {
		// Cabin face: bare primer-grey steel, dirty low down and at the edges.
		col = primer_color.rgb * (1.0 + grit);
		col *= 1.0 - 0.1 * smoothstep(0.85, 1.0, p.x / leaf_width_m);
		float stain = smoothstep(0.55, 0.7, fbm(p * 4.0 + vec2(2.0, 7.0))) * (0.3 + low * 0.7);
		col = mix(col, stain_color.rgb, stain * 0.7);
		float rust = (low * 0.6 + edge * 0.4) * smoothstep(0.5, 0.72, fbm(p * 7.0 + vec2(8.3, 1.1)));
		col = mix(col, rust_color.rgb, rust * 0.7);
		float oil = smoothstep(0.7, 0.8, fbm(p * 3.0 + vec2(3.3, 6.6))) * 0.5;
		col = mix(col, stain_color.rgb, oil);
		rough = mix(roughness_bare, 0.92, max(max(rust, stain * 0.7), oil));
		metal = metallic_bare * 0.7;
	} else if (tag == 3) {
		// Relief crest: the pressed high spots wear to bright bare steel, with chips.
		col = primer_color.rgb * 1.3 * (1.0 + grit);
		float wear = smoothstep(0.45, 0.68, fbm(p * 14.0 + vec2(1.7, 9.2)));
		col = mix(col, bare_steel_color.rgb * 1.3, 0.5 + wear * 0.5);
		float chip = smoothstep(0.62, 0.74, fbm(p * 26.0 + vec2(6.1, 3.4)));
		col = mix(col, bare_steel_color.rgb * 1.25, chip * 0.5);
		rough = roughness_bare;
		metal = metallic_bare;
		if (v_street > 0.5) {
			// Street side: still painted, the paint just wears through on the high spots.
			vec3 paint = paint_color.rgb * (1.0 + grit) * 1.15;
			col = mix(paint, bare_steel_color.rgb * 1.2, clamp(wear * 0.55 + chip * 0.3, 0.0, 0.7));
			rough = mix(roughness_paint, roughness_bare, wear);
			metal = mix(metallic_paint, metallic_bare, wear * 0.5);
		}
	} else if (tag == 4) {
		// Relief valley: water and grime collect here, rust blooms.
		col = primer_color.rgb * 0.3 * (1.0 + grit);
		float rust = smoothstep(0.4, 0.65, fbm(p * 9.0 + vec2(2.0, 5.0)));
		col = mix(col, rust_color.rgb, rust * 0.8);
		col = mix(col, stain_color.rgb, blot * 0.6);
		rough = 0.9;
		metal = metallic_paint;
	} else {
		// Cut edge and rim: bare steel, rusty where it is worn.
		float worn = smoothstep(0.45, 0.7, fbm(p * 6.0 + vec2(2.0, 5.0)));
		col = bare_steel_color.rgb * (1.0 + grit * 1.5);
		col = mix(col, rust_color.rgb, worn * 0.5);
		rough = roughness_bare;
		metal = metallic_bare;
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.78, 0.95);
	METALLIC = clamp(metal, 0.0, 0.3);
}
