class_name ArmTattooFont
extends RefCounted
## Block-capital stroke font: lays a short text out as line segments for the arm tattoo shader.

## Most segments the tattoo shader loops over; longer text is cut from the end.
const MAX_SEGS := 64
## One glyph's box in grid units, and the gap left between glyphs and between lines.
const GLYPH_W := 4.0
const GLYPH_H := 6.0
const GAP := 1.5
## Share of the box height one line must fill before a two-line split is tried.
const MIN_FILL := 0.55
## Strokes as (x0, y0, x1, y1) on a 4x6 grid, x left to right, y bottom to top. Straight
## strokes with clipped corners only, like hand-poked capitals; the shader takes the min
## distance, so strokes may share endpoints. Plain Vector4 arrays: GDScript will not take a
## PackedVector4Array constructor in a const.
const GLYPHS: Dictionary = {
	"A": [
		Vector4(0, 0, 0, 5), Vector4(0, 5, 1, 6), Vector4(1, 6, 3, 6),
		Vector4(3, 6, 4, 5), Vector4(4, 5, 4, 0), Vector4(0, 3, 4, 3)],
	"B": [
		Vector4(0, 0, 0, 6), Vector4(0, 6, 3, 6), Vector4(3, 6, 4, 4.5),
		Vector4(4, 4.5, 3, 3), Vector4(0, 3, 3, 3), Vector4(3, 3, 4, 1.5),
		Vector4(4, 1.5, 3, 0), Vector4(3, 0, 0, 0)],
	"C": [
		Vector4(4, 5, 3, 6), Vector4(3, 6, 1, 6), Vector4(1, 6, 0, 5),
		Vector4(0, 5, 0, 1), Vector4(0, 1, 1, 0), Vector4(1, 0, 3, 0),
		Vector4(3, 0, 4, 1)],
	"D": [
		Vector4(0, 0, 0, 6), Vector4(0, 6, 3, 6), Vector4(3, 6, 4, 5),
		Vector4(4, 5, 4, 1), Vector4(4, 1, 3, 0), Vector4(3, 0, 0, 0)],
	"E": [
		Vector4(0, 0, 0, 6), Vector4(0, 6, 4, 6), Vector4(0, 3, 3, 3), Vector4(0, 0, 4, 0)],
	"F": [Vector4(0, 0, 0, 6), Vector4(0, 6, 4, 6), Vector4(0, 3, 3, 3)],
	"G": [
		Vector4(4, 6, 1, 6), Vector4(1, 6, 0, 5), Vector4(0, 5, 0, 1),
		Vector4(0, 1, 1, 0), Vector4(1, 0, 4, 0), Vector4(4, 0, 4, 3),
		Vector4(4, 3, 2, 3)],
	"H": [Vector4(0, 0, 0, 6), Vector4(4, 0, 4, 6), Vector4(0, 3, 4, 3)],
	"I": [Vector4(1, 6, 3, 6), Vector4(2, 6, 2, 0), Vector4(1, 0, 3, 0)],
	"J": [
		Vector4(4, 6, 4, 1), Vector4(4, 1, 3, 0), Vector4(3, 0, 1, 0), Vector4(1, 0, 0, 1)],
	"K": [Vector4(0, 0, 0, 6), Vector4(0, 3, 4, 6), Vector4(0, 3, 4, 0)],
	"L": [Vector4(0, 6, 0, 0), Vector4(0, 0, 4, 0)],
	"M": [
		Vector4(0, 0, 0, 6), Vector4(0, 6, 2, 3), Vector4(2, 3, 4, 6), Vector4(4, 6, 4, 0)],
	"N": [Vector4(0, 0, 0, 6), Vector4(0, 6, 4, 0), Vector4(4, 0, 4, 6)],
	"O": [
		Vector4(0, 1, 0, 5), Vector4(0, 5, 1, 6), Vector4(1, 6, 3, 6),
		Vector4(3, 6, 4, 5), Vector4(4, 5, 4, 1), Vector4(4, 1, 3, 0),
		Vector4(3, 0, 1, 0), Vector4(1, 0, 0, 1)],
	"P": [
		Vector4(0, 0, 0, 6), Vector4(0, 6, 3, 6), Vector4(3, 6, 4, 5),
		Vector4(4, 5, 4, 4), Vector4(4, 4, 3, 3), Vector4(3, 3, 0, 3)],
	"Q": [
		Vector4(0, 1, 0, 5), Vector4(0, 5, 1, 6), Vector4(1, 6, 3, 6),
		Vector4(3, 6, 4, 5), Vector4(4, 5, 4, 1), Vector4(4, 1, 3, 0),
		Vector4(3, 0, 1, 0), Vector4(1, 0, 0, 1), Vector4(2, 2, 4, 0)],
	"R": [
		Vector4(0, 0, 0, 6), Vector4(0, 6, 3, 6), Vector4(3, 6, 4, 5),
		Vector4(4, 5, 4, 4), Vector4(4, 4, 3, 3), Vector4(3, 3, 0, 3),
		Vector4(2, 3, 4, 0)],
	"S": [
		Vector4(4, 5, 3, 6), Vector4(3, 6, 0, 6), Vector4(0, 6, 0, 3),
		Vector4(0, 3, 4, 3), Vector4(4, 3, 4, 0), Vector4(4, 0, 1, 0),
		Vector4(1, 0, 0, 1)],
	"T": [Vector4(0, 6, 4, 6), Vector4(2, 6, 2, 0)],
	"U": [
		Vector4(0, 6, 0, 1), Vector4(0, 1, 1, 0), Vector4(1, 0, 3, 0),
		Vector4(3, 0, 4, 1), Vector4(4, 1, 4, 6)],
	"V": [Vector4(0, 6, 2, 0), Vector4(2, 0, 4, 6)],
	"W": [
		Vector4(0, 6, 1, 0), Vector4(1, 0, 2, 3), Vector4(2, 3, 3, 0), Vector4(3, 0, 4, 6)],
	"X": [Vector4(0, 6, 4, 0), Vector4(0, 0, 4, 6)],
	"Y": [Vector4(0, 6, 2, 3), Vector4(4, 6, 2, 3), Vector4(2, 3, 2, 0)],
	"Z": [Vector4(0, 6, 4, 6), Vector4(4, 6, 0, 0), Vector4(0, 0, 4, 0)],
	"0": [
		Vector4(0, 1, 0, 5), Vector4(0, 5, 1, 6), Vector4(1, 6, 3, 6),
		Vector4(3, 6, 4, 5), Vector4(4, 5, 4, 1), Vector4(4, 1, 3, 0),
		Vector4(3, 0, 1, 0), Vector4(1, 0, 0, 1), Vector4(1, 1, 3, 5)],
	"1": [Vector4(1, 5, 2, 6), Vector4(2, 6, 2, 0), Vector4(1, 0, 3, 0)],
	"2": [
		Vector4(0, 5, 1, 6), Vector4(1, 6, 3, 6), Vector4(3, 6, 4, 5),
		Vector4(4, 5, 4, 4), Vector4(4, 4, 0, 0), Vector4(0, 0, 4, 0)],
	"3": [
		Vector4(0, 6, 4, 6), Vector4(4, 6, 4, 0), Vector4(4, 0, 0, 0), Vector4(1, 3, 4, 3)],
	"4": [Vector4(3, 0, 3, 6), Vector4(3, 6, 0, 2), Vector4(0, 2, 4, 2)],
	"5": [
		Vector4(4, 6, 0, 6), Vector4(0, 6, 0, 3), Vector4(0, 3, 3, 3),
		Vector4(3, 3, 4, 2), Vector4(4, 2, 4, 1), Vector4(4, 1, 3, 0),
		Vector4(3, 0, 0, 0)],
	"6": [
		Vector4(4, 6, 1, 6), Vector4(1, 6, 0, 5), Vector4(0, 5, 0, 0),
		Vector4(0, 0, 4, 0), Vector4(4, 0, 4, 3), Vector4(4, 3, 0, 3)],
	"7": [Vector4(0, 6, 4, 6), Vector4(4, 6, 1, 0)],
	"8": [
		Vector4(0, 0, 0, 6), Vector4(0, 6, 4, 6), Vector4(4, 6, 4, 0),
		Vector4(4, 0, 0, 0), Vector4(0, 3, 4, 3)],
	"9": [
		Vector4(0, 0, 3, 0), Vector4(3, 0, 4, 1), Vector4(4, 1, 4, 6),
		Vector4(4, 6, 0, 6), Vector4(0, 6, 0, 3), Vector4(0, 3, 4, 3)],
	"'": [Vector4(2, 6, 2, 4)],
	"-": [Vector4(1, 3, 3, 3)],
	".": [Vector4(2, 0, 2, 1)],
	" ": [],
}


