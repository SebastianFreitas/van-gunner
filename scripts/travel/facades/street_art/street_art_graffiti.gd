extends RefCounted
## Generates one random spray-paint graffiti piece (tag, throw-up, symbol or slogan) as a pixel-art Image.

const _Paint := preload("res://scripts/travel/facades/street_art/street_art_paint.gd")

enum Kind { TAG, THROW_UP, SYMBOL, SLOGAN }

## Metres per art pixel on the wall; the placer reads it.
const PIXEL_M := 0.024
const TAG_WORDS: PackedStringArray = ["RAZE", "KRASH", "VEX", "DOOM", "SKUM", "ROT", "HAVOC",
		"GRIM", "ZERO", "NOX", "BLKD", "RUST", "KOZ", "DREG", "FANG", "OKO", "SPIT", "HEX",
		"MOTH", "SLAG"]
const THROW_WORDS: PackedStringArray = ["RAT", "DOA", "KAOS", "WAR", "BURN", "SKUM", "VEX",
		"ZAP", "GOON", "RIOT"]
const SLOGANS: PackedStringArray = ["NO FUTURE", "TURN BACK", "DEAD END", "RUN", "THEY WATCH",
		"NO COPS", "EAT THE RICH", "HELL IS HERE", "KEEP DRIVING", "WE SEE YOU",
		"NOBODY COMES", "PAY UP"]
## Row bitmaps, "#" is lit (plain Arrays: a PackedStringArray constructor is not a constant).
const SYMBOLS := {
	&"crown": ["#...#...#", "##.###.##", "#########", "#########",
			"#.#.#.#.#", "#########"],
	&"skull": ["..#####..", ".#######.", "##..#..##", "##..#..##",
			"#########", ".###.###.", "..#####..", "..#.#.#.."],
	&"anarchy": ["..#####..", ".#..#..#.", "#..#.#..#", "#.#...#.#",
			"##.###.##", "#.#...#.#", "##.....##", ".#.....#.", "..#####.."],
	&"star": ["...#...", "...#...", "#######", ".#####.", "..###..",
			".##.##.", "##...##"],
	&"arrow": [".....#...", "......#..", "#########", "......#..",
			".....#..."],
	&"eye": ["...#####...", ".##.....##.", "#...###...#", "#...###...#",
			".##.....##.", "...#####..."],
	&"x_smiley": ["...#####...", ".##.....##.", "#.#.#.#.#.#",
			"#..#...#..#", "#.#.#.#.#.#", "#.........#", ".#.#####.#.", ".##.....##.",
			"...#####..."],
	&"crosshair": ["...###...", ".##.#.##.", ".#..#..#.", "#...#...#",
			"#########", "#...#...#", ".#..#..#.", ".##.#.##.", "...###..."],
	&"bolt": ["....###", "...###.", "..###..", ".######", "....##.",
			"...##..", "..##...", "..#...."],
}


## One random piece: tag 45%, throw-up 25%, symbol 15%, slogan 15%.
static func make(rng: RandomNumberGenerator) -> Image:
	var roll := rng.randf()
	if roll < 0.45:
		return make_kind(rng, Kind.TAG)
	if roll < 0.70:
		return make_kind(rng, Kind.THROW_UP)
	if roll < 0.85:
		return make_kind(rng, Kind.SYMBOL)
	return make_kind(rng, Kind.SLOGAN)


## One piece of the given kind.
static func make_kind(rng: RandomNumberGenerator, kind: Kind) -> Image:
	match kind:
		Kind.TAG:
			return _tag(rng)
		Kind.THROW_UP:
			return _throw_up(rng)
		Kind.SYMBOL:
			return _symbol(rng)
		_:
			return _slogan(rng)


## Sprays a small over-tag across an existing image (posters), in place and without resizing.
static func scribble(img: Image, rng: RandomNumberGenerator) -> void:
	var col := _color(rng)
	var w := img.get_width()
	var h := img.get_height()
	var span := maxi(int(w * rng.randf_range(0.5, 0.8)), 2)
	var x0 := rng.randi_range(0, maxi(w - span, 0))
	var yc := rng.randi_range(2, maxi(h - 3, 2))
	var segs := rng.randi_range(4, 7)
	var pts: Array[Vector2i] = []
	for i in segs + 1:
		var sign_y := 1 if i % 2 == 0 else -1
		var px := x0 + floori(float(span * i) / float(segs))
		pts.append(Vector2i(px, yc + sign_y * rng.randi_range(1, 4)))
	for i in segs:
		_Paint.line(img, pts[i], pts[i + 1], col, 1)
	for _d in rng.randi_range(2, 3):
		var p := pts[rng.randi_range(0, segs)]
		for k in rng.randi_range(2, 5):
			_Paint.put(img, p.x, p.y + 1 + k, col)


