// Soft wear masks painted on the railgun's body boxes: soot, rust and a tape band, laid out in
// gun space (mesh-local position plus the instance's wear_origin). Off by default (wear_on 0), so
// hands and arms never change. Edges are the spot radius warped by fbm and faded by a smoothstep,
// so they read as burn, corrosion and cloth where a box patch read as a panel.
// Needs fbm from grime.gdshaderinc.

const int WEAR_MAX = 6;

uniform float wear_on : hint_range(0.0, 1.0) = 0.0;
uniform int wear_count = 0;
// xyz centre in gun space, w radius (soot and rust).
uniform vec4 wear_spot[WEAR_MAX];
// x kind (0 soot, 1 rust, 2 tape band), y and z the band's z range (tape).
uniform vec4 wear_info[WEAR_MAX];
uniform vec3 wear_tape_color : source_color = vec3(0.40, 0.425, 0.45);
// The mesh's position in the gun's body space; per instance because materials may be shared.
instance uniform vec3 wear_origin = vec3(0.0);

// Triplanar fbm in gun space; f is cells per gun unit.
float wear_noise(vec3 g, vec3 w, float f) {
	return w.x * fbm(g.yz * f) + w.y * fbm(g.xz * f) + w.z * fbm(g.xy * f);
}

void wear_apply(vec3 g, vec3 w, inout vec3 col, inout float rough, inout float spec,
		inout float metal) {
	for (int i = 0; i < WEAR_MAX; i++) {
		if (i >= wear_count) {
			break;
		}
		vec4 s = wear_spot[i];
		vec4 info = wear_info[i];
		if (info.x > 1.5) {
			// Tape band: ragged, slightly wavy edges in z, faint wrap lines along z.
			float bw = info.z - info.y;
			float wob = wear_noise(g, w, 5.0 / bw) - 0.5;
			float fray = wear_noise(g, w, 24.0 / bw) - 0.5;
			float e0 = info.y + (wob * 0.22 + fray * 0.08) * bw;
			float e1 = info.z + (wob * 0.18 - fray * 0.08) * bw;
			float soft = 0.05 * bw;
			float m = smoothstep(e0, e0 + soft, g.z) * (1.0 - smoothstep(e1 - soft, e1, g.z));
			float lines = sin(g.z / (bw / 9.0) * 6.2831853) * 0.5 + 0.5;
			float weave = wear_noise(g, w, 60.0 / bw);
			vec3 tape = wear_tape_color * (1.0 + (lines - 0.5) * 0.14 + (weave - 0.5) * 0.18);
			// A dark grimy rim just outside each edge separates the band from the body.
			float mo = smoothstep(e0 - 0.09 * bw, e0, g.z) * (1.0 - smoothstep(e1, e1 + 0.09 * bw, g.z));
			col = mix(col, vec3(0.012, 0.01, 0.008), clamp(mo - m, 0.0, 1.0) * 0.9);
			col = mix(col, tape, m);
			rough = mix(rough, 0.95, m);
			spec = mix(spec, 0.1, m);
			metal = mix(metal, 0.0, m);
			continue;
		}
		float r = s.w;
		float warp = wear_noise(g, w, 4.0 / r);
		float rr = r * (0.55 + 0.9 * warp);
		vec3 dv = g - s.xyz;
		// Rust drips: below the centre the distance is squashed, so the patch runs down (-y).
		if (info.x > 0.5 && dv.y < 0.0) {
			dv.y *= 0.4;
		}
		float dist = length(dv);
		float m = 1.0 - smoothstep(rr * 0.7, rr, dist);
		// A few detached specks just outside the edge.
		float speck_n = wear_noise(g + vec3(7.3, 2.1, 5.9), w, 16.0 / r);
		float speck = smoothstep(0.66, 0.78, speck_n) * (1.0 - smoothstep(rr, rr * 1.6, dist));
		m = max(m, speck * 0.8);
		if (info.x < 0.5) {
			// The mask wins: no specular at all, or the warm light washes the black tan.
			vec3 soot = mix(vec3(0.04, 0.036, 0.032), vec3(0.004), smoothstep(0.3, 0.95, m));
			col = mix(col, soot, smoothstep(0.0, 0.6, m));
		} else {
			float pit = smoothstep(0.58, 0.74, wear_noise(g + vec3(3.1, 8.7, 1.3), w, 14.0 / r));
			vec3 rust = mix(vec3(0.012, 0.008, 0.006), vec3(0.30, 0.12, 0.04), pit * 0.85);
			col = mix(col, rust, m);
		}
		rough = mix(rough, 1.0, m);
		spec = mix(spec, 0.0, m);
		metal = mix(metal, 0.0, m);
	}
}
