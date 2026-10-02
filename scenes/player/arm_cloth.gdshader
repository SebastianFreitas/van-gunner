shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Worn T-shirt cloth for the first-person sleeves (viewmodel metres, the same
// scale as arm_surface.gdshader). The meshes are skinned, so VERTEX is already posed; every
// pattern reads the rest chart from CUSTOM0 = (rest x, y, z, edge) instead, so nothing swims.
// edge is 0 at a torn edge and rises to 1 inside the cloth.

#include "res://scenes/shaders/grime.gdshaderinc"
#include "res://scenes/player/viewmodel_fov.gdshaderinc"

// The three tints are sRGB values: source_color makes Godot convert them to linear.
uniform vec3 base_tint : source_color = vec3(0.20, 0.18, 0.13);
uniform vec3 edge_dirt : source_color = vec3(0.05, 0.045, 0.035);
uniform vec3 blood_tone : source_color = vec3(0.12, 0.04, 0.03);
uniform float seed = 0.0;

// Virtual metres: mottle about 6/m, grain about 60/m, ribs 2.5 cm.
const float MOTTLE_M = 6.0;
const float GRAIN_M = 60.0;
const float RIB_PITCH = 0.025;
// A raw constant mixed into ALBEDO is linear, so this brown sits just under the body tint.
const vec3 SWEAT_TONE = vec3(0.013, 0.010, 0.005);

// Rest chart: xyz rest position, w edge (0 at a tear, 1 inside the cloth).
varying vec4 cloth;

void vertex() {
	cloth = CUSTOM0;
	// A mesh without the chart would discard everything at e = 0: render a flat worn tint instead.
	if (dot(CUSTOM0, CUSTOM0) == 0.0) {
		cloth.w = 1.0;
	}
	if (!IN_SHADOW_PASS) {
		apply_viewmodel_fov(PROJECTION_MATRIX);
	}
}

float tri_fbm(vec3 p, vec3 w, float scale) {
	return fbm(p.zy * scale) * w.x + fbm(p.xz * scale) * w.y + fbm(p.xy * scale) * w.z;
}

float tri_noise(vec3 p, vec3 w, float scale) {
	return noise21(p.zy * scale) * w.x + noise21(p.xz * scale) * w.y
			+ noise21(p.xy * scale) * w.z;
}

// A soft iso-line of a field: 1 on the level, 0 a band half-width away (widened by its screen
// derivative so it stays a line, not a flicker).
float iso_band(float v, float level, float half_width) {
	return 1.0 - smoothstep(0.0, half_width + fwidth(v), abs(v - level));
}

void fragment() {
	// Triplanar weights from the rest-space face normal, so the pattern holds still in motion.
	vec3 rn = abs(cross(dFdx(cloth.xyz), dFdy(cloth.xyz)));
	float rn_sum = rn.x + rn.y + rn.z;
	vec3 w = (rn_sum < 1e-14) ? vec3(1.0 / 3.0) : rn / rn_sum;
	w = w * w;
	w = w / (w.x + w.y + w.z);

	vec3 p = cloth.xyz + vec3(seed, seed * 0.37, seed * 0.71);
	float e = cloth.w;
	float fw = max(fwidth(p.x), max(fwidth(p.y), fwidth(p.z)));

	// Base tint with broad mottle, +-15%.
	float mottle = tri_fbm(p, w, MOTTLE_M);
	vec3 col = base_tint * (1.0 + clamp((mottle - 0.5) * 2.0, -1.0, 1.0) * 0.15);

	// Jersey weave: soft ribs along the rest Y axis and fine grain, +-6% together, each faded to
	// its average before it drops under 2 pixels.
	float rib = sin(p.y / RIB_PITCH * 6.2831853);
	float rib_fade = 1.0 - smoothstep(RIB_PITCH * 0.25, RIB_PITCH * 0.5, fw);
	float grain = tri_noise(p, w, GRAIN_M);
	float grain_fade = 1.0 - smoothstep(0.25 / GRAIN_M, 0.5 / GRAIN_M, fw);
	float weave = rib * rib_fade * 0.6 + (grain - 0.5) * 2.0 * grain_fade * 0.4;
	col *= 1.0 + clamp(weave, -1.0, 1.0) * 0.06;

	// Sweat-stain rings: a few iso-lines of a slow fbm, darkened toward a brown.
	float sweat = tri_fbm(p + vec3(53.1, 7.7, 29.3), w, 2.5);
	float rings = max(iso_band(sweat, 0.38, 0.015),
			max(iso_band(sweat, 0.46, 0.015), iso_band(sweat, 0.54, 0.015)));
	col = mix(col, SWEAT_TONE, rings * 0.25);

	// Blood blotches: sparse patches of a 3/m fbm above 0.72, soft edged.
	float blood = tri_fbm(p + vec3(11.9, 41.3, 5.3), w, 3.0);
	col = mix(col, blood_tone, smoothstep(0.72, 0.78, blood) * 0.7);

	// Edge dirt: darkens toward the tear.
	col = mix(col, edge_dirt, (1.0 - smoothstep(0.0, 0.25, e)) * 0.6);

	// Ragged hem: fine noise along the edge eats into the cloth.
	if (e < 0.07 * tri_noise(p + vec3(3.7, 19.1, 8.3), w, GRAIN_M)) {
		discard;
	}
	// Torn wear: where a warped 18/m fbm peaks the cloth is gone, so holes are ragged and
	// elongated, never a grid of discs. The warp bends the field by up to 2 cm and a fine noise
	// frays the rim. Thresholds from the fbm's octave weights (0.5, 0.25, 0.125, 0.0625): mean
	// 0.469, sd about 0.125 with the fray, so 0.69 (z 1.75) tears about 4% of the cloth and 0.64
	// (z 1.37) about 9% near the hem.
	vec3 pw = p + (tri_fbm(p, w, 9.0) - 0.5) * 0.04;
	float tear = tri_fbm(pw + vec3(17.3, 5.1, 23.7), w, 18.0)
			+ (tri_noise(p, w, 140.0) - 0.5) * 0.10;
	float tear_thr = mix(0.64, 0.69, smoothstep(0.4, 0.55, e));
	if (tear > tear_thr) {
		discard;
	}

	if (!FRONT_FACING) {
		col *= 0.45; // the inside of the sleeve is darker
	}
	ALBEDO = col;
	ROUGHNESS = clamp(0.88 + 0.07 * grain, 0.88, 0.95);
	METALLIC = 0.0;
	SPECULAR = 0.3;
}
