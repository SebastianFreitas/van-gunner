class_name VanFrontWall
extends StaticBody3D
## The cargo room's cab-end wall as one slab cut from VanBodyProfile's section, with a doorway
## notch that the CabDoor leaf fills, so its edges meet the bowed walls and roof vault exactly.

const FACE_Z := -4.55  ## interior face (the old panels' front face; machines are placed against it)
const BACK_Z := -4.75  ## cab-side face
const DOOR_HALF_W := 0.775
const DOOR_TOP_Y := 2.30
const SECTION_STEPS := 24
const CASING_W := 0.08
const CASING_DEPTH := 0.025


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child_name in ["Slab", "Collision", "CasingLeft", "CasingRight", "CasingHead"]:
		var existing := get_node_or_null(NodePath(child_name))
		if existing != null:
			existing.free()

	var profile := VanBodyProfile.from_interior(get_parent())
	var walls := get_parent().get_node_or_null(^"Shell/SideWalls") as VanSideWall

	var poly := outline(profile)
	var max_x := 0.0
	var max_y := 0.0
	for p in poly:
		max_x = maxf(max_x, absf(p.x))
		max_y = maxf(max_y, p.y)
	var uv_size := Vector2(2.0 * max_x, max_y)

	var slab := MeshInstance3D.new()
	slab.name = "Slab"
	slab.mesh = _build_slab_mesh(poly, uv_size)
	slab.material_override = _wall_material(walls, uv_size)
	slab.layers = VanLighting.LAYER_VAN_INTERIOR
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(slab)

	var collision := CollisionPolygon3D.new()
	collision.name = "Collision"
	collision.polygon = poly
	collision.depth = FACE_Z - BACK_Z
	collision.position = Vector3(0.0, 0.0, (FACE_Z + BACK_Z) * 0.5)
	add_child(collision)

	var trim_mat := _trim_material(walls)
	var casing_z := FACE_Z + CASING_DEPTH * 0.5
	_add_box(
		"CasingLeft",
		Vector3(CASING_W, DOOR_TOP_Y + CASING_W, CASING_DEPTH),
		Vector3(-(DOOR_HALF_W + CASING_W * 0.5), (DOOR_TOP_Y + CASING_W) * 0.5, casing_z),
		trim_mat
	)
	_add_box(
		"CasingRight",
		Vector3(CASING_W, DOOR_TOP_Y + CASING_W, CASING_DEPTH),
		Vector3(DOOR_HALF_W + CASING_W * 0.5, (DOOR_TOP_Y + CASING_W) * 0.5, casing_z),
		trim_mat
	)
	_add_box(
		"CasingHead",
		Vector3(2.0 * DOOR_HALF_W + 2.0 * CASING_W, CASING_W, CASING_DEPTH),
		Vector3(0.0, DOOR_TOP_Y + CASING_W * 0.5, casing_z),
		trim_mat
	)


## The wall outline with a rectangular doorway notch cut into its floor edge.
func outline(profile: VanBodyProfile) -> PackedVector2Array:
	var sec := profile.section_points(SECTION_STEPS)
	if sec.size() < 6:
		push_warning("VanFrontWall: section has too few points for a doorway notch")
		return sec

	var poly := PackedVector2Array()
	poly.append(sec[0])
	poly.append(Vector2(-DOOR_HALF_W, 0.0))
	poly.append(Vector2(-DOOR_HALF_W, DOOR_TOP_Y))
	poly.append(Vector2(DOOR_HALF_W, DOOR_TOP_Y))
	poly.append(Vector2(DOOR_HALF_W, 0.0))
	for i in range(1, sec.size()):
		poly.append(sec[i])
	return poly


