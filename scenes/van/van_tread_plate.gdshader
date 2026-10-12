// Tread-plate ("diamond plate") offcut on the donor rear leaf: bare bright steel, raised lozenges
// on the cabin face only (the street face is flat), flame-cut edges with a heat-tint band.
// Lozenges: staggered rows of raised ovals, alternate rows at plus and minus 45 degrees, pitch
// 0.05 m, drawn in the normal only and faded to the flat field with fwidth. Model-space metres
// (the plate sits at the hinge origin).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/shaders/grime.gdshaderinc"

uniform float seed = 0.0;
// The plate's outline in model xy (padded with its last point): distance to it drives the heat band.
uniform vec2 outline[16];
uniform int outline_count = 3;
uniform vec3 field_color : source_color = vec3(0.53, 0.535, 0.54);
uniform vec3 top_color : source_color = vec3(0.65, 0.655, 0.66);
uniform vec3 heat_color : source_color = vec3(0.2, 0.15, 0.1);
uniform float pitch = 0.05;
uniform float heat_width = 0.02;

varying vec3 v_pos;
varying vec3 v_nrm;


void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}


// Lozenge height at p: an oval 0.04 long, 0.013 wide, row parity picks the diagonal.
float lozenge(vec2 p) {
	float row = floor(p.y / pitch);
	float odd = mod(row, 2.0);
	vec2 q = vec2(p.x / pitch - odd * 0.5, p.y / pitch);
	vec2 c = (fract(q) - 0.5) * pitch;
	float s = mix(0.7071, -0.7071, odd);
	vec2 r = vec2(c.x * 0.7071 + c.y * s, -c.x * s + c.y * 0.7071);
	float d = length(vec2(r.x / 0.021, r.y / 0.0075));
	return 1.0 - smoothstep(0.55, 1.0, d);
}


float edge_dist(vec2 p) {
	float best = 1e3;
	for (int i = 0; i < 16; i++) {
		if (i >= outline_count) {
			break;
		}
		vec2 a = outline[i];
		vec2 b = outline[(i + 1) % outline_count];
		vec2 ab = b - a;
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		best = min(best, length(p - a - ab * t));
	}
	return best;
}


void fragment() {
	vec2 p = v_pos.xy;
	bool cabin = v_nrm.z < -0.5;
	float fw = length(fwidth(p));
	float fade = 1.0 - smoothstep(pitch * 0.08, pitch * 0.25, fw);
	float h = 0.0;
	if (cabin) {
		float e = 0.0012;
		float h0 = lozenge(p);
		float hx = lozenge(p + vec2(e, 0.0));
		float hy = lozenge(p + vec2(0.0, e));
		vec3 n = normalize(vec3(-(hx - h0) / e * 0.0035, -(hy - h0) / e * 0.0035, -1.0) * vec3(1.0, 1.0, 1.0));
		n = mix(vec3(0.0, 0.0, -1.0), n, fade);
		NORMAL = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * n);
		h = h0;
	}
	h = mix(0.5, h, fade);
	float valley = 1.0 - h;
	float grime = noise21(p * 9.0 + seed) * 0.6 + noise21(p * 31.0 - seed) * 0.4;
	float oil = valley * smoothstep(0.35, 0.8, grime);
	vec3 col = mix(field_color, top_color, h);
	col *= 1.0 - oil * 0.45;
	float dist = edge_dist(p);
	float heat = (1.0 - smoothstep(0.004, heat_width, dist)) * (0.7 + 0.3 * noise21(p * 40.0 + seed));
	if (!cabin && abs(v_nrm.z) < 0.5) {
		heat = 1.0;
	}
	col = mix(col, heat_color, heat);
	ALBEDO = col;
	METALLIC = mix(0.28, 0.1, max(oil, heat));
	ROUGHNESS = mix(0.78, 0.9, max(oil, heat));
}
