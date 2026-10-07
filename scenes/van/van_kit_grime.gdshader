shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/shaders/grime.gdshaderinc"

// Salvage-kit pieces: van_wall.gdshader's recipe in object-space metres, so a 7 cm rib and a
// 2 m panel both grime sensibly. One shared material; the look is per piece (instance uniforms).
uniform vec3 seam_color = vec3(0.07, 0.075, 0.07);
uniform vec3 kick_color = vec3(0.1, 0.095, 0.085);
uniform vec3 wear_color = vec3(0.32, 0.3, 0.26);
uniform vec3 stain_color = vec3(0.04, 0.035, 0.03);
uniform vec3 rust_color = vec3(0.24, 0.09, 0.035);
uniform float panel_spacing_m : hint_range(0.6, 2.5) = 1.15;
uniform float kick_height_m : hint_range(0.15, 0.8) = 0.38;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.84;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.24;

instance uniform vec3 paint = vec3(0.2, 0.21, 0.2);
instance uniform vec3 primer = vec3(0.1, 0.095, 0.085);
instance uniform float rust_amount : hint_range(0.0, 1.0) = 0.4;
instance uniform float grime_amount : hint_range(0.0, 1.0) = 0.6;
instance uniform int wall_style = 0;
instance uniform float rib_pitch_m : hint_range(0.0, 1.0) = 0.0;
instance uniform float seed = 0.0;
// Van-local y of the mesh origin and of the piece top (D62); top below -5 means "unset".
// up_obj is van up in the mesh frame, since kit frames put up on x or z, not always y.
instance uniform vec3 up_obj = vec3(0.0, 1.0, 0.0);
instance uniform float y_base_m = 0.0;
instance uniform float top_y_m = -10.0;
// 0 FACTORY (rivets, spot welds), 1 HAND (crude bead), -1 none (D61).
instance uniform int fastener_era = -1;

varying vec3 obj_pos;
varying vec3 obj_nrm;

void vertex() {
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
}

