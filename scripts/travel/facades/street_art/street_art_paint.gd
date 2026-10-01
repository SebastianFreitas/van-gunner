extends RefCounted
## Static pixel-art drawing helpers for street art: budgeted palettes, primitives, text, outlines, drips, wear, tears and stains on RGBA8 Images.

## Spray paint colours (sRGB, as stored in the Image); all sit under PAINT_MAX_LUM.
const PAINT: Array[Color] = [
	Color(0.55, 0.16, 0.13), # red
	Color(0.38, 0.09, 0.09), # oxblood
	Color(0.60, 0.32, 0.12), # rust orange
	Color(0.60, 0.50, 0.15), # mustard
	Color(0.62, 0.60, 0.55), # dirty white
	Color(0.07, 0.07, 0.07), # black
	Color(0.15, 0.42, 0.42), # teal
	Color(0.30, 0.45, 0.20), # green
	Color(0.35, 0.18, 0.40), # purple
	Color(0.60, 0.30, 0.42), # pink
	Color(0.55, 0.56, 0.58), # chrome silver
	Color(0.20, 0.28, 0.50), # blue
]
## Poster paper stocks.
const PAPER: Array[Color] = [
	Color(0.64, 0.60, 0.50), # off-white
	Color(0.62, 0.54, 0.36), # yellowed
	Color(0.60, 0.42, 0.42), # pink stock
	Color(0.45, 0.55, 0.50), # green stock
	Color(0.62, 0.52, 0.20), # yellow stock
	Color(0.40, 0.46, 0.58), # blue stock
]
## Poster ink colours.
const INK: Array[Color] = [
	Color(0.05, 0.05, 0.05), # black
	Color(0.48, 0.10, 0.08), # red
	Color(0.12, 0.14, 0.30), # navy
]
## Tone that fade() pulls colours toward.
const FADE_TONE := Color(0.36, 0.33, 0.29)
## Tone that stain() pulls colours toward.
const STAIN_TONE := Color(0.30, 0.22, 0.12)
## Linear luminance caps from the albedo budget.
const PAINT_MAX_LUM := 0.40
const PAPER_MAX_LUM := 0.45


## New fully transparent RGBA8 image.
static func new_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Random colour from a palette.
static func pick(rng: RandomNumberGenerator, palette: Array[Color]) -> Color:
	return palette[rng.randi_range(0, palette.size() - 1)]


## Colour pulled toward FADE_TONE, alpha kept.
static func fade(c: Color, amount: float) -> Color:
	return c.lerp(FADE_TONE, clampf(amount, 0.0, 1.0))


## Scales a colour's linear luminance down to max_lum if it is above it; alpha kept.
static func budget(c: Color, max_lum: float) -> Color:
	var lin := c.srgb_to_linear()
	var lum := 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
	if lum > max_lum:
		var k := max_lum / lum
		lin = Color(lin.r * k, lin.g * k, lin.b * k, lin.a)
	var out := lin.linear_to_srgb()
	out.a = c.a
	return out


## Sets one pixel if it is inside the image.
static func put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## Fills a rect clipped to the image.
static func rect(img: Image, r: Rect2i, c: Color) -> void:
	var clipped := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	img.fill_rect(clipped, c)


## Bresenham line; wider lines stamp a width x width square at each step.
static func line(img: Image, a: Vector2i, b: Vector2i, c: Color, width: int = 1) -> void:
	var w := maxi(width, 1)
	var half := w >> 1
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while true:
		rect(img, Rect2i(x - half, y - half, w, w), c)
		if x == b.x and y == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


## Filled disc.
static func disc(img: Image, center: Vector2i, r: int, c: Color) -> void:
	if r < 0:
		return
	for dy in range(-r, r + 1):
		var half := int(sqrt(float(r * r - dy * dy)))
		rect(img, Rect2i(center.x - half, center.y + dy, 2 * half + 1, 1), c)


## Ring of the given thickness whose outer radius is r.
static func ring(img: Image, center: Vector2i, r: int, c: Color, thickness: int = 1) -> void:
	if r < 0:
		return
	var inner := r - maxi(thickness, 1)
	var inner2 := inner * inner if inner >= 0 else -1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d2 := dx * dx + dy * dy
			if d2 <= r * r and d2 > inner2:
				put(img, center.x + dx, center.y + dy, c)


