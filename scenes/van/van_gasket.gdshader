shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Old salvaged window rubber on the donor rear window gasket, in the road's grime recipe:
// patterns in model-space metres, soft isotropic blotches only (no grain, no edge fade), bone dry
// with a low specular so the bead's inner slope never catches the street light as a pale band.

#include "res://scenes/shaders/grime.gdshaderinc"

// Linear albedo, no sRGB hint, neutral grey-black: the warm interior light does the tinting.
uniform vec3 base_color = vec3(0.08, 0.08, 0.08);
uniform vec3 dirt_color = vec3(0.028, 0.028, 0.028);
uniform vec3 dust_color = vec3(0.05, 0.05, 0.05);
uniform float grime : hint_range(0.0, 1.0) = 0.6;

uniform float light_desat : hint_range(0.0, 1.0) = 0.85;
uniform float light_scale : hint_range(0.0, 2.0) = 0.38;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	// The strip is thin: lay the pattern on the window plane, offset by depth so the two
	// flanges and the web do not repeat each other.
	vec2 p = obj_pos.xy + vec2(obj_pos.z * 5.3, obj_pos.z * 3.1);
	vec3 col = base_color * (0.9 + 0.2 * fbm(p * 2.0 + 3.1));

	// Soft grey dust blotches and darker grime wash, low contrast.
	float dust = smoothstep(0.4, 0.8, fbm(p * 1.5 + 9.7));
	col = mix(col, dust_color, dust * 0.5);
	float wash = smoothstep(0.35, 0.8, fbm(p * 0.9 + 7.3)) * grime;
	col = mix(col, dirt_color, wash * 0.5);

	// Neutral grey-black, luminance 0.025..0.06 so the warm cabin lamp stays off brown.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = vec3(clamp(lum, 0.025, 0.06));

	ALBEDO = col;
	ROUGHNESS = 0.97;
	METALLIC = 0.0;
	SPECULAR = 0.05;
}

// Own matte diffuse: the warm cabin lamps (about 24 energy together) would tint even a 0.03 albedo
// brown, so the light is pulled toward its luminance and slightly cool. No specular is added.
void light() {
	float l = dot(LIGHT_COLOR, vec3(0.2126, 0.7152, 0.0722));
	vec3 lc = mix(LIGHT_COLOR, vec3(l), light_desat) * vec3(0.9, 0.98, 1.1);
	DIFFUSE_LIGHT += lc * ATTENUATION * clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * light_scale / PI;
}
