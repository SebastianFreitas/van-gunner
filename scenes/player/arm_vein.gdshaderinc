// Vein shading from the same packed paths the skin geometry is raised by (ArmVeinSet.pack, set
// per arm as vein_pts). Same chart and rounded profile as the baked hand mesh's vein relief, evaluated per pixel.
const int VEIN_MAX = 160;
// Chart radius, ArmVeinSet.ARC_R, and the height scale of the fattest vein, ArmVeinSet.MAX_R.
const float VEIN_ARC_R = 0.035;
const float VEIN_MAX_R = 0.006;
// Smooth-max width where two veins join.
const float VEIN_BLEND = 0.3;
// How far the groove reaches past a vein's edge, in chart units.
const float VEIN_GROOVE = 0.0035;

uniform vec4 vein_pts[160]; // x, v, radius, height scale; paths split by a z < 0 point
uniform int vein_count = 0;

float vein_smax(float a, float b) {
	if (a <= 0.0) {
		return b;
	}
	if (b <= 0.0) {
		return a;
	}
	float gap = max(VEIN_BLEND - abs(a - b), 0.0);
	return max(a, b) + gap * gap / (4.0 * VEIN_BLEND);
}

// x: crest height 0..1 (1 is the fattest vein); y: signed distance to the nearest vein edge
// (negative inside); z: the chart footprint of one pixel. A segment far from the pixel is skipped
// by its bounding box before any distance is taken.
vec3 vein_field(vec4 c) {
	vec2 ch = vec2(c.x, VEIN_ARC_R * atan(c.z, c.y));
	float fw = max(fwidth(ch.x), fwidth(ch.y));
	float total = 0.0;
	float path_best = 0.0;
	float edge = 1.0;
	for (int i = 0; i < VEIN_MAX - 1; i++) {
		if (i >= vein_count - 1) {
			break;
		}
		vec4 a = vein_pts[i];
		vec4 b = vein_pts[i + 1];
		if (a.z < 0.0) {
			total = vein_smax(total, path_best);
			path_best = 0.0;
			continue;
		}
		if (b.z < 0.0) {
			continue;
		}
		float m = max(a.z, b.z) + VEIN_GROOVE;
		if (ch.x < min(a.x, b.x) - m || ch.x > max(a.x, b.x) + m
				|| abs(ch.y - 0.5 * (a.y + b.y)) > 0.5 * abs(a.y - b.y) + m) {
			continue;
		}
		vec2 ab = b.xy - a.xy;
		float t = clamp(dot(ch - a.xy, ab) / max(dot(ab, ab), 1e-7), 0.0, 1.0);
		float d = length(ch - (a.xy + ab * t));
		float r = mix(a.z, b.z, t);
		edge = min(edge, d - r);
		float q = d / max(r, 1e-5);
		if (q < 1.0) {
			path_best = max(path_best, mix(a.w, b.w, t) * (r / VEIN_MAX_R) * sqrt(1.0 - q * q));
		}
	}
	total = vein_smax(total, path_best);
	// The per-bone mask eases in over its first third, so where a bone's weight ends inside a
	// triangle the veins fade out instead of stopping on the triangle edge.
	float mask = clamp(c.w, 0.0, 1.0) * smoothstep(0.0, 0.35, c.w);
	return vec3(min(total, 1.0) * mask, edge, fw);
}
