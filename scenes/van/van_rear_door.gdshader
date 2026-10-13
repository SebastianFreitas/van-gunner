// Rear door leaf: scrapyard rusty steel, one part with the rust-steel surround around it
// (van_rust_steel.gdshader: same palette, scale flakes, pits, streaks and pitting normal map).
// The street face is about 60% heavy rust; faded grey-green paint survives only in islands away
// from the edges, seams and the bottom, with a thin darker lip. The cabin face is mostly bare
// rusty steel with a few grey primer patches on the flat beams. The mesh builders tag every
// vertex (COLOR.r = tag / 8, see rear_door_skin.gd), so no face is guessed from its normal or
// depth and sloped relief keeps its meaning:
// 0 street, 1 cabin, 2 cut edge / rim (bare rusty steel), 3 relief crest (worn bright steel),
// 4 relief valley (deepest rust and grime), 5 cavity behind the holes (near black).
// The mesh is the left leaf in hinge-local metres (the right leaf mirrors it), so every pattern is
// laid out in model-space metres. Detail comes from grime.gdshaderinc, no bitmaps.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/shaders/grime.gdshaderinc"

// Leaf size and floor line in hinge-local metres, set by the builder.
uniform float leaf_width_m = 1.0;
uniform float leaf_bottom_y = 0.0;
// Per-leaf noise offset in metres, so the mirrored leaves get different patterns.
uniform vec2 leaf_offset = vec2(0.0);
// Rust palette shared with van_rust_steel.gdshader.
uniform vec3 steel_color : source_color = vec3(0.075, 0.08, 0.08);
uniform vec3 scale_color : source_color = vec3(0.035, 0.04, 0.045);
uniform vec3 rust_color : source_color = vec3(0.21, 0.075, 0.028);
uniform vec3 deep_rust_color : source_color = vec3(0.09, 0.03, 0.012);
uniform vec3 bright_steel_color : source_color = vec3(0.2, 0.16, 0.12);
uniform vec3 paint_color : source_color = vec3(0.17, 0.19, 0.185);
uniform vec3 primer_color : source_color = vec3(0.2, 0.2, 0.195);
uniform vec3 hole_dark_color : source_color = vec3(0.03, 0.03, 0.028);
// Street-face paint: share of the leaf the islands cover (0.5 = original) and their size.
uniform float paint_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float paint_island_scale = 1.8;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.86;
uniform float metallic_value : hint_range(0.0, 0.6) = 0.22;
// Scales the rust base and the streaks on both faces (1 = original).
uniform float rust_amount : hint_range(0.0, 1.0) = 1.0;
// 1 gives the cabin face the street face's paint system too (0 = bare rust and primer only).
uniform float cabin_paint : hint_range(0.0, 1.0) = 0.0;
// Cabin-face band (leaf-local x, metres) painted solid out to the seam-side beam; off when x1 <= x0.
uniform float crest_paint_x0 = 0.0;
uniform float crest_paint_x1 = 0.0;

varying vec3 v_pos;
varying flat float v_tag;
varying flat float v_street;
varying vec3 v_nrm;
varying float v_lip;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
	v_lip = COLOR.g;
	v_tag = floor(COLOR.r * 8.0 + 0.5);
	v_street = NORMAL.z > 0.0 ? 1.0 : 0.0;
}

