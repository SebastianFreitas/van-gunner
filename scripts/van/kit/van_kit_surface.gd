class_name VanKitSurface
extends RefCounted
## Maps an outline in surface cm onto a kit surface as a thin slab that follows the wall's lean
## and the ceiling's vault; leaf surfaces return rear-door hinge-local points.

const LEFT_WALL := &"left_wall"
const RIGHT_WALL := &"right_wall"
const FLOOR := &"floor"
const CEILING := &"ceiling"
const CAB_WALL := &"cab_wall"
const LEFT_LEAF := &"left_leaf"
const RIGHT_LEAF := &"right_leaf"

## Longest strip (m) a poly is cut into across the bend direction (wall y, ceiling x).
const STRIP := 0.25
const _CAB_Z := -4.55
## Doorway notch of the cab-end wall: half width + casing, header + casing (van_front_wall.gd).
const _NOTCH_HALF := 0.855
const _NOTCH_TOP := 2.38
## Rear leaf rig: hinge origin, Panel offset along x, Panel half size, cabin face z in the hinge.
const _HINGE_Y := 1.55
const _HINGE_Z := 4.71
const _HINGE_X := 2.39
const _PANEL_X := 1.19
const _PANEL_HALF := Vector2(1.19, 1.55)
const _FACE_Z := -0.08
## Ceiling barrel as van_shell.tscn sets it on VanCeiling (span_x 4.08, edge_height 3.05, peak_rise).
const _VAULT_HALF_X := 2.04
const _VAULT_EDGE := 3.05
const _VAULT_RISE := 0.38

## The side walls the lean is read from; set by whoever has the rig (VanKitClip.cut does).
static var walls: VanSideWall


static func is_leaf(surface: StringName) -> bool:
	return surface == LEFT_LEAF or surface == RIGHT_LEAF


## Origin of a leaf's hinge in van space (leaf surfaces return points relative to it).
static func hinge_origin(surface: StringName) -> Vector3:
	var sign_x := -1.0 if surface == LEFT_LEAF else 1.0
	return Vector3(sign_x * _HINGE_X, _HINGE_Y, _HINGE_Z)


static func _wall_x(y: float) -> float:
	if walls != null:
		return walls.wall_x_at(y)
	return VanBodyProfile.new().inner_x_at(y)


static func _vault_y(x: float) -> float:
	return _VAULT_EDGE + _VAULT_RISE * (1.0 - minf(x * x / (_VAULT_HALF_X * _VAULT_HALF_X), 1.0))


## The point `depth_m` off the liner at (a, b) cm; a is z on walls, floor and ceiling and x on
## the cab wall and leaves; b is y on walls, cab wall and leaves and x on floor and ceiling.
static func point(surface: StringName, a_cm: float, b_cm: float, depth_m: float) -> Vector3:
	var a := a_cm * 0.01
	var b := b_cm * 0.01
	match surface:
		LEFT_WALL, RIGHT_WALL:
			var sign_x := -1.0 if surface == LEFT_WALL else 1.0
			return Vector3(sign_x * _wall_x(b), b, a) + normal(surface, a_cm, b_cm) * depth_m
		FLOOR:
			return Vector3(b, depth_m, a)
		CEILING:
			return Vector3(b, _vault_y(b), a) + normal(surface, a_cm, b_cm) * depth_m
		CAB_WALL:
			return Vector3(a, b, _CAB_Z + depth_m)
		LEFT_LEAF, RIGHT_LEAF:
			var off := _PANEL_X if surface == LEFT_LEAF else -_PANEL_X
			return Vector3(off + a, b, _FACE_Z - depth_m)
	return Vector3.ZERO


## Unit normal into the cabin (hinge-local on leaves).
static func normal(surface: StringName, _a_cm: float, b_cm: float) -> Vector3:
	var b := b_cm * 0.01
	match surface:
		LEFT_WALL, RIGHT_WALL:
			var sign_x := -1.0 if surface == LEFT_WALL else 1.0
			var dx := (_wall_x(b + 0.02) - _wall_x(b - 0.02)) / 0.04
			return Vector3(-sign_x, dx, 0.0) / sqrt(1.0 + dx * dx)
		FLOOR:
			return Vector3.UP
		CEILING:
			var slope := -2.0 * _VAULT_RISE * b / (_VAULT_HALF_X * _VAULT_HALF_X)
			if absf(b) >= _VAULT_HALF_X:
				slope = 0.0
			return Vector3(slope, -1.0, 0.0) / sqrt(1.0 + slope * slope)
		CAB_WALL:
			return Vector3.BACK
		LEFT_LEAF, RIGHT_LEAF:
			return Vector3.FORWARD
	return Vector3.UP


