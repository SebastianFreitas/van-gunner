shader_type spatial;
render_mode diffuse_burley;

uniform vec3 base_color : source_color = vec3(0.16, 0.18, 0.17);
uniform vec3 seam_color : source_color = vec3(0.035, 0.045, 0.04);
uniform vec3 rust_color : source_color = vec3(0.30, 0.105, 0.045);
uniform vec2 tile_count = vec2(5.0, 2.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.82;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 tiled = UV * tile_count;
	vec2 cell = floor(tiled);
	vec2 edge = min(fract(tiled), 1.0 - fract(tiled));
	float seam = 1.0 - smoothstep(0.018, 0.055, min(edge.x, edge.y));
	float stain = smoothstep(0.68, 0.98, hash(cell + floor(fract(tiled) * 5.0)));
	float vertical_grime = smoothstep(0.1, 0.95, fract(UV.y * 7.0 + hash(cell)));
	vec3 color = mix(base_color, seam_color, seam);
	color = mix(color, rust_color, stain * vertical_grime * 0.55);
	ALBEDO = color;
	METALLIC = 0.58;
	ROUGHNESS = roughness_value;
}
