shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// First-person arms, sleeve and rifle steel: the road's grime recipe on the 0.18-scaled viewmodel.
// Patterns are laid out in model-space virtual metres and sampled triplanar, so tapered limb
// cylinders show no seam; seed_offset shifts the noise so two limbs on one recipe differ.

#include "res://scenes/shaders/grime.gdshaderinc"
#include "res://scenes/player/viewmodel_fov.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.22, 0.26, 0.21);
uniform vec3 shade_color : source_color = vec3(0.11, 0.14, 0.12);
uniform vec3 dirt_color : source_color = vec3(0.08, 0.08, 0.06);
// Virtual metres: grain about 60/m, mottle about 6/m (about 11/m and 1/m real on the 0.18 rig).
uniform float grain_m : hint_range(10.0, 120.0) = 60.0;
uniform float mottle_m : hint_range(1.0, 20.0) = 6.0;
// Cloth rib pitch along the limb axis in virtual metres; 0 is skin or steel (no ribs).
uniform float rib_m : hint_range(0.0, 0.1) = 0.0;
uniform float grime : hint_range(0.0, 1.0) = 0.5;
uniform float roughness_value : hint_range(0.78, 0.95) = 0.88;
uniform float metallic_value : hint_range(0.0, 0.3) = 0.0;
uniform float seed_offset = 0.0;
// Raised veins (skin only): 0 is no veins. Drawn from the mesh's CUSTOM0 (x along the arm,
// y and z across it, w the mask). Widths are in mesh units: the inflated forearm is about 0.25
// wide, so the main vein is about 0.09 of it and the branches 0.05.
uniform float vein_strength : hint_range(0.0, 1.0) = 0.0;
// Vein cells per mesh unit along the arm and across it.
uniform float vein_along_m = 1.5;
uniform float vein_around_m = 6.0;
// Full width of a main vein in mesh units; branches are 0.55 of it.
uniform float vein_width : hint_range(0.004, 0.06) = 0.022;
// Peak ridge height in view metres (the rig is 0.18-scaled): 0.4 x the half width x 0.18.
uniform float vein_height : hint_range(0.0, 0.004) = 0.0008;

// Saggy old-meat bump (skin only): 0 is off, so cloth and steel, which share this shader, stay
// as they are. Shades folds and wrinkles from the rest chart so they do not swim when the hand bends.
uniform float skin_bump : hint_range(0.0, 1.0) = 0.0;
// Frequency of the sharp knots, in rest-space units.
uniform float sag_scale = 0.0;
// Frequency of the fine wrinkles, in rest-space units.
uniform float wrinkle_scale = 0.0;
// Peak fold slope scale in view metres per unit of height gradient (the rig is 0.18-scaled).
const float SKIN_BUMP_HEIGHT = 0.0015;

// Painted crown highlight: a fixed view-space key, up and toward the camera's left, so the
// ridge's lit flank and shaded flank read even where the arm lamp does not reach.
const vec3 VEIN_KEY = normalize(vec3(-0.3, 0.8, 0.52));

// Skin only: the engine skins vertices before vertex() runs, so VERTEX is already posed and a
// pattern drawn from it swims as the arm moves. The skin mesh bakes its rest pose into CUSTOM1
// (xyz position, w hand weight) and CUSTOM2 (xyz normal), and the patterns read those instead.
uniform bool use_rest_pos = false;

varying vec3 obj_pos;
varying vec3 obj_normal;
// CUSTOM0: x along the arm, y and z across it, w vein mask.
varying vec4 vein_data;
// Rest-pose position (xyz) and hand weight (w); the posed VERTEX when use_rest_pos is off.
varying vec4 rest_data;

// Skin layers (tattoo, scars, wounds, grazes, dirt); read vein_data, so it follows the varyings.
#include "res://scenes/player/arm_skin_layers.gdshaderinc"