## Outline (cm) of the cab wall (cab section minus the doorway and its casing) or of a leaf's
## Panel cabin face; empty for the other surfaces.
static func outline(surface: StringName) -> PackedVector2Array:
	if is_leaf(surface):
		var h := _PANEL_HALF * 100.0
		return PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y),
			Vector2(-h.x, h.y)])
	if surface != CAB_WALL:
		return PackedVector2Array()
	var section := VanBodyProfile.new(walls).section_points(24)
	var notch := PackedVector2Array([Vector2(-_NOTCH_HALF, -0.5), Vector2(_NOTCH_HALF, -0.5),
		Vector2(_NOTCH_HALF, _NOTCH_TOP), Vector2(-_NOTCH_HALF, _NOTCH_TOP)])
	var parts := Geometry2D.clip_polygons(section, notch)
	var best := PackedVector2Array()
	for part in parts:
		if Geometry2D.is_polygon_clockwise(part):
			continue
		if part.size() > best.size():
			best = part
	var out := PackedVector2Array()
	for p in best:
		out.append(p * 100.0)
	return out


## A thin slab of `poly_cm`: outer face `depth_m` off the liner, back face `thick_m` behind it.
static func slab(surface: StringName, poly_cm: PackedVector2Array, depth_m: float,
		thick_m: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in _strips(surface, poly_cm):
		_add_piece(st, surface, piece, depth_m, thick_m)
	var mesh := ArrayMesh.new()
	if st.get_primitive_type() != Mesh.PRIMITIVE_TRIANGLES:
		return mesh
	st.commit(mesh)
	return mesh


## `poly` cut into strips of at most STRIP across the bend direction (b on walls and ceiling).
static func _strips(surface: StringName, poly: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var bends := surface == LEFT_WALL or surface == RIGHT_WALL or surface == CEILING
	if not bends or poly.size() < 3:
		out.append(poly)
		return out
	var lo := INF
	var hi := -INF
	var left := INF
	var right := -INF
	for p in poly:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
		left = minf(left, p.x)
		right = maxf(right, p.x)
	var n := maxi(1, ceili((hi - lo) / (STRIP * 100.0)))
	for i in n:
		var y0 := lo + (hi - lo) * i / n
		var y1 := lo + (hi - lo) * (i + 1) / n
		var rect := PackedVector2Array([Vector2(left - 1.0, y0), Vector2(right + 1.0, y0),
			Vector2(right + 1.0, y1), Vector2(left - 1.0, y1)])
		for part in Geometry2D.intersect_polygons(poly, rect):
			if part.size() >= 3 and absf(_area(part)) > 1e-3:
				out.append(part)
	return out


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5


static func _add_piece(st: SurfaceTool, surface: StringName, poly: PackedVector2Array,
		depth: float, thick: float) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	var back := depth - thick
	for i in range(0, tris.size(), 3):
		var ids: Array[int] = [tris[i], tris[i + 1], tris[i + 2]]
		var n := normal(surface, poly[ids[0]].x, poly[ids[0]].y)
		_tri(st, surface, [poly[ids[0]], poly[ids[1]], poly[ids[2]]], depth, n)
		_tri(st, surface, [poly[ids[0]], poly[ids[1]], poly[ids[2]]], back, -n)
	# Side walls: each edge's quad faces away from the polygon interior.
	var ccw := not Geometry2D.is_polygon_clockwise(poly)
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		var edge := p1 - p0
		if edge.length_squared() < 1e-8:
			continue
		var out2 := Vector2(edge.y, -edge.x).normalized() * (1.0 if ccw else -1.0)
		var mid := (p0 + p1) * 0.5
		var out3 := (point(surface, mid.x + out2.x * 0.1, mid.y + out2.y * 0.1, depth)
				- point(surface, mid.x, mid.y, depth)).normalized()
		var o0 := point(surface, p0.x, p0.y, depth)
		var o1 := point(surface, p1.x, p1.y, depth)
		var b0 := point(surface, p0.x, p0.y, back)
		var b1 := point(surface, p1.x, p1.y, back)
		_quad(st, [o0, o1, b1, b0], [p0, p1, p1, p0], out3)


## One triangle of the surface at `depth`, wound clockwise seen along `want`.
static func _tri(st: SurfaceTool, surface: StringName, uv: Array, depth: float,
		want: Vector3) -> void:
	var pts: Array[Vector3] = []
	for p: Vector2 in uv:
		pts.append(point(surface, p.x, p.y, depth))
	var order := [0, 1, 2]
	if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(want) > 0.0:
		order = [0, 2, 1]
	for k: int in order:
		var p: Vector2 = uv[k]
		st.set_normal(want)
		st.set_uv(p * 0.01)
		st.add_vertex(pts[k])


static func _quad(st: SurfaceTool, v: Array[Vector3], uv: Array, want: Vector3) -> void:
	var face := (v[1] - v[0]).cross(v[3] - v[0])
	var tris := [[0, 1, 2], [0, 2, 3]]
	if face.dot(want) > 0.0:
		tris = [[0, 2, 1], [0, 3, 2]]
	for t: Array in tris:
		for k: int in t:
			var p: Vector2 = uv[k]
			st.set_normal(want)
			st.set_uv(p * 0.01)
			st.add_vertex(v[k])