void fragment() {
	vec2 p = v_pos.xy;
	vec2 q = p + leaf_offset;
	int tag = int(v_tag);
	float fw = max(fwidth(p.x), fwidth(p.y));
	float fine_vis = 1.0 - smoothstep(0.04, 0.1, fw);
	// Nearness to the leaf's hinge, seam and floor edges, where the paint goes first.
	float edge_d = min(min(p.x, leaf_width_m - p.x), p.y - leaf_bottom_y);
	float edge = 1.0 - smoothstep(0.0, 0.4, edge_d);
	float low = 1.0 - smoothstep(0.0, 1.2, p.y - leaf_bottom_y);

	// Rust base, the surround's recipe: blotches, fine breakup, pits, mill-scale streaks.
	float blotch = fbm(q * 3.2 + 3.0);
	float fine = fbm(q * 14.0 + 11.0);
	float pits = smoothstep(0.7, 0.9, noise21(q * 30.0)) * fine_vis;
	float streak = fbm(vec2(q.x * 14.0, q.y * 1.4) + 5.5);
	float rust = smoothstep(0.34, 0.66, blotch + low * 0.2 + (fine - 0.5) * 0.3);
	rust = clamp(rust + edge * 0.35, 0.0, 1.0) * rust_amount;
	float deep = smoothstep(0.55, 1.0, rust) * (0.5 + 0.5 * pits + 0.3 * fine);

	vec3 col = mix(steel_color, scale_color, smoothstep(0.35, 0.8, streak) * 0.8 * rust_amount);
	col = mix(col, rust_color, rust * 0.9);
	col = mix(col, deep_rust_color, deep * 0.7);
	col = mix(col, vec3(0.01), pits * rust * 0.5);
	col *= 0.9 + 0.2 * noise21(q * 30.0 + 7.0) * fine_vis + 0.1 * (1.0 - fine_vis);
	float rough = roughness_value - (1.0 - rust) * 0.1 + pits * 0.08;
	float metal = metallic_value * (1.0 - rust * 0.8);

	if (tag == 5) {
		col = hole_dark_color * (0.8 + 0.4 * fine);
		rough = 0.9;
		metal = 0.0;
	} else if (tag == 0) {
		// Street face: heavy rust that runs down in streaks, paint islands in the clear middle.
		float run = smoothstep(0.5, 0.75, fbm(vec2(q.x * 22.0, q.y * 2.2) + vec2(3.1, 0.4)))
				* rust_amount;
		float island = smoothstep(1.0 - paint_coverage, 1.1 - paint_coverage,
				fbm(q * paint_island_scale + vec2(9.4, 2.6)) + 0.08 * (fine - 0.5));
		island *= smoothstep(0.2, 0.6, edge_d) * (1.0 - run * 0.8);
		float on = smoothstep(0.15, 0.4, island);
		// A thin darker lip where the paint peels back.
		float lip = on * (1.0 - smoothstep(0.4, 0.7, island));
		vec3 paint = paint_color * (0.85 + 0.3 * fine);
		paint = mix(paint, paint * 0.55, lip * fine_vis);
		col = mix(col, rust_color * 0.8, run * 0.4 * (1.0 - on));
		col = mix(col, paint, on);
		rough = mix(rough, 0.88, on);
		metal = mix(metal, 0.1, on);
	} else if (tag == 1) {
		// Cabin face: mostly bare rusty steel, a few primer-grey patches, grime low down.
		float on = 0.0;
		if (cabin_paint > 0.0) {
			// Same paint system as the street face, mirrored pattern offset so the faces differ.
			float run = smoothstep(0.5, 0.75, fbm(vec2(q.x * 22.0, q.y * 2.2) + vec2(5.3, 1.9)))
					* rust_amount;
			float island = smoothstep(1.0 - paint_coverage, 1.1 - paint_coverage,
					fbm(q * paint_island_scale + vec2(4.1, 7.7)) + 0.08 * (fine - 0.5));
			island *= smoothstep(0.2, 0.6, edge_d) * (1.0 - run * 0.8);
			on = smoothstep(0.15, 0.4, island);
			// The unpressed seam-side crest is painted solid, not faded by the seam or the islands.
			float band = smoothstep(crest_paint_x0, crest_paint_x0 + 0.02, p.x)
					* (1.0 - step(crest_paint_x1, p.x))
					* step(0.0001, crest_paint_x1 - crest_paint_x0);
			on = max(on, band) * cabin_paint;
			float lip = on * (1.0 - smoothstep(0.4, 0.7, island)) * (1.0 - band);
			vec3 paint = paint_color * (0.85 + 0.3 * fine);
			paint = mix(paint, paint * 0.55, lip * fine_vis);
			col = mix(col, rust_color * 0.8, run * 0.4 * (1.0 - on) * cabin_paint);
			col = mix(col, paint, on);
			rough = mix(rough, 0.88, on);
			metal = mix(metal, 0.1, on);
		}
		float patch = smoothstep(0.6, 0.7, fbm(q * 2.4 + vec2(2.0, 7.0)) + 0.1 * (fine - 0.5));
		patch *= 1.0 - edge * 0.8;
		vec3 primer = primer_color * (0.85 + 0.3 * fine);
		col = mix(col, primer, patch * 0.85);
		col = mix(col, deep_rust_color, low * 0.3 * (1.0 - patch) * (1.0 - on));
		rough = mix(rough, 0.84, patch);
		metal = mix(metal, 0.12, patch);
	} else if (tag == 3) {
		// Relief crest: rust worn through to brighter bare steel, with chips.
		float wear = smoothstep(0.42, 0.68, fbm(q * 14.0 + vec2(1.7, 9.2)));
		float chip = smoothstep(0.62, 0.74, fbm(q * 24.0 + vec2(6.1, 3.4))) * fine_vis;
		col = mix(col, bright_steel_color, clamp(0.3 + wear * 0.5 + chip * 0.2, 0.0, 0.85));
		rough = 0.8;
		metal = 0.28;
	} else if (tag == 4) {
		// Relief valley: water and grime collect here, the deepest rust.
		col = mix(deep_rust_color, scale_color, smoothstep(0.4, 0.8, streak) * 0.5);
		col = mix(col, rust_color * 0.6, (1.0 - deep) * 0.3);
		col *= 0.7 + 0.3 * fine;
		rough = 0.92;
		metal = 0.05;
	} else if (tag == 6) {
		// Donor window wall and pressed step: dark worn painted steel like the rest of the leaf.
		// The wall runs along z, so wear is laid out along the hole's perimeter (the tangent of the
		// wall's own xy normal) and across the depth; COLOR.g is the lip weight (1 at the step's
		// crest where it meets the cabin face, 0 on the tunnel) and bared steel gathers there.
		vec2 wn = normalize(v_nrm.xy + vec2(0.0001));
		float along = dot(p, vec2(-wn.y, wn.x));
		// Streaks are long across `along` and fine across z, so they circle the hole; the
		// generic x-running `streak` is left out (it ran glass to cabin like wood grain).
		float grain = mix(0.5, fbm(vec2(along * 2.5, v_pos.z * 160.0) + vec2(4.7, 1.3)), fine_vis);
		float blotch_w = fbm(vec2(along * 3.0, v_pos.z * 14.0) + vec2(8.2, 2.9));
		float grime = smoothstep(0.35, 0.7, blotch_w);
		float loss = smoothstep(0.55, 0.8, fbm(vec2(along * 5.0, v_pos.z * 30.0) + vec2(1.1, 6.3)));
		// Near-black grime, dark worn paint, a little rust where the paint is gone.
		vec3 paint = paint_color * 0.14 * (0.75 + 0.5 * grain);
		col = mix(paint, vec3(0.012, 0.012, 0.011), grime * 0.7);
		col = mix(col, deep_rust_color * 0.5, loss * 0.5);
		// Bare steel rim on the step's crest: chipped, not an even line.
		float lip = clamp(v_lip, 0.0, 1.0);
		float chip = fbm(vec2(along * 70.0, lip * 6.0) + vec2(3.3, 8.8));
		float bare = smoothstep(0.45, 0.62, lip - 0.12 * (1.0 - chip) + 0.25 * (chip - 0.5))
				* smoothstep(0.3, 0.5, chip + 0.35 * lip);
		col = mix(col, vec3(0.3, 0.28, 0.25) * (0.8 + 0.4 * chip), bare * 0.9);
		// The hole's bottom wall faces up into the light from both sides: keep it darkest.
		col *= mix(1.0, 0.2, smoothstep(0.3, 0.7, v_nrm.y) * (1.0 - bare));
		rough = mix(0.88, 0.8, bare);
		metal = 0.28 * bare;
		streak = grain;
	} else {
		// Cut edge and rim: bare steel gone rusty.
		col = mix(col, steel_color * 1.4, (1.0 - rust) * 0.5);
		col = mix(col, rust_color * 0.9, 0.3);
		rough = 0.82;
		metal = 0.2;
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.78, 0.95);
	METALLIC = clamp(metal, 0.0, 0.3);
	NORMAL_MAP = vec3((streak - 0.5) * 0.2 + 0.5, (pits - 0.5) * 0.2 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.6;
}
