extends RefCounted
## Cabin side of a rear door leaf: a welded steel skeleton (stile, perimeter, cross-members and a
## frame round the window) whose bays hold a pressed panel with one big access hole, a few small
## holes, rolled flanges and ribs, plus weld beads at the joints. Hinge-local XY, same space as
## rear_door_skin.gd.

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
const BEAD_T := 0.03
## One big rounded access hole in the bay below the cross-member (photo 2): bay index, centre x
## and y as fractions of the bay, half width as a fraction of the bay width, half height and corner
## radius in metres.
const BIG_HOLE: Array = [3, 0.45, 0.5, 0.30, 0.11, 0.11]
## Small round and slot holes around it: bay index, centre fractions, half size and corner radius.
const HOLES: Array[Array] = [
	[3, 0.08, 0.5, 0.07, 0.07, 0.07], [3, 0.89, 0.5, 0.12, 0.045, 0.045],
	[2, 0.55, 0.5, 0.06, 0.06, 0.06], [2, 0.70, 0.5, 0.06, 0.06, 0.06],
]
## Pressed ribs across the bay: bay index, centre fractions, half length and half width (m).
const RIBS: Array[Array] = [[2, 0.72, 0.14, 0.6, 0.0175], [2, 0.72, 0.86, 0.6, 0.0175]]
## Rib crest stands this far in front of the panel face.
const RIB_H := 0.025
## Rolled lip: the flange tip is bevelled in two steps of this much inward and outward.
const ROLL := 0.01


## Adds the skeleton, panels, patch and welds into `st`. `win` is the window hole outline.
static func build(st: SurfaceTool, rect: Rect2, win: PackedVector2Array, z_cab: float,
		z_plate_back: float) -> void:
	var bays := _bays(rect, win)
	var rows: Array[Array] = [BIG_HOLE.duplicate()]
	rows[0][3] = BIG_HOLE[3] * bays[BIG_HOLE[0]].size.x
	rows.append_array(HOLES)
	var holes: Array = []
	for h in rows:
		var bay: Rect2 = bays[h[0]]
		holes.append(_rrect(bay.position + Vector2(bay.size.x * h[1], bay.size.y * h[2]),
				h[3], h[4], h[5]))
	var cuts: Array = [win]
	for bay: Rect2 in bays:
		cuts.append(_Skin._box(bay))
	for poly in _Skin._clip(_Skin._pieces(rect, cuts), _Skin.leaf_outline(rect)):
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
		for i in rows.size():
			if rows[i][0] == b:
				outlines.append(holes[i])
				rings.append(_Skin._ring(holes[i], PANEL_T))
		for poly in _Skin._pieces(bay, outlines):
			_Skin._poly(st, poly, z_pf, Vector3.FORWARD)
		for poly in _Skin._pieces(bay, rings):
			_Skin._poly(st, poly, z_pb, Vector3.BACK)
	for i in holes.size():
		_flange(st, holes[i], z_pf, z_pb, z_fl)
	for r in RIBS:
		var bay: Rect2 = bays[r[0]]
		var c := bay.position + Vector2(bay.size.x * r[1], bay.size.y * r[2])
		_Skin._prism(st, _rrect(c, r[3], r[4], r[4]), z_pf - RIB_H, z_pf)
	_beads(st, bays, z_cab, _Skin.leaf_outline(rect))


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


## Rolled lip: inner wall from the panel front, a bevel in and a bevel out round a narrow crest,
## then the outer wall back to the panel.
static func _flange(st: SurfaceTool, outline: PackedVector2Array, z_pf: float, z_pb: float,
		z_fl: float) -> void:
	var z_a := z_fl - 2.0 * ROLL
	var r1 := _Skin._ring(outline, ROLL)
	var r2 := _Skin._ring(outline, PANEL_T - ROLL)
	var ring := _Skin._ring(outline, PANEL_T)
	_Skin._walls(st, outline, z_pf, z_a, true)
	_Skin._walls(st, ring, z_pb, z_a, false)
	var count := outline.size()
	for k in count:
		var n := (k + 1) % count
		var nm := _Skin._out_normal(outline, outline[k], outline[n])
		var inner := Vector3(-nm.x * 2.0, -nm.y * 2.0, 1.0)
		var outer := Vector3(nm.x * 2.0, nm.y * 2.0, 1.0)
		_quad(st, outline[k], outline[n], r1[n], r1[k], z_a, z_fl, inner)
		_quad(st, r1[k], r1[n], r2[n], r2[k], z_fl, z_fl, Vector3.BACK)
		_quad(st, r2[k], r2[n], ring[n], ring[k], z_fl, z_a, outer)


## A quad between two outline segments at heights `za` (first pair) and `zb` (second pair).
static func _quad(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2, za: float,
		zb: float, out: Vector3) -> void:
	var p := Vector3(a.x, a.y, za)
	var q := Vector3(b.x, b.y, za)
	var r := Vector3(c.x, c.y, zb)
	var t := Vector3(d.x, d.y, zb)
	_Skin._tri(st, p, q, r, out)
	_Skin._tri(st, p, r, t, out)


## Weld beads straddling every bay corner, sizes varied, clipped to `outline`.
static func _beads(st: SurfaceTool, bays: Array[Rect2], z_cab: float,
		outline: PackedVector2Array) -> void:
	var i := 0
	for bay in bays:
		var mid := bay.get_center()
		for corner in [bay.position, Vector2(bay.end.x, bay.position.y), bay.end,
				Vector2(bay.position.x, bay.end.y)]:
			var v: Vector2 = corner
			var away := Vector2(signf(v.x - mid.x), signf(v.y - mid.y))
			var r := 0.032 + 0.004 * float(i % 3)
			var pts := _Skin._oval(v + away * RING_W * 0.5, r, r)
			# Clipped to the rounded leaf outline so none floats past a corner.
			for part in Geometry2D.intersect_polygons(pts, outline):
				_Skin._prism(st, part, z_cab - BEAD_T, z_cab + 0.01)
			i += 1
