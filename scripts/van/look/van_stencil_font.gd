extends RefCounted
## A 5x7 pixel stencil font that renders worn, hand-painted text and tally marks into Images for the van's decals.

const GLYPH_W := 5
const GLYPH_H := 7

## Each entry: 7 rows, low 5 bits per row, MSB (bit 4) = leftmost pixel.
## Stencil-style glyphs: closed counters get a 1px gap top/bottom middle.
const GLYPHS: Dictionary = {
	"A": [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
	"B": [0b11110, 0b10001, 0b10001, 0b11100, 0b10001, 0b10001, 0b11110],
	"C": [0b01111, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b01111],
	"D": [0b11100, 0b10010, 0b10001, 0b10001, 0b10001, 0b10010, 0b11100],
	"E": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111],
	"F": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000],
	"G": [0b01111, 0b10000, 0b10000, 0b10111, 0b10001, 0b10001, 0b01111],
	"H": [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
	"I": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111],
	"J": [0b00111, 0b00010, 0b00010, 0b00010, 0b00010, 0b10010, 0b01100],
	"K": [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001],
	"L": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
	"M": [0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001],
	"N": [0b10001, 0b11001, 0b10101, 0b10101, 0b10011, 0b10001, 0b10001],
	"O": [0b01110, 0b10001, 0b10001, 0b00000, 0b10001, 0b10001, 0b01110],
	"P": [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000],
	"Q": [0b01110, 0b10001, 0b10001, 0b00000, 0b10101, 0b10010, 0b01101],
	"R": [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001],
	"S": [0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110],
	"T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100],
	"U": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
	"V": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100],
	"W": [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010],
	"X": [0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001],
	"Y": [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100],
	"Z": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111],
	"0": [0b01110, 0b10011, 0b10101, 0b00000, 0b10101, 0b11001, 0b01110],
	"1": [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
	"2": [0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111],
	"3": [0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110],
	"4": [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010],
	"5": [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b00001, 0b11110],
	"6": [0b01111, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110],
	"7": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000],
	"8": [0b01110, 0b10001, 0b10001, 0b00000, 0b10001, 0b10001, 0b01110],
	"9": [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b11110],
	"'": [0b00100, 0b00100, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000],
	"-": [0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000],
	" ": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000],
}


static func render_text(text: String, rng: RandomNumberGenerator, wear: float, scale: int) -> Image:
	var upper := text.to_upper()
	if upper.is_empty():
		var empty_img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		empty_img.fill(Color(0.0, 0.0, 0.0, 0.0))
		return empty_img

	var w := upper.length() * (GLYPH_W + 1) + 1
	var h := GLYPH_H + 4
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var pen_x := 1
	for ch: String in upper:
		var rows: Array = GLYPHS.get(ch, GLYPHS[" "])
		var bottom_row_x: Array[int] = []
		for row: int in range(GLYPH_H):
			var bits: int = rows[row]
			for col: int in range(GLYPH_W):
				var lit: bool = (bits & (1 << (GLYPH_W - 1 - col))) != 0
				var dropout := rng.randf() < wear
				if lit and not dropout:
					img.set_pixel(pen_x + col, 2 + row, Color(1.0, 1.0, 1.0, 1.0))
					if row == GLYPH_H - 1:
						bottom_row_x.append(col)

		var do_drip := rng.randf() < 0.35
		var drip_col := rng.randi_range(0, GLYPH_W - 1)
		var drip_len := rng.randi_range(1, 2)
		if do_drip and not bottom_row_x.is_empty():
			var drip_x := pen_x + bottom_row_x[drip_col % bottom_row_x.size()]
			var drip_y0 := 2 + GLYPH_H
			for i: int in range(drip_len):
				var py := drip_y0 + i
				if py < h:
					img.set_pixel(drip_x, py, Color(1.0, 1.0, 1.0, 0.85))

		pen_x += GLYPH_W + 1

	img.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	return img


static func render_tallies(count: int, rng: RandomNumberGenerator, scale: int) -> Image:
	@warning_ignore("integer_division")
	var full_groups := count / 5
	var remainder := count % 5
	var groups := full_groups + (1 if remainder > 0 else 0)
	if groups <= 0:
		groups = 0

	var group_w := 7 ## 4 strokes, 2px apart, spanning columns 0..6.
	var w := groups * group_w + (groups - 1) * 3 + 2 if groups > 0 else 1
	var h := 9
	var img := Image.create(max(w, 1), h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var white := Color(1.0, 1.0, 1.0, 1.0)
	var x0 := 1
	var remaining := count
	for g: int in range(groups):
		var strokes_in_group: int = min(5, remaining)
		var verticals: int = min(4, strokes_in_group)
		for s: int in range(verticals):
			var sx := x0 + s * 2
			var jitter := rng.randi_range(0, 1)
			for row: int in range(6):
				var py := 1 + jitter + row
				if py < h:
					img.set_pixel(sx, py, white)
		if strokes_in_group == 5:
			_draw_line(img, x0 - 1, 5, x0 + 7, 1, white)
		remaining -= strokes_in_group
		x0 += group_w + 3

	img.resize(max(w, 1) * scale, h * scale, Image.INTERPOLATE_NEAREST)
	return img


static func _draw_line(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, color)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
