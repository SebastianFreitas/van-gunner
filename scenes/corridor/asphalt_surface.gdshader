shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Washed-out, trashed asphalt — loud grit, tire wear, oil, cracks, patches, litter.
// Patterns use world XZ so detail reads on BoxMesh tops regardless of UV scale.

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
uniform float washout : hint_range(0.0, 1.0) = 0.35;
uniform float trash : hint_range(0.0, 1.0) = 0.95;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.94;

varying vec3 v_world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
	return fract(sin(vec2(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3))
	)) * 43758.5453);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise21(p);
		p = p * 2.07 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

float crack_field(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float min_d = 1.0;
	float second = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(cell + g);
			vec2 r = g + o - f;
			float d = length(r);
			if (d < min_d) {
				second = min_d;
				min_d = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return second - min_d;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 pos = v_world_pos.xz;

	// Aggregate grit — strong pebble contrast.
	float grit_n = fbm(pos * 4.5 + vec2(3.1, 1.7));
	float grit = smoothstep(0.3, 0.7, grit_n);
	float grain = noise21(pos * 28.0);

	// Longitudinal tire lanes — clear polished bands.
	float lane_l = exp(-pow((pos.x + 1.4) / 0.7, 2.0));
	float lane_r = exp(-pow((pos.x - 1.4) / 0.7, 2.0));
	float lane_c = exp(-pow(pos.x / 0.95, 2.0)) * 0.65;
	float tire_mod = 0.45 + 0.55 * fbm(vec2(pos.x * 0.35, pos.y * 0.08) + 4.0);
	float tire = clamp(lane_l + lane_r + lane_c, 0.0, 1.0) * tire_mod;

	// Oil / grease puddles — lower threshold so they show up.
	float blotch_a = fbm(pos * 0.55 + vec2(8.7, 3.2));
	float blotch_b = fbm(pos * 1.1 + vec2(2.4, 14.0));
	float oil = max(
		smoothstep(0.55, 0.78, blotch_a),
		smoothstep(0.62, 0.85, blotch_b) * 0.7
	) * trash;

	// Repair patches — irregular darker asphalt blobs (not rectangles).
	vec2 patch_cell = floor(pos / vec2(3.2, 3.8));
	float patch_roll = hash21(patch_cell + 7.0);
	float patch_mask = step(0.62, patch_roll) * trash;
	vec2 patch_local = fract(pos / vec2(3.2, 3.8)) - 0.5;
	vec2 patch_off = (hash22(patch_cell + 3.0) - 0.5) * 0.28;
	vec2 patch_p = patch_local - patch_off;
	float patch_ang = hash21(patch_cell + 5.0) * 6.28318;
	float pca = cos(patch_ang);
	float psa = sin(patch_ang);
	patch_p = vec2(pca * patch_p.x - psa * patch_p.y, psa * patch_p.x + pca * patch_p.y);
	vec2 patch_stretch = vec2(0.7, 1.15) + hash22(patch_cell + 9.0) * vec2(0.45, 0.35);
	float patch_r = length(patch_p / patch_stretch);
	float patch_warp = fbm(pos * 2.2 + patch_cell) * 0.22;
	float patch_shape = 1.0 - smoothstep(0.22 + patch_warp, 0.38 + patch_warp * 0.5, patch_r);
	float patch = patch_mask * patch_shape
		* (0.7 + 0.3 * fbm(pos * 1.4 + patch_cell));

	// Cracks — full-strength seams, but only on ~40% of the road.
	float crack_coverage = smoothstep(0.56, 0.64, fbm(pos * 0.22 + 11.0));
	float cf = crack_field(pos * 0.85 + 2.3);
	float cracks = 1.0 - smoothstep(0.02, 0.08, cf);
	cracks *= crack_coverage * trash;

	// Secondary hairline cracks (same coverage mask).
	float cf2 = crack_field(pos * 1.6 + 9.1);
	float hair = (1.0 - smoothstep(0.01, 0.04, cf2))
		* smoothstep(0.5, 0.8, fbm(pos * 0.5 + 5.0)) * crack_coverage * trash * 0.7;
	cracks = max(cracks, hair);

	// Edge dirt / gutter runoff.
	float edge_dirt = smoothstep(4.5, 7.5, abs(pos.x));
	edge_dirt *= 0.4 + 0.6 * fbm(vec2(pos.x * 0.6, pos.y * 0.2) + 6.0);

	// --- Litter (paper, cans, plastic, debris) --------------------------------
	vec2 litter_cell = floor(pos / 1.35);
	vec2 litter_f = fract(pos / 1.35) - 0.5;
	vec2 litter_id = litter_cell + 31.0;
	float litter_roll = hash21(litter_id);
	float litter_on = step(1.0 - 0.22 * trash, litter_roll); // ~22% cells at trash=1
	vec2 litter_off = (hash22(litter_id + 1.0) - 0.5) * 0.55;
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
			float crumple = 0.7 + 0.3 * noise21(litter_p * 40.0 + litter_id);
			paper = rect * crumple;
		} else if (litter_kind < 0.55) {
			// Can / bottle silhouette.
			float el = length(litter_p / vec2(0.07, 0.12));
			can = 1.0 - smoothstep(0.75, 1.05, el);
		} else if (litter_kind < 0.75) {
			// Plastic bag / wrapper smear.
			float bag = fbm(litter_p * 8.0 + litter_id);
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

	float bleach = washout * (0.25 + 0.75 * fbm(pos * 0.15 + vec2(1.5, 9.0)));

	vec3 color = base_color;
	color = mix(color, grit_color, grit * 0.7);
	color = mix(color, wear_color, tire * 0.85);
	color = mix(color, patch_color, patch * 1.0);
	color = mix(color, oil_color, oil * 0.95);
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

	ALBEDO = color;
	METALLIC = 0.02 + oil * 0.18 + can * 0.35;
	ROUGHNESS = clamp(
		roughness_value
			- tire * 0.14
			+ grit * 0.05
			+ oil * 0.12
			+ edge_dirt * 0.06
			- cracks * 0.08
			- paper * 0.1
			- can * 0.2,
		0.3,
		1.0
	);

	float n_x = (grit_n - 0.5) * 0.55 + cracks * 0.7 + oil * 0.15;
	float n_y = (fbm(pos * 3.5 + 3.0) - 0.5) * 0.45 + cracks * 0.4;
	n_x += (paper + can + plastic) * 0.35;
	NORMAL_MAP = normalize(vec3(n_x, n_y, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.75;
}
