// Skin blights (rare warts, scabs, pit scars) and palm calluses for the arm skin bump; needs grime.gdshaderinc and the shader's seed_offset, blight_scale and callus_scale.

vec3 blight_hash(vec3 c) {
	vec3 q = vec3(dot(c, vec3(127.1, 311.7, 74.7)), dot(c, vec3(269.5, 183.3, 246.1)),
			dot(c, vec3(113.5, 271.9, 124.6)));
	return fract(sin(q) * 43758.5453);
}

// x height (signed, pits negative), y type (0 wart, 1 scab, 2 pit, -1 none), z the winner's
// normalized distance. Sparse irregular cells: warped domain, jittered centre, lobed outline.
vec3 blight_info(vec3 p, float accept) {
	vec3 q = p * blight_scale + vec3(seed_offset * 1.7);
	q += 0.7 * (vec3(fbm(q.yz * 0.5), fbm(q.zx * 0.5), fbm(q.xy * 0.5)) - 0.5);
	vec3 cell = floor(q);
	vec3 pos = vec3(0.0, -1.0, 1.0);
	vec3 pit = vec3(0.0, -1.0, 1.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				vec3 a = blight_hash(c);
				if (a.x >= accept) {
					continue;
				}
				vec3 b = blight_hash(c + vec3(19.3, 7.1, 43.7));
				vec3 s = blight_hash(c + vec3(5.7, 31.1, 12.3));
				vec3 o = q - (c + 0.2 + 0.6 * s);
				o.y *= mix(0.6, 1.4, b.z);
				float lobe_a = 1.0 + 0.35 * sin(3.0 * atan(o.z, o.x) + a.y * 6.28)
						+ 0.2 * sin(5.0 * atan(o.z, o.x) + a.z * 6.28);
				float lobe_b = 1.0 + 0.35 * sin(3.0 * atan(o.y, o.x) + a.y * 6.28)
						+ 0.2 * sin(5.0 * atan(o.y, o.x) + a.z * 6.28);
				float rad = mix(0.22, 0.45, b.y) * mix(lobe_a, lobe_b, 0.5);
				float d = length(o) / max(rad, 1e-3);
				if (d >= 1.0) {
					continue;
				}
				float nz = noise21(q.xz * 8.0 + vec2(q.y * 3.0));
				if (b.x < 0.5) {
					float hgt = mix(0.7, 1.0, a.y) * pow(1.0 - d, 0.6) * (0.85 + 0.3 * nz);
					if (hgt > pos.x) {
						pos = vec3(hgt, 0.0, d);
					}
				} else if (b.x < 0.8) {
					float hgt = 0.5 * smoothstep(1.0, 0.7, d)
							* (0.6 + 0.8 * noise21(q.xz * 16.0 + vec2(q.y * 7.0)));
					if (hgt > pos.x) {
						pos = vec3(hgt, 1.0, d);
					}
				} else {
					float hgt = -smoothstep(0.75, 0.0, d) * 0.8
							+ 0.35 * smoothstep(0.55, 0.8, d) * smoothstep(1.0, 0.8, d);
					if (hgt < pit.x) {
						pit = vec3(hgt, 2.0, d);
					}
				}
			}
		}
	}
	// A pit cell wins inside its radius.
	return (pit.x < -0.001) ? pit : pos;
}

float blight_height(vec3 p, float accept) {
	return blight_info(p, accept).x;
}

// Flat thick waxy pads: elongated plateau cells, edges softened by a low fbm warp.
float callus_height(vec3 p) {
	vec3 q = p * callus_scale + vec3(seed_offset * 2.3);
	q += 0.5 * (vec3(fbm(q.yz * 0.3), fbm(q.zx * 0.3), fbm(q.xy * 0.3)) - 0.5);
	vec3 cell = floor(q);
	float best = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				vec3 a = blight_hash(c + vec3(61.7, 3.3, 27.9));
				if (a.x >= 0.35) {
					continue;
				}
				vec3 b = blight_hash(c + vec3(11.1, 83.3, 9.7));
				vec3 o = q - (c + 0.2 + 0.6 * b);
				int ax = int(a.y * 2.999);
				if (ax == 0) {
					o.x *= 2.0;
				} else if (ax == 1) {
					o.y *= 2.0;
				} else {
					o.z *= 2.0;
				}
				float d = length(o) / mix(0.35, 0.55, a.z);
				best = max(best, smoothstep(1.0, 0.55, d));
			}
		}
	}
	return best;
}

// Colour for one blight (info from blight_info); m is the dorsal mask times skin_bump.
vec3 blight_tint(vec3 col, vec3 info, float m) {
	float d = info.z;
	if (info.y < -0.5) {
		return col;
	} else if (info.y < 0.5) {
		col *= mix(1.0, 0.45, m * smoothstep(0.6, 0.95, d) * smoothstep(1.05, 0.95, d));
		col = mix(col, col * vec3(1.15, 1.08, 0.85), m * smoothstep(0.7, 0.1, d) * 0.8);
	} else if (info.y < 1.5) {
		col = mix(col, vec3(0.13, 0.05, 0.03), m * smoothstep(1.0, 0.75, d) * 0.85);
	} else {
		col *= mix(1.0, 0.45, m * smoothstep(0.8, 0.0, d));
	}
	return col;
}
