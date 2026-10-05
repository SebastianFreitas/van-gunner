// Skin blights (rare warts, crusted scabs, pit scars) for the arm skin: smooth metaball domes in the rest chart; needs grime.gdshaderinc and the shader's seed_offset (the cell scale is a parameter).

vec3 blight_hash(vec3 c) {
	vec3 q = vec3(dot(c, vec3(127.1, 311.7, 74.7)), dot(c, vec3(269.5, 183.3, 246.1)),
			dot(c, vec3(113.5, 271.9, 124.6)));
	return fract(sin(q) * 43758.5453);
}

// Squared distance only: no sqrt, no atan, no lobes, so no cusp at the centre and a zero slope
// at the rim.
float blight_dome(vec3 o, float r, float k) {
	float t = max(1.0 - dot(o, o) / (r * r), 0.0);
	return pow(t, k);
}

// Soft-clamped fields in 0..1: x wart, y scab, z pit core, w pit lip. Blobs are summed, never
// max()ed, because max leaves a crease where two meet.
vec4 blight_field(vec3 p, float scale, float accept, float widen) {
	vec3 q = p * scale + vec3(seed_offset * 1.7);
	// One low octave only: fbm's high octaves made the edges jagged.
	q += 0.25 * (vec3(noise21(q.yz * 0.6), noise21(q.zx * 0.6), noise21(q.xy * 0.6)) - 0.5);
	vec3 cell = floor(q);
	vec4 sum = vec4(0.0);
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
				vec3 centre = c + 0.3 + 0.4 * s;
				float r0 = mix(0.20, 0.32, b.y);
				float r = r0 * widen;
				float sq = mix(0.75, 1.3, b.z);
				vec3 o = q - centre;
				o.y *= sq;
				if (b.x < 0.5 || b.x < 0.8) {
					float kx = (b.x < 0.5) ? 3.0 : 2.0;
					float blob = blight_dome(o, r, kx);
					int n_sat = int(s.z * 3.0);
					for (int k = 0; k < n_sat; k++) {
						vec3 h = blight_hash(c + vec3(float(k) * 13.1 + 3.7, 7.7, 3.3));
						vec3 dir = normalize(h - 0.5 + vec3(1e-3));
						vec3 sc = centre + dir * r0 * mix(0.9, 1.4, h.x);
						vec3 so = q - sc;
						so.y *= sq;
						blob += mix(0.6, 0.9, h.z) * blight_dome(so, r * mix(0.45, 0.7, h.y), kx);
					}
					if (b.x < 0.5) {
						sum.x += blob;
					} else {
						sum.y += blob;
					}
				} else {
					float qq = dot(o, o) / (r * r);
					sum.z += pow(max(1.0 - qq, 0.0), 2.0);
					sum.w += pow(max(1.0 - qq / 1.69, 0.0), 2.0);
				}
			}
		}
	}
	return 1.0 - exp(-2.0 * sum);
}

// Dome wart, flat-topped scab, pit with a soft raised lip.
float blight_height(vec4 f) {
	return f.x + 0.6 * smoothstep(0.0, 0.45, f.y) - 0.8 * f.z + 0.3 * f.w;
}

// Vertex relief: wider and lower than the shading field so one coarse vertex never pokes up
// alone, and no pits so the mesh is never dented.
float blight_relief(vec3 p, float scale, float accept) {
	vec4 f = blight_field(p, scale, accept, 1.5);
	return 0.5 * (f.x + 0.6 * smoothstep(0.0, 0.45, f.y));
}

// Shading cues for the blight field; m is the dorsal mask times skin_bump.
void blight_shade(vec4 f, vec3 p, float scale, float m, inout vec3 col, inout float rough, inout float ao) {
	// Foot ring: the cavity at the base of a wart or scab.
	float fb = max(f.x, f.y);
	float foot = smoothstep(0.03, 0.2, fb) * smoothstep(0.5, 0.25, fb);
	col *= 1.0 - 0.3 * m * foot;
	ao -= 0.5 * m * foot;
	// Wart: paler and yellower, glossy on top.
	col = mix(col, col * vec3(1.25, 1.15, 0.80), m * f.x * 0.8);
	rough -= 0.18 * m * f.x * f.x;
	// Scab: dark crust with cracks and a pale flaking edge.
	float crust = smoothstep(0.1, 0.4, f.y);
	col = mix(col, vec3(0.09, 0.035, 0.025), m * crust * 0.9);
	vec2 cp = p.xz * scale * 5.0 + vec2(p.y * scale * 5.0);
	float crack = 1.0 - smoothstep(0.02, 0.06, crack_field(cp));
	col *= 1.0 - 0.5 * m * crust * crack;
	col = mix(col, col * 1.6, m * smoothstep(0.1, 0.2, f.y) * smoothstep(0.35, 0.2, f.y) * 0.5);
	rough += 0.07 * m * crust;
	// Pit: dark and occluded, with a waxy lip.
	col *= mix(1.0, 0.5, m * f.z);
	ao -= 0.5 * m * f.z;
	float lip = clamp(f.w - 1.5 * f.z, 0.0, 1.0);
	col = mix(col, col * vec3(1.3, 1.1, 1.05), m * lip * 0.6);
	rough -= 0.15 * m * lip;
	ao = clamp(ao, 0.0, 1.0);
}
