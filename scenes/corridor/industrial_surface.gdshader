shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Stop-bay steel and concrete (bay walls and floors, the vestibule, the warehouse room, the shop
// booth plates, oil drums) in the road's grime recipe. Patterns are laid out in model-space
// metres picked by the face's dominant normal axis, so every user must be an unscaled mesh
// (all are centred BoxMeshes today): panels, seams and rivets, then grain, a grime wash, rust,
// streaks, oil on floors, a dirt band at a wall's foot and floor cracks.

#include "res://scenes/shaders/grime.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.16, 0.18, 0.17);
uniform vec3 seam_color : source_color = vec3(0.035, 0.045, 0.04);
uniform vec3 rust_color : source_color = vec3(0.30, 0.105, 0.045);
uniform vec3 dirt_color : source_color = vec3(0.1, 0.09, 0.07);
uniform vec3 oil_color : source_color = vec3(0.025, 0.024, 0.022);
/// Panel width along the face and panel height (on floors: along x and z), in metres.
uniform vec2 panel_size_m = vec2(1.2, 2.4);
/// Model-space y of the floor a wall stands on; side faces get a dirt band above it. -1000 is off.
uniform float foot_y_m = -1000.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.86;
uniform float metallic_value : hint_range(0.0, 0.3) = 0.2;
uniform float grime : hint_range(0.0, 1.0) = 0.6;

varying vec3 obj_pos;
varying vec3 obj_normal;


void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}


// A line `width` wide (in pattern units) at every integer of `coord`, faded to its average
// coverage as it shrinks under a couple of pixels, so seams never shimmer at distance.
float soft_seam(float coord, float width) {
	float fw = fwidth(coord);
	float d = abs(fract(coord + 0.5) - 0.5);
	float line = 1.0 - smoothstep(width * 0.5, width * 0.5 + fw * 1.5, d);
	float fade = smoothstep(width * 0.5, width * 1.5, fw);
	return mix(line, width, fade);
}


void fragment() {
	vec3 n = normalize(obj_normal);
	vec3 an = abs(n);
	vec2 p;
	if (an.x >= an.y && an.x >= an.z) {
		p = obj_pos.zy;
	} else if (an.y >= an.z) {
		p = obj_pos.xz;
	} else {
		p = obj_pos.xy;
	}
	float side = 1.0 - smoothstep(0.5, 0.8, an.y);
	float top = smoothstep(0.5, 0.9, n.y);
	vec2 fw2 = fwidth(p);
	float fw = max(fw2.x, fw2.y);
	float gfade = 1.0 - smoothstep(0.02, 0.05, fw);

	// Panels and seams, offset half a panel so small centred boxes get no seam down the middle.
	vec2 panel = p / panel_size_m + 0.5;
	vec2 cell = floor(panel);
	vec2 seam_w = vec2(0.03) / panel_size_m;
	float seam = max(soft_seam(panel.x, seam_w.x), soft_seam(panel.y, seam_w.y));

	// Rivets 7 cm in from each seam every 0.3 m, gone before they shrink under a few pixels.
	vec2 to_seam = abs(fract(panel + 0.5) - 0.5) * panel_size_m;
	float riv_a = length(vec2(to_seam.x - 0.07, (fract(p.y / 0.3) - 0.5) * 0.3));
	float riv_b = length(vec2(to_seam.y - 0.07, (fract(p.x / 0.3) - 0.5) * 0.3));
	float rivet = (1.0 - smoothstep(0.012, 0.02, min(riv_a, riv_b)))
		* (1.0 - smoothstep(0.004, 0.012, fw));

	// Base tone per panel, then grain.
	float tone = fbm(p * 0.6 + cell * 1.7);
	vec3 col = base_color * (0.85 + 0.3 * tone) * (0.92 + 0.16 * hash21(cell));
	float grain = noise21(p * 22.0);
	col *= mix(1.0, 0.88 + 0.24 * grain, gfade);

	// Broad grime wash.
	float wash = smoothstep(0.35, 0.8, fbm(p * 0.4 + 7.3)) * grime;
	col = mix(col, col * 0.6, wash);

	// Rust blooms along seams, round rivets and near a wall's foot.
	float foot_h = obj_pos.y - foot_y_m;
	float near_foot = side * (1.0 - smoothstep(0.0, 1.2, foot_h));
	float rust_bias = seam * 0.5 + rivet * 0.6 + near_foot * 0.4;
	float rust = smoothstep(0.62, 0.85, fbm(p * 1.1 + 13.0) + rust_bias * 0.25) * grime;
	col = mix(col, rust_color, rust * 0.6);

	// Rust and rain streaks run down side faces.
	float streak = smoothstep(0.55, 0.8, fbm(vec2(p.x * 4.0, p.y * 0.3) + 1.7)) * side * grime;
	col = mix(col, mix(dirt_color, rust_color, 0.4) * 0.8, streak * 0.45);

	// Worn rivet heads, then the seams on top.
	col = mix(col, base_color * 1.4, rivet * 0.5);
	col = mix(col, seam_color, seam * 0.8);

	// Dust and oil on floors.
	float dust = top * grime * smoothstep(0.4, 0.8, fbm(p * 0.8 + 4.4));
	col = mix(col, dirt_color, dust * 0.4);
	float oil = top * smoothstep(0.6, 0.78, fbm(p * 0.5 + 21.0)) * grime;
	col = mix(col, oil_color, oil * 0.75);

	// Dirt band at a wall's foot, matching the sidewalk's edge dirt.
	float band = 0.35 + 0.35 * fbm(vec2(p.x * 1.5, 3.0));
	float foot = side * (1.0 - smoothstep(0.0, band, foot_h));
	col = mix(col, dirt_color, foot * 0.7 * (0.5 + 0.5 * grime));

	// Floor cracks, faded with distance.
	float cfade = 1.0 - smoothstep(0.03, 0.08, fw);
	float cracks = (1.0 - smoothstep(0.02, 0.06, crack_field(p * 1.2 + 2.3)))
		* smoothstep(0.5, 0.65, fbm(p * 0.3 + 11.0)) * grime * cfade * top;
	col = mix(col, seam_color, cracks * 0.7);

	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	if (lum > 0.4) {
		col *= 0.4 / lum;
	}
	ALBEDO = col;

	float rough = clamp(roughness_value + wash * 0.04 + rust * 0.06 + foot * 0.04, 0.78, 0.95);
	ROUGHNESS = mix(rough, 0.35, oil);
	METALLIC = clamp(
		metallic_value * (1.0 - rust * 0.8 - wash * 0.4 - foot) + rivet * 0.1, 0.0, 0.3);

	NORMAL_MAP = vec3(
		(grain - 0.5) * 0.2 * gfade + rust * 0.1,
		(tone - 0.5) * 0.2 - seam * 0.25,
		1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.4;
}