## A faded spray colour for one piece.
static func _color(rng: RandomNumberGenerator) -> Color:
	return _Paint.fade(_Paint.pick(rng, _Paint.PAINT), rng.randf_range(0.15, 0.55))


## Moves the pixels inside a column block up or down by dy, clipped to the image.
static func _shift_block(img: Image, block: Rect2i, dy: int) -> void:
	var src := img.duplicate() as Image
	_Paint.rect(img, block, Color(0, 0, 0, 0))
	for y in range(block.position.y, block.end.y):
		for x in range(block.position.x, block.end.x):
			if x >= 0 and y >= 0 and x < src.get_width() and y < src.get_height():
				var c := src.get_pixel(x, y)
				if c.a >= 0.5:
					_Paint.put(img, x, y + dy, c)


## Paints a pixel only where the image is already solid.
static func _put_solid(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
			and img.get_pixel(x, y).a >= 0.5:
		img.set_pixel(x, y, c)


## Slanted, stretched wildstyle tag with an underline swoosh.
static func _tag(rng: RandomNumberGenerator) -> Image:
	var col := _color(rng)
	var word := TAG_WORDS[rng.randi_range(0, TAG_WORDS.size() - 1)]
	var tw := _Paint.text_width(word, 1)
	var h := _Paint.text_height(1) + 4
	var w := tw + 24
	var scratch := _Paint.new_image(w, h)
	_Paint.text(scratch, word, Vector2i(4, 2), col, 1)
	# A crown or star over the first letter needs headroom above the stretched letters.
	var crest := rng.randf() < 0.2
	var top := 8 if crest else 0
	var img := _Paint.new_image(w, h * 2 + top)
	for y in h:
		var shift := floori((h - 1 - y) * 0.4)
		for x in w:
			var c := scratch.get_pixel(x, y)
			if c.a >= 0.5:
				_Paint.put(img, x + shift, top + y * 2, c)
				_Paint.put(img, x + shift, top + y * 2 + 1, c)
	for i in word.length():
		_shift_block(img, Rect2i(4 + i * 7 + 1, 0, 7, img.get_height()), rng.randi_range(-2, 2))
	if rng.randf() < 0.7:
		var sy := top + h * 2 - 2
		var tip := Vector2i(tw + 10, sy - rng.randi_range(2, 4))
		_Paint.line(img, Vector2i(5, sy), tip, col, 1)
		if rng.randf() < 0.4:
			_Paint.line(img, tip, tip + Vector2i(-2, -2), col, 1)
			_Paint.line(img, tip, tip + Vector2i(-2, 2), col, 1)
	if crest:
		var key := &"crown" if rng.randf() < 0.5 else &"star"
		_Paint.stamp(img, PackedStringArray(SYMBOLS[key]), Vector2i(4, 1), col, 1)
	_Paint.drips(img, rng, 0.25, 4)
	_Paint.wear(img, rng, rng.randf_range(0.04, 0.12))
	_Paint.finalize(img, _Paint.PAINT_MAX_LUM)
	return img


## Chunky overlapping bubble letters, two-tone fill, shine and a hard outline.
static func _throw_up(rng: RandomNumberGenerator) -> Image:
	var word := THROW_WORDS[rng.randi_range(0, THROW_WORDS.size() - 1)]
	var n := word.length()
	var adv := BlockGlyphs.glyph_width(3) - 1
	var letter_h := _Paint.text_height(3)
	# 4 px margin for grow + outlines, 3 px of letter jitter, 5 px of drip room below.
	var img := _Paint.new_image(n * adv + 1 + 8, letter_h + 3 + 8 + 5)
	var ys := PackedInt32Array()
	for i in n:
		var y := 4 + rng.randi_range(0, 3)
		ys.append(y)
		_Paint.text(img, word[i], Vector2i(4 + i * adv, y), Color.WHITE, 3)
	_Paint.grow(img)
	var fade_amt := rng.randf_range(0.15, 0.55)
	var fill: Color
	if rng.randf() < 0.55:
		fill = _Paint.fade(_Paint.PAINT[10 if rng.randf() < 0.5 else 4], fade_amt)
	else:
		fill = _Paint.fade(_Paint.pick(rng, _Paint.PAINT), fade_amt)
	var low := fill.darkened(0.3)
	if rng.randf() < 0.4:
		low = _Paint.fade(_Paint.pick(rng, _Paint.PAINT), fade_amt)
	var split := letter_h - 7
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.5:
				continue
			var i := clampi(floori(float(x - 4) / float(adv)), 0, n - 1)
			img.set_pixel(x, y, low if y >= ys[i] + split else fill)
	var shine := _Paint.fade(_Paint.PAINT[4], fade_amt)
	for _s in rng.randi_range(3, 6):
		var i := rng.randi_range(0, n - 1)
		var sx := 4 + i * adv + rng.randi_range(2, 11)
		var sy := ys[i] + rng.randi_range(1, 4)
		_put_solid(img, sx + 1, sy, shine)
		_put_solid(img, sx, sy + 1, shine)
	var dark: Array[int] = [1, 8, 11]
	var out_col: Color = _Paint.PAINT[5] if rng.randf() < 0.7 \
			else _Paint.PAINT[dark[rng.randi_range(0, 2)]]
	img = _Paint.outline(img, out_col, 2)
	if rng.randf() < 0.35:
		img = _Paint.outline(img, _color(rng), 1)
	_Paint.drips(img, rng, 0.2, 5)
	_Paint.wear(img, rng, rng.randf_range(0.02, 0.08))
	_Paint.finalize(img, _Paint.PAINT_MAX_LUM)
	return img


## A stencil-style icon, sometimes drawn twice side by side.
static func _symbol(rng: RandomNumberGenerator) -> Image:
	var col := _color(rng)
	var keys := SYMBOLS.keys()
	var rows := PackedStringArray(SYMBOLS[keys[rng.randi_range(0, keys.size() - 1)]])
	var scale := rng.randi_range(2, 3)
	var count := 2 if rng.randf() < 0.35 else 1
	var sw := rows[0].length() * scale
	var gap := 3
	var img := _Paint.new_image(4 + count * sw + (count - 1) * gap, 4 + rows.size() * scale + 4)
	for i in count:
		_Paint.stamp(img, rows, Vector2i(2 + i * (sw + gap), 2), col, scale)
	_Paint.drips(img, rng, 0.35, 4)
	_Paint.wear(img, rng, rng.randf_range(0.05, 0.15))
	_Paint.finalize(img, _Paint.PAINT_MAX_LUM)
	return img


## One or two lines of shaky block capitals.
static func _slogan(rng: RandomNumberGenerator) -> Image:
	var col := _color(rng)
	var phrase := SLOGANS[rng.randi_range(0, SLOGANS.size() - 1)]
	var lines: Array[String] = [phrase]
	if phrase.length() > 9 and phrase.contains(" "):
		var best := -1
		for i in phrase.length():
			if phrase[i] == " " and (best < 0
					or absi(i * 2 - phrase.length()) < absi(best * 2 - phrase.length())):
				best = i
		lines = [phrase.substr(0, best), phrase.substr(best + 1)]
	var max_w := 0
	for line in lines:
		max_w = maxi(max_w, _Paint.text_width(line, 1))
	var img := _Paint.new_image(max_w + 8, 6 + lines.size() * 9 + 6)
	var step := BlockGlyphs.glyph_gap(1)
	var ly := 3
	for line in lines:
		var x := (img.get_width() - _Paint.text_width(line, 1)) >> 1
		var x_start := x
		for ch in line:
			_Paint.text(img, ch, Vector2i(x, ly + rng.randi_range(0, 1)), col, 1)
			x += _Paint.text_width(ch, 1) + step
		if line == lines[lines.size() - 1] and rng.randf() < 0.3:
			var ux := x_start + _Paint.text_width(line, 1)
			_Paint.line(img, Vector2i(x_start, ly + 9), Vector2i(ux, ly + 9), col, 1)
		ly += 9
	_Paint.drips(img, rng, 0.3, 5)
	_Paint.wear(img, rng, rng.randf_range(0.08, 0.2))
	_Paint.finalize(img, _Paint.PAINT_MAX_LUM)
	return img
