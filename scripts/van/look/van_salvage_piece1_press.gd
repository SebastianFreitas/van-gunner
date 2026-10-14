extends RefCounted
## Salvage piece 1, pressing: the wall pieces' room faces get the rear door leaf's cabin-face
## treatment (rear_door_skeleton.gd): round-cornered panels recessed into the face, each with a
## flat floor and a flank swept from RearDoorPress.profile. Triangles go out through the wall
## builder's _tri and _quad; a face is (u, v) in metres on its plane, w the recess into the wall.

const _Skeleton := preload("res://scripts/van/rear_door_skeleton.gd")
const _Flange := preload("res://scripts/van/rear_door_flange.gd")
const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const _Surround := preload("res://scripts/van/rear_door_surround.gd")

## Crest rectangles: the post and kick box in (z, y), the head panel's slope in (z, distance up
## the slope from its nose).
const KICK := Rect2(4.97, 0.12, 0.554, 0.76)
const POST_LOW := Rect2(5.664, 0.12, 0.396, 0.76)
const POST_UP := Rect2(5.664, 1.72, 0.396,
		VanInteriorSize.REAR_DOOR_TOP - _Flange.RADIUS_TOP - 0.05 - 1.72)
## The post crests run on to the fillet's first row, stopping this far short of it (a flat strip,
## so no hole touches the sheet edge).
const SEAM_GAP := 0.005
const HEAD := Rect2(4.97, 0.20, 0.554, 0.50)
const NOSE_SEGMENTS := 12

var _o: RefCounted
var _xf := Transform3D.IDENTITY
var _out := Vector3.ZERO


func _init(owner: RefCounted) -> void:
	_o = owner


## Where the post crests stop: just short of the sheet's end, the fillet's first row.
static func crest_end(z_deep: float) -> float:
	return z_deep - _Surround.BEVEL - SEAM_GAP


## `poly` with its vertex `i` replaced by a circular fillet of the door's bottom radius.
func fillet(poly: PackedVector2Array, i: int) -> PackedVector2Array:
	var n := poly.size()
	var c := poly[i]
	var u := (poly[(i + n - 1) % n] - c).normalized()
	var v := (poly[(i + 1) % n] - c).normalized()
	var half := absf(u.angle_to(v)) * 0.5
	var r := _Flange.RADIUS_BOTTOM
	var centre := c + (u + v).normalized() * (r / sin(half))
	var a1 := (c + u * (r / tan(half)) - centre).angle()
	var sweep_a := angle_difference(a1, (c + v * (r / tan(half)) - centre).angle())
	var out := poly.slice(0, i)
	for k in range(NOSE_SEGMENTS + 1):
		var a := a1 + sweep_a * float(k) / float(NOSE_SEGMENTS)
		out.append(centre + Vector2(cos(a), sin(a)) * r)
	out.append_array(poly.slice(i + 1))
	return out


## One pressed sheet on the plane x = `room_x`; `rect` is the face in (z, y), `crests` the
## openings, `extras` boundary vertices the abutting faces already have.
func room_sheet(room_x: float, rect: Rect2, crests: Array,
		extras: PackedVector2Array) -> void:
	_xf = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)),
			Vector3(room_x, 0.0, 0.0))
	_out = Vector3(-1, 0, 0)
	_sheet(rect, crests, extras)


## The head panel's sloped room face, from `lo` to `hi` (its flat run, on the line from `nose`
## to `corner`), z `u0`..`u1`; the recess goes along the face normal into the wall.
func slope_sheet(nose: Vector2, corner: Vector2, lo: Vector2, hi: Vector2, u0: float,
		u1: float) -> void:
	var dir := (corner - nose).normalized()
	var rec := Vector2(dir.y, -dir.x)
	_xf = Transform3D(Basis(Vector3(0, 0, 1), Vector3(dir.x, dir.y, 0.0),
			Vector3(rec.x, rec.y, 0.0)), Vector3(nose.x, nose.y, 0.0))
	_out = Vector3(-rec.x, -rec.y, 0.0)
	var v0 := (lo - nose).dot(dir)
	var v1 := (hi - nose).dot(dir)
	_sheet(Rect2(u0, v0, u1 - u0, v1 - v0), [HEAD], PackedVector2Array())


## The pressed sheets that replace the flat room faces the skip rules left out: lower post and
## kick box up to where the pocket's bevel starts, upper post above it, the head panel's slope.
func press_faces(y_b: float, y_top: float, lo: Vector2, hi: Vector2) -> void:
	var head: PackedVector2Array = _o.head_outline
	var room_x: float = _o.ROOM_X
	var floor_y: float = _o.FLOOR_Y
	var rear_in: float = _o.rear_in_z
	var front_z: float = _o.FRONT_Z
	var pocket_z0: float = _o.pocket_z0
	var pocket_z1: float = _o.pocket_z1
	var z0: float = _o.KICK_Z0 + _Surround.BEVEL
	var sheet_end: float = rear_in - _o.SINK - _Surround.BEVEL
	var c_end := crest_end(rear_in - _o.SINK)
	var post_low := Rect2(POST_LOW.position, Vector2(c_end - POST_LOW.position.x, POST_LOW.size.y))
	var post_up := Rect2(POST_UP.position, Vector2(c_end - POST_UP.position.x, POST_UP.size.y))
	room_sheet(room_x, Rect2(z0, floor_y, sheet_end - z0, y_b - floor_y), [KICK, post_low],
			PackedVector2Array([Vector2(pocket_z0, y_b), Vector2(pocket_z1, y_b),
			Vector2(front_z, y_b), Vector2(front_z, floor_y)]))
	room_sheet(room_x, Rect2(front_z, y_top, sheet_end - front_z, _o.ARC_Y - y_top), [post_up],
			PackedVector2Array([Vector2(pocket_z0, y_top), Vector2(pocket_z1, y_top)]))
	slope_sheet(head[0], head[head.size() - 1], lo, hi, z0, front_z)


