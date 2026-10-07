class_name VanKitRulesPaint
extends RefCounted
## Rules check, paint caps and side openings.

const _BREAK := "VAN KIT RULE BREAK: "
const _KIT_DIR := "res://resources/van/kit/windows/"
const _PATCH_DIR := "res://resources/van_kit/patches/"
const HOLE_MAX_CM := Vector2(128.2, 76.0)
const OPEN_HALF_MIN_CM := Vector2(120.2, 68.7)
const OPEN_HALF_MAX_CM := Vector2(126.2, 74.0)
const HOLE_GROW_CM := 2.0


## Paint lines (info, one per colour) then the break lines.
static func check(dset: VanDonorSet) -> PackedStringArray:
	var out := PackedStringArray()
	for d in dset.donors:
		_paint(String(d.id), d.paint, out)
	_paint("tread_plate", VanKitSkinMesh.TREAD_PAINT, out)
	for file in DirAccess.get_files_at(_KIT_DIR):
		if file.ends_with(".tres"):
			var def := load(_KIT_DIR + file) as VanWindowAssetDef
			if def != null and def.paint != Color(0, 0, 0):
				_paint(String(def.id), def.paint, out)
	_patches(out)
	# TODO: machine-accent clause (>= 0.25 under every accent within 30 deg) once art-3d.md
	# or a resource lists the accents.
	_openings(dset, out)
	return out


## Patch source paints: sign field, sign border and fridge enamel are trims (albedo <= 0.40, no
## rack green); bare steel goes through the wall caps; the car door takes a donor's paint.
static func _patches(out: PackedStringArray) -> void:
	for def in VanKitDefs.load_dir(_PATCH_DIR):
		var patch := def as VanPatchDef
		for pair: Array in [[&"field", patch.field], [&"trim", patch.trim]]:
			var c: Color = pair[1]
			if c == Color(0, 0, 0):
				continue
			var label := "%s_%s" % [patch.id, pair[0]]
			if patch.id == &"sheet_steel" or patch.id == &"chequer_plate":
				_paint(label, c, out)
				continue
			var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			out.append("paint %s: L %.3f S %.2f hue %.0f (trim)" % [label, lum, c.s, c.h * 360.0])
			if lum > 0.40:
				out.append(_BREAK + "paint %s: L %.3f over 0.40" % [label, lum])
			if c.s > 0.10 and c.h * 360.0 >= 97.0 and c.h * 360.0 <= 157.0:
				out.append(_BREAK + "paint %s: hue in 97..157" % label)


static func _paint(label: String, c: Color, out: PackedStringArray) -> void:
	var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var hue := c.h * 360.0
	out.append("paint %s: L %.3f S %.2f hue %.0f" % [label, lum, c.s, hue])
	var grey := c.s <= 0.10
	if c.s > 0.37:
		out.append(_BREAK + "paint %s: S %.2f over 0.37" % [label, c.s])
	if c.s > 0.10 and hue >= 97.0 and hue <= 157.0:
		out.append(_BREAK + "paint %s: hue %.0f in 97..157" % [label, hue])
	if lum > (0.25 if grey else 0.22) or lum < 0.08:
		out.append(_BREAK + "paint %s: L %.3f outside 0.08..%.2f" % [label, lum, 0.25 if grey else 0.22])


static func _openings(dset: VanDonorSet, out: PackedStringArray) -> void:
	for w in dset.windows:
		var opening: PackedVector2Array = w[&"opening"]
		if opening.is_empty():
			continue
		var box := _bounds(opening)
		var half := box.size * 0.5
		var tag := String(w[&"window_id"])
		if half.x < OPEN_HALF_MIN_CM.x - 0.01 or half.y < OPEN_HALF_MIN_CM.y - 0.01 \
				or half.x > OPEN_HALF_MAX_CM.x + 0.01 or half.y > OPEN_HALF_MAX_CM.y + 0.01:
			out.append(_BREAK + "opening %s: half %s outside bounds" % [tag, half])
		if half.x + HOLE_GROW_CM > HOLE_MAX_CM.x + 0.01 or half.y + HOLE_GROW_CM > HOLE_MAX_CM.y + 0.01:
			out.append(_BREAK + "hole %s: half %s over %s" % [tag, half + Vector2.ONE * HOLE_GROW_CM, HOLE_MAX_CM])
		var piece := _bounds(w[&"piece_outline"])
		var zone := VanKitFootprint.PIECE_ZONES[0] if box.get_center().x > 0.0 \
				else VanKitFootprint.PIECE_ZONES[1]
		if piece.position.x < zone.x * 100.0 - 0.01 or piece.end.x > zone.y * 100.0 + 0.01 \
				or piece.position.y < VanKitFootprint.PIECE_Y.x * 100.0 - 0.01 \
				or piece.end.y > VanKitFootprint.PIECE_Y.y * 100.0 + 0.01:
			out.append(_BREAK + "piece %s: outline %s outside the piece zone" % [tag, piece])


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	return box
