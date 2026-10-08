extends RefCounted
## Cabin side of a rear door leaf: a welded steel skeleton (stile, perimeter, cross-members and a
## frame round the window) whose bays hold a pressed panel with flanged lightening holes, a patch
## plate over one hole and weld beads at the joints. Hinge-local XY, same space as rear_door_skin.gd.

const _Skin := preload("res://scripts/van/rear_door_skin.gd")

## Hinge stile is a heavier section than the rest of the perimeter (redneck: not one beam size).
const STILE_W := 0.14
const BEAM_W := 0.11
const RING_W := 0.09
## Lower cross-member, as a y band above the bottom beam.
const CROSS := Vector2(0.32, 0.44)
## Panel front stands this far behind the beam faces; the panel slab and flange thickness.
const PANEL_DROP := 0.05
const PANEL_T := 0.03
const FLANGE_LEN := 0.05
const PATCH_T := 0.03
const BEAD_T := 0.03
## Lightening holes: bay index, centre x and y as fractions of the bay, half size, corner radius.
const HOLES: Array[Array] = [
	[0, 0.25, 0.5, 0.40, 0.10, 0.07], [0, 0.72, 0.5, 0.38, 0.10, 0.10],
	[1, 0.5, 0.70, 0.07, 0.30, 0.07], [1, 0.5, 0.22, 0.07, 0.22, 0.07],
	[2, 0.28, 0.5, 0.55, 0.12, 0.10], [2, 0.78, 0.5, 0.30, 0.12, 0.12],
	[3, 0.22, 0.5, 0.38, 0.10, 0.10], [3, 0.55, 0.5, 0.30, 0.10, 0.06],
	[3, 0.86, 0.5, 0.17, 0.10, 0.10],
]
## The patch plate covers this lightening hole (index into HOLES) from its centre outward.
const PATCH_HOLE := 5


## Adds the skeleton, panels, patch and welds into `st`. `win` is the window hole outline.
static func build(st: SurfaceTool, rect: Rect2, win: PackedVector2Array, z_cab: float,
		z_plate_back: float) -> void:
	var bays := _bays(rect, win)
	var holes: Array = []
	for h in HOLES:
		var bay: Rect2 = bays[h[0]]
		holes.append(_rrect(bay.position + Vector2(bay.size.x * h[1], bay.size.y * h[2]),
				h[3], h[4], h[5]))
	var cuts: Array = [win]
	for bay: Rect2 in bays:
		cuts.append(_Skin._box(bay))
	for poly in _Skin._pieces(rect, cuts):
		_Skin._poly(st, poly, z_cab, Vector3.FORWARD)
	var z_pf := z_cab + PANEL_DROP
	var z_pb := z_pf + PANEL_T
	var z_fl := z_pb + FLANGE_LEN
	for b in bays.size():
		var bay: Rect2 = bays[b]
		var box := _Skin._box(bay)
		_Skin._walls(st, box, z_cab, z_plate_back, true)
		var outlines: Array = []
		var rings: Array = []
		for i in HOLES.size():
			if HOLES[i][0] == b:
				outlines.append(holes[i])
				rings.append(_Skin._ring(holes[i], PANEL_T))
		for poly in _Skin._pieces(bay, outlines):
			_Skin._poly(st, poly, z_pf, Vector3.FORWARD)
		for poly in _Skin._pieces(bay, rings):
			_Skin._poly(st, poly, z_pb, Vector3.BACK)
	for i in holes.size():
		_flange(st, holes[i], z_pf, z_pb, z_fl)
	# Patch plate welded over the inner half of one hole.
	var ph: PackedVector2Array = holes[PATCH_HOLE]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in ph:
		lo = lo.min(p)
		hi = hi.max(p)
	var pbay: Rect2 = bays[HOLES[PATCH_HOLE][0]]
	var c := (lo + hi) * 0.5
	var patch := Rect2(c.x - 0.09, pbay.position.y + 0.02, hi.x - c.x + 0.16, pbay.size.y - 0.04)
	_Skin._prism(st, _Skin._box(patch), z_pf - PATCH_T, z_pf)
	_beads(st, bays, z_cab)


## The open cells between the beams: top, seam side, two below the window.
static func _bays(rect: Rect2, win: PackedVector2Array) -> Array[Rect2]:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in win:
		lo = lo.min(p)
		hi = hi.max(p)
	var x0 := STILE_W
	var x1 := rect.end.x - BEAM_W
	var ring_hi := hi + Vector2(RING_W, RING_W)
	var ring_lo_y := lo.y - RING_W
	var y_bot := rect.position.y + BEAM_W
	var y_top := rect.end.y - BEAM_W
	var cross_lo := rect.position.y + CROSS.x + BEAM_W
	var cross_hi := rect.position.y + CROSS.y + BEAM_W
	var out: Array[Rect2] = []
	out.append(Rect2(x0, ring_hi.y, x1 - x0, y_top - ring_hi.y))
	out.append(Rect2(ring_hi.x, lo.y + 0.01, x1 - ring_hi.x, ring_hi.y - lo.y - 0.01))
	out.append(Rect2(x0, cross_hi, x1 - x0, ring_lo_y - cross_hi))
	out.append(Rect2(x0, y_bot, x1 - x0, cross_lo - y_bot))
	return out


static func _rrect(c: Vector2, hw: float, hh: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for k in 4:
		var s: Vector2 = corners[k]
		var mid := c + Vector2(s.x * (hw - r), s.y * (hh - r))
		for i in 4:
			var a := PI * 0.5 * (float(k) + float(i) / 3.0)
			pts.append(mid + Vector2(cos(a), sin(a)) * r)
	return pts


## Turned-in lip: inner wall from the panel front, outer wall behind it, flat end cap.
static func _flange(st: SurfaceTool, outline: PackedVector2Array, z_pf: float, z_pb: float,
		z_fl: float) -> void:
	var ring := _Skin._ring(outline, PANEL_T)
	_Skin._walls(st, outline, z_pf, z_fl, true)
	_Skin._walls(st, ring, z_pb, z_fl, false)
	var count := outline.size()
	for k in count:
		var n := (k + 1) % count
		_Skin._quad_xy(st, outline[k], outline[n], ring[n], ring[k], z_fl, Vector3.BACK)


## Weld beads straddling every bay corner, sizes varied.
static func _beads(st: SurfaceTool, bays: Array[Rect2], z_cab: float) -> void:
	var i := 0
	for bay in bays:
		var mid := bay.get_center()
		for corner in [bay.position, Vector2(bay.end.x, bay.position.y), bay.end,
				Vector2(bay.position.x, bay.end.y)]:
			var v: Vector2 = corner
			var away := Vector2(signf(v.x - mid.x), signf(v.y - mid.y))
			var r := 0.032 + 0.004 * float(i % 3)
			var pts := _Skin._oval(v + away * RING_W * 0.5, r, r)
			_Skin._prism(st, pts, z_cab - BEAD_T, z_cab + 0.01)
			i += 1
