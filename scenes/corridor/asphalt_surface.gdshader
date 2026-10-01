shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Washed-out, trashed asphalt — loud grit, tire wear, oil, cracks, patches, litter.
// Patterns use world XZ so detail reads on BoxMesh tops regardless of UV scale.

#include "res://scenes/shaders/grime.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.09, 0.091, 0.088);
uniform vec3 grit_color : source_color = vec3(0.2, 0.19, 0.175);
uniform vec3 wear_color : source_color = vec3(0.22, 0.21, 0.19);
uniform vec3 oil_color : source_color = vec3(0.015, 0.014, 0.012);
uniform vec3 crack_color : source_color = vec3(0.02, 0.018, 0.016);
uniform vec3 patch_color : source_color = vec3(0.028, 0.026, 0.024);
uniform vec3 dirt_color : source_color = vec3(0.05, 0.045, 0.035);
uniform vec3 paper_color : source_color = vec3(0.42, 0.38, 0.3);
uniform vec3 can_color : source_color = vec3(0.25, 0.12, 0.06);
uniform vec3 plastic_color : source_color = vec3(0.12, 0.22, 0.18);
uniform vec3 skid_color : source_color = vec3(0.016, 0.016, 0.018);
uniform vec3 spill_color : source_color = vec3(0.010, 0.010, 0.011);
uniform vec3 scorch_color : source_color = vec3(0.012, 0.010, 0.009);
uniform vec3 ash_color : source_color = vec3(0.10, 0.095, 0.09);
uniform float skids : hint_range(0.0, 2.0) = 1.0;
uniform float spills : hint_range(0.0, 2.0) = 1.0;
uniform float scorches : hint_range(0.0, 2.0) = 1.0;
uniform float washout : hint_range(0.0, 1.0) = 0.35;
uniform float trash : hint_range(0.0, 1.0) = 0.95;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.94;
uniform float vertex_wreck : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world_pos;
varying float v_wreck;

// Rotated, warped fbm: the include's lattice is axis-aligned and shows as a grid.
vec2 rot2(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float fbm_r(vec2 p) {
	p = rot2(p, 0.61);
	p += (vec2(noise21(p * 0.5 + 7.3), noise21(p * 0.5 + 2.9)) - 0.5) * 0.8;
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amp * noise21(p);
		amp *= 0.5;
		p = rot2(p, 0.93) * 2.03 + vec2(17.3, 9.1);
	}
	return sum / 0.96875 * 0.9375;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// A BoxMesh has no colour array and reads COLOR as 1.0, so the uniform gates it.
	v_wreck = clamp(COLOR.r, 0.0, 1.0) * vertex_wreck;
}

// Rare tyre skids — two swerving rubber bands, patchy and streaked.
void skid_layer(vec2 p, inout vec3 col, inout float rough) {
	if (skids <= 0.0) {
		return;
	}
	float px = length(fwidth(p));
	float stri_fade = 1.0 - smoothstep(0.25, 0.6, px * 22.0);
	vec2 base = floor(p / 14.0);
	float mask = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			if (hash21(cell + 17.3) >= 0.18 * skids) {
				continue;
			}
			float ang = hash21(cell + 3.1) * TAU;
			vec2 ctr = (cell + mix(vec2(0.2), vec2(0.8), hash22(cell + 5.7))) * 14.0;
			vec2 dir = vec2(cos(ang), sin(ang));
			vec2 d = p - ctr;
			float t = dot(d, dir);
			float s = dot(d, vec2(-dir.y, dir.x));
			float len = 4.0 + 8.0 * hash21(cell + 9.9);
			float k = (hash21(cell + 11.3) - 0.5) * 0.06;
			float s_off = k * t * t;
			float band = max(
				1.0 - smoothstep(0.08, 0.11, abs(s - s_off - 0.85)),
				1.0 - smoothstep(0.08, 0.11, abs(s - s_off + 0.85))
			);
			float ends = smoothstep(0.0, 1.2, t) * (1.0 - smoothstep(len - 2.5, len, t));
			band *= ends * step(0.0, t) * step(t, len);
			float stri = mix(0.5, noise21(vec2(t * 0.6, s * 22.0)), stri_fade);
			band *= mix(0.55, 1.0, stri);
			band *= smoothstep(0.25, 0.6, fbm(p * 0.9 + cell));
			mask = max(mask, band);
		}
	}
	col = mix(col, skid_color, mask * 0.85);
	rough = mix(rough, 0.6, mask * 0.6);
}

