class_name VanBodyProfile
extends RefCounted
## One cross-section for the whole van body: the inner liner outline (floor, bowed sides, roof
## vault) and an outer skin offset from it, so inside and outside pieces sample the same curve.

const WALL_THICKNESS := 0.12  ## horizontal offset from the inner liner to the outer skin
const ROOF_THICKNESS := 0.14  ## vertical offset from the inner vault to the outer roof
const FALLBACK_WALL_HEIGHT := 3.08
const FALLBACK_BOTTOM_HALF := 2.42
const FALLBACK_TOP_HALF := 2.00
const FALLBACK_BOW := 0.18
const FALLBACK_VAULT_EDGE := 3.05
const FALLBACK_VAULT_RISE := 0.38
const FALLBACK_VAULT_HALF := 2.04

var walls: VanSideWall
var ceiling: VanCeiling


func _init(p_walls: VanSideWall = null, p_ceiling: VanCeiling = null) -> void:
	walls = p_walls
	ceiling = p_ceiling


## Builds a profile from an `Interior` node that instances `Shell/SideWalls` and `Shell/Ceiling`.
static func from_interior(interior: Node) -> VanBodyProfile:
	if interior == null:
		return VanBodyProfile.new()
	var side_walls := interior.get_node_or_null(^"Shell/SideWalls") as VanSideWall
	var ceiling_node := interior.get_node_or_null(^"Shell/Ceiling") as VanCeiling
	return VanBodyProfile.new(side_walls, ceiling_node)


func wall_height() -> float:
	if walls != null:
		return walls.wall_height
	return FALLBACK_WALL_HEIGHT


func half_length() -> float:
	if walls != null:
		return walls.span_z * 0.5
	return 4.7


## Inner half-width of the liner at height `y`.
func inner_x_at(y: float) -> float:
	if walls != null:
		return walls.wall_x_at(y)
	var t := clampf(y / FALLBACK_WALL_HEIGHT, 0.0, 1.0)
	var taper := lerpf(FALLBACK_BOTTOM_HALF, FALLBACK_TOP_HALF, t * t)
	return taper + FALLBACK_BOW * sin(PI * t)


## Outer half-width of the skin at height `y`.
func outer_x_at(y: float) -> float:
	return inner_x_at(y) + WALL_THICKNESS


## Inner vault height at lateral `x`, clamped so it never dips below the wall top (no notch).
func roof_y_at(x: float) -> float:
	var v: float
	if ceiling != null:
		v = ceiling.vault_y_at(x)
	else:
		var t := clampf(absf(x) / FALLBACK_VAULT_HALF, 0.0, 1.0)
		v = FALLBACK_VAULT_EDGE + FALLBACK_VAULT_RISE * (1.0 - t * t)
	return maxf(v, wall_height())


## Outer roof height at lateral `x`, stretched to the wider outer wall width.
func outer_roof_y_at(x: float) -> float:
	var h := wall_height()
	var stretch := inner_x_at(h) / outer_x_at(h)
	return roof_y_at(x * stretch) + ROOF_THICKNESS


## Closed CCW outline of the cross-section in the XY plane (no repeated closing point).
func section_points(steps: int, outer: bool = false) -> PackedVector2Array:
	var n := maxi(steps, 4)
	var h := wall_height()
	var pts := PackedVector2Array()
	var xs := func(y: float) -> float: return outer_x_at(y) if outer else inner_x_at(y)
	var ry := func(x: float) -> float: return outer_roof_y_at(x) if outer else roof_y_at(x)

	_append_point(pts, Vector2(-xs.call(0.0), 0.0))
	_append_point(pts, Vector2(xs.call(0.0), 0.0))

	for i in range(1, n + 1):
		var y: float = h * float(i) / float(n)
		_append_point(pts, Vector2(xs.call(y), y))

	var edge_x: float = xs.call(h)
	var first_roof_x: float = edge_x * (1.0 - 2.0 * 1.0 / float(n))
	var first_roof_y: float = ry.call(first_roof_x)
	var wrap_top := first_roof_y > h
	if wrap_top:
		_append_point(pts, Vector2(edge_x, ry.call(edge_x)))
	for i in range(1, n):
		var x: float = edge_x * (1.0 - 2.0 * float(i) / float(n))
		_append_point(pts, Vector2(x, ry.call(x)))
	if wrap_top:
		_append_point(pts, Vector2(-edge_x, ry.call(-edge_x)))

	for i in range(n, 0, -1):
		var y2: float = h * float(i) / float(n)
		_append_point(pts, Vector2(-xs.call(y2), y2))

	return pts