void vertex() {
	rest_data = use_rest_pos ? CUSTOM1 : vec4(VERTEX, 0.0);
	obj_pos = rest_data.xyz;
	obj_normal = use_rest_pos ? CUSTOM2.xyz : NORMAL;
	vein_data = CUSTOM0;
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

vec3 knot_hash(vec3 c) {
	vec3 q = vec3(dot(c, vec3(127.1, 311.7, 74.7)), dot(c, vec3(269.5, 183.3, 246.1)),
			dot(c, vec3(113.5, 271.9, 124.6)));
	return fract(sin(q) * 43758.5453);
}

// Sharp knots: a cone (pointed top, hard crease at its base) at a jittered point in a sparse
// share of the cells, flat skin between them.
float knot_height(vec3 p) {
	vec3 cell = floor(p);
	float best = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				vec3 hv = knot_hash(c);
				vec3 kv = knot_hash(c + vec3(19.3, 7.1, 43.7));
				if (kv.x >= 0.18) {
					continue;
				}
				vec3 pt = c + 0.15 + 0.7 * hv;
				float rad = mix(0.18, 0.48, kv.y);
				float hgt = mix(0.35, 1.0, kv.z);
				best = max(best, hgt * max(0.0, 1.0 - length(p - pt) / rad));
			}
		}
	}
	return best;
}

// Fold height in the rest chart: sharp knots plus fine wrinkles, triplanar on the rest normal's weights.
float knot_at(vec3 rest) {
	vec3 q = rest * sag_scale;
	q += 0.6 * vec3(fbm(q.yz * 0.37), fbm(q.zx * 0.37), fbm(q.xy * 0.37)) - 0.3;
	return knot_height(q);
}

float skin_height(vec3 rest, vec3 w) {
	return 0.75 * knot_at(rest) + 0.25 * tri_fbm(rest, w, wrinkle_scale);
}

// Veins from two side projections of the across coordinates, blended so there is no seam.
// x is the crest profile, y and z its screen derivatives; fw is the mesh units per pixel.
vec3 vein_field(vec4 c, float fw) {
	float wu = abs(c.y) / max(abs(c.y) + abs(c.z), 1e-4);
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 2; i++) {
		float s = (i == 0) ? c.z : c.y;
		float ws = (i == 0) ? wu : 1.0 - wu;
		vec2 q = vec2(c.x * vein_along_m, s * vein_around_m) + vec2(seed_offset);
		q.y += (fbm(q * 0.7) - 0.5) * 1.6; // wiggle and branching
		for (int k = 0; k < 2; k++) {
			// Layer 0 is the main vein, layer 1 a thinner branch on its own noise.
			vec2 qk = (k == 0) ? q : q * 1.9 + vec2(37.1, 11.7);
			float w = (k == 0) ? vein_width * 0.5 : vein_width * 0.275;
			float hk = (k == 0) ? 1.0 : 0.6;
			float v = noise21(qk) * 2.0 - 1.0;
			// Distance to the zero crossing in mesh units, from the screen derivative.
			float d = abs(v) * fw / max(fwidth(v), 1e-6);
			float t = d / w;
			float tt = min(t, 1.0);
			float prof = (1.0 - tt * tt) * (1.0 - tt * tt);
			float slope = (t < 1.0) ? -4.0 * t * (1.0 - t * t) : 0.0;
			// A ridge under 4 px vanishes, one over 8 px is whole, so it never shimmers.
			float fade = smoothstep(4.0, 8.0, 2.0 * w / fw);
			sum.x += ws * hk * fade * prof;
			sum.y += ws * hk * fade * slope * dFdx(t);
			sum.z += ws * hk * fade * slope * dFdy(t);
		}
	}
	return sum * clamp(c.w, 0.0, 1.0);
}