## Front and back faces from the outline plus returns lining the doorway notch.
func _build_slab_mesh(poly: PackedVector2Array, uv_size: Vector2) -> ArrayMesh:
	var triangles := Geometry2D.triangulate_polygon(poly)
	if triangles.is_empty():
		push_warning("VanFrontWall: outline failed to triangulate")
		return ArrayMesh.new()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var uv_of := func(p: Vector2) -> Vector2:
		return Vector2(p.x / uv_size.x + 0.5, p.y / uv_size.y)

	for i in range(0, triangles.size(), 3):
		var ia := triangles[i]
		var ib := triangles[i + 1]
		var ic := triangles[i + 2]
		var a := poly[ia]
		var b := poly[ib]
		var c := poly[ic]
		var signed_area := (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
		var front_idx := [ia, ib, ic] if signed_area < 0.0 else [ia, ic, ib]
		var back_idx := [front_idx[0], front_idx[2], front_idx[1]]

		for idx in front_idx:
			st.set_normal(Vector3.BACK)
			st.set_uv(uv_of.call(poly[idx]))
			st.add_vertex(Vector3(poly[idx].x, poly[idx].y, FACE_Z))
		for idx in back_idx:
			st.set_normal(Vector3.FORWARD)
			st.set_uv(uv_of.call(poly[idx]))
			st.add_vertex(Vector3(poly[idx].x, poly[idx].y, BACK_Z))

	# The three notch edges (left jamb, header underside, right jamb): the outer perimeter
	# lies on the side-wall/roof liner and would z-fight, so it gets no return.
	var left_top := Vector3(-DOOR_HALF_W, DOOR_TOP_Y, FACE_Z)
	var left_bottom := Vector3(-DOOR_HALF_W, 0.0, FACE_Z)
	var left_top_back := Vector3(-DOOR_HALF_W, DOOR_TOP_Y, BACK_Z)
	var left_bottom_back := Vector3(-DOOR_HALF_W, 0.0, BACK_Z)
	_add_quad(st, left_bottom, left_top, left_top_back, left_bottom_back, Vector3.RIGHT, _notch_uvs())

	var right_top := Vector3(DOOR_HALF_W, DOOR_TOP_Y, FACE_Z)
	var right_bottom := Vector3(DOOR_HALF_W, 0.0, FACE_Z)
	var right_top_back := Vector3(DOOR_HALF_W, DOOR_TOP_Y, BACK_Z)
	var right_bottom_back := Vector3(DOOR_HALF_W, 0.0, BACK_Z)
	_add_quad(st, right_bottom, right_bottom_back, right_top_back, right_top, Vector3.LEFT, _notch_uvs())

	var head_left := Vector3(-DOOR_HALF_W, DOOR_TOP_Y, FACE_Z)
	var head_right := Vector3(DOOR_HALF_W, DOOR_TOP_Y, FACE_Z)
	var head_left_back := Vector3(-DOOR_HALF_W, DOOR_TOP_Y, BACK_Z)
	var head_right_back := Vector3(DOOR_HALF_W, DOOR_TOP_Y, BACK_Z)
	_add_quad(st, head_left, head_right, head_right_back, head_left_back, Vector3.DOWN, _notch_uvs())

	st.generate_tangents()
	return st.commit()


func _notch_uvs() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])


## Emits one quad as two triangles, flipping winding so the front face is clockwise from `normal`.
func _add_quad(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
	uvs: PackedVector2Array
) -> void:
	var verts := [a, b, c, d]
	var face_normal := (b - a).cross(c - a)
	if face_normal.dot(normal) < 0.0:
		verts.reverse()
		uvs = PackedVector2Array([uvs[3], uvs[2], uvs[1], uvs[0]])

	var order := [0, 1, 2, 0, 2, 3]
	for idx in order:
		st.set_normal(normal)
		st.set_uv(uvs[idx])
		st.add_vertex(verts[idx])


func _wall_material(walls: VanSideWall, uv_size: Vector2) -> Material:
	if walls != null and walls.wall_material is ShaderMaterial:
		var mat := (walls.wall_material as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter("wall_size_m", uv_size)
		return mat
	if walls != null and walls.wall_material != null:
		return walls.wall_material
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.2, 0.21, 0.2)
	fallback.roughness = 0.8
	return fallback


func _trim_material(walls: VanSideWall) -> Material:
	if walls != null and walls.door_jamb_material != null:
		return walls.door_jamb_material
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.08, 0.09, 0.09)
	fallback.metallic = 0.65
	fallback.roughness = 0.4
	return fallback


func _add_box(node_name: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var box := MeshInstance3D.new()
	box.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.position = pos
	box.material_override = mat
	box.layers = VanLighting.LAYER_VAN_INTERIOR
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(box)
