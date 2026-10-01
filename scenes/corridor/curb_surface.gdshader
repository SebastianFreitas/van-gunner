// Curb and gutter grime in the road's recipe: worn concrete kerb with joints, chipped
// edges, tyre scuffs and old faded paint (mode 0); black sludge, wet patches and leaf
// litter (mode 1). Patterns lie in model-space metres, so the boxes must be unscaled,
// centred BoxMeshes with the long side along z. Every pattern finer than ~0.25 m fades
// with fwidth.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/shaders/grime.gdshaderinc"

uniform int mode = 0; // 0 curb, 1 gutter
uniform vec3 base_color : source_color = vec3(0.30, 0.29, 0.265);
uniform vec3 joint_color : source_color = vec3(0.06, 0.058, 0.055);
uniform vec3 scuff_color : source_color = vec3(0.025, 0.025, 0.027);
uniform vec3 dirt_color : source_color = vec3(0.07, 0.065, 0.055);
uniform vec3 paint_a : source_color = vec3(0.55, 0.45, 0.12); // faded kerb yellow
uniform vec3 paint_b : source_color = vec3(0.45, 0.12, 0.10); // faded kerb red
uniform vec3 paint_c : source_color = vec3(0.52, 0.51, 0.48); // dirty white
uniform vec3 sludge_color : source_color = vec3(0.035, 0.034, 0.03);
uniform vec3 leaf_color : source_color = vec3(0.08, 0.06, 0.035);
uniform float joint_spacing_m = 1.2;
uniform float paint_amount : hint_range(0.0, 1.0) = 0.35;

varying vec3 v_pos;
varying vec3 v_nrm;
varying vec2 v_off;
// Half width (x) and half height (y): constant over every face of a centred box.
varying vec2 v_half;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
	vec2 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	v_off = hash22(floor(world_origin)) * 100.0;
	v_half = vec2(abs(VERTEX.x), abs(VERTEX.y));
}

// 1 while a pattern of period 1 in p is still wider than ~2 px, 0 once it is finer.
float fine_fade(vec2 p) {
	vec2 w = fwidth(p);
	return 1.0 - smoothstep(0.3, 0.8, max(w.x, w.y));
}

