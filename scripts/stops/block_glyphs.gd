class_name BlockGlyphs
extends RefCounted
## Stamped 5 x 7 block-letter font shared by shop flyers and street signs: glyph bit rows,
## text drawing into an Image, and label textures for signs.


static func pattern(ch: String) -> Array[int]:
	# 5x7 bit rows, MSB left. Sparse / stamped look.
	var empty: Array[int] = []
	match ch.to_upper():
		"A":
			return [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001]
		"B":
			return [0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110]
		"C":
			return [0b01111, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b01111]
		"D":
			return [0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110]
		"E":
			return [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111]
		"F":
			return [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000]
		"H":
			return [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001]
		"I":
			return [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111]
		"K":
			return [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001]
		"L":
			return [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111]
		"N":
			return [0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001]
		"O":
			return [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110]
		"P":
			return [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000]
		"R":
			return [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001]
		"S":
			return [0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110]
		"T":
			return [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100]
		"U":
			return [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110]
		"W":
			return [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010]
		"Y":
			return [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100]
		"%":
			return [0b11001, 0b11010, 0b00100, 0b01000, 0b10110, 0b10011, 0b00000]
		"!":
			return [0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000, 0b00100]
		"0":
			return [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110]
		"5":
			return [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110]
		"G":
			return [0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110]
		"J":
			return [0b00111, 0b00010, 0b00010, 0b00010, 0b00010, 0b10010, 0b01100]
		"M":
			return [0b10001, 0b11011, 0b10101, 0b10001, 0b10001, 0b10001, 0b10001]
		"Q":
			return [0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101]
		"V":
			return [0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b01010, 0b00100]
		"X":
			return [0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001]
		"Z":
			return [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111]
		"1":
			return [0b00100, 0b01100, 0b10100, 0b00100, 0b00100, 0b00100, 0b11111]
		"2":
			return [0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111]
		"3":
			return [0b01110, 0b10001, 0b00001, 0b00110, 0b00001, 0b10001, 0b01110]
		"4":
			return [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010]
		"6":
			return [0b01110, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110]
		"7":
			return [0b11111, 0b00001, 0b00010, 0b00100, 0b00100, 0b00100, 0b00100]
		"8":
			return [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110]
		"9":
			return [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b01110]
		"-":
			return [0b00000, 0b00000, 0b00000, 0b01110, 0b00000, 0b00000, 0b00000]
		"&":
			return [0b01100, 0b10010, 0b01100, 0b01110, 0b10010, 0b10011, 0b01101]
		".":
			return [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00100]
		"'":
			return [0b00100, 0b00100, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000]
		"/":
			return [0b00001, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b10000]
		":":
			return [0b00000, 0b00000, 0b00100, 0b00000, 0b00100, 0b00000, 0b00000]
		" ":
			return empty
		_:
			return [0b01110, 0b10001, 0b00010, 0b00100, 0b00100, 0b00000, 0b00100]


static func glyph_width(scale: int) -> int:
	return 5 * scale


static func glyph_gap(scale: int) -> int:
	return 2 * scale


static func line_height(scale: int) -> int:
	return 7 * scale


static func text_width_px(text: String, scale: int) -> int:
	var glyph_w := glyph_width(scale)
	var gap := glyph_gap(scale)
	var width := 0
	for ch in text.to_upper():
		var glyph := pattern(ch)
		if glyph.is_empty():
			width += gap
		else:
			width += glyph_w + gap
	return maxi(width - gap, 0)


static func draw_text(img: Image, text: String, origin: Vector2i, color: Color, scale: int) -> void:
	var cursor_x := origin.x
	var glyph_w := glyph_width(scale)
	var gap := glyph_gap(scale)
	for ch in text.to_upper():
		var glyph := pattern(ch)
		if glyph.is_empty():
			cursor_x += gap
			continue
		for row in glyph.size():
			var bits: int = glyph[row]
			for col in 5:
				if (bits >> (4 - col)) & 1:
					for sy in scale:
						for sx in scale:
							var px := cursor_x + col * scale + sx
							var py := origin.y + row * scale + sy
							if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
								var existing := img.get_pixel(px, py)
								img.set_pixel(px, py, existing.lerp(color, color.a))
		cursor_x += glyph_w + gap


static func make_label(text: String, scale: int, fg: Color, bg: Color, pad: int = 2) -> ImageTexture:
	var w := maxi(text_width_px(text, scale) + 2 * pad, 1)
	var h := line_height(scale) + 2 * pad
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	draw_text(img, text, Vector2i(pad, pad), fg, scale)
	return ImageTexture.create_from_image(img)


static func make_vertical_label(text: String, scale: int, fg: Color, bg: Color, pad: int = 2) -> ImageTexture:
	var line_h := line_height(scale)
	var gap := glyph_gap(scale)
	var w := glyph_width(scale) + 2 * pad
	var h := text.length() * (line_h + gap) - gap + 2 * pad
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	for i in text.length():
		draw_text(img, text[i], Vector2i(pad, pad + i * (line_h + gap)), fg, scale)
	return ImageTexture.create_from_image(img)