## Paints every '#' of a row bitmap as a scale x scale block.
static func stamp(img: Image, rows: PackedStringArray, origin: Vector2i, c: Color,
		scale: int = 1) -> void:
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			if row[x] == "#":
				var at := origin + Vector2i(x, y) * scale
				rect(img, Rect2i(at, Vector2i(scale, scale)), c)


## Width in pixels of block-letter text.
static func text_width(s: String, scale: int) -> int:
	return BlockGlyphs.text_width_px(s, scale)


## Height in pixels of one line of block-letter text.
static func text_height(scale: int) -> int:
	return BlockGlyphs.line_height(scale)


## Block-letter text; alpha forced to 1 so draw_text's lerp writes the colour exactly.
static func text(img: Image, s: String, origin: Vector2i, c: Color, scale: int = 1) -> void:
	BlockGlyphs.draw_text(img, s, origin, Color(c.r, c.g, c.b, 1.0), scale)


## Block-letter text centred horizontally at row y.
static func text_centered(img: Image, s: String, y: int, c: Color, scale: int = 1) -> void:
	var x := (img.get_width() - text_width(s, scale)) >> 1
	text(img, s, Vector2i(x, y), c, scale)


## New image with a hard outline of colour c around every opaque shape (throw-up style).
## The caller leaves a margin of `thickness` px.
static func outline(img: Image, c: Color, thickness: int = 1) -> Image:
	var out := img.duplicate() as Image
	var w := out.get_width()
	var h := out.get_height()
	for _pass in maxi(thickness, 0):
		var prev := out.duplicate() as Image
		for y in h:
			for x in w:
				if prev.get_pixel(x, y).a >= 0.5:
					continue
				if (x > 0 and prev.get_pixel(x - 1, y).a >= 0.5) \
						or (x < w - 1 and prev.get_pixel(x + 1, y).a >= 0.5) \
						or (y > 0 and prev.get_pixel(x, y - 1).a >= 0.5) \
						or (y < h - 1 and prev.get_pixel(x, y + 1).a >= 0.5):
					out.set_pixel(x, y, c)
	return out


## One-pixel 4-neighbour dilation in place; each new pixel takes its neighbour's colour.
static func grow(img: Image) -> void:
	var src := img.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a >= 0.5:
				continue
			var from := Vector2i(-1, -1)
			if x > 0 and src.get_pixel(x - 1, y).a >= 0.5:
				from = Vector2i(x - 1, y)
			elif x < w - 1 and src.get_pixel(x + 1, y).a >= 0.5:
				from = Vector2i(x + 1, y)
			elif y > 0 and src.get_pixel(x, y - 1).a >= 0.5:
				from = Vector2i(x, y - 1)
			elif y < h - 1 and src.get_pixel(x, y + 1).a >= 0.5:
				from = Vector2i(x, y + 1)
			if from.x >= 0:
				img.set_pixel(x, y, src.get_pixel(from.x, from.y))


