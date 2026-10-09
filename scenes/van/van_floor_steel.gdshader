// Van floor steel: rusted deck plate on the rear door's recipe (van_rear_door.gdshader: same
// palette, blotch / fine / pit / streak layers, paint islands). One shader for every floor piece;
// the mesh builder tags each vertex (COLOR.r = tag / 8, see van_floor_skin.gd) so no face is
// guessed from its normal:
// 0 top, 1 rib crest (worn bright steel), 2 rib valley (dirty deep rust), 3 cut edge / end face
// (ragged rust), 4 weld bead (grey-blue, lumpy), 5 cavity (near black), 6 checker plate (raised
// diamonds about 6 cm apart, drawn in the normal only).
// Patterns sit in model-space metres: xz on tops, the face's own axes on sides. `origin` is the
// node's offset in the floor so every piece shares one pattern space.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/shaders/grime.gdshaderinc"

// Donor tint (the paint colour), noise offset seed and painted island share.
uniform vec3 tint : source_color = vec3(0.17, 0.19, 0.185);
uniform float seed = 0.0;
uniform float paint : hint_range(0.0, 1.0) = 0.5;
// Plates only: how far the donor tint overrides crest and rib-flank faces (the host keeps 0).
uniform float donor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 origin = vec3(0.0);
// Rust palette shared with van_rear_door.gdshader.
uniform vec3 steel_color : source_color = vec3(0.055, 0.06, 0.062);
uniform vec3 scale_color : source_color = vec3(0.035, 0.04, 0.045);
uniform vec3 rust_color : source_color = vec3(0.27, 0.1, 0.038);
uniform vec3 deep_rust_color : source_color = vec3(0.09, 0.03, 0.012);
uniform vec3 bright_steel_color : source_color = vec3(0.2, 0.16, 0.12);
uniform vec3 hole_dark_color : source_color = vec3(0.008, 0.008, 0.0075);
uniform vec3 weld_color : source_color = vec3(0.5, 0.5, 0.52);
uniform float paint_island_scale = 1.8;
uniform float metallic_value : hint_range(0.0, 0.6) = 0.22;

varying vec3 v_pos;
varying vec2 v_face;
varying flat float v_tag;

void vertex() {
	v_pos = VERTEX + origin;
	vec3 an = abs(NORMAL);
	if (an.x > 0.5) {
		v_face = v_pos.zy;
	} else if (an.z > 0.5) {
		v_face = v_pos.xy;
	} else {
		v_face = v_pos.xz;
	}
	v_tag = floor(COLOR.r * 8.0 + 0.5);
}