## Lays `text` out as segments in a width x height box (origin bottom-left, y up). Returns
## {"segs": PackedVector4Array, "unit": float}; unit is one grid unit in box units, which the
## shader uses for the stroke width.
static func layout(text: String, width: float, height: float) -> Dictionary:
	var empty := {"segs": PackedVector4Array(), "unit": 0.0}
	if width <= 0.0 or height <= 0.0:
		return empty
	var upper := text.to_upper()
	var clean := ""
	for i in upper.length():
		var c := upper.substr(i, 1)
		clean += c if GLYPHS.has(c) else " "
	clean = clean.strip_edges()
	if clean.is_empty():
		return empty
	var result := _fit(clean, width, height)
	var warned := false
	while (result["segs"] as PackedVector4Array).size() > MAX_SEGS:
		if not warned:
			push_warning("ArmTattooFont: '%s' needs over %d strokes, cutting it short"
					% [clean, MAX_SEGS])
			warned = true
		clean = clean.substr(0, clean.length() - 1).strip_edges()
		result = _fit(clean, width, height)
	return result


## Copy of `segs` with every endpoint moved by up to `amount` on x and y independently, for a
## hand-poked wobble. The caller passes about 0.15 x the layout's unit.
static func jitter(segs: PackedVector4Array, rng: RandomNumberGenerator,
		amount: float) -> PackedVector4Array:
	var out := PackedVector4Array()
	for s: Vector4 in segs:
		out.append(Vector4(
				s.x + rng.randf_range(-amount, amount), s.y + rng.randf_range(-amount, amount),
				s.z + rng.randf_range(-amount, amount), s.w + rng.randf_range(-amount, amount)))
	return out


