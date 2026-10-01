// Skins the street's real paving pieces (square tiles, small setts, granite curb blocks,
// rubble chunks). The mesh has no UVs: COLOR.r = wreck, COLOR.g = per-piece tone,
// COLOR.b = up (1 on tops and chamfers, 0 at the foot of the sides). Patterns are planar
// in world metres, and every fine pattern fades with fwidth before it goes sub-pixel.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/shaders/grime.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.42, 0.41, 0.38);
uniform vec3 dirt_color : source_color = vec3(0.16, 0.13, 0.10);
uniform vec3 stain_color : source_color = vec3(0.10, 0.09, 0.075);
uniform float tone_spread = 0.35;
uniform float grain_per_m = 9.0;
uniform float crack_width_m = 0.035;
uniform float crack_amount = 1.0;
uniform float litter = 0.5;
uniform float roughness_value = 0.9;
// How far wreck pulls the albedo toward dirt_color.
uniform float wreck_dirt = 0.6;

// Draws embedded pebbles and stones on top faces (soil only; 0 leaves every other kind as is).
uniform float gravel : hint_range(0.0, 1.0) = 0.0;
// Worn, packed-earth tone variation (soil only).
uniform float packed : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world;
varying vec3 v_wnormal;

// One layer of round pebbles on a jittered grid (one hashed point and radius per cell,
// present in `density` of the cells). Fades to a flat 8% lift toward the stone colour
// (its average) before the cells go sub-pixel.
vec3 gravel_layer(vec2 wp, float cell, float r_min, float r_max, vec3 col, vec3 stone,
		float density) {
	vec3 lit = col;
	vec2 base = floor(wp / cell);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 id = base + vec2(float(i), float(j));
			vec2 pt = (id + 0.2 + 0.6 * hash22(id + 11.3)) * cell;
			float d = length(wp - pt);
			float r = mix(r_min, r_max, hash21(id + 23.7));
			float aa = max(fwidth(d), 0.003);
			float present = step(hash21(id + 41.9), density);
			float mask = (1.0 - smoothstep(r - aa, r + aa, d)) * present;
			float rim = (1.0 - smoothstep(r, r + 0.02, d)) * present;
			lit *= 1.0 - 0.35 * (rim - mask);
			vec3 pebble = stone * mix(0.6, 0.95, hash21(id + 67.1));
			lit = mix(lit, pebble, mask);
		}
	}
	float fade = 1.0 - smoothstep(cell * 0.15, cell * 0.4, length(fwidth(wp)));
	return mix(mix(col, stone, 0.08), lit, fade);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_wnormal);
	vec2 p;
	if (abs(n.y) > 0.6) {
		p = v_world.xz;
	} else if (abs(n.x) > abs(n.z)) {
		p = v_world.zy;
	} else {
		p = v_world.xy;
	}
	float top = smoothstep(0.6, 0.85, n.y);

	float tone = COLOR.g;
	float wreck = COLOR.r;
	float up = COLOR.b;

	vec3 col = base_color * (1.0 - tone_spread * 0.5 + tone_spread * tone);

	// Grain, faded before it gets sub-pixel.
	float fw = max(length(fwidth(p)), 1e-5);
	float g = noise21(p * grain_per_m + tone * 7.0);
	float gfade = 1.0 - smoothstep(0.03, 0.08, fw * grain_per_m * 0.1);
	col *= mix(1.0, 0.88 + 0.24 * g, gfade);

	// Stains.
	float s = fbm(p * 0.7 + vec2(tone * 13.0));
	col = mix(col, stain_color, smoothstep(0.55, 0.8, s) * 0.5);

	// Wear on tops.
	float w = fbm(p * 1.3 + 4.0);
	col *= 1.0 + 0.08 * top * smoothstep(0.6, 0.75, w);

	// Damaged paving grades from fair to dirty as it nears an obliterated zone.
	col = mix(col, dirt_color, clamp(wreck, 0.0, 1.0) * wreck_dirt);

	// Cracks on tops, only on wrecked pieces; crack_field returns an edge distance in
	// cell units, and the cells are 1/1.8 m.
	float edge_m = crack_field(p * 1.8 + vec2(tone * 31.0)) / 1.8;
	float line = 1.0 - smoothstep(crack_width_m * 0.5, crack_width_m, edge_m);
	float cfade = 1.0 - smoothstep(0.02, 0.05, fw);
	float crack = line * crack_amount * top * smoothstep(0.15, 0.6, wreck + tone * 0.3) * cfade
			* (0.35 + 0.65 * wreck);
	col = mix(col, dirt_color * 0.6, clamp(crack, 0.0, 1.0));

	// Wreck darkening and dirt toward the foot of the sides.
	col *= mix(1.0, 0.8, wreck);
	col = mix(dirt_color, col, smoothstep(0.0, 0.7, up));

	// Litter on tops.
	vec2 cell = floor(v_world.xz / 0.6);
	if (hash21(cell) < 0.04 * litter * (0.5 + wreck) && top > 0.5) {
		vec2 centre = cell * 0.6 + 0.3 + (hash22(cell) - 0.5) * 0.3;
		vec2 half_size = vec2(0.04 + 0.04 * hash21(cell + 3.1), 0.03 + 0.03 * hash21(cell + 5.7));
		vec2 d = abs(v_world.xz - centre);
		if (d.x < half_size.x && d.y < half_size.y) {
			col = vec3(0.62, 0.60, 0.55);
		}
	}

	// Worn packed earth: broad tone drift and darker damp spots, so bare soil is not one flat tone.
	float rough = roughness_value;
	if (packed > 0.0) {
		float big = noise21(v_world.xz * 0.35);
		float mid = noise21(v_world.xz * 1.6 + 5.0);
		float damp = smoothstep(0.55, 0.75, noise21(v_world.xz * 0.8 + 31.0));
		col *= mix(1.0, 0.82 + 0.3 * big + 0.12 * (mid - 0.5), packed);
		col = mix(col, col * 0.7, damp * 0.5 * packed);
		rough = mix(rough, rough - 0.08 * damp, packed);
	}

	// Pebbles and gravel set into the soil, tops only. Real gravel sits in a few soft patches;
	// the rest is bare dirt with a faint grit.
	if (gravel > 0.0) {
		vec2 wp = v_world.xz;
		float patch_n = noise21(wp * 0.45) * 0.65 + noise21(wp * 1.3 + 17.0) * 0.35;
		float patch_m = smoothstep(0.62, 0.78, patch_n);
		vec3 stone = vec3(0.24, 0.23, 0.21);
		vec3 coarse = gravel_layer(wp, 0.22, 0.03, 0.055, col, stone, 0.15);
		vec3 packed_col = mix(col, coarse, patch_m * 0.6);
		vec3 fine = gravel_layer(wp, 0.07, 0.012, 0.025, packed_col, stone, 0.45);
		packed_col = mix(packed_col, fine, max(patch_m, 0.08));
		col = mix(col, packed_col, gravel * smoothstep(0.5, 0.8, up));
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;

	// Far away the chamfers and tops must not glow as a grid: lean their normals up and
	// dull the specular.
	float far = smoothstep(18.0, 45.0, length(VERTEX));
	if (up > 0.5) {
		NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, far * 0.8));
	}
	SPECULAR = 0.4 * (1.0 - far * 0.7);
}
