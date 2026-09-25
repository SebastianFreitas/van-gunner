shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The war rig's outer skin: painted panels with hull seams, wear through to primer and bare
// metal, rust, rain streaks, scratches and a road-dirt sill band, all in model-space metres.
// `plate_mode` swaps the hull seams for a single welded armour plate (weld bead, heat tint,
// bolts) for patch panels bolted onto the hull.

#include "res://scenes/shaders/grime.gdshaderinc"

uniform vec3 paint_color : source_color = vec3(0.29, 0.30, 0.22);
uniform vec3 accent_color : source_color = vec3(0.20, 0.21, 0.16);
uniform vec3 primer_color : source_color = vec3(0.36, 0.33, 0.30);
uniform vec3 metal_color : source_color = vec3(0.40, 0.39, 0.37);
uniform vec3 rust_color : source_color = vec3(0.30, 0.105, 0.045);
uniform vec3 dirt_color : source_color = vec3(0.07, 0.06, 0.05);
uniform vec3 weld_color : source_color = vec3(0.12, 0.11, 0.10);
uniform vec3 heat_color : source_color = vec3(0.22, 0.17, 0.20);

/// Metres per model unit; scales every model-space coordinate.
uniform float surface_size_m = 1.0;
/// Vertical panel seams along the hull, in metres.
uniform float seam_spacing_m = 1.2;
uniform float sill_y_m = 0.0;
/// Height above the sill the road dirt reaches.
uniform float dirt_band_m = 0.7;
/// Model-space y range of a painted accent stripe; set x > y to disable.
uniform vec2 accent_band = vec2(1.1, 1.35);
/// Overall primer/bare-metal/rust amount.
uniform float wear : hint_range(0.0, 1.0) = 0.5;
/// Shifts every noise lookup so two vans don't share blotches.
uniform vec2 seed_offset = vec2(0.0, 0.0);

uniform bool plate_mode = false;
/// A plate's UV 0..1 spans this many metres.
uniform vec2 plate_size_m = vec2(1.0, 0.6);
uniform float bolt_spacing_m = 0.25;

uniform float roughness_min : hint_range(0.0, 1.0) = 0.78;
uniform float roughness_max : hint_range(0.0, 1.0) = 0.95;
uniform float metallic_max : hint_range(0.0, 1.0) = 0.3;

varying vec3 v_pos_m;
varying vec3 v_nrm;


void vertex() {
	v_pos_m = VERTEX * surface_size_m;
	v_nrm = NORMAL;
}


// A thin plate weld bead, heat tint and bolt row around the plate's UV edges.
void plate_detail(vec2 uv_m, inout vec3 col, inout float rust_bias, inout float rough_hint) {
	vec2 half_size = plate_size_m * 0.5;
	vec2 local = uv_m - half_size;
	vec2 to_edge = half_size - abs(local);
	float e = min(to_edge.x, to_edge.y);

	float bead = 1.0 - smoothstep(0.015, 0.02, e);
	float bead_fade = 1.0 - smoothstep(0.3, 1.0, fwidth(e * 40.0));
	bead *= bead_fade;
	float bead_noise = noise21((uv_m + seed_offset) * 30.0);
	col = mix(col, weld_color * (0.85 + 0.3 * bead_noise), bead * 0.9);
	rough_hint = mix(rough_hint, 1.0, bead * 0.6);

	float heat = smoothstep(0.02, 0.08, e) * (1.0 - smoothstep(0.08, 0.14, e));
	col = mix(col, mix(col, heat_color, 0.35), heat);

	rust_bias += bead * 0.6;

	// Bolt heads every bolt_spacing_m, inset 0.05 m from each edge.
	for (int axis = 0; axis < 2; axis++) {
		float along = axis == 0 ? local.x : local.y;
		float across = axis == 0 ? to_edge.y : to_edge.x;
		float inset = across - 0.05;
		float near_edge = 1.0 - smoothstep(0.0, 0.01, abs(inset));
		float cell = round(along / bolt_spacing_m) * bolt_spacing_m;
		float d = length(vec2(along - cell, inset));
		float bolt_mask = (1.0 - smoothstep(0.010, 0.014, d)) * near_edge;
		float bolt_fade = 1.0 - smoothstep(0.3, 1.0, fwidth(along * (1.0 / bolt_spacing_m)));
		bolt_mask *= bolt_fade;
		float ring = (1.0 - smoothstep(0.007, 0.010, d)) * near_edge * bolt_fade;
		col = mix(col, metal_color * 0.6, bolt_mask * 0.8);
		col = mix(col, weld_color, ring * 0.5);
	}
}


