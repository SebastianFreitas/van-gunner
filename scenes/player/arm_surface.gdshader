shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// First-person arms, sleeve and rifle steel: the road's grime recipe on the 0.18-scaled viewmodel.
// Patterns are laid out in model-space virtual metres and sampled triplanar, so tapered limb
// cylinders show no seam; seed_offset shifts the noise so two limbs on one recipe differ.

#include "res://scenes/shaders/grime.gdshaderinc"

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

// Painted crown highlight: a fixed view-space key, up and toward the camera's left, so the
// ridge's lit flank and shaded flank read even where the arm lamp does not reach.
const vec3 VEIN_KEY = normalize(vec3(-0.3, 0.8, 0.52));

varying vec3 obj_pos;
varying vec3 obj_normal;
// CUSTOM0: x along the arm, y and z across it, w vein mask.
varying vec4 vein_data;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	vein_data = CUSTOM0;
}

float tri_fbm(vec3 p, vec3 w, float scale) {
	return fbm(p.zy * scale) * w.x + fbm(p.xz * scale) * w.y + fbm(p.xy * scale) * w.z;
}

float tri_noise(vec3 p, vec3 w, float scale) {
	return noise21(p.zy * scale) * w.x + noise21(p.xz * scale) * w.y
			+ noise21(p.xy * scale) * w.z;
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
	ROUGHNESS = clamp(roughness_value - 0.04 * (grain - 0.5) - 0.25 * vn, 0.60, 0.95);
	METALLIC = metallic_value;
	SPECULAR = 0.5 + 0.2 * vn;
}
