// Rear door leaf skin. The cabin face is a stamped steel inner skin (geometry: raised frame, ribs,
// rolled-lip holes); the cavity behind the holes shows the outer skin's dark back face. Worn paint
// and grime only, no painted holes. The street face is plain outer paint, the rim is bare steel.
// The mesh is the left leaf in hinge-local metres (the right leaf mirrors it), so every pattern is
// laid out in model-space metres. Detail comes from grime.gdshaderinc, no bitmaps.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/shaders/grime.gdshaderinc"

uniform float leaf_width_m = 2.378;
uniform float leaf_height_m = 3.38;
uniform vec4 paint_color : source_color = vec4(0.2, 0.2, 0.19, 1.0);
uniform vec4 outer_paint_color : source_color = vec4(0.16, 0.165, 0.155, 1.0);
uniform vec4 bare_steel_color : source_color = vec4(0.26, 0.26, 0.25, 1.0);
uniform vec4 hole_dark_color : source_color = vec4(0.03, 0.03, 0.028, 1.0);
uniform vec4 rust_color : source_color = vec4(0.09, 0.045, 0.025, 1.0);
uniform vec4 stain_color : source_color = vec4(0.04, 0.035, 0.03, 1.0);
uniform float roughness_paint = 0.86;
uniform float roughness_bare = 0.78;
uniform float metallic_paint = 0.12;
uniform float metallic_bare = 0.28;

varying vec3 v_pos;
varying vec3 v_nrm;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	vec2 p = v_pos.xy;
	float fw = max(fwidth(p.x), fwidth(p.y));
	float grit_vis = 1.0 - smoothstep(0.02, 0.05, fw);
	float grit = (fbm(p * 10.0) - 0.47) * 0.2 * grit_vis;
	float bottom = -leaf_height_m * 0.4527;
	float kick = (1.0 - smoothstep(-1.29, -1.21, p.y))
			* smoothstep(0.35, 0.6, fbm(p * 12.0 + vec2(5.0, 2.0)));
	float rough = roughness_paint;
	float metal = metallic_paint;
	vec3 col;

	if (v_nrm.z < -0.5 && v_pos.z > 0.0) {
		// Cavity: the outer skin's back face, deep and dark.
		col = hole_dark_color.rgb * (1.0 + grit);
		rough = 0.9;
	} else if (v_nrm.z < -0.5) {
		// Cabin face: raised pressings (z about -0.08) are lighter and wear to bare steel; the
		// flat sheet between them sits darker.
		float raised = 1.0 - smoothstep(-0.079, -0.077, v_pos.z);
		col = paint_color.rgb * mix(0.8, 1.1, raised);
		col *= 1.0 - 0.1 * smoothstep(0.85, 1.0, p.x / leaf_width_m);
		col *= 1.0 + grit;
		float wear = clamp(raised * 0.8 + kick, 0.0, 1.0)
				* smoothstep(0.45, 0.68, fbm(p * 14.0 + vec2(1.7, 9.2)));
		col = mix(col, bare_steel_color.rgb, wear);
		// Grime pools low and in the flat recesses as blotches, never as vertical grain.
		float pool = (1.0 - raised) * 0.5 + (1.0 - smoothstep(-1.2, 0.4, p.y)) * 0.5;
		float stain = smoothstep(0.55, 0.7, fbm(p * 4.0 + vec2(2.0, 7.0))) * pool;
		col = mix(col, stain_color.rgb, stain * 0.7);
		// Chipped paint on the raised pressing edges shows bare steel.
		float chip = raised * smoothstep(0.62, 0.74, fbm(p * 26.0 + vec2(6.1, 3.4)));
		col = mix(col, bare_steel_color.rgb * 1.15, chip * 0.6);
		float low_strip = 1.0 - smoothstep(0.0, 0.08, p.y - bottom);
		float rust = clamp(low_strip, 0.0, 1.0)
				* smoothstep(0.5, 0.72, fbm(p * 7.0 + vec2(8.3, 1.1)));
		col = mix(col, rust_color.rgb, rust * 0.85);
		float oil = smoothstep(0.7, 0.8, fbm(p * 3.0 + vec2(3.3, 6.6))) * 0.5;
		col = mix(col, stain_color.rgb, oil);
		rough = mix(roughness_paint, roughness_bare, wear);
		rough = mix(rough, 0.92, max(max(rust, stain * 0.7), oil));
		metal = mix(metallic_paint, metallic_bare, wear);
	} else if (v_nrm.z > 0.5) {
		col = outer_paint_color.rgb * (1.0 + grit);
		col *= 1.0 + 0.35 * smoothstep(0.62, 0.74, fbm(p * 24.0 + vec2(1.3, 8.8)));
		float blot = smoothstep(0.62, 0.78, fbm(p * 2.5 + vec2(4.4, 0.7)));
		col = mix(col, rust_color.rgb, blot * 0.7);
		col = mix(col, bare_steel_color.rgb * 0.6, kick * 0.5);
		rough = mix(roughness_paint, 0.92, blot);
		metal = mix(metallic_paint, metallic_bare, kick * 0.5);
	} else {
		float worn = smoothstep(0.45, 0.7, fbm(p * 6.0 + vec2(2.0, 5.0)));
		// Recess walls: bright bare rim at the face, going near black toward the blind bottom.
		float depth = smoothstep(-0.08, 0.04, v_pos.z);
		col = bare_steel_color.rgb * mix(1.0, 0.12, depth) * (1.0 + grit * 1.5);
		col = mix(col, rust_color.rgb, worn * 0.5);
		rough = roughness_bare;
		metal = metallic_bare;
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.78, 0.95);
	METALLIC = clamp(metal, 0.0, 0.3);
}
