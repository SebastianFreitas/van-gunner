shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.22, 0.235, 0.225);
uniform vec3 seam_color : source_color = vec3(0.07, 0.075, 0.07);
uniform vec3 kick_color : source_color = vec3(0.1, 0.095, 0.085);
uniform vec3 belt_color : source_color = vec3(0.14, 0.15, 0.145);
uniform vec3 wear_color : source_color = vec3(0.32, 0.3, 0.26);
uniform vec3 stain_color : source_color = vec3(0.04, 0.035, 0.03);
uniform vec3 rust_color : source_color = vec3(0.24, 0.09, 0.035);
uniform vec2 wall_size_m = vec2(9.4, 3.08);
uniform float panel_spacing_m : hint_range(0.6, 2.5) = 1.15;
uniform float rib_spacing_m : hint_range(0.15, 0.8) = 0.42;
uniform float kick_height_m : hint_range(0.15, 0.8) = 0.38;
uniform float belt_y_m : hint_range(0.6, 1.8) = 0.96;
uniform float waist_y_m : hint_range(1.0, 2.2) = 1.48;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.78;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.28;

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
		p = p * 2.07 + vec2(13.1, 7.9);
		a *= 0.5;
	}
	return v;
}

float line_mask(float coord, float width) {
	return 1.0 - smoothstep(0.0, width, abs(coord));
}

void fragment() {
	// UV authored 0..1 across wall: X along van length (Z), Y up height.
	vec2 uv_m = UV * wall_size_m;
	float y = uv_m.y;
	float z = uv_m.x;

	// Vertical cargo-panel seams along the length.
	float panel_phase = fract(z / panel_spacing_m);
	float panel_seam = 1.0 - smoothstep(0.01, 0.032, min(panel_phase, 1.0 - panel_phase));

	// Soft stamped ribs between seams (common van liner look).
	float rib_phase = fract(z / rib_spacing_m);
	float rib = smoothstep(0.12, 0.0, abs(rib_phase - 0.5) - 0.18);

	// Kick plate / scuff band near the floor.
	float kick = 1.0 - smoothstep(kick_height_m - 0.05, kick_height_m + 0.08, y);

	// Horizontal body belt + waist crease.
	float belt = line_mask(y - belt_y_m, 0.028) + line_mask(y - waist_y_m, 0.02) * 0.75;

	// Ceiling and floor edge darkening.
	float edge_y = max(
		smoothstep(0.12, 0.0, y),
		smoothstep(wall_size_m.y - 0.2, wall_size_m.y, y)
	);

	// Vertical brush / wipe marks from cargo rubbing the walls.
	float brush = fbm(vec2(z * 0.35, y * 3.4) + vec2(2.2, 0.4));
	float scuff = smoothstep(0.62, 0.92, brush) * mix(0.35, 1.0, kick);

	// Grease / dirt pools near seams and kick.
	float dirt = fbm(vec2(z * 0.55, y * 0.8) + 9.1);
	float grime = smoothstep(0.68, 0.95, dirt) * (kick * 0.7 + panel_seam * 0.45 + edge_y * 0.35);

	// Occasional rust freckles on seams / lower band.
	float rust = smoothstep(0.84, 0.98, hash21(floor(uv_m * vec2(5.5, 7.0))))
		* (panel_seam * 0.65 + kick * 0.4);

	// Rivet / screw heads along panel edges and belt line.
	vec2 rivet_cell = floor(vec2(z / (panel_spacing_m), y / 0.42));
	vec2 rivet_local = fract(vec2(z / panel_spacing_m, y / 0.42)) - vec2(0.5);
	float rivet_row = step(0.78, hash21(rivet_cell + 4.0));
	float near_seam = max(panel_seam, belt * 0.85);
	float rivet = rivet_row * near_seam * (1.0 - smoothstep(0.03, 0.07, length(rivet_local * vec2(1.6, 1.0))));

	vec3 color = base_color;
	color = mix(color, kick_color, kick * 0.82);
	color = mix(color, belt_color, belt * 0.7);
	color = mix(color, seam_color, panel_seam * 0.85 + rib * 0.22);
	color = mix(color, wear_color, scuff * 0.4);
	color = mix(color, stain_color, grime * 0.7 + edge_y * 0.25);
	color = mix(color, rust_color, rust * 0.7);
	color = mix(color, vec3(0.12, 0.12, 0.11), rivet * 0.9);
	color *= 0.93 + 0.14 * noise21(uv_m * 22.0);

	ALBEDO = color;
	METALLIC = metallic_value * (0.55 + 0.45 * (1.0 - kick)) * (1.0 - grime * 0.65);
	ROUGHNESS = clamp(
		roughness_value
			+ kick * 0.1
			+ panel_seam * 0.06
			+ grime * 0.1
			- rivet * 0.22
			- scuff * 0.05,
		0.22,
		1.0
	);

	float n_x = (panel_phase - 0.5) * panel_seam * 0.9 + (rib_phase - 0.5) * rib * 0.45;
	float n_y = (y - belt_y_m) * belt * 8.0 + kick * -0.25;
	NORMAL_MAP = vec3(n_x, n_y, 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.85;
}
