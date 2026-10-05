// Knuckle creases and back-of-hand tendons for arm_surface.gdshader: a signed relief the
// skin's bump block turns into a normal tilt and a shade. Shading only, never vertex().
// Every point is rest (mesh) space, set once per arm by ArmSkinFolds.apply.

const int FOLD_MAX = 14;
const int TENDON_MAX = 4;

uniform int fold_count = 0;
uniform vec4 fold_p[14]; // xyz joint centre on the finger axis, w reach of the creases
uniform vec4 fold_d[14]; // xyz unit finger axis, w finger radius at the joint
uniform vec4 fold_n[14]; // xyz unit back-of-finger direction, w crease count
// Crease spacing and half-width, in finger radii.
uniform float fold_gap : hint_range(0.2, 0.8) = 0.42;
uniform float fold_width : hint_range(0.05, 0.3) = 0.17;
uniform int tendon_count = 0;
uniform vec4 tendon_a[4]; // xyz wrist end, w half-width
uniform vec4 tendon_b[4]; // xyz knuckle end
uniform vec3 tendon_n = vec3(0.0, 1.0, 0.0); // unit back-of-hand direction
// Relief scale in skin_height units; 0 turns the whole layer off.
uniform float fold_height : hint_range(0.0, 1.0) = 0.0;
uniform float fold_shade : hint_range(0.0, 0.8) = 0.7; // how dark a crease floor gets
uniform float tendon_light : hint_range(0.0, 0.4) = 0.26; // how much a tendon crown lifts

// 1 when a feature `size` wide covers 2.5 px or more, 0 under 1 px, so it never shimmers.
float fold_fade(float size, float fw) {
	return smoothstep(1.0, 2.5, size / max(fw, 1e-6));
}

// Signed relief at a rest point with rest normal n: creases cut in (down to -1), tendons
// stand out (up to +1).
float fold_relief(vec3 rest, vec3 n, float fw) {
	float h = 0.0;
	int fc = min(fold_count, FOLD_MAX);
	for (int i = 0; i < fc; i++) {
		vec3 rel = rest - fold_p[i].xyz;
		float reach = fold_p[i].w;
		float dist = length(rel);
		if (dist >= reach) {
			continue;
		}
		float r = fold_d[i].w;
		float gap = fold_gap * r;
		float cnt = fold_n[i].w;
		// The lines wander so they never look ruled.
		float along = dot(rel, fold_d[i].xyz)
				+ (noise21(rest.xz * 90.0 + vec2(rest.y * 37.0)) - 0.5) * 0.5 * gap;
		float u = along / gap + 0.5 * (cnt - 1.0);
		float k = clamp(floor(u + 0.5), 0.0, cnt - 1.0);
		float t = min(abs(u - k) * gap / (fold_width * r), 1.0);
		float groove = (1.0 - t * t) * (1.0 - t * t);
		float back = smoothstep(0.1, 0.6, dot(n, fold_n[i].xyz));
		float edge = 1.0 - smoothstep(0.7 * reach, reach, dist);
		h -= groove * back * edge * fold_fade(2.0 * fold_width * r, fw);
	}
	float up = smoothstep(0.2, 0.7, dot(n, tendon_n));
	int tc = (up > 0.0) ? min(tendon_count, TENDON_MAX) : 0;
	for (int i = 0; i < tc; i++) {
		// Distance to the cord as seen from above the hand: both flattened along tendon_n.
		vec3 ab = tendon_b[i].xyz - tendon_a[i].xyz;
		vec3 ap = rest - tendon_a[i].xyz;
		ab -= tendon_n * dot(ab, tendon_n);
		ap -= tendon_n * dot(ap, tendon_n);
		float s = clamp(dot(ap, ab) / max(dot(ab, ab), 1e-8), 0.0, 1.0);
		float hw = max(tendon_a[i].w, 1e-6);
		float t = min(length(ap - ab * s) / hw, 1.0);
		float ridge = (1.0 - t * t) * (1.0 - t * t);
		// Fades in off the wrist and sinks under the knuckle.
		float run = smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.8, 1.0, s));
		h += ridge * run * up * fold_fade(2.0 * hw, fw);
	}
	return clamp(h, -1.0, 1.0);
}
