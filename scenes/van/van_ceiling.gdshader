shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.32, 0.30, 0.27);
uniform vec3 seam_color : source_color = vec3(0.14, 0.13, 0.115);
uniform vec3 foam_color : source_color = vec3(0.38, 0.36, 0.32);
uniform vec3 stain_color : source_color = vec3(0.22, 0.18, 0.12);
uniform vec3 water_color : source_color = vec3(0.28, 0.26, 0.22);
uniform vec2 ceiling_size_m = vec2(4.08, 9.4);
uniform float bay_spacing_m : hint_range(0.6, 2.5) = 1.35;
uniform float quilt_scale_m : hint_range(0.06, 0.4) = 0.14;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
		p = p * 2.07 + vec2(11.3, 5.7);
		a *= 0.5;
	}
	return v;
}

float line_mask(float coord, float width) {
	return 1.0 - smoothstep(0.0, width, abs(coord));
}

void fragment() {
	// UV authored 0..1 across vault: X across cabin, Y along van length.
	vec2 uv_m = UV * ceiling_size_m;
	vec2 pos = (UV - vec2(0.5)) * ceiling_size_m;

	// Soft quilt / foam pad grid (classic van headliner look).
	vec2 quilt_cell = floor(uv_m / quilt_scale_m);
	vec2 quilt_local = fract(uv_m / quilt_scale_m) - vec2(0.5);
	float quilt_edge_x = 1.0 - smoothstep(0.0, 0.08, abs(abs(quilt_local.x) - 0.42));
	float quilt_edge_y = 1.0 - smoothstep(0.0, 0.08, abs(abs(quilt_local.y) - 0.42));
	float quilt_seam = max(quilt_edge_x, quilt_edge_y);
	float quilt_pad = 1.0 - smoothstep(0.18, 0.46, length(quilt_local * vec2(1.05, 1.0)));
	float quilt_noise = fbm(quilt_cell * 0.37 + uv_m * 1.4);

	// Bay seams under vigas (every bay_spacing_m along Z).
	float bay_phase = fract(uv_m.y / bay_spacing_m);
	float bay_seam = 1.0 - smoothstep(0.012, 0.04, min(bay_phase, 1.0 - bay_phase));

	// Longitudinal headliner tape / weld lines near the center and sides.
	float center_tape = line_mask(pos.x, 0.035) * 0.55;
	float side_rail = max(
		smoothstep(ceiling_size_m.x * 0.42, ceiling_size_m.x * 0.5, abs(pos.x)),
		0.0
	);

	// Water stains / leaks dripping from roof seams.
	float drip = fbm(vec2(pos.x * 1.8, pos.y * 0.35) + vec2(3.1, 8.4));
	float water = smoothstep(0.68, 0.92, drip) * (bay_seam * 0.65 + side_rail * 0.4);

	// Grease / nicotine / cargo dust blotches.
	float blotch = fbm(pos * 0.42 + vec2(6.2, 1.7));
	float stain = smoothstep(0.62, 0.9, blotch) * (0.35 + 0.65 * side_rail);

	// Tiny fastener dots along bay seams.
	vec2 rivet_cell = floor(vec2(uv_m.x / 0.35, uv_m.y / bay_spacing_m));
	vec2 rivet_local = fract(vec2(uv_m.x / 0.35, uv_m.y / bay_spacing_m)) - vec2(0.5);
	float rivet_row = step(0.7, hash21(rivet_cell + 9.0));
	float rivet = rivet_row * bay_seam
		* (1.0 - smoothstep(0.03, 0.065, length(rivet_local * vec2(1.4, 1.0))));

	vec3 color = mix(base_color, foam_color, 0.55 + 0.35 * quilt_pad);
	color = mix(color, foam_color * (0.9 + 0.2 * quilt_noise), quilt_pad * 0.45);
	color = mix(color, seam_color, quilt_seam * 0.55 + bay_seam * 0.75 + center_tape);
	color = mix(color, stain_color, stain * 0.55 + side_rail * 0.18);
	color = mix(color, water_color, water * 0.7);
	color = mix(color, vec3(0.16, 0.15, 0.13), rivet * 0.9);
	color *= 0.94 + 0.12 * noise21(uv_m * 26.0);

	ALBEDO = color;
	METALLIC = metallic_value * (1.0 - stain * 0.5);
	ROUGHNESS = clamp(
		roughness_value
			+ quilt_seam * 0.04
			+ bay_seam * 0.06
			+ stain * 0.08
			+ water * 0.1
			- rivet * 0.2,
		0.25,
		1.0
	);

	// Soft quilt pillow normals + shallow bay grooves.
	float n_x = quilt_local.x * quilt_pad * 1.4 + (bay_phase - 0.5) * bay_seam * 0.5;
	float n_y = quilt_local.y * quilt_pad * 1.2;
	NORMAL_MAP = vec3(n_x, n_y, 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.55;
}
