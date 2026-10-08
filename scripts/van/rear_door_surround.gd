extends RefCounted
## Rear door surround: the 2D outlines of the deep pressed-steel frame around the door opening. A
## deep ring (DEPTH into the cabin) hugs the opening, a shallower ledge steps it back out to the
## side walls and roof, and a thin collar closes the strip under the flange band.

const _Flange := preload("res://scripts/van/rear_door_flange.gd")
## How far the deep ring stands out from the portal's cabin face (the one frame depth).
const DEPTH := 0.3
## How far the wall ledge stands out around the deep ring.
const LEDGE_DEPTH := 0.2
## Width of the deep ring beyond the flange band's outer edge.
const RING_W := 0.16
## Collar: from this far outside the opening edge to the flange band's outer edge.
const COLLAR_FROM := 0.03
## Pillar pocket: y range, x range as offsets from the door edge, and how deep it is stamped.
const POCKET_Y0 := 1.0
const POCKET_Y1 := 1.6
const POCKET_X0 := 0.185
const POCKET_X1 := 0.235
const POCKET_DEPTH := 0.12
## The ramp's inner edge stands this far outside the door opening, level with the leaves' cabin face.
const RAMP_IN := 0.015
## Where the ramp reaches the deep face, as an offset from the opening.
const RAMP_OUT := 0.13
## Bevel on every crease (trim along each side) and its arc segments.
const BEVEL := 0.03
const BEVEL_STEPS := 4
## The header (and so the collar below it) starts this far above the opening's top.
const HEADER_GAP := 0.01


## Outlines in xy. `deep` and `pocket` are right-hand pieces (mirror for the left), `ledge` and
## `collar` are whole. `pocket` is the stamped floor inside `deep`'s cut-out.
static func zones(section: PackedVector2Array, half: float, top: float,
		y_a: float) -> Dictionary:
	var above := _rect(-9.0, 9.0, y_a, 9.0)
	var body: PackedVector2Array = Geometry2D.intersect_polygons(section, above)[0]
	var band := _opening(half, top, _Flange.WALL_OFFSET)
	var ring_o := _Flange.WALL_OFFSET + RING_W
	# The flat deep face lies between the two bevels; the ledge starts past the outer bevel.
	var ring := _opening(half, top, ring_o - BEVEL - 0.003)
	var ring_out := _opening(half, top, ring_o + BEVEL)
	# The deep face stops about 2 cm short of the liner (the body is padded 3 cm into it), so it
	# never lies within 1 cm of the side wall's face yet leaves no visible gap.
	var ring_in := Geometry2D.intersect_polygons(ring, Geometry2D.offset_polygon(body, -0.05)[0])[0]
	var deep_in := _opening(half, top, RAMP_OUT + BEVEL)
	var collar: Array[PackedVector2Array] = []
	var low := _rect(-9.0, 9.0, y_a, top + HEADER_GAP)
	for p in Geometry2D.clip_polygons(band, _opening(half, top, COLLAR_FROM)):
		collar.append_array(Geometry2D.intersect_polygons(p, low))
	var ledge: Array[PackedVector2Array] = []
	var deep_all: Array[PackedVector2Array] = []
	for p in Geometry2D.clip_polygons(body, band):
		ledge.append_array(Geometry2D.clip_polygons(p, ring_out))
		for q in Geometry2D.clip_polygons(p, deep_in):
			deep_all.append_array(Geometry2D.intersect_polygons(q, ring_in))
	var deep: Array[PackedVector2Array] = []
	var pocket: Array[PackedVector2Array] = []
	var xa := half + POCKET_X0
	var xb := half + POCKET_X1
	for p in deep_all:
		for right in Geometry2D.intersect_polygons(p, _rect(0.0, 9.0, -9.0, 9.0)):
			for r in [_rect(-9.0, 9.0, -9.0, POCKET_Y0), _rect(-9.0, 9.0, POCKET_Y1, 9.0),
					_rect(-9.0, xa, POCKET_Y0, POCKET_Y1), _rect(xb, 9.0, POCKET_Y0, POCKET_Y1)]:
				deep.append_array(Geometry2D.intersect_polygons(right, r))
			pocket.append_array(Geometry2D.intersect_polygons(
					right, _rect(xa, xb, POCKET_Y0, POCKET_Y1)))
	return {"deep": deep, "pocket": pocket, "ledge": ledge, "collar": collar}


## The opening pushed out by `o`, round at the top (the leaves' corner radius plus `o`) and open
## below the floor, as a closed outline.
static func _opening(half: float, top: float, o: float) -> PackedVector2Array:
	var r := _Flange.RADIUS_TOP
	var pts := PackedVector2Array([Vector2(-(half + o), -1.0)])
	for k in range(_Flange.ARC_STEPS + 1):
		var a := PI - PI * 0.5 * float(k) / float(_Flange.ARC_STEPS)
		pts.append(Vector2(-(half - r) + (r + o) * cos(a), top - r + (r + o) * sin(a)))
	for k in range(_Flange.ARC_STEPS + 1):
		var a2 := PI * 0.5 - PI * 0.5 * float(k) / float(_Flange.ARC_STEPS)
		pts.append(Vector2(half - r + (r + o) * cos(a2), top - r + (r + o) * sin(a2)))
	pts.append(Vector2(half + o, -1.0))
	return pts


static func _rect(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
