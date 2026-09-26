shader_type spatial;
// Procedural CRT phosphor screen: scanlines, glass vignette, scrolling blocky glyph rows, blinking cursor and a boot flicker; no textures.
render_mode unshaded, cull_back;

#include "res://scenes/shaders/grime.gdshaderinc"

uniform vec3 phosphor : source_color = vec3(0.25, 1.0, 0.4);
uniform float brightness : hint_range(0.0, 1.0) = 0.8;
uniform float boot : hint_range(0.0, 1.0) = 1.0;
uniform float glyph_cols = 26.0;
uniform float glyph_rows = 12.0;
uniform float scroll_rate = 1.5;
uniform float text_amount : hint_range(0.0, 1.0) = 1.0;
uniform float scanline_count = 180.0;


void fragment() {
	vec2 uv = UV;

	// Scrolling glyph rows over a blocky cell grid.
	float t = floor(TIME * scroll_rate);
	float col_f = floor(uv.x * glyph_cols);
	float row = floor(uv.y * glyph_rows) + t;
	float len = hash21(vec2(row, 7.1));
	len = len < 0.15 ? 0.0 : len;
	bool cell_lit = (col_f / glyph_cols < len) && (hash21(vec2(col_f, row)) > 0.35);

	// Blocky 3x5 sub-glyph inside the lit cell, with a 1-subpixel gap at right/bottom.
	vec2 cell = vec2(col_f, row);
	vec2 frac_cell = fract(vec2(uv.x * glyph_cols, uv.y * glyph_rows));
	vec2 sub = floor(frac_cell * vec2(3.0, 5.0));
	bool in_gap = sub.x >= 2.0 || sub.y >= 4.0;
	float sub_on = (hash21(cell + sub * 13.7) > 0.45) ? 1.0 : 0.0;
	float glyph = (cell_lit && !in_gap) ? sub_on : 0.0;
	glyph *= text_amount;

	// Blinking cursor: the cell right after the bottom row's text.
	float bottom_row = floor(glyph_rows - 1.0) + t;
	float bottom_len = hash21(vec2(bottom_row, 7.1));
	bottom_len = bottom_len < 0.15 ? 0.0 : bottom_len;
	float cursor_col = floor(bottom_len * glyph_cols) + 1.0;
	bool is_cursor_row = floor(uv.y * glyph_rows) == floor(glyph_rows - 1.0);
	bool is_cursor_col = col_f == cursor_col;
	float cursor = (is_cursor_row && is_cursor_col) ? step(0.5, fract(TIME * 1.6)) * text_amount : 0.0;

	// Dim phosphor fill plus a faint rolling band.
	float base = 0.06;
	float band = 0.04 * smoothstep(0.0, 0.1, fract(uv.y * 0.5 - TIME * 0.15));

	float intensity = max(glyph, cursor) + base + band;

	// Scanlines fade out with fwidth so distant screens don't moiré.
	float sl_fade = 1.0 - smoothstep(0.35, 0.8, fwidth(uv.y * scanline_count));
	float scanline = mix(1.0, 0.72 + 0.28 * sin(uv.y * scanline_count * TAU), sl_fade);
	intensity *= scanline;

	// Glass vignette.
	float vig = smoothstep(0.75, 0.25, length(uv - 0.5) * 1.25);
	intensity *= vig;

	// Boot-up stutter and idle flicker.
	float flick = 0.92 + 0.08 * noise21(vec2(TIME * 30.0, 0.0));
	if (boot < 1.0) {
		flick *= step(hash21(vec2(floor(TIME * 20.0), 3.0)), boot);
	}
	intensity *= boot * brightness * flick;

	ALBEDO = clamp(phosphor * intensity, vec3(0.0), vec3(0.95));
}
