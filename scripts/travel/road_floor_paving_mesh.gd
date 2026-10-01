extends RefCounted
## Packs RoadFloor's paving pieces (chamfered blocks) into one ArrayMesh per material.

const SIDE_NEG_X := 1
const SIDE_POS_X := 2
const SIDE_NEG_Z := 4
const SIDE_POS_Z := 8
const SIDE_ALL := 15
const VIS_RANGE_END := 64.0

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()


## Adds a box of `size` centred on its local origin, moved by `xform`. Vertex colour is
## (wreck, tone, up): up is 1 on the top and 0 at the bottom so the shader can grime the base.
func add_block(
		size: Vector3, xform: Transform3D, wreck: float, tone: float, chamfer: float,
		sides: int, with_bottom: bool) -> void:
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var c := clampf(chamfer, 0.0, minf(minf(hx, hz), hy) * 0.9)
	var all_up := Vector4(1.0, 1.0, 1.0, 1.0)
	_quad(Vector3(-hx + c, hy, -hz + c), Vector3(hx - c, hy, -hz + c),
			Vector3(hx - c, hy, hz - c), Vector3(-hx + c, hy, hz - c),
			Vector3.UP, all_up, wreck, tone, xform)
	if c > 0.0:
		var s := sqrt(0.5)
		_quad(Vector3(hx - c, hy, -hz + c), Vector3(hx - c, hy, hz - c),
				Vector3(hx, hy - c, hz), Vector3(hx, hy - c, -hz),
				Vector3(s, s, 0.0), all_up, wreck, tone, xform)
		_quad(Vector3(-hx + c, hy, -hz + c), Vector3(-hx + c, hy, hz - c),
				Vector3(-hx, hy - c, hz), Vector3(-hx, hy - c, -hz),
				Vector3(-s, s, 0.0), all_up, wreck, tone, xform)
		_quad(Vector3(-hx + c, hy, hz - c), Vector3(hx - c, hy, hz - c),
				Vector3(hx, hy - c, hz), Vector3(-hx, hy - c, hz),
				Vector3(0.0, s, s), all_up, wreck, tone, xform)
		_quad(Vector3(-hx + c, hy, -hz + c), Vector3(hx - c, hy, -hz + c),
				Vector3(hx, hy - c, -hz), Vector3(-hx, hy - c, -hz),
				Vector3(0.0, s, -s), all_up, wreck, tone, xform)
	var side_ups := Vector4(0.0, 0.0, 1.0, 1.0)
	var top := hy - c
	if sides & SIDE_POS_X != 0:
		_quad(Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(hx, top, hz),
				Vector3(hx, top, -hz), Vector3.RIGHT, side_ups, wreck, tone, xform)
	if sides & SIDE_NEG_X != 0:
		_quad(Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz), Vector3(-hx, top, hz),
				Vector3(-hx, top, -hz), Vector3.LEFT, side_ups, wreck, tone, xform)
	if sides & SIDE_POS_Z != 0:
		_quad(Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, top, hz),
				Vector3(-hx, top, hz), Vector3.BACK, side_ups, wreck, tone, xform)
	if sides & SIDE_NEG_Z != 0:
		_quad(Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, top, -hz),
				Vector3(-hx, top, -hz), Vector3.FORWARD, side_ups, wreck, tone, xform)
	if with_bottom:
		_quad(Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz),
				Vector3(-hx, -hy, hz), Vector3.DOWN, Vector4.ZERO, wreck, tone, xform)


func is_empty() -> bool:
	return _verts.is_empty()


## Builds one surface from everything added so far, then clears the emitter for reuse.
func commit(parent: Node3D, node_name: String, material: Material) -> MeshInstance3D:
	if _verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.visibility_range_end = VIS_RANGE_END
	parent.add_child(mi)
	_verts = PackedVector3Array()
	_normals = PackedVector3Array()
	_colors = PackedColorArray()
	return mi


## Emits (a, b, c) and (a, c, d). The winding is fixed against the world normal, so every
## face is front-facing (Godot front faces are clockwise) however the corners were listed.
func _quad(
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ups: Vector4,
		wreck: float, tone: float, xform: Transform3D) -> void:
	var n_world := (xform.basis * n).normalized()
	var pts: Array[Vector3] = [xform * a, xform * b, xform * c, xform * d]
	var up_values: Array[float] = [ups.x, ups.y, ups.z, ups.w]
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var i0: int = tri[0]
		var i1: int = tri[1]
		var i2: int = tri[2]
		if (pts[i1] - pts[i0]).cross(pts[i2] - pts[i0]).dot(n_world) > 0.0:
			var swap := i1
			i1 = i2
			i2 = swap
		for i: int in [i0, i1, i2]:
			_verts.append(pts[i])
			_normals.append(n_world)
			_colors.append(Color(wreck, tone, up_values[i]))
