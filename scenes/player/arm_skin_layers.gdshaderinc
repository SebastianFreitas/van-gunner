// Skin layers for the first-person arms: a faded prison tattoo, scars, wounds, knuckle grazes, dirt
// and blood specks, drawn over the finished skin colour from the rest-pose chart (positions are
// mesh/rest space, so nothing swims when the arm moves). Every count and amount defaults to 0, and
// then skin_layers returns at once, so cloth, steel and the old dress look exactly as before.
// Include it after grime.gdshaderinc and after the host's `vein_data` varying (CUSTOM0: x along the
// arm, y and z across it): the dirt streaks read it. Noise comes from the grime include.

// Cells per rest-space metre, the same scale arm_surface applies to its own grain and mottle.
const float SK_GRAIN = 60.0;
const float SK_MOTTLE = 6.0;
// Ink pressure cells per box unit.
const float SK_PRESS = 20.0;

uniform int scar_count = 0;
uniform vec4 scar_a[8]; // xyz start, w half-width
uniform vec4 scar_b[8]; // xyz end, w stitched (1.0 = yes)
uniform int wound_count = 0;
uniform vec4 wound_p[4]; // xyz centre, w radius
uniform vec4 wound_d[4]; // xyz long direction, w elongation
uniform int knuckle_count = 0;
uniform vec4 knuckles[4]; // xyz centre, w radius
uniform float dirt_amount = 0.0;
uniform vec3 dirt_tone = vec3(0.012, 0.010, 0.007); // linear, the skin is only about 0.06
uniform vec3 blood_tone = vec3(0.07, 0.010, 0.007); // linear
uniform int tat_count = 0;
uniform vec4 tat_segs[64]; // x0 y0 x1 y1 in box units
uniform vec3 tat_origin;
uniform vec3 tat_axis;
uniform vec3 tat_ref;
uniform float tat_radius;
uniform float tat_angle;
uniform float tat_along0;
uniform float tat_width;
uniform float tat_height;
uniform float tat_stroke;
uniform vec3 ink_color = vec3(0.012, 0.020, 0.022); // linear, darker than the skin to read

// 0 when a feature of `size` rest units is under 2 pixels, 1 over 4; fw is rest units per pixel.
float sk_fade(float size, float fw) {
	return smoothstep(2.0, 4.0, size / max(fw, 1e-6));
}

// Value noise on the three axis planes with equal weights (no normal here), stretched back to the
// contrast one plane gives.
float sk_noise(vec3 p, float s) {
	float n = noise21(p.zy * s) + noise21(p.xz * s + vec2(7.3, 1.9))
			+ noise21(p.xy * s + vec2(3.1, 5.7));
	return clamp(0.5 + (n / 3.0 - 0.5) * 1.7, 0.0, 1.0);
}

float sk_fbm(vec3 p, float s) {
	float n = fbm(p.zy * s) + fbm(p.xz * s + vec2(7.3, 1.9)) + fbm(p.xy * s + vec2(3.1, 5.7));
	return clamp(0.5 + (n / 3.0 - 0.5) * 1.7, 0.0, 1.0);
}

float sk_seg2(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-8), 0.0, 1.0);
	return length(p - a - ab * t);
}

// The tattoo: the box is unrolled around the forearm (axis, reference direction, radius) and the
// stroke segments are drawn as soft, uneven ink with stick-and-poke dots.
void sk_ink(vec3 p, float fw, float wob, inout vec3 albedo) {
	vec3 q = p - tat_origin;
	float along = dot(q, tat_axis) - tat_along0;
	float ang = atan(dot(q, cross(tat_ref, tat_axis)), dot(q, tat_ref));
	float wa = ang - tat_angle;
	wa -= TAU * floor((wa + PI) / TAU);
	if (abs(wa) > 1.4) {
		return;
	}
	vec2 b = vec2(along, wa * tat_radius + 0.5 * tat_height);
	float d = 1e6;
	int cnt = min(tat_count, 64);
	for (int i = 0; i < cnt; i++) {
		vec4 sg = tat_segs[i];
		d = min(d, sk_seg2(b, sg.xy, sg.zw));
	}
	float w = tat_stroke;
	float ink = 1.0 - smoothstep(w, 2.0 * w, d + wob * 0.4 * w);
	float press = mix(0.8, 1.0, noise21(b * SK_PRESS));
	float pitch = 0.9 * w;
	float poke_dot = 1.0 - smoothstep(0.30, 0.45, length(fract(b / pitch) - 0.5));
	// A dot of 0.30..0.45 pitch radius covers about 0.43 of the cell on average.
	float poke = mix(0.65, 1.0, mix(0.43, poke_dot, sk_fade(pitch, fw)));
	albedo = mix(albedo, ink_color, ink * press * poke);
}