void fragment() {
	int tag = int(v_tag);
	vec2 q = v_face + vec2(seed * 7.3, seed * 3.1);
	float fw = max(fwidth(v_face.x), fwidth(v_face.y));
	float fine_vis = 1.0 - smoothstep(0.04, 0.1, fw);

	float blotch = fbm(q * 3.2 + 3.0);
	float fine = fbm(q * 14.0 + 11.0);
	float pits = smoothstep(0.7, 0.9, noise21(q * 30.0)) * fine_vis;
	// q.y is z on tops: long along x, short along z, so rust runs across the ribs (along z reads as wood).
	float streak = fbm(vec2(q.x * 1.4, q.y * 14.0) + 5.5);
	float rust = smoothstep(0.34, 0.66, blotch + (fine - 0.5) * 0.3 + (fract(seed * 0.37) - 0.5) * 0.4);
	float deep = smoothstep(0.55, 1.0, rust) * (0.5 + 0.5 * pits + 0.3 * fine);

	vec3 col = mix(steel_color, scale_color, smoothstep(0.35, 0.8, streak) * 0.8);
	col = mix(col, rust_color, rust * 0.9);
	col = mix(col, deep_rust_color, deep * 0.7);
	col = mix(col, vec3(0.01), pits * rust * 0.5);
	col *= 0.9 + 0.2 * noise21(q * 30.0 + 7.0) * fine_vis + 0.1 * (1.0 - fine_vis);
	float metal = metallic_value * (1.0 - rust * 0.8);
	vec2 nm = vec2((streak - 0.5) * 0.2, (pits - 0.5) * 0.2);
	float nm_depth = 0.6;
	float rough = 0.95;
	float metal_cap = 0.3;

	if (tag == 5) {
		col = hole_dark_color * (0.8 + 0.4 * fine);
		metal = 0.0;
		rough = 1.0;
	} else if (tag == 0 || tag == 6) {
		float thr = 0.64 - 0.42 * paint;
		float island = smoothstep(thr, thr + 0.1,
				fbm(q * paint_island_scale + vec2(9.4, 2.6) + vec2(fract(seed * 0.618), fract(seed * 0.382)) * 5.0) + 0.08 * (fine - 0.5));
		float on = smoothstep(0.15, 0.4, island);
		float lip = on * (1.0 - smoothstep(0.4, 0.7, island));
		vec3 pc = tint * (0.85 + 0.3 * fine);
		pc = mix(pc, pc * 0.55, lip * fine_vis);
		float run = smoothstep(0.5, 0.75, fbm(vec2(q.x * 2.2, q.y * 22.0) + vec2(3.1, 0.4)));
		col = mix(col, rust_color * 0.8, run * 0.3 * (1.0 - on));
		col = mix(col, pc, on);
		metal = mix(metal, 0.1, on);
		if (tag == 6) {
			// Raised diamonds, 6 cm between centres, in the normal only; flat once a diamond is
			// under about 3 px.
			vec2 p = v_face / 0.085;
			vec2 f = fract(vec2(p.x + p.y, p.x - p.y)) - 0.5;
			float cvis = (1.0 - smoothstep(0.012, 0.02, fw)) * step(max(abs(f.x), abs(f.y)), 0.42);
			vec2 t = (abs(f.x) > abs(f.y) ? sign(f.x) * vec2(1.0, 1.0) : sign(f.y) * vec2(1.0, -1.0));
			t *= 0.7071 * cvis;
			vec3 dx = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
			vec3 dz = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
			NORMAL = normalize(dx * t.x * 0.8 + dz * t.y * 0.8 + NORMAL);
		}
	} else if (tag == 1) {
		float wear = smoothstep(0.42, 0.68, fbm(q * 14.0 + vec2(1.7, 9.2)));
		float chip = smoothstep(0.62, 0.74, fbm(q * 24.0 + vec2(6.1, 3.4))) * fine_vis;
		// Worn steel sheen at the tops, patchy where rust and paint are left.
		float sheen = (1.0 - rust * 0.6) * (0.35 + 0.65 * wear);
		col = mix(col, bright_steel_color, clamp(0.45 + sheen * 0.4 + chip * 0.15, 0.0, 0.9));
		metal = mix(0.2, 0.6, sheen);
		rough = mix(0.8, 0.45, sheen);
		metal_cap = 0.6;
	} else if (tag == 2) {
		float dirt = fbm(q * 9.0 + vec2(4.4, 8.8));
		col = mix(deep_rust_color, scale_color, smoothstep(0.4, 0.8, streak) * 0.5);
		col = mix(col, rust_color * 0.6, (1.0 - deep) * 0.3);
		col *= (0.7 + 0.3 * fine) * (0.45 + 0.55 * dirt);
		metal = 0.05;
	} else if (tag == 4) {
		// Weld bead: bright raw steel, lumpy from the noise.
		col = weld_color * (0.7 + 0.8 * fine);
		nm = vec2(fbm(q * 55.0 + 2.0), fbm(q * 55.0 + 19.0)) - 0.5;
		nm_depth = 2.0;
		metal = 0.3;
		rough = 0.5;
	} else {
		// Cut edge and end face: the rear door surround's rust, ragged over about 4 cm.
		float rag = fbm(q * 25.0 + vec2(13.0, 5.0));
		float rag2 = fbm(q * 60.0 + vec2(2.0, 31.0)) * fine_vis;
		col = mix(deep_rust_color, rust_color, smoothstep(0.35, 0.65, rag + (rag2 - 0.5) * 0.2));
		col = mix(col, steel_color * 1.4, smoothstep(0.62, 0.78, rag) * 0.5);
		metal = 0.2;
	}

	if (donor > 0.0 && (tag == 1 || tag == 3)) {
		// The ribs cover most of a plate: paint them in the donor tint, worn a little on the crests.
		vec3 dc = tint * (0.85 + 0.3 * fine);
		dc = tag == 1 ? mix(dc, bright_steel_color, 0.15 + 0.2 * (1.0 - rust)) : dc * 0.6;
		col = mix(col, dc, donor * (tag == 1 ? 0.85 : 0.7));
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = clamp(metal, 0.0, metal_cap);
	NORMAL_MAP = vec3(nm + 0.5, 1.0);
	NORMAL_MAP_DEPTH = nm_depth;
}
