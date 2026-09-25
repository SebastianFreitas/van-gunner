shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Old cracked sidewalk concrete — slab seams, stains, chewed edges.
// UV is 0–1 per BoxMesh face; pass surface_size_m as (width, length) in meters.

#include "res://scenes/shaders/grime.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.2, 0.19, 0.175);
uniform vec3 seam_color : source_color = vec3(0.08, 0.075, 0.07);
uniform vec3 stain_color : source_color = vec3(0.12, 0.11, 0.09);
uniform vec3 crack_color : source_color = vec3(0.05, 0.048, 0.042);
uniform vec3 dirt_color : source_color = vec3(0.1, 0.09, 0.07);
uniform vec3 wear_color : source_color = vec3(0.26, 0.245, 0.22);
uniform vec2 surface_size_m = vec2(1.75, 20.0);
uniform float slab_spacing_m : hint_range(0.6, 2.5) = 1.2;
uniform float washout : hint_range(0.0, 1.0) = 0.5;
uniform float trash : hint_range(0.0, 1.0) = 0.65;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;

void fragment() {
	vec2 pos = (UV - vec2(0.5)) * surface_size_m;
	vec2 uv_m = UV * surface_size_m;

	// Slab grid seams along walk length.
	float slab_phase = fract(uv_m.y / slab_spacing_m);
	float slab_seam = 1.0 - smoothstep(0.015, 0.05, min(slab_phase, 1.0 - slab_phase));
	float cross_seam = 1.0 - smoothstep(0.02, 0.06, min(UV.x, 1.0 - UV.x));
	float seams = max(slab_seam, cross_seam * 0.55);

	// Foot-traffic wear down the middle of the walk.
	float aisle = 1.0 - smoothstep(0.15, surface_size_m.x * 0.42, abs(pos.x));
	float wear = aisle * smoothstep(0.3, 0.75, fbm(pos * vec2(2.0, 0.45) + 2.1));

	// Spills / dark stains.
	float blotch = fbm(pos * 0.55 + vec2(5.2, 1.8));
	float stain = smoothstep(0.62, 0.88, blotch) * trash;

	// Cracks — more near seams and trashy slabs.
	float cracks = 1.0 - smoothstep(0.014, 0.05, crack_field_h21(uv_m * 0.7 + 4.1));
	cracks *= (0.35 + 0.65 * seams + 0.4 * trash)
		* smoothstep(0.4, 0.8, fbm(uv_m * 0.4 + 9.0));

	// Edge dirt against wall (outer) and curb (inner) — UV.x extremes.
	float wall_dirt = smoothstep(0.55, 0.95, UV.x) + smoothstep(0.45, 0.05, UV.x);
	wall_dirt *= 0.4 + 0.6 * fbm(vec2(UV.x * 4.0, uv_m.y * 0.3) + 7.0);

	float grain = noise21(uv_m * 36.0);
	float bleach = washout * (0.3 + 0.7 * fbm(pos * 0.2 + vec2(2.0, 8.0)));

	vec3 color = base_color;
	color = mix(color, wear_color, wear * 0.45);
	color = mix(color, seam_color, seams * 0.7);
	color = mix(color, stain_color, stain * 0.65);
	color = mix(color, dirt_color, wall_dirt * 0.5);
	color = mix(color, crack_color, cracks * 0.8);

	color *= 0.91 + 0.16 * grain;
	color = mix(color, vec3(0.24, 0.23, 0.21), bleach * 0.3);
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma), washout * 0.2);

	ALBEDO = color;
	METALLIC = 0.0;
	ROUGHNESS = clamp(
		roughness_value
			+ seams * 0.04
			+ stain * 0.08
			- wear * 0.06
			+ wall_dirt * 0.04,
		0.4,
		1.0
	);

	float n_x = (fbm(uv_m * 8.0) - 0.5) * 0.3 + cracks * 0.35;
	float n_y = (slab_phase - 0.5) * seams * 0.4 + (grain - 0.5) * 0.15;
	NORMAL_MAP = vec3(n_x, n_y, 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.4;
}
