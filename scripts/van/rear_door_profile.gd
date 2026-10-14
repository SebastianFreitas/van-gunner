class_name RearDoorProfile
extends RefCounted
## One rear leaf's shape and paint: outline, window hole, cabin-face pressed bays, street-face
## relief and shader params. The stock leaf is the original pressed door; the donor leaf (the one
## at x<0) is a bigger, mismatched door cut down to fit the opening, in worn yellow paint.
## Leaf-local XY like rear_door_skin.gd: hinge on x 0, +x toward the centre seam.

const _Press := preload("res://scripts/van/rear_door_press.gd")

## Donor top corner on the hinge side keeps its big rounding; the latch side is cut diagonally.
const DONOR_HINGE_ROUND := 0.45
const DONOR_LATCH_CUT := 0.25
const ARC_STEPS := 12
## The filler plate reaches this far under the body.
const FILLER_OVERLAP := 0.03
## Its straight edges stay this far inside the opening so their walls never share a plane with the collar's.
const FILLER_INSET := 0.02
## Donor bays: crest-to-foot flank width and beam widths (about, from the reference door). The
## bays derive from the leaf rect and the window hole: the vent centres on the window, the molle
## panel spans the leaf, and both keep MOLLE_SIDE_BEAM clear of the leaf's sides.
const BAY_SLOPE := 0.03
const BAY_ROUND := 0.07
const VENT_W := 0.95
const VENT_BEAM_ABOVE := 0.05
const VENT_BEAM_TOP := 0.07
const MOLLE_SIDE_BEAM := 0.25
const MOLLE_BEAM_BELOW := 0.07
const MOLLE_BEAM_BOTTOM := 0.09
## The molle bay is this much narrower per side than its beams allow, so more door paint shows.
const MOLLE_NARROW := 0.07
## Street-face wide bead: half width and height above the leaf bottom as a share of the leaf height.
const WIDE_BEAD_HALF_W := 0.055
const WIDE_BEAD_AT := 1.0 / 3.0
## Donor window: a tall convex shape (reference Sprinter door). Half size of its bounding box, how
## far the latch-side edge leans in at the top, corner radii and curve steps per corner.
const DONOR_WIN_HALF := Vector2(0.65, 0.75)
const DONOR_WIN_LEAN := 0.12
const DONOR_WIN_TOP_R := 0.30
const DONOR_WIN_BOTTOM_R := 0.12
const DONOR_WIN_TOP_STEPS := 6
const DONOR_WIN_BOTTOM_STEPS := 3

var _donor := false
## Window hole outline, offsets from the window centre. Set by the leaf builder, which owns it.
var window_hole := PackedVector2Array()
var paint_color := Color(0.17, 0.19, 0.185)
var paint_coverage := 0.5
var paint_island_scale := 1.8
var leaf_offset := Vector2.ZERO
var roughness := 0.86
var metallic := 0.22
## Share of the rust base and streaks kept, and whether the cabin face is painted like the street.
var rust_amount := 1.0
var cabin_paint := 0.0
## Leaf-local x band of the cabin face painted solid (the seam-side crest); off when x1 <= x0.
var crest_paint_x0 := 0.0
var crest_paint_x1 := 0.0


## The original leaf: 18 cm corners, three pressed openings, swage beads and window doubler.
static func stock() -> RearDoorProfile:
	var p := RearDoorProfile.new()
	p.leaf_offset = Vector2(37.3, 11.7)
	return p


## The mismatched donor door: big hinge rounding, diagonal latch cut, two big bays, wide bead,
## utility-yellow paint, mostly intact, over little rust.
static func donor() -> RearDoorProfile:
	var p := RearDoorProfile.new()
	p._donor = true
	# Old faded mustard, washed out and grimy (saturated colour is for lights), luminance
	# about 0.12 linear.
	p.paint_color = Color(0.42, 0.38, 0.22)
	p.paint_coverage = 0.80
	p.rust_amount = 0.45
	p.cabin_paint = 1.0
	# 2.09 not 2.278: the seam edge fade (edge_d 0.2..0.6) is only solid from there.
	p.crest_paint_x0 = 2.09
	p.crest_paint_x1 = 2.48
	p.paint_island_scale = 1.3
	p.leaf_offset = Vector2(91.7, 23.1)
	p.window_hole = _donor_window()
	p.roughness = 0.84
	p.metallic = 0.18
	return p


