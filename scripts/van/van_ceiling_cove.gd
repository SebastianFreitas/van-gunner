extends RefCounted
## Steel cove strips along the ceiling-to-wall join (vangapfix D33).

## Sink of the wall-side back face into the wall, so it clears the side door slide track.
const _SINK := 0.035
## How far the strip runs down the wall and in along the vault from the join.
const _LAP := 0.05
## How far the inboard edge hangs below the vault surface.
const _DROP := 0.045
## How far the strip rises above the vault surface, hiding the seam from above.
const _RISE := 0.02
## Rear end when the rear wall has no hinge node to read.
const _REAR_Z_FALLBACK := 4.547
## Distance from the rear hinge to the door frame face where the strip stops.
const _HINGE_TO_FRAME := 0.163
## The front end is buried this far into the front wall.
const _FRONT_BURY := 0.02

var _ceiling: VanCeiling


func _init(ceiling: VanCeiling) -> void:
	_ceiling = ceiling


func add_coves() -> void:
	for cove_name: StringName in [&"CoveL", &"CoveR"]:
		var old: Node = _ceiling.get_node_or_null(NodePath(cove_name))
		if old != null:
			old.free()
	var shell := _ceiling.get_parent()
	if shell == null:
		return
	var walls := shell.get_node_or_null(^"SideWalls") as VanSideWall
	if walls == null:
		return
	var mat: Material = walls.wall_material
	if mat == null:
		var left := walls.get_node_or_null(^"LeftWall") as MeshInstance3D
		if left != null:
			mat = left.material_override
	var z0 := VanFrontWall.FACE_Z - _FRONT_BURY
	var z1 := _REAR_Z_FALLBACK
	var hinge := shell.get_node_or_null(^"RearWall/LeftHinge") as Node3D
	if hinge != null:
		z1 = hinge.position.z - _HINGE_TO_FRAME
	var section := _section(walls)
	var sides := {&"CoveL": -1.0, &"CoveR": 1.0}
	for cove_name: StringName in sides:
		var s: float = sides[cove_name]
		var node := MeshInstance3D.new()
		node.name = cove_name
		node.mesh = _build_mesh(section, s, z0, z1, walls)
		node.material_override = mat
		node.layers = VanLighting.LAYER_VAN_INTERIOR
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_ceiling.add_child(node)


## Where the wall profile meets the vault, as (|x|, y): a few passes settle the fixed point.
static func join(walls: VanSideWall, ceiling: VanCeiling) -> Vector2:
	var y := ceiling.edge_height
	var x := 0.0
	for i in 4:
		x = walls.wall_x_at(y)
		y = ceiling.vault_y_at(x)
	return Vector2(x, y)


func _section(walls: VanSideWall) -> PackedVector2Array:
	var j := join(walls, _ceiling)
	var yb := j.y - _LAP
	var xt := j.x - _LAP
	var xc := j.x - _SINK
	var pts := PackedVector2Array()
	pts.append(Vector2(walls.wall_x_at(yb) + _SINK, yb))
	pts.append(Vector2(walls.wall_x_at(yb) - _SINK, yb))
	pts.append(Vector2(xc, _ceiling.vault_y_at(xc) - _DROP))
	pts.append(Vector2(xt, _ceiling.vault_y_at(xt) - _DROP))
	pts.append(Vector2(xt, _ceiling.vault_y_at(xt) + _RISE))
	pts.append(Vector2(j.x + _SINK, j.y + _RISE))
	return pts


func _build_mesh(section: PackedVector2Array, s: float, z0: float, z1: float,
		walls: VanSideWall) -> ArrayMesh:
	var inv := _ceiling.transform.affine_inverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var p := section[i]
		var q := section[(i + 1) % 6]
		var out := Vector3(-(q.y - p.y) * s, q.x - p.x, 0.0).normalized()
		var p0 := Vector3(p.x * s, p.y, z0)
		var p1 := Vector3(p.x * s, p.y, z1)
		var q0 := Vector3(q.x * s, q.y, z0)
		var q1 := Vector3(q.x * s, q.y, z1)
		_tri(st, p0, q0, q1, out, walls, inv)
		_tri(st, p0, q1, p1, out, walls, inv)
	var fan := [[2, 3, 4], [2, 4, 5], [2, 5, 0], [2, 0, 1]]
	for cap in 2:
		var z := z0 if cap == 0 else z1
		var out := Vector3(0.0, 0.0, -1.0 if cap == 0 else 1.0)
		for tri: Array in fan:
			var pa := section[tri[0] as int]
			var pb := section[tri[1] as int]
			var pc := section[tri[2] as int]
			_tri(st, Vector3(pa.x * s, pa.y, z), Vector3(pb.x * s, pb.y, z),
				Vector3(pc.x * s, pc.y, z), out, walls, inv)
	st.generate_tangents()
	return st.commit()


## Godot front faces are clockwise seen from outside, so flip any triangle that isn't.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3,
		walls: VanSideWall, inv: Transform3D) -> void:
	var second := b
	var third := c
	if (c - a).cross(b - a).dot(out) < 0.0:
		second = c
		third = b
	_vert(st, a, out, walls, inv)
	_vert(st, second, out, walls, inv)
	_vert(st, third, out, walls, inv)


func _vert(st: SurfaceTool, p: Vector3, out: Vector3, walls: VanSideWall,
		inv: Transform3D) -> void:
	st.set_normal((inv.basis * out).normalized())
	st.set_uv(Vector2((p.z + walls.span_z * 0.5) / walls.span_z,
		clampf(p.y / walls.wall_height, 0.0, 1.0)))
	st.add_vertex(inv * p)
