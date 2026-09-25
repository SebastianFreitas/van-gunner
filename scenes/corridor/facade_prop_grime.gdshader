shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Large facade props (awnings, docks, arcades, set-piece bodies) in the road's grime recipe,
// patterns laid out in model-space metres so they read like the road and walls instead of a
// flat plastic slab.

#include "res://scenes/shaders/grime.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.2, 0.19, 0.175);
uniform vec3 dirt_color : source_color = vec3(0.1, 0.09, 0.07);
uniform vec3 stain_color : source_color = vec3(0.12, 0.11, 0.09);
uniform vec3 crack_color : source_color = vec3(0.05, 0.048, 0.042);
uniform float roughness_value : hint_range(0.78, 0.95) = 0.88;
uniform float metallic_value : hint_range(0.0, 0.3) = 0.0;
uniform float grime : hint_range(0.0, 1.0) = 0.6;

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

void fragment() {
	vec3 an = abs(normalize(obj_normal));
	vec2 p;
	if (an.x >= an.y && an.x >= an.z) {
		p = obj_pos.zy;
	} else if (an.y >= an.z) {
		p = obj_pos.xz;
	} else {
		p = obj_pos.xy;
	}
	float side = 1.0 - smoothstep(0.5, 0.8, an.y);
	float top = smoothstep(0.5, 0.9, normalize(obj_normal).y);

	vec2 fw2 = fwidth(p);
	float fw = max(fw2.x, fw2.y);

	vec3 col = base_color * (0.9 + 0.2 * (fbm(p * 0.7 + 3.1) - 0.5) * 2.0);

	// Grain, faded with distance so it never shimmers.
	float gfade = 1.0 - smoothstep(0.02, 0.05, fw);
	col *= mix(1.0, 0.85 + 0.3 * noise21(p * 18.0), gfade);

	// Broad grime wash.
	float wash = smoothstep(0.35, 0.8, fbm(p * 0.45 + 7.3)) * grime;
	col = mix(col, col * 0.55, wash);

	// Rain streaks on side faces.
	float streak = smoothstep(0.55, 0.8, fbm(vec2(p.x * 3.0, p.y * 0.25) + 1.7)) * grime * side;
	col = mix(col, dirt_color * 0.8, streak * 0.6);

	// Dust on top faces.
	float dust = top * grime * (0.5 + 0.5 * fbm(p * 1.1 + 4.4));
	col = mix(col, dirt_color, dust * 0.5);

	// Stains.
	float stain = smoothstep(0.6, 0.75, fbm(p * 1.3 + 17.0)) * grime;
	col = mix(col, stain_color, stain * 0.6);

	// Cracks, faded with distance.
	float cfade = 1.0 - smoothstep(0.03, 0.08, fw);
	float coverage = smoothstep(0.5, 0.65, fbm(p * 0.3 + 11.0));
	float cracks = (1.0 - smoothstep(0.02, 0.06, crack_field(p * 1.2 + 2.3))) * coverage * grime
		* cfade;
	col = mix(col, crack_color, cracks * 0.7);

	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	if (lum > 0.4) {
		col *= 0.4 / lum;
	}
	ALBEDO = col;

	ROUGHNESS = clamp(roughness_value + wash * 0.05 + dust * 0.05, 0.78, 0.95);
	METALLIC = clamp(metallic_value * (1.0 - wash * 0.5), 0.0, 0.3);
}