void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 an = abs(n);
	vec2 p;
	float h;
	bool side_face = true;
	if (an.x >= an.y && an.x >= an.z) {
		p = v_pos_m.zy;
		h = v_pos_m.z;
	} else if (an.y >= an.z) {
		p = v_pos_m.xz;
		h = v_pos_m.x;
		side_face = false;
	} else {
		p = v_pos_m.xy;
		h = v_pos_m.x;
	}
	float y = v_pos_m.y;
	vec2 ps = p + seed_offset;

	vec3 col = paint_color;

	// Painted accent stripe, brushed by fbm so its edge isn't a hard line.
	float brush = fbm(ps * 3.0) - 0.5;
	float lo = smoothstep(accent_band.x - 0.02, accent_band.x + 0.02, y + brush * 0.03);
	float hi = 1.0 - smoothstep(accent_band.y - 0.02, accent_band.y + 0.02, y + brush * 0.03);
	float accent = clamp(lo * hi, 0.0, 1.0);
	col = mix(col, accent_color, accent);

	// Hull seams (skipped in plate mode, which has its own edge).
	float seam_bias = 0.0;
	if (!plate_mode) {
		float seam_pos = h / seam_spacing_m;
		float dist = abs(fract(seam_pos + 0.5) - 0.5) * seam_spacing_m;
		float seam = 1.0 - smoothstep(0.0, 0.015, dist);
		seam_bias = 1.0 - smoothstep(0.0, 0.25, dist);
		col = mix(col, dirt_color, seam * 0.6);
	}

	// Wear: primer patches, bare metal chips, rust blooms; all scaled by wear.
	float primer_mask = smoothstep(0.62 - 0.12 * wear, 0.72 - 0.12 * wear, fbm(ps * 0.6)) * wear;
	col = mix(col, primer_color, primer_mask);

	float chip_noise = fbm(ps * 4.0);
	float chip_mask = smoothstep(0.55, 0.85, chip_noise + seam_bias * 0.3) * wear;
	float metallic_out = chip_mask * metallic_max;
	col = mix(col, metal_color, chip_mask * 0.7);

	float near_sill = 1.0 - smoothstep(0.0, dirt_band_m * 1.6, y - sill_y_m);
	float rust_bias = seam_bias * 0.5 + near_sill * 0.4;

	float rough_hint = 0.0;
	if (plate_mode) {
		plate_detail(p, col, rust_bias, rough_hint);
	}

	float rust = smoothstep(0.62, 0.85, fbm(ps * 1.1 + 13.0) + rust_bias * 0.25) * wear;
	col = mix(col, rust_color, rust * 0.6);
	metallic_out = mix(metallic_out, 0.0, rust);

	// Rain streaks on side faces only.
	if (side_face) {
		float streak = noise21(vec2(h * 9.0, y * 0.35) + seed_offset);
		float streak_mask = smoothstep(0.6, 0.85, streak);
		col = mix(col, dirt_color, streak_mask * 0.35);
	}

	// Scratches: thin near-horizontal lines, faded with distance.
	float scratch_line = abs(fract(y * 23.0 + noise21(ps * vec2(0.8, 6.0)) * 0.7) - 0.5);
	float scratch_mask = (1.0 - smoothstep(0.010, 0.015, scratch_line))
		* smoothstep(0.7, 0.9, noise21(ps * 1.3));
	scratch_mask *= 1.0 - smoothstep(0.3, 1.0, fwidth(y * 23.0));
	col = mix(col, metal_color, scratch_mask * 0.5);

	// Sill dirt band, broken by fbm.
	float band = dirt_band_m * (0.7 + 0.3 * fbm(vec2(h * 1.5, 3.0) + seed_offset));
	float sill = 1.0 - smoothstep(sill_y_m, sill_y_m + band, y);
	col = mix(col, dirt_color, sill * 0.85);
	if (!side_face && n.y > 0.5) {
		col = mix(col, dirt_color, 0.3);
	}

	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	if (lum > 0.4) {
		col *= 0.4 / lum;
	}
	ALBEDO = col;

	float rough = roughness_max - chip_mask * (roughness_max - roughness_min);
	rough = mix(rough, roughness_max, rust * 0.5 + rough_hint * 0.5);
	ROUGHNESS = clamp(rough, roughness_min, roughness_max);
	METALLIC = clamp(metallic_out, 0.0, metallic_max);
}