## Paint drips: some columns run down from their lowest opaque pixel, with a blob on long ones.
static func drips(img: Image, rng: RandomNumberGenerator, chance: float, max_len: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	# Find every column's lowest pixel first so a blob never feeds the next column.
	var lowest := PackedInt32Array()
	lowest.resize(w)
	for x in w:
		lowest[x] = -1
		for y in range(h - 1, -1, -1):
			if img.get_pixel(x, y).a >= 0.5:
				lowest[x] = y
				break
	for x in w:
		var y0 := lowest[x]
		if y0 < 0 or max_len < 1 or rng.randf() >= chance:
			continue
		var col := img.get_pixel(x, y0)
		var length := rng.randi_range(1, max_len)
		var end_y := y0
		for i in range(1, length + 1):
			if y0 + i >= h:
				break
			img.set_pixel(x, y0 + i, col)
			end_y = y0 + i
		if end_y - y0 >= 3 and rng.randf() < 0.5:
			put(img, x - 1, end_y, col)
			put(img, x + 1, end_y, col)


## Clears 2x2 blocks at random, more likely beside already cleared blocks (flaking paint).
static func wear(img: Image, rng: RandomNumberGenerator, amount: float) -> void:
	var bw := (img.get_width() + 1) >> 1
	var bh := (img.get_height() + 1) >> 1
	var cleared := PackedByteArray()
	cleared.resize(bw * bh)
	for by in bh:
		for bx in bw:
			var near := (bx > 0 and cleared[by * bw + bx - 1] == 1) \
					or (bx < bw - 1 and cleared[by * bw + bx + 1] == 1) \
					or (by > 0 and cleared[(by - 1) * bw + bx] == 1) \
					or (by < bh - 1 and cleared[(by + 1) * bw + bx] == 1)
			var p := amount * 2.0 if near else amount
			if rng.randf() < p:
				cleared[by * bw + bx] = 1
				rect(img, Rect2i(bx * 2, by * 2, 2, 2), Color(0, 0, 0, 0))


## Torn paper edges: ragged bites on all borders, maybe a clipped corner or a torn-off top.
static func tear(img: Image, rng: RandomNumberGenerator, depth: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var clear := Color(0, 0, 0, 0)
	var d := 0
	for x in w:
		d = clampi(d + rng.randi_range(-1, 1), 0, depth)
		rect(img, Rect2i(x, 0, 1, d), clear)
	d = 0
	for x in w:
		d = clampi(d + rng.randi_range(-1, 1), 0, depth)
		rect(img, Rect2i(x, h - d, 1, d), clear)
	d = 0
	for y in h:
		d = clampi(d + rng.randi_range(-1, 1), 0, depth)
		rect(img, Rect2i(0, y, d, 1), clear)
	d = 0
	for y in h:
		d = clampi(d + rng.randi_range(-1, 1), 0, depth)
		rect(img, Rect2i(w - d, y, d, 1), clear)
	if rng.randf() < 0.3:
		var leg := int(minf(w, h) * rng.randf_range(0.2, 0.45))
		var corner := rng.randi_range(0, 3)
		for i in leg:
			var run := leg - i
			var x0 := 0 if corner % 2 == 0 else w - run
			var y0 := i if corner < 2 else h - 1 - i
			rect(img, Rect2i(x0, y0, run, 1), clear)
	if rng.randf() < 0.15:
		var strip := int(h * rng.randf_range(0.15, 0.35))
		var edge := PackedInt32Array()
		edge.resize(w)
		var e := strip
		for x in w:
			e = clampi(e + rng.randi_range(-1, 1), maxi(strip - 3, 1), strip + 3)
			edge[x] = e
			rect(img, Rect2i(x, 0, 1, e), clear)
		var tape := Color(0.55, 0.52, 0.45)
		for _i in rng.randi_range(2, 3):
			var tx := rng.randi_range(0, w - 1)
			if edge[tx] < h and img.get_pixel(tx, edge[tx]).a >= 0.5:
				img.set_pixel(tx, edge[tx], tape)


## Dirty blobs: darken and brown the opaque pixels, with a darker 1-px rim.
static func stain(img: Image, rng: RandomNumberGenerator, count: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for _i in count:
		var r := rng.randi_range(3, 10)
		var cx := rng.randi_range(0, w - 1)
		var cy := rng.randi_range(0, h - 1)
		var m := rng.randf_range(0.72, 0.88)
		for y in range(maxi(cy - r, 0), mini(cy + r + 1, h)):
			for x in range(maxi(cx - r, 0), mini(cx + r + 1, w)):
				var d2 := (x - cx) * (x - cx) + (y - cy) * (y - cy)
				if d2 > r * r:
					continue
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var k := m * 0.8 if d2 > (r - 1) * (r - 1) else m
				var dark := Color(c.r * k, c.g * k, c.b * k, c.a)
				img.set_pixel(x, y, dark.lerp(STAIN_TONE, 0.25))


## One fold line across the image at 30..70%: opaque pixels on it get darker.
static func crease(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var horizontal := rng.randf() < 0.5
	var at := int((h if horizontal else w) * rng.randf_range(0.3, 0.7))
	for i in (w if horizontal else h):
		var x := i if horizontal else at
		var y := at if horizontal else i
		var c := img.get_pixel(x, y)
		if c.a >= 0.5:
			img.set_pixel(x, y, Color(c.r * 0.82, c.g * 0.82, c.b * 0.82, c.a))


## Final pass: alpha becomes 0 or 255 and every colour goes through the albedo budget.
static func finalize(img: Image, max_lum: float) -> void:
	var clear := Color(0, 0, 0, 0)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, clear)
			else:
				img.set_pixel(x, y, budget(Color(c.r, c.g, c.b, 1.0), max_lum))
