shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.18, 0.13, 0.085);
uniform vec3 grain_dark : source_color = vec3(0.11, 0.08, 0.055);
uniform vec3 grain_light : source_color = vec3(0.28, 0.2, 0.13);
uniform vec3 wear_color : source_color = vec3(0.32, 0.24, 0.16);
uniform float beam_length_m : hint_range(1.0, 8.0) = 4.12;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.82;
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
		p = p * 2.11 + vec2(9.4, 4.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// Cylinder UVs: X around the beam, Y along height (beam length after rotation).
	float around = UV.x;
	float along = UV.y * beam_length_m;

	// Longitudinal wood grain stretched along the beam.
	float grain_wave = sin(along * 9.5 + fbm(vec2(along * 0.35, around * 2.0)) * 4.0);
	float grain = smoothstep(-0.35, 0.85, grain_wave);
	float fine = noise21(vec2(along * 18.0, around * 6.0));

	// Knots / dark rings.
	vec2 knot_cell = floor(vec2(along / 0.85, around * 3.0));
	vec2 knot_local = fract(vec2(along / 0.85, around * 3.0)) - vec2(0.5);
	float knot_pick = step(0.9, hash21(knot_cell + 7.0));
	float knot = knot_pick * (1.0 - smoothstep(0.08, 0.22, length(knot_local * vec2(1.6, 1.0))));

	// End wear + handling scuffs toward beam tips.
	float tip = max(
		smoothstep(0.15, 0.0, along),
		smoothstep(beam_length_m - 0.15, beam_length_m, along)
	);
	float scuff = smoothstep(0.58, 0.9, fbm(vec2(along * 1.2, around * 4.0) + 3.3));

	vec3 color = mix(grain_dark, base_color, 0.55 + 0.45 * fine);
	color = mix(color, grain_light, grain * 0.55);
	color = mix(color, grain_dark, knot * 0.85);
	color = mix(color, wear_color, tip * 0.45 + scuff * 0.22);
	color *= 0.92 + 0.16 * noise21(vec2(along * 22.0, around * 10.0));

	ALBEDO = color;
	METALLIC = metallic_value;
	ROUGHNESS = clamp(
		roughness_value
			+ grain * 0.05
			+ knot * 0.08
			+ tip * 0.1
			- scuff * 0.04,
		0.35,
		1.0
	);

	float n_x = (grain_wave) * 0.35 + (around - 0.5) * 0.15;
	float n_y = fine * 0.25;
	NORMAL_MAP = vec3(n_x, n_y, 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.45;
}
