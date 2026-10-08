shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Bare, heavily rusted raw steel for the rear door surround. Model-space triplanar, so it needs
// no UVs; rust gathers on bevels (grazing normals), creases (cavity noise) and the low parts.
uniform vec3 steel_color : source_color = vec3(0.075, 0.08, 0.08);
uniform vec3 scale_color : source_color = vec3(0.035, 0.04, 0.045);
uniform vec3 rust_color : source_color = vec3(0.21, 0.075, 0.028);
uniform vec3 deep_rust_color : source_color = vec3(0.09, 0.03, 0.012);
uniform vec3 weld_color : source_color = vec3(0.025, 0.022, 0.02);
uniform float pattern_scale : hint_range(0.5, 8.0) = 2.5;
uniform float low_y_m = -0.6;
uniform float high_y_m = 1.8;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.86;
uniform float metallic_value : hint_range(0.0, 0.6) = 0.22;

varying vec3 v_pos;
varying vec3 v_nrm;

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

// One planar projection: returns x = rust amount, y = pits, z = mill-scale streak, w = stain.
vec4 plane(vec2 p, float y_low) {
	float blotch = fbm(p * 1.3 + 3.0);
	float fine = fbm(p * 7.0 + 11.0);
	float rust = smoothstep(0.38, 0.72, blotch + y_low * 0.25 + (fine - 0.5) * 0.3);
	float pits = smoothstep(0.7, 0.9, noise21(p * 24.0));
	float streak = fbm(vec2(p.x * 14.0, p.y * 1.2) + 5.5);
	float stain = smoothstep(0.5, 0.8, fbm(vec2(p.x * 9.0, p.y * 0.35) + 1.7));
	return vec4(rust, pits, streak, stain);
}

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = v_pos * pattern_scale;
	float y_low = 1.0 - clamp((v_pos.y - low_y_m) / (high_y_m - low_y_m), 0.0, 1.0);

	vec4 a = plane(p.zy, y_low);
	vec4 b = plane(p.xz + 4.0, y_low);
	vec4 c = plane(p.xy + 9.0, y_low);
	vec4 s = a * w.x + b * w.y + c * w.z;

	// Bevels and edges: normals that vary across a pixel (fwidth) bloom rust hardest.
	float edge = clamp(length(fwidth(n)) * 6.0, 0.0, 1.0);
	float rust = clamp(s.x + edge * 0.7 + y_low * 0.15, 0.0, 1.0);
	float deep = smoothstep(0.55, 1.0, rust) * (0.5 + 0.5 * s.y);
	// Weld seams darken along sharp ramp edges.
	float weld = edge * smoothstep(0.35, 0.7, fbm(p.zy * 18.0 + p.xz * 6.0));

	vec3 col = mix(steel_color, scale_color, smoothstep(0.35, 0.8, s.z) * 0.8);
	col = mix(col, rust_color, rust * 0.85);
	col = mix(col, deep_rust_color, deep * 0.7);
	col = mix(col, rust_color * 0.8, s.w * (1.0 - abs(n.y)) * 0.4);
	col = mix(col, vec3(0.01), s.y * rust * 0.5);
	col = mix(col, weld_color, weld * 0.6);
	col *= 0.9 + 0.2 * noise21(p.xy * 30.0 + p.z * 13.0);

	ALBEDO = col;
	METALLIC = metallic_value * (1.0 - rust * 0.8);
	ROUGHNESS = clamp(roughness_value - (1.0 - rust) * 0.18 + s.y * 0.1, 0.3, 1.0);
	NORMAL_MAP = vec3((s.z - 0.5) * 0.2 + 0.5, (s.y - 0.5) * 0.2 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.6;
}