func is_donor() -> bool:
	return _donor


## Bounding rect of the window hole (offsets from the window centre).
func window_bounds() -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in window_hole:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)


## The leaf outline counter-clockwise inside `r`, or empty for the stock one (rear_door_skin.gd
## builds that from its own corner radii). The donor's hinge side is the flame cut: vertices 0-3
## are bottom-hinge, bottom-latch, latch-top and the diagonal's end, then the top corner and the
## cut down to vertex 0.
func outline(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not _donor:
		return pts
	var cut := donor_cut(r)
	pts.append(cut[3])
	pts.append(Vector2(r.end.x, r.position.y))
	pts.append(Vector2(r.end.x, r.end.y - DONOR_LATCH_CUT))
	pts.append(Vector2(r.end.x - DONOR_LATCH_CUT, r.end.y))
	pts.append_array(cut.slice(0, 3))
	return pts


## The donor's pre-cut shape (the big hinge rounding): what collision and interaction cover.
func footprint(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not _donor:
		return pts
	pts.append(r.position)
	pts.append(Vector2(r.end.x, r.position.y))
	pts.append(Vector2(r.end.x, r.end.y - DONOR_LATCH_CUT))
	pts.append(Vector2(r.end.x - DONOR_LATCH_CUT, r.end.y))
	pts.append_array(_hinge_arc(r, DONOR_HINGE_ROUND, PI * 0.5, PI))
	return pts


## Where the flame cut changes direction: the window hole's bottom less 0.10 (hole centre is
## REAR_DOOR_TOP - REAR_WINDOW_Y below the leaf top).
func donor_split_y(r: Rect2) -> float:
	var centre_y := r.end.y - (VanInteriorSize.REAR_DOOR_TOP - VanOpenings.REAR_WINDOW_Y)
	return centre_y + window_bounds().position.y - 0.10


## The flame cut, top to bottom: slanting in under the top, then a near-vertical run to the floor.
func donor_cut(r: Rect2) -> PackedVector2Array:
	var split_y := donor_split_y(r)
	var x := r.position.x
	return PackedVector2Array([Vector2(x + 0.52, r.end.y), Vector2(x + 0.46, split_y),
			Vector2(x + 0.42, split_y - 0.06), Vector2(x + 0.42, r.position.y)])


## The cut's x at height `y` (the stock leaf has none: the hinge edge). It only grows with y.
func cut_x(r: Rect2, y: float) -> float:
	if not _donor:
		return r.position.x
	var cut := donor_cut(r)
	for i in cut.size() - 1:
		if y >= cut[i + 1].y:
			var t := clampf((cut[i].y - y) / (cut[i].y - cut[i + 1].y), 0.0, 1.0)
			return lerpf(cut[i].x, cut[i + 1].x, t)
	return cut[3].x


## The flat strip behind the cut, 0.03 inboard of it and never across it. Empty for the stock leaf.
func filler(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not _donor:
		return pts
	var cut := donor_cut(r)
	cut[0].y -= FILLER_INSET
	cut[3].y += FILLER_INSET
	for p in cut:
		pts.append(p + Vector2(FILLER_OVERLAP, 0.0))
	for i in range(cut.size() - 1, -1, -1):
		pts.append(cut[i] + Vector2(FILLER_OVERLAP + 0.02, 0.0))
	return pts


## The cabin face's pressed openings other than the window (empty: the stock layout of
## rear_door_skeleton.gd). `win` is the window hole in leaf space, `win_slope` its flank width. Each is a foot outline whose
## crest cut is BAY_SLOPE wider.
func cabin_openings(r: Rect2, win: PackedVector2Array, win_slope: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if not _donor:
		return out
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in win:
		lo = lo.min(p)
		hi = hi.max(p)
	var vent_y0 := hi.y + win_slope + VENT_BEAM_ABOVE + BAY_SLOPE
	var vent_y1 := r.end.y - VENT_BEAM_TOP - BAY_SLOPE
	var vent_cx := (lo.x + hi.x) * 0.5
	var vent_w := minf(VENT_W, 2.0 * minf(vent_cx - r.position.x - MOLLE_SIDE_BEAM,
			r.end.x - MOLLE_SIDE_BEAM - vent_cx))
	var vx0 := vent_cx - vent_w * 0.5
	var vx1 := vent_cx + vent_w * 0.5
	out.append(_Press.rounded([Vector2(vx0, vent_y0), Vector2(vx0, vent_y1),
			Vector2(vx1, vent_y1), Vector2(vx1, vent_y0)], BAY_ROUND))
	var molle_y0 := r.position.y + MOLLE_BEAM_BOTTOM + BAY_SLOPE
	var molle_y1 := lo.y - win_slope - MOLLE_BEAM_BELOW - BAY_SLOPE
	var mx0 := maxf(r.position.x + MOLLE_SIDE_BEAM, cut_x(r, molle_y1 + BAY_SLOPE) + 0.06) + MOLLE_NARROW
	var mx1 := r.end.x - MOLLE_SIDE_BEAM - MOLLE_NARROW
	out.append(_Press.rounded([Vector2(mx0, molle_y0), Vector2(mx0, molle_y1),
			Vector2(mx1, molle_y1), Vector2(mx1, molle_y0)], BAY_ROUND))
	return out


## True when the street face takes one wide bead and no doubler ring or stock swage beads.
func wide_street_bead() -> bool:
	return _donor


## The donor window: straight hinge-side edge (-x) and bottom, latch-side edge leaning in at the
## top, big top corners and small bottom ones. Same winding as the stock hole.
static func _donor_window() -> PackedVector2Array:
	var h := DONOR_WIN_HALF
	var corners: Array[Vector2] = [Vector2(-h.x, -h.y), Vector2(-h.x, h.y),
			Vector2(h.x - DONOR_WIN_LEAN, h.y), Vector2(h.x, -h.y)]
	var radii: Array[float] = [DONOR_WIN_BOTTOM_R, DONOR_WIN_TOP_R, DONOR_WIN_TOP_R,
			DONOR_WIN_BOTTOM_R]
	var steps: Array[int] = [DONOR_WIN_BOTTOM_STEPS, DONOR_WIN_TOP_STEPS, DONOR_WIN_TOP_STEPS,
			DONOR_WIN_BOTTOM_STEPS]
	var pts := PackedVector2Array()
	for i in corners.size():
		var c := corners[i]
		var u := (corners[(i + corners.size() - 1) % corners.size()] - c).normalized()
		var v := (corners[(i + 1) % corners.size()] - c).normalized()
		var half_angle := absf(u.angle_to(v)) * 0.5
		var centre := c + (u + v).normalized() * (radii[i] / sin(half_angle))
		var a1 := ((c + u * (radii[i] / tan(half_angle))) - centre).angle()
		var sweep := angle_difference(a1, ((c + v * (radii[i] / tan(half_angle))) - centre).angle())
		for k in steps[i] + 1:
			var a := a1 + sweep * float(k) / float(steps[i])
			pts.append(centre + Vector2(cos(a), sin(a)) * radii[i])
	return pts


## Arc about the hinge-side top corner of `r` from angle `a0` to `a1`, radius `rad` (centre
## `HINGE_ROUND` in from the corner, as the outline's own rounding).
func _hinge_arc(r: Rect2, rad: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var mid := Vector2(r.position.x + DONOR_HINGE_ROUND, r.end.y - DONOR_HINGE_ROUND)
	for i in ARC_STEPS + 1:
		var a := lerpf(a0, a1, float(i) / float(ARC_STEPS))
		pts.append(mid + Vector2(cos(a), sin(a)) * rad)
	return pts
