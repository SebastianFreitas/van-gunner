shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.11, 0.105, 0.095);
uniform vec3 rib_color : source_color = vec3(0.055, 0.052, 0.048);
uniform vec3 wear_color : source_color = vec3(0.18, 0.165, 0.14);
uniform vec3 stain_color : source_color = vec3(0.035, 0.028, 0.02);
uniform vec3 rust_color : source_color = vec3(0.22, 0.09, 0.04);
uniform vec2 floor_size_m = vec2(4.8, 9.6);
uniform float rib_spacing_m : hint_range(0.04, 0.25) = 0.085;
uniform float panel_spacing_m : hint_range(0.6, 3.0) = 1.55;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.88;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.22;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise21(p);
		p = p * 2.07 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// UV is authored in meters from floor center: X across, Y along van length.
	vec2 pos = (UV - vec2(0.5)) * floor_size_m;
	vec2 uv_m = UV * floor_size_m;

	// Longitudinal cargo ribs (classic van bed).
	float rib_phase = fract(uv_m.x / rib_spacing_m);
	float rib_groove = smoothstep(0.08, 0.0, abs(rib_phase - 0.5) - 0.28);
	float rib_crest = smoothstep(0.42, 0.5, abs(rib_phase - 0.5));

	// Cross-panel seams every panel_spacing_m along Z.
	float panel_phase = fract(uv_m.y / panel_spacing_m);
	float panel_seam = 1.0 - smoothstep(0.012, 0.038, min(panel_phase, 1.0 - panel_phase));

	// Center aisle wear from foot traffic.
	float aisle = 1.0 - smoothstep(0.35, 1.55, abs(pos.x));
	float walk_noise = fbm(pos * vec2(1.6, 0.55) + vec2(2.1, 0.4));
	float wear = aisle * smoothstep(0.28, 0.78, walk_noise);

	// Edge grime near walls.
	float edge_x = smoothstep(1.7, 2.35, abs(pos.x));
	float edge_z = smoothstep(4.0, 4.75, abs(pos.y));
	float edge_dirt = max(edge_x, edge_z * 0.65);

	// Oil / grease blotches.
	float blotch = fbm(pos * 0.55 + vec2(8.7, 3.2));
	float oil = smoothstep(0.72, 0.92, blotch) * (0.45 + 0.55 * edge_dirt);

	// Scuffs and scratched metal patches.
	float scuff = smoothstep(0.74, 0.95, fbm(pos * vec2(3.4, 1.1) + 11.0));
	scuff *= mix(0.25, 1.0, aisle);

	// Occasional rust freckles near seams and edges.
	float rust = smoothstep(0.82, 0.97, hash21(floor(uv_m * vec2(7.0, 4.0))))
		* (panel_seam * 0.7 + edge_dirt * 0.55);

	// Bolt heads at panel / rib crossings.
	vec2 bolt_cell = floor(uv_m / vec2(rib_spacing_m * 4.0, panel_spacing_m));
	vec2 bolt_local = fract(uv_m / vec2(rib_spacing_m * 4.0, panel_spacing_m)) - vec2(0.5);
	float bolt_mask = step(0.72, hash21(bolt_cell + 19.0));
	float bolt = bolt_mask * (1.0 - smoothstep(0.035, 0.07, length(bolt_local)));

	vec3 color = base_color;
	color = mix(color, rib_color, rib_groove * 0.85);
	color = mix(color, wear_color, wear * 0.55 + scuff * 0.22);
	color = mix(color, stain_color, oil * 0.75 + edge_dirt * 0.28 + panel_seam * 0.45);
	color = mix(color, rust_color, rust * 0.65);
	color = mix(color, vec3(0.08, 0.08, 0.075), bolt * 0.9);

	// Tiny grain so it doesn't read as plastic.
	color *= 0.92 + 0.16 * noise21(uv_m * 28.0);

	ALBEDO = color;
	METALLIC = metallic_value * (0.55 + 0.45 * rib_crest) * (1.0 - oil * 0.7);
	ROUGHNESS = clamp(
		roughness_value
			+ rib_groove * 0.08
			+ wear * 0.06
			+ oil * 0.12
			- bolt * 0.25
			- scuff * 0.04,
		0.2,
		1.0
	);

	// Fake rib normals for light catch without a heightmap.
	float n_x = (rib_phase - 0.5) * 2.0 * (0.45 + rib_groove * 0.8);
	float n_y = (panel_phase - 0.5) * panel_seam * 0.35;
	NORMAL_MAP = vec3(n_x, n_y, 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.7;
}
