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
uniform vec3 gum_color : source_color = vec3(0.09, 0.088, 0.085);
uniform vec3 fill_color : source_color = vec3(0.07, 0.06, 0.05); // dirt/gravel in a missing slab
uniform vec3 weed_color : source_color = vec3(0.045, 0.06, 0.035);
uniform vec3 litter_color : source_color = vec3(0.40, 0.38, 0.33);
uniform vec3 scorch_color : source_color = vec3(0.012, 0.010, 0.009);
uniform float breakage : hint_range(0.0, 1.0) = 0.5;
uniform float litter : hint_range(0.0, 1.0) = 0.6;
uniform float weeds : hint_range(0.0, 1.0) = 0.6;

// Voronoi on the sidewalk's cell layout (crack_field_h21's), returning x = gap to the
// second-nearest site and y = the nearest site's hash, so one shard can be picked by id.
vec2 shard_cells(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float min_d = 8.0;
	float second = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash21(cell + g), hash21(cell + g + 19.0));
			float d = length(g + o - f);
			if (d < min_d) {
				second = min_d;
				min_d = d;
				id = hash21(cell + g + 53.0);
			} else if (d < second) {
				second = d;
			}
		}
	}
	return vec2(second - min_d, id);
}

vec2 rot2(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x + s * v.y, -s * v.x + c * v.y);
}