## Grid-unit width of one line; the gap after the last glyph is left out so centring is true.
static func _line_w(line: String) -> float:
	return line.length() * (GLYPH_W + GAP) - GAP


## One line if it fills the box height well enough, else the taller of one or two lines.
static func _fit(text: String, width: float, height: float) -> Dictionary:
	var lines: Array[String] = [text]
	var unit := minf(width / _line_w(text), height / GLYPH_H)
	if GLYPH_H * unit < MIN_FILL * height and text.contains(" "):
		var mid := text.length() * 0.5
		var cut := -1
		for i in text.length():
			if text[i] == " " and (cut < 0 or absf(i - mid) < absf(cut - mid)):
				cut = i
		var two: Array[String] = [
			text.substr(0, cut).strip_edges(), text.substr(cut + 1).strip_edges()]
		var widest := maxf(_line_w(two[0]), _line_w(two[1]))
		var two_unit := minf(width / widest, height / (2.0 * GLYPH_H + GAP))
		if two_unit > unit:
			lines = two
			unit = two_unit
	var block_h := (lines.size() * GLYPH_H + (lines.size() - 1) * GAP) * unit
	var y_base := (height - block_h) * 0.5
	var segs := PackedVector4Array()
	for li in lines.size():
		var line := lines[li]
		var ox := (width - _line_w(line) * unit) * 0.5
		var oy := y_base + (lines.size() - 1 - li) * (GLYPH_H + GAP) * unit
		for ci in line.length():
			var strokes: Array = GLYPHS[line[ci]]
			var gx := ox + ci * (GLYPH_W + GAP) * unit
			for s: Vector4 in strokes:
				segs.append(Vector4(
						gx + s.x * unit, oy + s.y * unit, gx + s.z * unit, oy + s.w * unit))
	return {"segs": segs, "unit": unit}
