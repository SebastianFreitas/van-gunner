extends RefCounted
## Generates one aged paper poster (WANTED van, festival or gig, gang notice) as a pixel-art Image.

const _Paint := preload("res://scripts/travel/facades/street_art/street_art_paint.gd")
const _Graffiti := preload("res://scripts/travel/facades/street_art/street_art_graffiti.gd")

enum Kind { WANTED, FESTIVAL, NOTICE }

## Metres per art pixel on the wall: finer than spray paint, it is print.
const PIXEL_M := 0.016
const FEST_TITLES: PackedStringArray = ["NIGHT FAIR", "CARNIVAL", "ROCK FEST", "BOXING", "CIRCUS",
		"RAVE", "DERBY", "MOTOR SHOW", "BLOCK PARTY", "WRESTLING"]
const FEST_ACTS: PackedStringArray = ["THE RUSTS", "DEAD AXLE", "NEON PIGS", "SOOT", "IRON MAY",
		"LOW TIDE", "KID VOLT", "THE GRAVEL", "MOTH CLUB", "BAD BRAKES"]
const DAYS: PackedStringArray = ["FRI", "SAT", "SUN"]
const MONTHS: PackedStringArray = ["JAN", "MAR", "MAY", "JUN", "AUG", "OCT", "NOV"]
const NOTICE_HEADS: PackedStringArray = ["CURFEW", "KEEP OUT", "OUR STREETS", "PAY OR BURN",
		"NO ENTRY", "MISSING", "THEY SEE YOU", "TOLL ZONE"]
const NOTICE_LINES: PackedStringArray = ["AFTER DARK", "BY ORDER", "NO WARNING", "YOU PAY",
		"TURN BACK", "LAST CALL", "STAY IN", "WE KNOW"]
const _NOTICE_SYMBOLS: Array[StringName] = [&"skull", &"crown", &"eye", &"anarchy"]


## One poster of the given kind; van_name is only read by WANTED.
static func make(rng: RandomNumberGenerator, kind: Kind, van_name: String) -> Image:
	match kind:
		Kind.WANTED:
			return _wanted(rng, van_name)
		Kind.FESTIVAL:
			return _festival(rng)
		_:
			return _notice(rng)