// Keloid ridges with a glossy centre; stitched ones get dark dots either side of the line.
void sk_scars(vec3 p, float fw, float wob, inout vec3 albedo, inout float rough) {
	int cnt = min(scar_count, 8);
	for (int i = 0; i < cnt; i++) {
		vec3 a = scar_a[i].xyz;
		vec3 ab = scar_b[i].xyz - a;
		float hw = scar_a[i].w;
		float len = max(length(ab), 1e-5);
		vec3 dir = ab / len;
		float s = dot(p - a, dir);
		float d = length(p - a - dir * clamp(s, 0.0, len));
		float m = 1.0 - smoothstep(0.6 * hw, hw, d + wob * 0.5 * hw);
		vec3 keloid = min(mix(albedo * 1.6, vec3(0.12, 0.075, 0.065), 0.5), vec3(0.40));
		albedo = mix(albedo, keloid, m);
		rough = mix(rough, 0.55, m);
		if (scar_b[i].w > 0.5 && s > 0.0 && s < len) {
			float pitch = 4.0 * hw;
			vec2 off = vec2(d - 1.6 * hw, (fract(s / pitch) - 0.5) * pitch);
			float stitch = 1.0 - smoothstep(0.25 * hw, 0.35 * hw, length(off));
			albedo = mix(albedo, vec3(0.05), stitch * sk_fade(0.7 * hw, fw));
		}
	}
}

// Wet near-black core, a sunken rim, a crust ring and a bruise halo around it.
void sk_wounds(vec3 p, float wob, inout vec3 albedo, inout float rough) {
	int cnt = min(wound_count, 4);
	for (int i = 0; i < cnt; i++) {
		float r = max(wound_p[i].w, 1e-5);
		vec3 qd = p - wound_p[i].xyz;
		vec3 dir = wound_d[i].xyz;
		float a = dot(qd, dir);
		float e = length(vec2(a / (r * max(wound_d[i].w, 0.01)), length(qd - dir * a) / r));
		e += wob * 0.3;
		if (e > 1.8) {
			continue;
		}
		float halo = 1.0 - smoothstep(0.9, 1.8, e);
		albedo *= mix(1.0, 0.72, halo);
		albedo = mix(albedo, vec3(0.022, 0.016, 0.028), halo * 0.4);
		float crust = 1.0 - smoothstep(0.85, 0.95, e);
		albedo = mix(albedo, vec3(0.03, 0.012, 0.008), crust);
		rough = mix(rough, 0.92, crust);
		float wet = 1.0 - smoothstep(0.50, 0.58, e);
		albedo = mix(albedo, vec3(0.035, 0.010, 0.008), wet);
		rough = mix(rough, 0.25, wet);
		albedo *= 1.0 - 0.2 * (1.0 - smoothstep(0.0, 0.05, abs(e - 0.55)));
	}
}

// Scraped knuckles: a noise-broken raw patch.
void sk_knuckles(vec3 p, float gf, inout vec3 albedo, inout float rough) {
	int cnt = min(knuckle_count, 4);
	for (int i = 0; i < cnt; i++) {
		float r = knuckles[i].w;
		float d = length(p - knuckles[i].xyz);
		if (d >= r) {
			continue;
		}
		float scrape = mix(0.5, smoothstep(0.40, 0.60, sk_noise(p, SK_GRAIN)), gf);
		float graze = (1.0 - smoothstep(0.55 * r, r, d)) * scrape;
		albedo = mix(albedo, vec3(0.07, 0.020, 0.015), graze * 0.6);
		rough = mix(rough, 0.6, graze);
	}
}