void fragment() {
	vec2 pos = (UV - vec2(0.5)) * surface_size_m;
	vec2 uv_m = UV * surface_size_m;
	// Metres per screen pixel: every fine layer below fades with it.
	float fw_m = max(length(fwidth(uv_m)), 1e-5);

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

	// Broken slabs: per slab, a few are gone (dirt and gravel) or shattered, one shard sunken.
	vec2 slab_id = vec2(0.0, floor(uv_m.y / slab_spacing_m));
	float slab_h = hash21(slab_id + 41.0);
	float edge_m = min(
		min(slab_phase, 1.0 - slab_phase) * slab_spacing_m,
		min(uv_m.x, surface_size_m.x - uv_m.x)
	);
	float interior = smoothstep(0.02, 0.05, edge_m);
	float brk = breakage;
	float missing = float(slab_h < 0.03 * brk * 2.0) * interior;
	float shattered = float(slab_h >= 0.03 * brk * 2.0 && slab_h < 0.10 * brk * 2.0)
		* interior;
	float pebble_fade = 1.0 - smoothstep(0.25, 0.5, fw_m * 14.0);
	float pebble = mix(0.3, step(0.7, hash21(floor(uv_m * 14.0))), pebble_fade);
	float hole_rim = interior * (1.0 - smoothstep(0.06, 0.09, edge_m));
	vec3 hole_col = (fill_color + 0.03 * pebble) * mix(1.0, 0.6, hole_rim);
	color = mix(color, hole_col, missing);
	vec2 shard = shard_cells(uv_m / 0.6 + slab_h * 37.0);
	float gap_vis = smoothstep(0.5, 1.5, 0.015 / fw_m);
	float shard_gap = mix(0.04, 1.0 - smoothstep(0.015, 0.035, shard.x), gap_vis);
	float sunken = float(shard.y < 0.2);
	float sunk_edge = 1.0 - smoothstep(0.0, 0.12, shard.x);
	vec3 shard_col = color * mix(1.0, 0.75, sunken);
	shard_col = mix(shard_col, fill_color, 0.35 * sunken * sunk_edge);
	shard_col *= mix(1.0, 0.45, shard_gap);
	color = mix(color, shard_col, shattered);

	// Chewing gum, thicker down the worn middle.
	vec2 gum_cell = floor(uv_m / 0.22);
	vec2 gum_pt = (gum_cell + 0.15 + 0.7 * hash22(gum_cell + 3.0)) * 0.22;
	float gum_r = mix(0.012, 0.025, hash21(gum_cell + 5.0));
	float gum_on = step(hash21(gum_cell), 0.035 * (1.0 + wear));
	float gum_vis = 1.0 - smoothstep(0.012, 0.03, fw_m);
	float gum_dot = gum_on * gum_vis
		* (1.0 - smoothstep(gum_r * 0.8, gum_r, length(uv_m - gum_pt)));
	color = mix(color, gum_color, gum_dot * 0.8);

	color = mix(color, stain_color, stain * 0.65);
	color = mix(color, dirt_color, wall_dirt * 0.5);
	color = mix(color, crack_color, cracks * 0.8);

	// Weeds in the seams, the cracks and the wall-side dirt band.
	float weed_cond = step(0.001, weeds)
		* smoothstep(0.59 - 0.2 * weeds, 0.65 - 0.2 * weeds, fbm(pos * 2.0));
	float weed_rag = mix(0.5, noise21(pos * 25.0), 1.0 - smoothstep(0.02, 0.04, fw_m));
	float weed_spread = mix(0.02, 0.06, weed_rag);
	float weed_m = max(1.0 - smoothstep(0.0, weed_spread, edge_m), cracks);
	weed_m = max(weed_m, smoothstep(0.45, 0.85, wall_dirt) * smoothstep(0.3, 0.7, weed_rag));
	color = mix(color, weed_color, weed_cond * weed_m * 0.8);

	// Litter: paper scraps with a crease, and cigarette butts. 3x3 cells so nothing is cut.
	float paper = 0.0;
	float crease = 0.0;
	float butt = 0.0;
	vec2 lit_cell = floor(uv_m / 0.9);
	float lit_aa = max(fw_m * 0.7, 0.002);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = lit_cell + vec2(float(x), float(y));
			float h = hash21(c + 9.0);
			vec2 ctr = (c + 0.15 + 0.7 * hash22(c + 17.0)) * 0.9;
			vec2 size = vec2(
				mix(0.08, 0.2, hash21(c + 23.0)),
				mix(0.05, 0.12, hash21(c + 29.0))
			);
			vec2 l = rot2(uv_m - ctr, hash21(c + 31.0) * 6.2832);
			float sd = max(abs(l.x) - size.x * 0.5, abs(l.y) - size.y * 0.5);
			float sc = float(h < 0.10 * litter) * (1.0 - smoothstep(-lit_aa, lit_aa, sd));
			paper = max(paper, sc);
			float fold = 1.0 - smoothstep(
				0.0, 0.006, abs(l.y * 0.6 + l.x * 0.4 - (hash21(c + 37.0) - 0.5) * 0.03));
			crease = max(crease, sc * fold);
			vec2 bc = (c + 0.15 + 0.7 * hash22(c + 41.0)) * 0.9;
			vec2 bl = rot2(uv_m - bc, hash21(c + 43.0) * 6.2832);
			float bsd = max(abs(bl.x) - 0.006, abs(bl.y) - 0.0175);
			butt = max(butt, float(h < 0.18 * litter) * (1.0 - smoothstep(-lit_aa, lit_aa, bsd)));
		}
	}
	float paper_vis = 1.0 - smoothstep(0.02, 0.04, fw_m);
	float butt_vis = 1.0 - smoothstep(0.008, 0.016, fw_m);
	color = mix(color, litter_color * (1.0 - 0.3 * crease), paper * paper_vis * 0.9);
	color = mix(color, vec3(0.35, 0.30, 0.22), butt * butt_vis * 0.9);

	// Broken glass: a few bright specks that vanish (never sparkle) once under ~2 px.
	vec2 glass_cell = floor(uv_m / 0.35);
	float glass_on = float(hash21(glass_cell + 77.0) < 0.06 * litter);
	int glass_count = 2 + int(floor(hash21(glass_cell + 79.0) * 3.0));
	float speck = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= glass_count) {
			break;
		}
		float fi = float(i);
		vec2 sp = (glass_cell + 0.12 + 0.76 * hash22(glass_cell + 83.0 + fi * 7.0)) * 0.35;
		float sr = mix(0.006, 0.012, hash21(glass_cell + 89.0 + fi * 5.0));
		speck = max(speck, 1.0 - smoothstep(sr * 0.7, sr, length(uv_m - sp)));
	}
	speck *= glass_on * (1.0 - smoothstep(0.005, 0.01, fw_m));
	color += 0.06 * speck;

	// Rare burnt patches, 12 m cells, 3x3 so a patch is never cut at a cell edge.
	float scorch = 0.0;
	vec2 burn_cell = floor(uv_m / 12.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = burn_cell + vec2(float(x), float(y));
			vec2 ctr = (c + 0.2 + 0.6 * hash22(c + 37.3)) * 12.0;
			float r = mix(0.5, 1.4, hash21(c + 41.3)) * (0.7 + 0.6 * fbm(uv_m * 1.3 + c * 5.0));
			float burnt = float(hash21(c + 31.7) < 0.05)
				* (1.0 - smoothstep(r * 0.6, r, length(uv_m - ctr)));
			scorch = max(scorch, burnt);
		}
	}
	color = mix(color, scorch_color, scorch * 0.85);

	color *= 0.91 + 0.16 * grain;
	color = mix(color, vec3(0.24, 0.23, 0.21), bleach * 0.3);
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma), washout * 0.2);

	ALBEDO = color;
	METALLIC = 0.0;
	float rough = clamp(
		roughness_value
			+ seams * 0.04
			+ stain * 0.08
			- wear * 0.06
			+ wall_dirt * 0.04,
		0.4,
		1.0
	);
	rough = mix(rough, 0.95, max(missing, scorch));
	ROUGHNESS = mix(rough, 0.25, speck);

	float n_x = (fbm(uv_m * 8.0) - 0.5) * 0.3 + cracks * 0.35;
	float n_y = (slab_phase - 0.5) * seams * 0.4 + (grain - 0.5) * 0.15;
	NORMAL_MAP = vec3(n_x, n_y, 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.4;
}
