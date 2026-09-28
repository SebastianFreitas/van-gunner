shader_type spatial;
// Dark-tinted exterior pane for the side cargo windows: single-sided so it is
// invisible from the cabin, fresnel-tinted glass with procedural dust and a
// dirtier bottom edge outside.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://scenes/shaders/grime.gdshaderinc"

uniform float dust_scale_m = 0.35;
// +1 for the right wall's pane, -1 for the left wall's; the pane mesh is emitted in both
// windings so cull_back can't hide it from the cabin, and the fragment discard does instead.
instance uniform float outward_sign = 1.0;

varying vec3 model_pos;
varying vec3 v_world_pos;
varying vec3 v_outward;

void vertex() {
	model_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_outward = normalize((MODEL_MATRIX * vec4(outward_sign, 0.0, 0.0, 0.0)).xyz);
}

void fragment() {
	if (dot(CAMERA_POSITION_WORLD - v_world_pos, v_outward) <= 0.0) {
		discard;
	}

	vec3 base_albedo = vec3(0.018, 0.024, 0.027);
	float base_roughness = 0.3;
	float base_alpha_low = 0.75;
	float base_alpha_high = 0.97;

	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	float f = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	float alpha = mix(base_alpha_low, base_alpha_high, f);
	NORMAL = n;

	float dust = smoothstep(0.45, 0.8, fbm(model_pos.zy / dust_scale_m)) * 0.35;
	float bottom_band = smoothstep(0.4, -0.6, model_pos.y);
	float dirt = clamp(dust + bottom_band * 0.5, 0.0, 1.0);

	vec3 dirty_albedo = vec3(0.045, 0.042, 0.038);
	ALBEDO = mix(base_albedo, dirty_albedo, dirt);
	ROUGHNESS = mix(base_roughness, 0.9, dirt);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = mix(alpha, 0.95, dirt);
}
