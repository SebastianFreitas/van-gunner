shader_type spatial;
render_mode diffuse_burley, cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.07, 0.075, 0.07);
uniform vec3 groove_color : source_color = vec3(0.03, 0.032, 0.03);
uniform vec3 edge_color : source_color = vec3(0.045, 0.048, 0.045);
uniform float groove_scale : hint_range(4.0, 40.0) = 14.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.96;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 cell = abs(fract(uv * groove_scale) - 0.5);
	float groove = 1.0 - smoothstep(0.02, 0.08, min(cell.x, cell.y));
	float border = max(
		smoothstep(0.04, 0.0, min(uv.x, 1.0 - uv.x)),
		smoothstep(0.06, 0.0, min(uv.y, 1.0 - uv.y))
	);
	float wear = smoothstep(0.55, 0.95, hash21(floor(uv * 18.0)));

	vec3 color = mix(base_color, groove_color, groove * 0.85);
	color = mix(color, edge_color, border);
	color *= 0.9 + 0.15 * wear;

	ALBEDO = color;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	NORMAL_MAP = vec3((cell.x - cell.y) * 0.35, 0.0, 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.35;
}