// Rare burnouts — two or three overlapping partial tyre rings.
void burnout_layer(vec2 p, inout vec3 col, inout float rough) {
	if (skids <= 0.0) {
		return;
	}
	float px = length(fwidth(p));
	float stri_fade = 1.0 - smoothstep(0.25, 0.6, px * 22.0);
	vec2 base = floor(p / 26.0);
	float mask = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			if (hash21(cell + 21.7) >= 0.05 * skids) {
				continue;
			}
			vec2 ctr = (cell + mix(vec2(0.2), vec2(0.8), hash22(cell + 25.3))) * 26.0;
			int rings = 2 + int(step(0.5, hash21(cell + 2.2)));
			for (int r = 0; r < 3; r++) {
				if (r >= rings) {
					break;
				}
				float fr = float(r) * 7.7;
				vec2 rc = ctr + (hash22(cell + 40.0 + fr) - 0.5) * 1.2;
				float rad = 1.4 + hash21(cell + 50.0 + fr);
				float start = hash21(cell + 60.0 + fr) * TAU;
				float arc = radians(220.0 + 120.0 * hash21(cell + 70.0 + fr));
				vec2 d = p - rc;
				float dist = length(d);
				float rel = mod(atan(d.y, d.x) - start, TAU);
				float ring = 1.0 - smoothstep(0.08, 0.12, abs(dist - rad));
				ring *= 1.0 - smoothstep(arc - 0.12, arc, rel);
				float stri = mix(0.5, noise21(vec2(rel * rad * 0.6, (dist - rad) * 22.0)), stri_fade);
				ring *= mix(0.55, 1.0, stri);
				ring *= smoothstep(0.25, 0.6, fbm(p * 0.9 + cell));
				mask = max(mask, ring);
			}
		}
	}
	col = mix(col, skid_color, mask * 0.85);
	rough = mix(rough, 0.6, mask * 0.6);
}

// Rare big oil spills — a wet blob with a drip trail of shrinking drops.
void spill_layer(vec2 p, inout vec3 col, inout float rough, inout float metal) {
	if (spills <= 0.0) {
		return;
	}
	vec2 base = floor(p / 18.0);
	float mask = 0.0;
	float rim = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			if (hash21(cell + 13.1) >= 0.12 * spills) {
				continue;
			}
			vec2 ctr = (cell + mix(vec2(0.2), vec2(0.8), hash22(cell + 15.9))) * 18.0;
			float rad = 0.8 + 1.4 * hash21(cell + 19.3);
			vec2 d = p - ctr;
			float dist = length(d) + (fbm(p * 1.3 + cell) - 0.5) * 0.8 * rad;
			float blob = 1.0 - smoothstep(rad - 0.15, rad, dist);
			rim = max(rim, smoothstep(rad - 0.02, rad, dist) * (1.0 - smoothstep(rad + 0.03, rad + 0.05, dist)));
			float tang = hash21(cell + 23.7) * TAU;
			vec2 tdir = vec2(cos(tang), sin(tang));
			float tlen = 2.0 + 3.0 * hash21(cell + 27.1);
			float u = dot(d, tdir);
			float v = dot(d, vec2(-tdir.y, tdir.x));
			float du = (fract(u / 0.35) - 0.5) * 0.35;
			float drop_r = mix(0.14, 0.06, clamp(u / tlen, 0.0, 1.0));
			float drop = 1.0 - smoothstep(drop_r - 0.02, drop_r, length(vec2(du, v)));
			drop *= step(0.0, u) * step(u, tlen) * step(abs(v), drop_r);
			mask = max(mask, max(blob, drop));
		}
	}
	col = mix(col, spill_color, mask * 0.92);
	col *= 1.0 - 0.25 * rim;
	rough = mix(rough, 0.3, mask);
	metal = mix(metal, 0.25, mask);
}

// Rare scorched patches — burnt tar, ash speckle and a melted rim.
void scorch_layer(vec2 p, inout vec3 col, inout float rough) {
	if (scorches <= 0.0) {
		return;
	}
	float px = length(fwidth(p));
	float ash_fade = smoothstep(0.35, 0.8, px * 9.0);
	vec2 base = floor(p / 22.0);
	float mask = 0.0;
	float melt = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			if (hash21(cell + 29.3) >= 0.06 * scorches) {
				continue;
			}
			vec2 ctr = (cell + mix(vec2(0.2), vec2(0.8), hash22(cell + 33.1))) * 22.0;
			float rad = 1.0 + 1.5 * hash21(cell + 37.9);
			float dist = length(p - ctr) + (fbm(p * 1.3 + cell) - 0.5) * 0.8 * rad;
			mask = max(mask, 1.0 - smoothstep(rad - 0.6, rad, dist));
			melt = max(melt, smoothstep(0.85 * rad, 0.9 * rad, dist)
				* (1.0 - smoothstep(0.9 * rad, 0.95 * rad, dist)));
		}
	}
	float ash = mix(step(0.86, hash21(floor(p * 9.0))), 0.14, ash_fade);
	col = mix(col, scorch_color, mask);
	col = mix(col, ash_color, ash * mask * 0.5);
	rough = mix(rough, 0.95, mask * (1.0 - melt));
	rough = mix(rough, 0.55, melt);
}

