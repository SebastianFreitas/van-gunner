extends RefCounted
## Cabin side of a rear door leaf: one pressed steel sheet shaped into a frame. Three recessed
## openings (a thin strip under the header, the window, a tall one down to the sill with a notched
## corner) are separated by raised beams whose flanks roll down into them (rear_door_press.gd).
## Hinge-local XY, same space as rear_door_skin.gd.

const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const _Press := preload("res://scripts/van/rear_door_press.gd")

## The recess depth behind the beam crests (window tunnel walls and the panels start here).
const PANEL_DROP := _Press.DEPTH
## Flange thickness of the rolled street lip (`_flange`).
const PANEL_T := 0.03
## Rolled lip: the flange tip is bevelled in two steps of this much inward and outward.
const ROLL := 0.01
## Flank widths (offset from an opening's foot to the beam crest).
const WIN_SLOPE := 0.04
const STRIP_SLOPE := 0.035
const BOT_SLOPE := 0.05
## Raised crest widths: hinge side and seam side (from the opening foot to the leaf edge), the
## header, the bottom edge beam and the beam between the window and the bottom opening.
const HINGE_BEAM := 0.25
const SEAM_BEAM := 0.41
const HEADER_BEAM := 0.095
const BOTTOM_BEAM := 0.15
const MID_BEAM := 0.12
## The strip starts further from the hinge so the top hinge strap sits on the crest.
const STRIP_X0 := 0.5
## The bottom opening's cut corner toward the seam: run along x and drop along y, and its radius.
const NOTCH_RUN := 0.8
const NOTCH_DROP := 0.6
const BOT_ROUND := 0.14
const STRIP_ROUND := 0.09


## Adds the pressed cabin face into `st`. `win` is the window hole outline.
static func build(st: SurfaceTool, rect: Rect2, win: PackedVector2Array, z_cab: float,
		profile: RearDoorProfile) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in win:
		lo = lo.min(p)
		hi = hi.max(p)
	var x1 := rect.end.x - SEAM_BEAM
	var strip_y0 := hi.y + WIN_SLOPE + MID_BEAM * 0.4 + STRIP_SLOPE
	var strip_y1 := rect.end.y - HEADER_BEAM
	var strip := _Press.rounded([Vector2(STRIP_X0, strip_y0), Vector2(STRIP_X0, strip_y1),
			Vector2(x1, strip_y1), Vector2(x1, strip_y0)], STRIP_ROUND)
	var bot_y0 := rect.position.y + BOTTOM_BEAM + BOT_SLOPE
	var bot_y1 := lo.y - WIN_SLOPE - MID_BEAM - BOT_SLOPE
	var bottom := _Press.rounded([Vector2(HINGE_BEAM, bot_y0), Vector2(HINGE_BEAM, bot_y1),
			Vector2(x1 - NOTCH_RUN, bot_y1), Vector2(x1, bot_y1 - NOTCH_DROP),
			Vector2(x1, bot_y0)], BOT_ROUND)
	var openings: Array[PackedVector2Array] = [win, strip, bottom]
	var slopes: Array[float] = [WIN_SLOPE, STRIP_SLOPE, BOT_SLOPE]
	var bays := profile.cabin_openings(rect, win, WIN_SLOPE)
	if not bays.is_empty():
		openings = [win]
		openings.append_array(bays)
		slopes = [WIN_SLOPE]
		for _b in bays:
			slopes.append(RearDoorProfile.BAY_SLOPE)
	# The beam crests are the cabin face; each opening is cut out at the top of its flank.
	var cuts: Array = []
	for i in openings.size():
		cuts.append(_Skin._ring(openings[i], slopes[i]))
	_Skin.tag(st, _Skin.TAG_CABIN)
	for poly in _Skin._clip(_Skin._pieces(rect, cuts), _Skin.leaf_outline(rect, profile)):
		_Skin._poly(st, poly, z_cab, Vector3.FORWARD)
	for i in openings.size():
		_Press.sweep(st, openings[i], slopes[i], z_cab)
		# The window is a hole through the leaf, so only the strip and the bottom have a panel.
		if i > 0:
			_Press.floor_panel(st, openings[i], z_cab)


## Rolled lip: inner wall from the panel front, a bevel in and a bevel out round a narrow crest,
## then the outer wall back to the panel.
static func _flange(st: SurfaceTool, outline: PackedVector2Array, z_pf: float, z_pb: float,
		z_fl: float) -> void:
	var z_a := z_fl - 2.0 * ROLL
	var r1 := _Skin._ring(outline, ROLL)
	var r2 := _Skin._ring(outline, PANEL_T - ROLL)
	var ring := _Skin._ring(outline, PANEL_T)
	_Skin.tag(st, _Skin.TAG_VALLEY)
	_Skin._walls(st, outline, z_pf, z_a, true)
	_Skin.tag(st, _Skin.TAG_EDGE)
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