## WANTED poster for the player's own van: picture, stencil name, bounty, maybe a stamp.
static func _wanted(rng: RandomNumberGenerator, van_name: String) -> Image:
	var title := ""
	for ch in van_name.to_upper():
		var ok: bool = (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9")
		title += ch if ok else " "
	title = title.strip_edges()
	if title.is_empty():
		title = "THE VAN"
	var paper: Color = _Paint.PAPER[rng.randi_range(0, 1)]
	var red: Color = _Paint.INK[1]
	var ink: Color = red if rng.randf() < 0.25 else _Paint.INK[0]
	var reward := str([500, 1000, 2500, 5000, 10000, 25000][rng.randi_range(0, 5)])
	var longest := maxi(_Paint.text_width(title, 1), _Paint.text_width("DEAD OR ALIVE", 1))
	longest = maxi(longest, _Paint.text_width(reward, 1))
	var w := maxi(48, longest + 6)
	var h := 74
	var img := _Paint.new_image(w, h)
	_Paint.rect(img, Rect2i(0, 0, w, h), paper)
	_Paint.rect(img, Rect2i(2, 2, w - 4, h - 4), ink)
	_Paint.rect(img, Rect2i(3, 3, w - 6, h - 6), paper)
	var head_w := _Paint.text_width("WANTED", 1)
	_Paint.text_centered(img, "WANTED", 4, ink)
	_Paint.rect(img, Rect2i((w - head_w) >> 1, 12, head_w, 1), ink)
	var bx := (w - 36) >> 1
	_Paint.rect(img, Rect2i(bx, 14, 36, 20), ink)
	_Paint.rect(img, Rect2i(bx + 1, 15, 34, 18), paper)
	_draw_van(img, Vector2i(bx + 2, 16), 30, ink)
	for _i in rng.randi_range(6, 10):
		_Paint.put(img, bx + rng.randi_range(2, 33), rng.randi_range(16, 32), ink)
	_Paint.text_centered(img, title, 36, ink)
	_Paint.text_centered(img, "DEAD OR ALIVE", 45, ink)
	_Paint.text_centered(img, "REWARD", 54, ink)
	_Paint.text_centered(img, reward, 62, red if ink != red else ink)
	if rng.randf() < 0.3:
		var r := rng.randi_range(6, 8)
		var c := Vector2i(r if rng.randf() < 0.5 else w - r - 1, r if rng.randf() < 0.5 else h - r - 1)
		var stamp := _Paint.new_image(w, h)
		_Paint.ring(stamp, c, r, red, 1)
		var cells: Array[Vector2i] = []
		for y in h:
			for x in w:
				if stamp.get_pixel(x, y).a > 0.5:
					cells.append(Vector2i(x, y))
		for _i in rng.randi_range(4, 8):
			var cell := cells[rng.randi_range(0, cells.size() - 1)]
			stamp.set_pixel(cell.x, cell.y, Color(0, 0, 0, 0))
		img.blend_rect(stamp, Rect2i(0, 0, w, h), Vector2i.ZERO)
	_age(img, rng, Vector2(0.10, 0.35))
	return img


## Old pre-collapse festival, gig or fight poster: layout, motif, title, acts, date.
static func _festival(rng: RandomNumberGenerator) -> Image:
	var paper: Color = _Paint.pick(rng, _Paint.PAPER)
	var a1: Color = _Paint.pick(rng, _Paint.PAINT)
	var a2: Color = _Paint.pick(rng, _Paint.PAINT)
	var ink: Color = _Paint.INK[0]
	var base := Vector2i(70, 50) if rng.randf() < 0.3 else Vector2i(50, 70)
	var layout := rng.randi_range(0, 2)
	var heading := FEST_TITLES[rng.randi_range(0, FEST_TITLES.size() - 1)]
	var starburst := rng.randf() < 0.5
	var darker := a1 if a1.get_luminance() < a2.get_luminance() else a2
	var tcolor := ink if rng.randf() < 0.5 else darker
	var title_lines: Array[String] = [heading]
	if heading.contains(" ") and _Paint.text_width(heading, 1) > base.x - 6:
		var cut := heading.find(" ")
		title_lines = [heading.substr(0, cut), heading.substr(cut + 1)]
	var rows: Array[String] = []
	for _i in rng.randi_range(2, 3):
		var act := FEST_ACTS[rng.randi_range(0, FEST_ACTS.size() - 1)]
		if not rows.has(act):
			rows.append(act)
	rows.append("%s %d %s" % [DAYS[rng.randi_range(0, 2)], rng.randi_range(1, 28),
			MONTHS[rng.randi_range(0, MONTHS.size() - 1)]])
	if rng.randf() < 0.5:
		rows.append(str(rng.randi_range(2031, 2039)))
	var longest := 0
	for s in title_lines + rows:
		longest = maxi(longest, _Paint.text_width(s, 1))
	var w := maxi(base.x, longest + 6)
	var h := base.y
	var img := _Paint.new_image(w, h)
	_Paint.rect(img, Rect2i(0, 0, w, h), paper)
	if layout == 0:
		_Paint.rect(img, Rect2i(0, 0, w, h >> 1), a1)
	elif layout == 1:
		var bands := rng.randi_range(2, 4)
		var bh := floori(float(h) / float(bands * 2 + 1))
		for i in bands:
			_Paint.rect(img, Rect2i(0, (i * 2 + 1) * bh, w, bh), a1)
	else:
		for x in range(0, w, 4):
			for y in [0, h - 4]:
				_Paint.rect(img, Rect2i(x, y, 4, 4), a1 if (x >> 2) % 2 == 0 else a2)
		for y in range(4, h - 4, 4):
			for x in [0, w - 4]:
				_Paint.rect(img, Rect2i(x, y, 4, 4), a1 if (y >> 2) % 2 == 0 else a2)
	var c := Vector2i(w >> 1, int(h * 0.3))
	var r := mini(w, h) >> 2
	if starburst:
		_starburst(img, c, r, a2)
	elif heading == "BOXING":
		_Paint.disc(img, c, r, a2)
		_Paint.rect(img, Rect2i(c.x - (r >> 1), c.y + r - 2, r, (r >> 1) + 2), a2)
	else:
		_Paint.ring(img, c, r, a2, 1)
		for i in 6:
			var ang := float(i) * PI / 3.0
			_Paint.line(img, c, c + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r)), a2)
		_Paint.line(img, c, c + Vector2i(-3, r + 4), a2)
		_Paint.line(img, c, c + Vector2i(3, r + 4), a2)
		_Paint.rect(img, Rect2i(c.x - 4, c.y + r + 4, 9, 1), a2)
	var y := int(h * 0.45)
	for s in title_lines:
		var tx := (w - _Paint.text_width(s, 1)) >> 1
		_Paint.text(img, s, Vector2i(tx + 1, y + 1), paper, 1)
		_Paint.text(img, s, Vector2i(tx, y), tcolor, 1)
		y += 9
	y += 2
	var bottom := h - (6 if layout == 2 else 3)
	for s in rows:
		if y + 7 > bottom:
			continue
		_Paint.text_centered(img, s, y, ink, 1)
		y += 9
	_age(img, rng, Vector2(0.30, 0.60))
	return img


