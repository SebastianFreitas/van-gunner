shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// A chasing marquee bulb strip: a grid of round bulbs along UV.x, every third one lit and the
// lit set advancing over time.

uniform vec3 color : source_color = vec3(1.0, 0.85, 0.5);
uniform float energy = 3.0;
uniform float bulbs_per_m = 6.0;
uniform float length_m = 8.0;
uniform float speed = 6.0;

void fragment() {
	float u = UV.x * length_m * bulbs_per_m;
	float cell = floor(u);
	vec2 c = vec2(fract(u) - 0.5, UV.y - 0.5);
	float bulb = 1.0 - smoothstep(0.22, 0.3, length(c));
	float chase = step(0.5, fract((cell - TIME * speed) / 3.0));
	ALBEDO = vec3(0.05);
	EMISSION = color * energy * bulb * chase;
	ROUGHNESS = 0.5;
}
