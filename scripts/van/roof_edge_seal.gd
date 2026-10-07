extends RefCounted
## Roof edge seal: dark steel strip closing the band between the side skin's top and the roof lip along each long edge.

const _RearDoorLips := preload("res://scripts/van/rear_door_lips.gd")

## How far the strip's outer face stands proud of the roof lip's x.
const OUT_M := 0.02
## How far the strip's inner-bottom corner is sunk into the side skin.
const SINK_M := 0.02
## How far the strip reaches under the roof edge (inward of the lip).
const OVERLAP_M := 0.05
## How far the strip hangs down the side skin's face below the wall top.
const DROP_M := 0.05
## Outer-bottom corner's drop below the wall top (slightly higher than the inner one).
const OUTER_DROP_M := 0.03
## Rise of the outer-top corner above the roof rim.
const RISE_M := 0.02
## Drop of the inner-top corner below the rim, so the top is never parallel to the roof.
const TOP_SLOPE_M := 0.02


static func build(walls: VanSideWall, parent: Node3D) -> void:
	var hinge := walls.get_parent().get_node_or_null(^"RearWall/LeftHinge") as Node3D
	var mat: Material = null
	if hinge != null:
		mat = _RearDoorLips._material(hinge)
	if mat == null:
		mat = walls.door_jamb_material
	if mat == null:
		mat = walls.wall_material
	_add_side(walls, parent, -1.0, &"RoofEdgeSeal_L", mat)
	_add_side(walls, parent, 1.0, &"RoofEdgeSeal_R", mat)


static func _add_side(walls: VanSideWall, parent: Node3D, sign_x: float, node_name: StringName,
		mat: Material) -> void:
	var w := VanHull.skin_outer_x_at(walls, walls.wall_height)
	var rim_y := walls.wall_height + VanHull.SKIN_OFFSET_M
	var z0 := VanInteriorSize.FRONT_Z
	var z1 := VanHull.ROOF_Z_MAX
	var section: Array[Vector2] = [
		Vector2(w - SINK_M, walls.wall_height - DROP_M),
		Vector2(w + OUT_M, walls.wall_height - OUTER_DROP_M),
		Vector2(w + OUT_M, rim_y + RISE_M),
		Vector2(w - OVERLAP_M, rim_y - TOP_SLOPE_M),
	]
	var a: Array[Vector3] = []
	var b: Array[Vector3] = []
	for p in section:
		a.append(Vector3(p.x * sign_x, p.y, z0))
		b.append(Vector3(p.x * sign_x, p.y, z1))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := (a[0] + a[1] + a[2] + a[3] + b[0] + b[1] + b[2] + b[3]) * 0.125
	for i in 4:
		var j := (i + 1) % 4
		var face_n := (a[j] - a[i]).cross(b[i] - a[i]).normalized()
		# Outward means away from the solid's centre, whichever side this is.
		if face_n.dot((a[i] + a[j]) * 0.5 - centre) < 0.0:
			face_n = -face_n
		_quad(st, [a[i], a[j], b[j], b[i]], face_n)
	_quad(st, [a[0], a[1], a[2], a[3]], Vector3(0.0, 0.0, -1.0))
	_quad(st, [b[0], b[1], b[2], b[3]], Vector3(0.0, 0.0, 1.0))
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.layers = 1
	mi.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	parent.add_child(mi)


## Adds a quad (corners in loop order) wound so its front face looks along `n`. The face normal
## from the corner order is checked against `n`, so mirroring cannot flip a face.
static func _quad(st: SurfaceTool, c: Array[Vector3], n: Vector3) -> void:
	var tris := [[0, 1, 2], [0, 2, 3]]
	for t in tris:
		var p: Vector3 = c[t[0]]
		var q: Vector3 = c[t[1]]
		var r: Vector3 = c[t[2]]
		# Front face is clockwise from the viewer: the cross points into the solid.
		if (q - p).cross(r - p).dot(n) > 0.0:
			var tmp := q
			q = r
			r = tmp
		st.set_normal(n)
		st.add_vertex(p)
		st.set_normal(n)
		st.add_vertex(q)
		st.set_normal(n)
		st.add_vertex(r)
