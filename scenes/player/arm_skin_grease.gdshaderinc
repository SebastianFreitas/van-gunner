// Grease and grime for the first-person hands: dark oily black-brown packed into the palm, finger
// pads, creases and claw roots, smudged on the back of the hand, a few wiped streaks on the forearm
// thinning toward the elbow. Fixed design (no seeds). Include after arm_skin_layers and
// arm_skin_folds (fold_p, fold_d, fold_n); it darkens and roughens (matte, never shinier than bare skin).

uniform float grease_span = 1.0; // shoulder-to-hand distance in rest units (vein_data.x runs 0..span)
const vec3 GREASE_TONE = vec3(0.005, 0.004, 0.003); // linear, darker than the skin's 0.06

// Quintic-faded 3D value noise on a sin-free hash: no cell edges or axis-aligned steps.
float gr_hash(vec3 c) {
	c = fract(c * 0.1031);
	c += dot(c, c.zyx + 31.32);
	return fract((c.x + c.y) * c.z);
}

float gr_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float x0 = mix(mix(gr_hash(i), gr_hash(i + vec3(1, 0, 0)), u.x),
			mix(gr_hash(i + vec3(0, 1, 0)), gr_hash(i + vec3(1, 1, 0)), u.x), u.y);
	float x1 = mix(mix(gr_hash(i + vec3(0, 0, 1)), gr_hash(i + vec3(1, 0, 1)), u.x),
			mix(gr_hash(i + vec3(0, 1, 1)), gr_hash(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(x0, x1, u.z);
}

const mat3 GR_ROT = mat3(vec3(0.8, 0.0, -0.6), vec3(0.36, 0.8, 0.48), vec3(0.48, -0.6, 0.64));

// Domain-warped, rotated 4-octave fbm: soft smeared blotches, 0..1 centred near 0.5.
float gr_fbm(vec3 p, float s) {
	p = p * s;
	p += 1.3 * (vec3(gr_noise(p * 0.5 + 3.1), gr_noise(p * 0.5 + 7.7),
			gr_noise(p * 0.5 + 11.3)) - 0.5);
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * gr_noise(p);
		p = GR_ROT * p * 2.03 + vec3(17.3, 9.1, 4.7);
		a *= 0.5;
	}
	return clamp(0.5 + (v - 0.47) * 1.8, 0.0, 1.0);
}

// rest/n: rest position and normal. hand: hand weight. axis_d: along the arm from the shoulder.
// crease: 0..1 how deep a fold floor is here.
void grease_layer(vec3 rest, vec3 n, float hand, float axis_d, float crease,
		inout vec3 albedo, inout float rough) {
	// Palm side: the rest normal against the back-of-hand direction, a wide ramp so it never steps.
	float palm = 1.0 - smoothstep(-0.35, 0.35, dot(n, tendon_n));
	float region = hand * mix(0.45, 1.0, palm);
	float broad = gr_fbm(rest + vec3(2.7, 8.1, 4.3), 14.0);
	float fine = gr_fbm(rest + vec3(9.4, 1.6, 6.8), 52.0);
	float f = 0.7 * broad + 0.3 * fine;
	// Palm and pads are mostly coated, the back only smudged.
	float thr = mix(0.40, 0.24, region);
	float patch = smoothstep(thr, thr + 0.12, f) * smoothstep(0.0, 0.5, region);
	// Finger pads and inner fingers (palm side of every finger tube) and the claw roots (beyond
	// the last joint of each finger).
	float pad = 0.0;
	float claw = 0.0;
	int fc = min(fold_count, FOLD_MAX);
	for (int i = 0; i < fc; i++) {
		vec3 rel = rest - fold_p[i].xyz;
		float r = fold_d[i].w;
		float along = dot(rel, fold_d[i].xyz);
		float radial = length(rel - fold_d[i].xyz * along);
		float tube = (1.0 - smoothstep(1.6 * r, 2.8 * r, radial)) * smoothstep(-r, r, along);
		pad = max(pad, tube * palm);
		if (fold_n[i].w < 2.5) {
			claw = max(claw, (1.0 - smoothstep(1.5 * r, 2.6 * r, radial))
					* smoothstep(-0.5 * r, 1.5 * r, along));
		}
	}
	float heavy = hand * (0.55 * pad + 0.5 * claw);
	float body = clamp(patch * 0.85 + heavy * (0.45 + 0.55 * f), 0.0, 1.0);
	// Grime packed into the folds, broken up by the fine noise.
	float folds = clamp(crease, 0.0, 1.0) * hand * (0.55 + 0.45 * fine) * 0.95;
	// Forearm: wiped streaks along the arm, fewer and thinner toward the elbow.
	float t = axis_d / max(grease_span, 1e-4);
	float ends = smoothstep(0.50, 0.97, t) * (1.0 - hand);
	float wu = abs(vein_data.y) / max(abs(vein_data.y) + abs(vein_data.z), 1e-4);
	float along_n = t * 5.0;
	float s = wu * gr_noise(vec3(along_n, vein_data.z * 46.0, 1.7))
			+ (1.0 - wu) * gr_noise(vec3(along_n, vein_data.y * 46.0, 6.3) + vec3(5.3, 8.1, 0.0));
	float streak = smoothstep(0.62 - 0.1 * ends, 0.86, s) * smoothstep(0.38, 0.6, broad);
	float mask = clamp(body + folds + streak * ends * 0.55, 0.0, 1.0);
	// Partial mix, so the vein and tendon shading underneath still shows through.
	albedo = mix(albedo, GREASE_TONE, mask);
	// Grime is always matte: roughness only goes up, never below the bare skin.
	rough = max(rough, mix(rough, 0.9, mask));
}