void fragment() {
	// Project on the plane the face looks along; y stays up unless the face is a floor or lid.
	vec3 an = abs(obj_nrm);
	vec2 p;
	if (an.y > an.x && an.y > an.z) {
		p = obj_pos.xz;
	} else if (an.x > an.z) {
		p = vec2(obj_pos.z, obj_pos.y);
	} else {
		p = vec2(obj_pos.x, obj_pos.y);
	}
	vec2 q = p + vec2(seed * 3.7, seed * 1.3);
	float y = p.y;
	float z = p.x;

	// Form per donor style (1 corrugated, 2 swaged flat panels, 3 flat sheet, 0 pressed ribs):
	// panel width and rib profile differ so each donor reads by shape when the paints are dim.
	float spacing = panel_spacing_m * (wall_style == 2 ? 0.8 : (wall_style == 3 ? 1.35 : 1.0));
	float pitch = wall_style == 1 ? 0.3 : rib_pitch_m;
	// Seams every spacing, wide enough to survive distance (3..4 cm).
	float panel_phase = fract(z / spacing);
	float panel_seam = 1.0 - smoothstep(0.01, 0.032, min(panel_phase, 1.0 - panel_phase) * spacing);
	// Style 4 is tread plate: lozenges only, no panel seams or kick band.
	bool tread = wall_style == 4;
	panel_seam *= float(wall_style != 0 && !tread);

	// Stamped ribs: pitch is per piece, never under 0.20 m, and fades to its average by distance.
	float rib = 0.0;
	float rib_k = 0.22;
	if (pitch >= 0.2) {
		float rib_phase = fract(z / pitch);
		float fade = 1.0 - smoothstep(0.5, 1.5, fwidth(z / pitch) * 8.0);
		float prof = smoothstep(0.12, 0.0, abs(rib_phase - 0.5) - 0.18);
		if (wall_style == 1) {
			prof = 0.5 + 0.5 * cos(6.28318 * rib_phase);
			rib_k = 0.4;
		} else if (wall_style == 2) {
			prof = 1.0 - smoothstep(0.008, 0.026, min(rib_phase, 1.0 - rib_phase) * pitch);
			rib_k = 0.35;
		}
		rib = mix(0.5, prof, fade) * 0.8;
	}

	float kick = 1.0 - smoothstep(kick_height_m - 0.05, kick_height_m + 0.08, y);
	kick *= float(wall_style != 0 && !tread && an.y < 0.5);

	// Tread: 0.20 m lozenges in a staggered grid, raised by the normal only, faded by distance.
	vec2 tg = p / 0.2;
	float trow = floor(tg.y);
	tg.x += mod(trow, 2.0) * 0.5;
	vec2 tc = fract(tg) - 0.5;
	float tdir = mod(trow + floor(tg.x), 2.0) * 2.0 - 1.0;
	float tu = tc.x + tdir * tc.y;
	float tv = tc.x - tdir * tc.y;
	float tlen = abs(tu) * 0.5 + abs(tv) * 2.0;
	float tedge = clamp((0.3 - tlen) * 8.0, 0.0, 1.0);
	tedge = tedge * (1.0 - tedge) * 4.0;
	vec2 tgrad = sign(tu) * 0.5 * vec2(1.0, tdir) + sign(tv) * 2.0 * vec2(1.0, -tdir);
	float tfade = (1.0 - smoothstep(0.3, 0.8, fwidth(p.x * 5.0) + fwidth(p.y * 5.0))) * float(tread);

	// Van-local height: rust and grime pile up toward the floor, boots and cargo scuff the hips.
	float vy = dot(obj_pos, up_obj) + y_base_m;
	float low = 1.0 - smoothstep(0.0, 0.4, vy);
	float hip = smoothstep(0.9, 1.0, vy) * (1.0 - smoothstep(1.2, 1.3, vy));

	float brush = fbm(vec2(q.x * 0.35, q.y * 3.4) + vec2(2.2, 0.4));
	float scuff = smoothstep(0.62, 0.92, brush) * (0.15 + hip * 0.85 + kick * 0.2);

	float dirt = fbm(vec2(q.x * 0.55, q.y * 0.8) + 9.1);
	float grime = smoothstep(0.68, 0.95, dirt) * (0.35 + kick * 0.7 + panel_seam * 0.45 + low * 0.6)
		* grime_amount;

	float rust = smoothstep(0.84, 0.98, hash21(floor(q * vec2(5.5, 7.0))))
		* (0.35 + panel_seam * 0.65 + kick * 0.4 + low * 0.7) * rust_amount;

	// Rust streaks 2..6 cm wide: one candidate per 8 cm cell with a hashed width, so kept
	// neighbours never merge; hanging from the top edge (0.1..0.5 m) and along seams and rib
	// lines (long vertical noise), thicker near the floor.
	float scol = floor(z * 12.5);
	float col_h = hash21(vec2(scol, floor(seed)));
	float s_half = (0.02 + 0.04 * hash21(vec2(scol, floor(seed) + 3.0))) * 0.5;
	float s_in = 1.0 - smoothstep(s_half - 0.003, s_half, abs(fract(z * 12.5) - 0.5) * 0.08);
	float streak_cols = step(0.72, col_h) * s_in
		* (1.0 - smoothstep(0.5, 1.5, fwidth(z * 12.5) * 8.0));
	float hang = top_y_m - vy;
	float s_top = float(top_y_m > -5.0) * step(0.0, hang)
		* (1.0 - smoothstep(0.0, 0.1 + 0.4 * hash21(vec2(scol, 7.0)), hang));
	float seam_near = 1.0 - smoothstep(0.0, 0.07, min(panel_phase, 1.0 - panel_phase) * spacing);
	seam_near *= float(wall_style != 0 && !tread);
	float s_seam = max(seam_near, smoothstep(0.4, 0.7, rib))
		* smoothstep(0.35, 0.75, fbm(vec2(scol * 7.3 + seed, vy * 2.2)));
	float streak = max(s_top, s_seam) * streak_cols * (0.7 + low * 0.5) * rust_amount;
	rust = clamp(max(rust, streak * 1.1), 0.0, 1.0);

	// Chipped paint on the faces that turn away from the piece's main facing: the lid of a tall
	// piece, the sides of a thin slab, and the strip under a top edge.
	float tall = step(0.12, top_y_m - y_base_m);
	float away = mix(float(an.y < 0.5), float(an.y > 0.5), tall);
	float edge = max(away, step(0.0, hang) * (1.0 - smoothstep(0.0, 0.05, hang)) * tall);
	float chip_n = fbm(q * 18.0 + 4.0);
	// Low-frequency cluster so chips gather on worn patches and low/kick zones, not evenly.
	float chip_cluster = smoothstep(0.4, 0.65, fbm(q * 1.5 + 11.0) + max(low, kick) * 0.2);
	float chip_fade = 1.0 - smoothstep(0.5, 1.5, fwidth(p.x * 18.0) * 2.0);
	float chip_prime = smoothstep(0.62, 0.7, chip_n) * chip_cluster * edge * chip_fade;
	float chip_steel = smoothstep(0.72, 0.8, chip_n) * chip_cluster * edge * chip_fade;

	// Fasteners (D61): FACTORY rivets along seams and spot welds along ribs every 0.22 m,
	// HAND a lumpy 2 cm bead along seams; each fades to nothing before it aliases.
	float seam_dx = min(panel_phase, 1.0 - panel_phase) * spacing;
	float has_seam = float(wall_style != 0 && !tread);
	float fa_fade = 1.0 - smoothstep(0.5, 1.5, fwidth(p.y / 0.22) * 8.0);
	float fy = (fract(p.y / 0.22) - 0.5) * 0.22;
	float rivet = (1.0 - smoothstep(0.009, 0.017, length(vec2(seam_dx - 0.035, fy))))
		* has_seam * fa_fade * float(fastener_era == 0);
	float weld = 0.0;
	if (pitch >= 0.2) {
		float rdx = abs(fract(z / pitch) - 0.5) * pitch;
		weld = (1.0 - smoothstep(0.007, 0.014, length(vec2(rdx, fy)))) * fa_fade
			* float(fastener_era == 0);
	}
	float lump = noise21(vec2(p.y * 14.0, seed + 3.0));
	float bead_w = 0.006 + 0.008 * lump;
	float bead = (1.0 - smoothstep(bead_w, bead_w + 0.006, seam_dx)) * has_seam
		* float(fastener_era == 1) * (1.0 - smoothstep(0.5, 1.5, fwidth(p.y * 14.0) * 4.0));

	vec3 color = paint;
	color = mix(color, primer, kick * 0.6);
	color = mix(color, seam_color, panel_seam * 0.85 + rib * rib_k);
	color = mix(color, wear_color, scuff * 0.3);
	color = mix(color, mix(color * 0.45, stain_color * 0.7, 0.3), grime * 0.6);
	color = mix(color, rust_color, rust * 0.7);
	color = mix(color, primer, chip_prime * 0.9);
	color = mix(color, vec3(0.17, 0.17, 0.18), chip_steel * 0.9);
	color = mix(color, color * 1.7 + 0.02, rivet * 0.8);
	color = mix(color, seam_color, weld * 0.8);
	color = mix(color, seam_color * 0.6, bead * 0.9);
	// Grain about 10/m, faded out when a cell is under a couple of pixels.
	float grain_fade = 1.0 - smoothstep(0.3, 0.8, fwidth(p.x * 10.0) + fwidth(p.y * 10.0));
	color *= 1.0 + (noise21(q * 10.0) - 0.5) * 0.14 * grain_fade;

	ALBEDO = clamp(color, vec3(0.02), vec3(0.25));
	METALLIC = metallic_value * (0.55 + 0.45 * (1.0 - kick)) * (1.0 - grime * 0.65);
	ROUGHNESS = clamp(roughness_value + kick * 0.06 + panel_seam * 0.04 + grime * 0.08
		+ scuff * 0.04 + chip_steel * 0.03 - chip_prime * 0.02, 0.78, 0.95);

	float n_x = (panel_phase - 0.5) * panel_seam * 0.9 + (rib - 0.4) * rib_k * (wall_style == 1 ? 2.4 : 1.2);
	float n_y = kick * -0.25;
	n_x += (seam_dx - 0.035) * 25.0 * rivet * 0.4 + (lump - 0.5) * bead * 0.8;
	n_y += fy * 40.0 * (rivet + weld) * 0.4 + (noise21(vec2(p.y * 31.0, seed)) - 0.5) * bead * 0.5;
	n_x += tgrad.x * tedge * 0.35 * tfade;
	n_y += tgrad.y * tedge * 0.35 * tfade;
	NORMAL_MAP = vec3(n_x, n_y, 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.85;
}