## Gang notice: curfew, turf warning or missing person, with a symbol or a mugshot.
static func _notice(rng: RandomNumberGenerator) -> Image:
	var paper: Color = _Paint.PAPER[[0, 4, 2][rng.randi_range(0, 2)]]
	var red: Color = _Paint.INK[1]
	var ink: Color = red if rng.randf() < 0.4 else _Paint.INK[0]
	var heading := NOTICE_HEADS[rng.randi_range(0, NOTICE_HEADS.size() - 1)]
	var missing := heading == "MISSING"
	var head_lines: Array[String] = [heading]
	var cut := heading.rfind(" ")
	if cut >= 0 and _Paint.text_width(heading, 1) > 34:
		head_lines = [heading.substr(0, cut), heading.substr(cut + 1)]
	var key: StringName = _NOTICE_SYMBOLS[rng.randi_range(0, _NOTICE_SYMBOLS.size() - 1)]
	var symbol := PackedStringArray(_Graffiti.SYMBOLS[key])
	var tail: Array[String] = []
	for _i in rng.randi_range(1, 2):
		var line := NOTICE_LINES[rng.randi_range(0, NOTICE_LINES.size() - 1)]
		if not tail.has(line):
			tail.append(line)
	var scrawl := rng.randi_range(2, 3) if rng.randf() < 0.4 else 0
	var longest := 0
	for s in head_lines + tail:
		longest = maxi(longest, _Paint.text_width(s, 1))
	if missing:
		longest = maxi(longest, _Paint.text_width("LAST SEEN", 1))
	var pic_h := 22 if missing else symbol.size() * 2
	var used := 4 + head_lines.size() * 9 + 2 + pic_h + 4 + (10 if missing else 0)
	used += tail.size() * 9 + scrawl * 8 + 4
	var w := maxi(40, longest + 6)
	var h := maxi(56, used)
	var img := _Paint.new_image(w, h)
	_Paint.rect(img, Rect2i(0, 0, w, h), paper)
	var y := 4
	for s in head_lines:
		_Paint.text_centered(img, s, y, ink, 1)
		y += 9
	y += 2
	if missing:
		var bx := (w - 20) >> 1
		_Paint.rect(img, Rect2i(bx, y, 20, 22), ink)
		_Paint.rect(img, Rect2i(bx + 1, y + 1, 18, 20), paper)
		_draw_face(img, Vector2i(bx + 1, y + 1), ink,
				Color(paper.r * 0.75, paper.g * 0.75, paper.b * 0.75, 1.0))
		_Paint.text_centered(img, "LAST SEEN", y + 25, ink, 1)
		y += 35
	else:
		var sx := (w - symbol[0].length() * 2) >> 1
		_Paint.stamp(img, symbol, Vector2i(sx, y), ink, 2)
		y += pic_h + 4
	for s in tail:
		_Paint.text_centered(img, s, y, ink, 1)
		y += 9
	var sy := h - 4 - scrawl * 8 + 2
	for _i in scrawl:
		var span := rng.randi_range(10, 24)
		var x := rng.randi_range(3, maxi(w - 3 - span, 3))
		var prev := Vector2i(x, sy + rng.randi_range(0, 3))
		for k in range(2, span + 1, 2):
			var next := Vector2i(x + k, sy + rng.randi_range(0, 3))
			_Paint.line(img, prev, next, ink, 1)
			prev = next
		sy += 8
	_age(img, rng, Vector2(0.05, 0.30))
	return img