## True when every point lies on the head panel's sloped room face.
func on_slope(pts: Array) -> bool:
	var head: PackedVector2Array = _o.head_outline
	var dir: Vector2 = (head[head.size() - 1] - head[0]).normalized()
	return pts.all(func(p: Vector3) -> bool:
			return absf((Vector2(p.x, p.y) - head[0]).cross(dir)) < 0.0001)


func _sheet(rect: Rect2, crests: Array, extras: PackedVector2Array) -> void:
	var slope: float = _Skeleton.BOT_SLOPE
	var holes: Array[PackedVector2Array] = []
	for c: Rect2 in crests:
		var g := c.grow(-slope)
		var foot := RearDoorPress.rounded([g.position, Vector2(g.position.x, g.end.y), g.end,
				Vector2(g.end.x, g.position.y)], _Flange.RADIUS_BOTTOM - slope)
		holes.append(_Skin._ring(foot, slope))
		_panel(foot, slope)
	_crest_face(rect, holes, extras)


## Flank from the foot out to the crest (RearDoorPress.profile) and the flat floor at the foot.
func _panel(foot: PackedVector2Array, slope: float) -> void:
	var prof := RearDoorPress.profile(slope)
	var rings: Array[PackedVector2Array] = []
	for p in prof:
		rings.append(_Skin._ring(foot, p.x))
	var count := foot.size()
	for j in prof.size() - 1:
		for i in count:
			var n := (i + 1) % count
			_o.mesh.quad(_pt(rings[j][i], prof[j].y), _pt(rings[j][n], prof[j].y),
					_pt(rings[j + 1][n], prof[j + 1].y), _pt(rings[j + 1][i], prof[j + 1].y), _out)
	var idx := Geometry2D.triangulate_polygon(foot)
	for k in range(0, idx.size(), 3):
		_o.mesh.tri(_pt(foot[idx[k]], RearDoorPress.DEPTH), _pt(foot[idx[k + 1]], RearDoorPress.DEPTH),
				_pt(foot[idx[k + 2]], RearDoorPress.DEPTH), _out)


## The face rectangle minus the crest outlines as one polygon: each hole is joined to a free
## corner by a zero-width bridge, so the sheet shares the crest's and the edge's vertices.
func _crest_face(rect: Rect2, holes: Array[PackedVector2Array],
		extras: PackedVector2Array) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]
	var loop := PackedVector2Array()
	var corner_at: Array[int] = []
	for k in 4:
		var a := corners[k]
		var b := corners[(k + 1) % 4]
		corner_at.append(loop.size())
		loop.append(a)
		var along: Array[Vector2] = []
		for e in extras:
			if absf((b - a).cross(e - a)) < 0.00001 and (e - a).dot(b - a) > 0.00001 \
					and (e - b).dot(a - b) > 0.00001:
				along.append(e)
		along.sort_custom(func(p: Vector2, q: Vector2) -> bool:
				return p.distance_to(a) < q.distance_to(a))
		loop.append_array(PackedVector2Array(along))
	var picks := {}
	for h in holes:
		var best := -1
		var centre := Vector2.ZERO
		for p in h:
			centre += p / float(h.size())
		for k in corner_at:
			if not picks.has(k) and (best < 0 or loop[k].distance_to(centre)
					< loop[best].distance_to(centre)):
				best = k
		var hole := h.duplicate()
		if _area(hole) > 0.0:
			hole.reverse()
		picks[best] = hole
	var merged := PackedVector2Array()
	for k in loop.size():
		merged.append(loop[k])
		if not picks.has(k):
			continue
		var hole: PackedVector2Array = picks[k]
		var start := 0
		for i in hole.size():
			if hole[i].distance_to(loop[k]) < hole[start].distance_to(loop[k]):
				start = i
		for i in hole.size():
			merged.append(hole[(start + i) % hole.size()])
		merged.append(hole[start])
		merged.append(loop[k])
	var idx := Geometry2D.triangulate_polygon(merged)
	for k in range(0, idx.size(), 3):
		_o.mesh.tri(_pt(merged[idx[k]], 0.0), _pt(merged[idx[k + 1]], 0.0),
				_pt(merged[idx[k + 2]], 0.0), _out)


func _pt(p: Vector2, w: float) -> Vector3:
	return _xf * Vector3(p.x, p.y, w)


func _area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		area += poly[i].cross(poly[(i + 1) % poly.size()])
	return area