void fragment() {
	vec3 n = normalize(obj_normal);
	vec3 w = abs(n);
	w = w / max(w.x + w.y + w.z, 0.001);
	vec3 p = obj_pos + vec3(seed_offset, seed_offset * 0.37, seed_offset * 0.71);

	// Base tone, then mottle (hide patches, cloth fade, steel blotches) toward the shade colour.
	float mottle = tri_fbm(p, w, mottle_m);
	vec3 col = mix(base_color, shade_color, smoothstep(0.35, 0.75, mottle));
	// Grain: pores, weave or mill marks, faded with fwidth so it never shimmers.
	float fw = max(fwidth(p.x), max(fwidth(p.y), fwidth(p.z)));
	float grain_fade = 1.0 - smoothstep(0.3 / grain_m, 0.8 / grain_m, fw);
	float grain = tri_noise(p, w, grain_m);
	col *= 1.0 + (grain - 0.5) * 0.3 * grain_fade;
	// Veins: a raised soft ridge, tilted by its analytic slope, with a painted crown highlight.
	float vn = 0.0;
	if (vein_strength > 0.0) {
		vec3 vf = vein_field(vein_data, fw) * vein_strength;
		vn = min(vf.x, 1.0);
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		float hx = vf.y * vein_height;
		float hy = vf.z * vein_height;
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (hx * r1 + hy * r2);
		vec3 n_old = NORMAL;
		NORMAL = normalize(abs(det) * NORMAL - grad);
		float lit = dot(NORMAL, VEIN_KEY) - dot(n_old, VEIN_KEY);
		vec3 crest = col * vec3(0.90, 1.00, 1.04) * 1.06;
		col = mix(col, crest, vn * 0.5);
		col *= 1.0 + clamp(lit * 0.35, -0.20, 0.15);
	}
	// Saggy skin: tilt the normal by the fold height's gradient, darken and roughen the hollows.
	float fold_dark = 0.0;
	if (skin_bump > 0.0) {
		vec3 rest = rest_data.xyz;
		float eps = 0.25 / wrinkle_scale;
		vec3 g = vec3(
				skin_height(rest + vec3(eps, 0.0, 0.0), w) - skin_height(rest - vec3(eps, 0.0, 0.0), w),
				skin_height(rest + vec3(0.0, eps, 0.0), w) - skin_height(rest - vec3(0.0, eps, 0.0), w),
				skin_height(rest + vec3(0.0, 0.0, eps), w) - skin_height(rest - vec3(0.0, 0.0, eps), w)
		) / (2.0 * eps);
		g -= dot(g, n) * n; // slope along the surface only
		// Same screen-space mapping as the vein ridge: height change per pixel, then the tilt.
		float hx = skin_bump * SKIN_BUMP_HEIGHT * dot(g, dFdx(rest));
		float hy = skin_bump * SKIN_BUMP_HEIGHT * dot(g, dFdy(rest));
		vec3 sdx = dFdx(VERTEX);
		vec3 sdy = dFdy(VERTEX);
		vec3 s1 = cross(sdy, NORMAL);
		vec3 s2 = cross(NORMAL, sdx);
		float sdet = dot(sdx, s1);
		vec3 grad_view = sign(sdet) * (hx * s1 + hy * s2);
		NORMAL = normalize(abs(sdet) * NORMAL - grad_view);
		float kh = knot_at(rest);
		float wrinkle = tri_fbm(rest, w, wrinkle_scale);
		fold_dark = smoothstep(0.5, 0.25, wrinkle) * 0.6
				+ smoothstep(0.0, 0.08, kh) * smoothstep(0.3, 0.1, kh) * 0.4;
		col *= mix(1.0, 0.82, skin_bump * fold_dark);
	}
	// Dirt: fbm-masked grime that collects in the hollows.
	float dirt_mask = smoothstep(0.55, 0.85, tri_fbm(p + vec3(31.7, 9.3, 17.1), w, mottle_m * 0.7));
	col = mix(col, dirt_color, dirt_mask * grime);
	// Cloth ribs: a sine along the limb axis (the cylinder's Y), faded before it aliases.
	if (rib_m > 0.0) {
		float rib = sin(p.y / rib_m * 6.2831853) * 0.5 + 0.5;
		float rib_fade = 1.0 - smoothstep(rib_m * 0.2, rib_m * 0.5, fw);
		col *= 1.0 + (rib - 0.5) * 0.25 * rib_fade;
	}

	ALBEDO = col;
	ROUGHNESS = clamp(roughness_value - 0.04 * (grain - 0.5) - 0.25 * vn
			+ 0.05 * skin_bump * fold_dark, 0.60, 0.95);
	METALLIC = metallic_value;
	SPECULAR = 0.5 + 0.2 * vn;
	if (use_rest_pos) {
		vec3 skin_albedo = ALBEDO;
		float skin_rough = ROUGHNESS;
		skin_layers(rest_data.xyz, rest_data.w, vein_data.x, skin_albedo, skin_rough);
		ALBEDO = skin_albedo;
		ROUGHNESS = skin_rough;
	}
}
