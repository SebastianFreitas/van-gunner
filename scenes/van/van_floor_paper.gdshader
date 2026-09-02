shader_type spatial;
render_mode diffuse_burley, cull_disabled, depth_draw_opaque;

uniform vec3 paper_color : source_color = vec3(0.78, 0.74, 0.62);
uniform vec3 ink_color : source_color = vec3(0.22, 0.2, 0.16);
uniform float line_count : hint_range(4.0, 24.0) = 11.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float ruled = 1.0 - smoothstep(0.02, 0.06, abs(fract(uv.y * line_count) - 0.5));
	float margin = step(uv.x, 0.12) * (1.0 - smoothstep(0.015, 0.03, abs(uv.x - 0.12)));
	float blot = smoothstep(0.78, 0.95, hash21(floor(uv * vec2(9.0, 14.0))));
	float crease = smoothstep(0.48, 0.5, abs(uv.x - 0.52)) * 0.25;

	vec3 color = paper_color;
	color = mix(color, ink_color, ruled * 0.28 + margin * 0.45);
	color = mix(color, paper_color * 0.82, blot * 0.35 + crease);
	color *= 0.94 + 0.08 * hash21(uv * 40.0);

	ALBEDO = color;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