func _append_point(pts: PackedVector2Array, p: Vector2) -> void:
	if pts.size() > 0 and pts[pts.size() - 1].distance_to(p) < 0.001:
		return
	pts.append(p)


## Tunnel lining of an opening through the side wall. `poly` is the opening outline in
## (z_off, y_off) around `center` (Vector2(z, y)), matching VanSideWall's cut-poly convention.
func build_reveal_mesh(
	poly: PackedVector2Array, wall_sign: float, center: Vector2, loop_steps: int = 4
) -> ArrayMesh:
	if poly.size() < 3:
		return ArrayMesh.new()
	var steps := maxi(loop_steps, 1)

	var centroid := Vector2.ZERO
	for p in poly:
		centroid += p
	centroid /= float(poly.size())

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var u := 0.0
	var count := poly.size()
	for i in range(count):
		var a := poly[i]
		var b := poly[(i + 1) % count]
		for s in range(steps):
			var t0 := float(s) / float(steps)
			var t1 := float(s + 1) / float(steps)
			var p0 := a.lerp(b, t0)
			var p1 := a.lerp(b, t1)
			var seg_len := p0.distance_to(p1)
			_emit_reveal_quad(st, wall_sign, center, p0, p1, centroid, u, u + seg_len)
			u += seg_len

	st.generate_tangents()
	return st.commit()


func _emit_reveal_quad(
	st: SurfaceTool,
	wall_sign: float,
	center: Vector2,
	p0: Vector2,
	p1: Vector2,
	centroid: Vector2,
	u0: float,
	u1: float,
) -> void:
	var y0 := center.y + p0.y
	var z0 := center.x + p0.x
	var y1 := center.y + p1.y
	var z1 := center.x + p1.x

	var inner0 := Vector3(wall_sign * inner_x_at(y0), y0, z0)
	var outer0 := Vector3(wall_sign * outer_x_at(y0), y0, z0)
	var inner1 := Vector3(wall_sign * inner_x_at(y1), y1, z1)
	var outer1 := Vector3(wall_sign * outer_x_at(y1), y1, z1)

	var to_centroid := Vector2(centroid.x - (p0.x + p1.x) * 0.5, centroid.y - (p0.y + p1.y) * 0.5)
	var face_normal := (outer0 - inner0).cross(inner1 - inner0)
	var normal_2d := Vector2(face_normal.z, face_normal.y)
	var flip := normal_2d.dot(to_centroid) < 0.0

	var verts := [inner0, outer0, outer1, inner0, outer1, inner1]
	var uvs := [Vector2(u0, 0.0), Vector2(u0, 1.0), Vector2(u1, 1.0),
			Vector2(u0, 0.0), Vector2(u1, 1.0), Vector2(u1, 0.0)]
	if flip:
		verts = [verts[0], verts[2], verts[1], verts[3], verts[5], verts[4]]
		uvs = [uvs[0], uvs[2], uvs[1], uvs[3], uvs[5], uvs[4]]

	var edge0: Vector3 = verts[1] - verts[0]
	var edge1: Vector3 = verts[2] - verts[0]
	var normal := edge0.cross(edge1).normalized()

	for i in range(6):
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])