// Patchy mottle collecting more on the hands, plus streaks along the arm and crisp patches.
void sk_dirt(vec3 p, float hand, float axis_d, float fw, inout vec3 albedo, inout float rough) {
	float k = dirt_amount * (0.35 + 0.65 * hand);
	float f = sk_fbm(p, SK_MOTTLE);
	float mask = k * smoothstep(0.45, 0.75, f);
	// Streaks: noise on (along x 2, across x 64), across from the two side projections of the vein
	// frame so the wrap-around has no seam.
	float wu = abs(vein_data.y) / max(abs(vein_data.y) + abs(vein_data.z), 1e-4);
	float sn = wu * noise21(vec2(axis_d * 2.0, vein_data.z * 64.0))
			+ (1.0 - wu) * noise21(vec2(axis_d * 2.0, vein_data.y * 64.0) + vec2(5.3, 8.1));
	float streak = mix(0.2, smoothstep(0.50, 0.80, sn), sk_fade(1.0 / 64.0, fw));
	mask += k * 0.35 * streak;
	mask += k * 0.5 * smoothstep(0.58, 0.62, f);
	mask = clamp(mask, 0.0, 1.0);
	albedo = mix(albedo, dirt_tone, mask * 0.85);
	rough = min(rough + 0.05 * mask, 0.95);
}

// Hash dots of blood around each wound, about 8% of the skin within 3 radii. The dots are small
// spheres in jittered 3D cells (the surface cuts through them), kept inside their own cell.
void sk_specks(vec3 p, float fw, inout vec3 albedo) {
	int cnt = min(wound_count, 4);
	float zone = 0.0;
	for (int i = 0; i < cnt; i++) {
		float r = wound_p[i].w;
		zone = max(zone, 1.0 - smoothstep(2.5 * r, 3.0 * r, length(p - wound_p[i].xyz)));
	}
	if (zone <= 0.0) {
		return;
	}
	float cell = 1.0 / SK_GRAIN;
	vec3 c = floor(p / cell);
	vec3 jit = vec3(hash21(c.xy + c.z * 17.17), hash21(c.yz + c.x * 13.31 + 5.7),
			hash21(c.zx + c.y * 11.13 + 9.3));
	float rho = 0.27 * cell;
	float gate = step(hash21(c.xy * 1.37 + c.z * 7.77 + 31.1), 0.45);
	float spk = gate * (1.0 - smoothstep(0.7 * rho, rho, length(p - (c + 0.27 + 0.46 * jit) * cell)));
	albedo = mix(albedo, blood_tone, zone * mix(0.08, spk, sk_fade(2.0 * rho, fw)));
}

void skin_layers(vec3 p, float hand, float axis_d, inout vec3 albedo, inout float rough) {
	if (tat_count <= 0 && scar_count <= 0 && wound_count <= 0 && knuckle_count <= 0
			&& dirt_amount <= 0.0) {
		return;
	}
	// Derivatives first, while every fragment still runs the same code.
	float fw = max(fwidth(p.x), max(fwidth(p.y), fwidth(p.z)));
	float gf = sk_fade(1.0 / SK_GRAIN, fw);
	float wob = (sk_noise(p, SK_GRAIN) - 0.5) * gf;
	if (tat_count > 0) {
		sk_ink(p, fw, wob, albedo);
	}
	sk_scars(p, fw, wob, albedo, rough);
	sk_wounds(p, wob, albedo, rough);
	sk_knuckles(p, gf, albedo, rough);
	if (dirt_amount > 0.0) {
		sk_dirt(p, hand, axis_d, fw, albedo, rough);
	}
	sk_specks(p, fw, albedo);
}