void fragment() {
	vec2 pos = v_world_pos.xz;

	// Aggregate grit — strong pebble contrast.
	float grit_n = fbm_r(pos * 4.5 + vec2(3.1, 1.7));
	float grit = smoothstep(0.3, 0.7, grit_n);
	float grain = noise21(rot2(pos, 0.47) * 28.0);

	// Longitudinal tire lanes — clear polished bands.
	float lane_l = exp(-pow((pos.x + 1.4) / 0.7, 2.0));
	float lane_r = exp(-pow((pos.x - 1.4) / 0.7, 2.0));
	float lane_c = exp(-pow(pos.x / 0.95, 2.0)) * 0.65;
	float tire_mod = 0.45 + 0.55 * fbm_r(vec2(pos.x * 0.35, pos.y * 0.08) + 4.0);
	float tire = clamp(lane_l + lane_r + lane_c, 0.0, 1.0) * tire_mod;

	// Oil / grease puddles — lower threshold so they show up.
	float blotch_a = fbm_r(pos * 0.55 + vec2(8.7, 3.2));
	float blotch_b = fbm_r(pos * 1.1 + vec2(2.4, 14.0));
	float oil = max(
		smoothstep(0.55, 0.78, blotch_a),
		smoothstep(0.62, 0.85, blotch_b) * 0.7
	) * trash;

	// Repair patches — irregular darker asphalt blobs (not rectangles).
	// Each patch is evaluated from its 3x3 neighbour cells so it is never cut at a cell edge.
	float patch = 0.0;
	for (int py = -1; py <= 1; py++) {
		for (int px = -1; px <= 1; px++) {
			vec2 patch_cell = floor(pos / vec2(3.2, 3.8)) + vec2(float(px), float(py));
			float patch_roll = hash21(patch_cell + 7.0);
			float patch_mask = step(0.62, patch_roll) * trash;
			vec2 patch_local = pos / vec2(3.2, 3.8) - patch_cell - 0.5;
			vec2 patch_off = (hash22(patch_cell + 3.0) - 0.5) * 0.28;
			vec2 patch_p = patch_local - patch_off;
			float patch_ang = hash21(patch_cell + 5.0) * 6.28318;
			float pca = cos(patch_ang);
			float psa = sin(patch_ang);
			patch_p = vec2(pca * patch_p.x - psa * patch_p.y, psa * patch_p.x + pca * patch_p.y);
			vec2 patch_stretch = vec2(0.7, 1.15) + hash22(patch_cell + 9.0) * vec2(0.45, 0.35);
			float patch_r = length(patch_p / patch_stretch);
			float patch_warp = fbm_r(pos * 2.2 + patch_cell) * 0.22;
			float patch_shape = 1.0 - smoothstep(0.22 + patch_warp, 0.38 + patch_warp * 0.5, patch_r);
			float patch_fill = patch_mask * patch_shape
				* (0.7 + 0.3 * fbm_r(pos * 1.4 + patch_cell));
			patch = max(patch, patch_fill);
		}
	}

	// Cracks — full-strength seams, but only on ~40% of the road.
	float crack_coverage = smoothstep(0.56, 0.64, fbm_r(pos * 0.22 + 11.0));
	float cf = crack_field(rot2(pos, 0.38) * 0.85 + 2.3);
	float cracks = 1.0 - smoothstep(0.02, 0.08, cf);
	cracks *= crack_coverage * trash;

	// Secondary hairline cracks (same coverage mask).
	float cf2 = crack_field(rot2(pos, 1.07) * 1.6 + 9.1);
	float hair = (1.0 - smoothstep(0.01, 0.04, cf2))
		* smoothstep(0.5, 0.8, fbm_r(pos * 0.5 + 5.0)) * crack_coverage * trash * 0.7;
	cracks = max(cracks, hair);

	// Edge dirt / gutter runoff.
	float edge_dirt = smoothstep(4.5, 7.5, abs(pos.x));
	edge_dirt *= 0.4 + 0.6 * fbm_r(vec2(pos.x * 0.6, pos.y * 0.2) + 6.0);

	// --- Litter (paper, cans, plastic, debris) --------------------------------
	vec2 litter_cell = floor(pos / 1.35);
	vec2 litter_f = fract(pos / 1.35) - 0.5;
	vec2 litter_id = litter_cell + 31.0;
	float litter_roll = hash21(litter_id);
	float litter_on = step(1.0 - 0.22 * trash, litter_roll); // ~22% cells at trash=1
	vec2 litter_off = (hash22(litter_id + 1.0) - 0.5) * 0.3;
	vec2 litter_p = litter_f - litter_off;
	float litter_ang = hash21(litter_id + 2.0) * 6.28318;
	float ca = cos(litter_ang);
	float sa = sin(litter_ang);
	litter_p = vec2(ca * litter_p.x - sa * litter_p.y, sa * litter_p.x + ca * litter_p.y);
	float litter_kind = hash21(litter_id + 4.0);

	float paper = 0.0;
	float can = 0.0;
	float plastic = 0.0;
	float debris = 0.0;

	if (litter_on > 0.5) {
		if (litter_kind < 0.35) {
			// Crumpled paper scrap — soft rectangle.
			vec2 paper_sz = vec2(0.12, 0.08) + hash22(litter_id + 5.0) * 0.1;
			vec2 pd = abs(litter_p) / paper_sz;
			float rect = 1.0 - smoothstep(0.75, 1.05, max(pd.x, pd.y));
			float crumple = 0.7 + 0.3 * noise21(rot2(litter_p, 0.47) * 40.0 + litter_id);
			paper = rect * crumple;
		} else if (litter_kind < 0.55) {
			// Can / bottle silhouette.
			float el = length(litter_p / vec2(0.07, 0.12));
			can = 1.0 - smoothstep(0.75, 1.05, el);
		} else if (litter_kind < 0.75) {
			// Plastic bag / wrapper smear.
			float bag = fbm_r(litter_p * 8.0 + litter_id);
			plastic = (1.0 - smoothstep(0.12, 0.28, length(litter_p)))
				* smoothstep(0.35, 0.7, bag);
		} else {
			// Small debris cluster.
			float d1 = 1.0 - smoothstep(0.02, 0.05, length(litter_p - vec2(0.04, 0.02)));
			float d2 = 1.0 - smoothstep(0.015, 0.04, length(litter_p + vec2(0.05, -0.03)));
			float d3 = 1.0 - smoothstep(0.01, 0.03, length(litter_p + vec2(-0.03, 0.05)));
			debris = max(d1, max(d2, d3));
		}
	}

	float bleach = washout * (0.25 + 0.75 * fbm_r(pos * 0.15 + vec2(1.5, 9.0)));

	vec3 color = base_color;
	color = mix(color, grit_color, grit * 0.7);
	color = mix(color, wear_color, tire * 0.85);
	color = mix(color, patch_color, patch * 1.0);
	color = mix(color, oil_color, oil * 0.95);

	// Rare marks: skids, burnouts, big oil spills, scorches.
	float rough = roughness_value
		- tire * 0.14
		+ grit * 0.05
		+ oil * 0.12
		+ edge_dirt * 0.06
		- cracks * 0.08
		- paper * 0.1
		- can * 0.2;
	float metal = 0.02 + oil * 0.18 + can * 0.35;
	skid_layer(pos, color, rough);
	burnout_layer(pos, color, rough);
	spill_layer(pos, color, rough, metal);
	scorch_layer(pos, color, rough);

	color = mix(color, dirt_color, edge_dirt * 0.75);
	color = mix(color, crack_color, cracks * 0.95);

	// Litter colors on top.
	color = mix(color, paper_color, paper * 0.9);
	color = mix(color, can_color, can * 0.95);
	color = mix(color, plastic_color, plastic * 0.85);
	color = mix(color, vec3(0.04, 0.038, 0.03), debris * 0.9);

	// Micro grain.
	color *= 0.82 + 0.32 * grain;

	// Mild washout — keep feature contrast.
	color = mix(color, vec3(0.16, 0.155, 0.145), bleach * 0.2);
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma), washout * 0.12);

	// Broken road-edge asphalt: dust film plus crumbled dark patches (vertex_wreck gated).
	float crumble = v_wreck * smoothstep(0.4, 0.75, fbm_r(pos * 6.0 + 11.0));
	color = mix(color, vec3(0.10, 0.09, 0.075), v_wreck * 0.35);
	color = mix(color, crack_color, crumble * 0.6);
	rough = min(rough + v_wreck * 0.04, 0.95);

	ALBEDO = color;
	METALLIC = metal;
	ROUGHNESS = clamp(rough, 0.3, 1.0);

	float n_x = (grit_n - 0.5) * 0.55 + cracks * 0.7 + oil * 0.15
		+ crumble * 0.4;
	float n_y = (fbm_r(pos * 3.5 + 3.0) - 0.5) * 0.45 + cracks * 0.4
		+ crumble * 0.25;
	n_x += (paper + can + plastic) * 0.35;
	NORMAL_MAP = normalize(vec3(n_x, n_y, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.75;
}
