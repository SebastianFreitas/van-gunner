shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// One word rendered onto a sign face: a backlit box, a neon strip, or an unlit poster/banner.
// text_tex is a label built by facade_materials.label_texture (fg white, bg black), so its red
// channel alone tells ink from background.

uniform sampler2D text_tex : source_color, filter_nearest;
uniform vec3 color : source_color = vec3(1.0, 0.85, 0.6);
uniform float energy = 2.4;
uniform int mode = 0;                   // 0 backlit box, 1 neon, 2 poster
uniform float seed = 0.0;
uniform float dead_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.0;
uniform float letter_cells = 8.0;       // how many horizontal cells the dead-letter hash uses

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec4 t = texture(text_tex, UV);
	float ink = t.r;
	vec3 albedo;
	vec3 emission = vec3(0.0);
	float rough;
	if (mode == 0) {
		// Backlit box: dark letters cut out of a glowing panel.
		albedo = mix(vec3(0.02), color * 0.15, 1.0 - ink);
		emission = mix(color * energy * 0.45, vec3(0.02), ink);
		rough = 0.4;
	} else if (mode == 1) {
		// Neon: the letters themselves glow, some dead per a per-cell hash, all of them flickering.
		float cell = floor(UV.x * letter_cells);
		float dead = step(hash11(cell + seed), dead_ratio);
		float flick = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * 17.0 + seed) * sin(TIME * 5.3 + cell));
		albedo = mix(vec3(0.03), color * 0.25, ink);
		emission = color * energy * ink * (1.0 - dead) * clamp(flick, 0.0, 1.0);
		// Cheap blur via a mip level for a soft halo around lit tubes.
		if (textureLod(text_tex, UV, 2.0).r > 0.1) {
			emission += color * energy * 0.08 * (1.0 - ink) * (1.0 - dead);
		}
		rough = 0.3;
	} else {
		// Poster: unlit paper with ink and a grain, no emission.
		float grain = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);
		albedo = mix(color, vec3(0.06), ink) * (0.7 + 0.3 * grain);
		rough = 0.95;
	}
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = rough;
}
