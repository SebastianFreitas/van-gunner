// Shared grime noise for world shaders (the road's library): hash, value
// noise, fbm and a Voronoi crack field. Include it instead of pasting
// copies.

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
	return fract(sin(vec2(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3))
	)) * 43758.5453);
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
		p = p * 2.07 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

float crack_field(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float min_d = 1.0;
	float second = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(cell + g);
			vec2 r = g + o - f;
			float d = length(r);
			if (d < min_d) {
				second = min_d;
				min_d = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return second - min_d;
}

// The sidewalk's seeding: same crack shape as crack_field, a different cell layout.
float crack_field_h21(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float min_d = 1.0;
	float second = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash21(cell + g), hash21(cell + g + 19.0));
			vec2 r = g + o - f;
			float d = length(r);
			if (d < min_d) {
				second = min_d;
				min_d = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return second - min_d;
}