## Boxy war van seen from the side, facing right; origin is the top-left of its 30 x 16 area.
static func _draw_van(img: Image, origin: Vector2i, w: int, ink: Color) -> void:
	var paper := img.get_pixel(origin.x, origin.y)
	var x0 := origin.x
	var y0 := origin.y
	_Paint.rect(img, Rect2i(x0 + 3, y0, w - 12, 1), ink)
	_Paint.rect(img, Rect2i(x0 + 4, y0 + 1, 1, 2), ink)
	_Paint.rect(img, Rect2i(x0 + w - 10, y0 + 1, 1, 2), ink)
	_Paint.rect(img, Rect2i(x0, y0 + 3, w - 8, 8), ink)
	_Paint.rect(img, Rect2i(x0 + w - 8, y0 + 6, 8, 5), ink)
	_Paint.rect(img, Rect2i(x0 + w - 6, y0 + 7, 3, 2), paper)
	for wx in [x0 + 6, x0 + w - 8]:
		_Paint.disc(img, Vector2i(wx, y0 + 12), 3, ink)
		_Paint.put(img, wx, y0 + 12, paper)
	for sy in [6, 8, 10]:
		_Paint.put(img, x0 + w, y0 + sy, ink)


## Mugshot bust in the 18 x 20 area at origin: head oval, shoulders, shaded right half, eyes.
static func _draw_face(img: Image, origin: Vector2i, ink: Color, tone: Color) -> void:
	var paper := img.get_pixel(origin.x, origin.y)
	var cx := origin.x + 9
	var cy := origin.y + 7
	for dy in [0, 2]:
		_Paint.disc(img, Vector2i(cx, cy + dy), 6, ink)
	for dy in [0, 2]:
		_Paint.disc(img, Vector2i(cx, cy + dy), 5, paper)
	for y in range(cy - 5, cy + 8):
		for x in range(cx + 1, cx + 6):
			if img.get_pixel(x, y) == paper:
				img.set_pixel(x, y, tone)
	_Paint.rect(img, Rect2i(origin.x + 1, origin.y + 15, 16, 5), ink)
	_Paint.put(img, origin.x + 1, origin.y + 15, paper)
	_Paint.put(img, origin.x + 16, origin.y + 15, paper)
	_Paint.put(img, cx - 3, cy, ink)
	_Paint.put(img, cx + 2, cy, ink)


## Rays every 30 degrees from the centre plus a filled disc of a third of the radius.
static func _starburst(img: Image, center: Vector2i, r: int, c: Color) -> void:
	for i in 12:
		var ang := float(i) * PI / 6.0
		_Paint.line(img, center, center + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r)), c)
	_Paint.disc(img, center, floori(float(r) / 3.0), c)


## Ages a finished poster: fade, stains, fold, tears, flaking, maybe a tag, then the budget.
static func _age(img: Image, rng: RandomNumberGenerator, fade: Vector2) -> void:
	var amount := rng.randf_range(fade.x, fade.y)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				img.set_pixel(x, y, _Paint.fade(c, amount))
	_Paint.stain(img, rng, rng.randi_range(0, 3))
	if rng.randf() < 0.5:
		_Paint.crease(img, rng)
	_Paint.tear(img, rng, rng.randi_range(1, 3))
	_Paint.wear(img, rng, rng.randf_range(0.0, 0.05))
	if rng.randf() < 0.15:
		_Graffiti.scribble(img, rng)
	_Paint.finalize(img, _Paint.PAPER_MAX_LUM)