void fragment() {
	vec3 an = abs(v_nrm);
	bool top = an.y > an.x && an.y > an.z;
	bool xface = !top && an.x >= an.z;
	vec2 fq = vec2(v_pos.x, v_pos.y);
	if (top) {
		fq = vec2(v_pos.x, v_pos.z);
	} else if (xface) {
		fq = vec2(v_pos.z, v_pos.y);
	}
	vec2 q = fq + v_off;
	float along = v_pos.z;

	// Derivatives first, outside any per-face branch.
	float fw_along = fwidth(along);
	float fw_up = fwidth(v_pos.y);
	float fw_across = fwidth(v_pos.x);
	float aa = max(fwidth(q.x), fwidth(q.y));
	float f_grit = fine_fade(q * 40.0);
	float f_chip = fine_fade(vec2(along * 8.0));
	float edge_d = 1.0;
	if (top) {
		edge_d = v_half.x - abs(v_pos.x);
	} else if (xface) {
		edge_d = v_half.y - v_pos.y;
	}
	float fw_edge = fwidth(edge_d);

	vec3 col;
	float rough = 0.9;
	float metal = 0.0;

	if (mode == 0) {
		// a. base and grit
		col = base_color * (0.85 + 0.3 * fbm(q * 1.5));
		col += vec3((hash21(floor(q * 40.0)) - 0.5) * 0.08 * f_grit);

		// b. joints across the curb
		float side = (top || xface) ? 1.0 : 0.0;
		float jd = abs(fract(along / joint_spacing_m + 0.5) - 0.5) * joint_spacing_m;
		float line = 1.0 - smoothstep(0.0075 - fw_along, 0.0075 + fw_along, jd);
		line *= (1.0 - smoothstep(0.03, 0.12, fw_along)) * side;
		col = mix(col, joint_color, line);

		// c. worn kerb paint on 1-in-3 segment runs
		float seg = floor(along / joint_spacing_m);
		float run = floor(along / (joint_spacing_m * 3.0));
		float painted = hash21(vec2(run, 1.7) + v_off) < paint_amount ? 1.0 : 0.0;
		float ph = hash21(vec2(run, 5.3) + v_off);
		vec3 c0 = paint_a;
		vec3 c1 = paint_a;
		if (ph > 0.66) {
			c0 = paint_c;
			c1 = paint_c;
		} else if (ph > 0.33) {
			c0 = paint_b;
			c1 = paint_c;
		}
		vec3 pc = mod(seg, 2.0) < 0.5 ? c0 : c1;
		float worn = smoothstep(0.45, 0.5, fbm(q * 3.0));
		col = mix(col, pc, painted * worn * side * 0.8);

		// d. chipped top edges
		float chip = step(0.6, noise21(vec2(along * 8.0, 0.5) + v_off));
		chip *= 1.0 - smoothstep(0.02, 0.03, edge_d);
		chip *= f_chip * (1.0 - smoothstep(0.02, 0.08, fw_edge));
		col *= mix(1.0, 0.65, chip);
		col += vec3((hash21(floor(q * 40.0) + 3.0) - 0.5) * 0.06 * chip * f_grit);

		// e. tyre scuffs on the x faces
		float cell = floor(along / 2.0);
		float sh = hash21(vec2(cell, 3.1) + v_off);
		float s1 = hash21(vec2(cell, 7.7) + v_off);
		float s2 = hash21(vec2(cell, 9.9) + v_off);
		float s3 = hash21(vec2(cell, 11.3) + v_off);
		float slen = 0.3 + s1 * 1.2;
		float x0 = s2 * (2.0 - slen);
		float lx = along - cell * 2.0;
		float tall = 0.02 + s3 * 0.04;
		float face_h = v_half.y * 2.0;
		float y0 = -v_half.y + fract(s1 * 13.0 + s3 * 5.0) * max(0.0, 0.6 * face_h - tall);
		float ly = v_pos.y - y0;
		float sx = smoothstep(x0 - fw_along, x0 + fw_along, lx)
				* (1.0 - smoothstep(x0 + slen - fw_along, x0 + slen + fw_along, lx));
		float sy = smoothstep(-fw_up, fw_up, ly) * (1.0 - smoothstep(tall - fw_up, tall + fw_up, ly));
		float scuff = (xface && sh < 0.35) ? sx * sy : 0.0;
		scuff *= (1.0 - smoothstep(0.02, 0.08, fw_up)) * (1.0 - smoothstep(0.03, 0.12, fw_along));
		col = mix(col, scuff_color, scuff * 0.85);

		// f. dirt band at the foot of the x faces and along the top face's edges
		float band = 0.0;
		if (xface) {
			band = (1.0 - smoothstep(0.04, 0.05, v_pos.y + v_half.y))
					* (1.0 - smoothstep(0.02, 0.08, fw_up));
		} else if (top) {
			band = (1.0 - smoothstep(0.03, 0.05, edge_d))
					* (1.0 - smoothstep(0.02, 0.08, fw_edge));
		}
		col = mix(col, dirt_color, band * 0.6);

		// g. stains
		col *= 1.0 - 0.3 * smoothstep(0.55, 0.8, fbm(q * 0.7 + 3.0));

		// h. roughness
		rough = mix(0.9, 0.6, scuff);
	} else {
		// a. base
		col = base_color * (0.8 + 0.4 * fbm(q * 1.5));

		// b. sludge and wet patches
		float sludge = smoothstep(0.4, 0.7, fbm(q * 1.2));
		col = mix(col, sludge_color, sludge);
		float wet = smoothstep(0.7, 0.9, sludge);

		// c. leaf litter specks
		vec2 lc = floor(q / 0.18);
		float lh = hash21(lc + 13.0);
		vec2 lp = (lc + 0.2 + 0.6 * hash22(lc + 5.0)) * 0.18;
		float lr = 0.01 + 0.015 * hash21(lc + 21.0);
		float blob = lh < 0.25 ? 1.0 - smoothstep(lr - aa, lr + aa, length(q - lp)) : 0.0;
		blob *= 1.0 - smoothstep(0.02, 0.08, aa);
		col = mix(col, leaf_color * (0.7 + 0.6 * hash21(lc + 31.0)), blob);
		wet *= 1.0 - blob;

		// d. silt ridge along the centre line
		float ridge = 1.0 - smoothstep(0.01 - fw_across, 0.01 + fw_across, abs(v_pos.x));
		ridge *= (top ? 1.0 : 0.0) * (1.0 - smoothstep(0.02, 0.08, fw_across));
		col += vec3(0.02 * ridge);

		// e. roughness
		rough = mix(0.92, 0.35, wet);
		metal = 0.1 * wet;
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
}
