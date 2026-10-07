extends RefCounted
## Fixed steel frame on the cabin side of the rear doors, covering the leaves' clearance slits.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")

## Plate thickness along z.
const PLATE_T := 0.015
## Clearance kept between the frame's street face and the leaves' astragal.
const LEAF_CLEAR := 0.02
## How far the outer edge sinks into the liner, roof and floor.
const OUTER_SINK := 0.02
## How far the inner edge reaches inside the opening.
const INNER_REACH := 0.07
## Points per side run, sill to corner.
const SIDE_POINTS := 17
## Steps across the top run.
const TOP_STEPS := 32


static func build(doors: Node3D, left_hinge: Node3D) -> void:
	if doors == null or left_hinge == null:
		return
	var walls := doors.get_parent().get_node_or_null("SideWalls") as VanSideWall
	var ceiling := doors.get_parent().get_node_or_null("Ceiling") as VanCeiling
	var old := doors.get_node_or_null("Frame")
	if old != null:
		old.free()
	var z_street := left_hinge.position.z - (_LeafBuild.DOOR_THICKNESS * 0.5
			+ _LeafBuild.ASTRAGAL_LIFT + _LeafBuild.ASTRAGAL_T + LEAF_CLEAR)
	var z_cabin := z_street - PLATE_T
	var outer := _outline(walls, ceiling, OUTER_SINK, -OUTER_SINK)
	var inner := _outline(walls, ceiling, -INNER_REACH, INNER_REACH)
	var inv := doors.transform.affine_inverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := outer.size()
	for k in count:
		var n := (k + 1) % count
		var ok := outer[k]
		var on := outer[n]
		var ik := inner[k]
		var inn := inner[n]
		_quad(st, _at(ok, z_street), _at(on, z_street), _at(inn, z_street),
			_at(ik, z_street), Vector3(0.0, 0.0, 1.0), inv)
		_quad(st, _at(ok, z_cabin), _at(on, z_cabin), _at(inn, z_cabin),
			_at(ik, z_cabin), Vector3(0.0, 0.0, -1.0), inv)
		var outer_mid := (ok + on) * 0.5
		var inner_mid := (ik + inn) * 0.5
		var in_dir := _perp(ik, inn, inner_mid - outer_mid)
		_quad(st, _at(ik, z_cabin), _at(inn, z_cabin), _at(inn, z_street),
			_at(ik, z_street), in_dir, inv)
		var out_dir := _perp(ok, on, outer_mid - inner_mid)
		_quad(st, _at(ok, z_cabin), _at(on, z_cabin), _at(on, z_street),
			_at(ok, z_street), out_dir, inv)
	st.generate_tangents()
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = st.commit()
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	frame.layers = VanLighting.LAYER_VAN_INTERIOR
	frame.material_override = _material(left_hinge)
	doors.add_child(frame)


## One ring outline (rig x, y): left side up, across the vault, right side down.
static func _outline(walls: VanSideWall, ceiling: VanCeiling, d: float,
		y_bottom: float) -> PackedVector2Array:
	var cy := 3.0
	var cx := 0.0
	for i in 4:
		cx = VanHullMesh.wall_half(walls, cy, VanInteriorSize.TOP_HALF) + d
		cy = VanHullMesh.vault_y(ceiling, cx, VanInteriorSize.CEILING_EDGE_SHELL, 0.38) + d
	var pts := PackedVector2Array()
	for i in SIDE_POINTS:
		var y := lerpf(y_bottom, cy, float(i) / float(SIDE_POINTS - 1))
		var x := -(VanHullMesh.wall_half(walls, y, VanInteriorSize.TOP_HALF) + d)
		if i == SIDE_POINTS - 1:
			x = -cx
			y = cy
		pts.append(Vector2(x, y))
	for j in range(1, TOP_STEPS):
		var x := lerpf(-cx, cx, float(j) / float(TOP_STEPS))
		pts.append(Vector2(x, VanHullMesh.vault_y(
				ceiling, x, VanInteriorSize.CEILING_EDGE_SHELL, 0.38) + d))
	for i in SIDE_POINTS:
		var y := lerpf(cy, y_bottom, float(i) / float(SIDE_POINTS - 1))
		var x := VanHullMesh.wall_half(walls, y, VanInteriorSize.TOP_HALF) + d
		if i == 0:
			x = cx
			y = cy
		pts.append(Vector2(x, y))
	return pts


static func _at(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)


## In-plane perpendicular of segment a->b, flipped to face along `away`.
static func _perp(a: Vector2, b: Vector2, away: Vector2) -> Vector3:
	var seg := b - a
	var perp := Vector2(seg.y, -seg.x)
	if perp.dot(away) < 0.0:
		perp = -perp
	return Vector3(perp.x, perp.y, 0.0).normalized()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		out: Vector3, inv: Transform3D) -> void:
	_tri(st, a, b, c, out, inv)
	_tri(st, a, c, d, out, inv)


## Godot front faces are clockwise seen from outside, so flip any triangle that isn't.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3,
		inv: Transform3D) -> void:
	var second := b
	var third := c
	if (c - a).cross(b - a).dot(out) < 0.0:
		second = c
		third = b
	_vert(st, a, out, inv)
	_vert(st, second, out, inv)
	_vert(st, third, out, inv)


static func _vert(st: SurfaceTool, p: Vector3, out: Vector3, inv: Transform3D) -> void:
	st.set_normal((inv.basis * out).normalized())
	st.set_uv(Vector2(p.x, p.y))
	st.add_vertex(inv * p)


## The handle mount's steel, else the leaf body's, so the frame matches the doors.
static func _material(left_hinge: Node3D) -> Material:
	var mount := left_hinge.get_node_or_null("Handle/Mount")
	if mount != null:
		var mat := mount.get("material") as Material
		if mat != null:
			return mat
	var body := left_hinge.get_node_or_null("CurvedBody") as GeometryInstance3D
	if body != null:
		return body.material_override
	return null
