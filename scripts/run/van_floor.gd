class_name VanFloor
extends Node3D

## Worn cargo-van floor with ribbed decking plus flat floor dressing (mats, paper, tape).

@export var span_x := 4.8
@export var span_z := 9.6
@export var deck_thickness := 0.25
@export var floor_material: Material
@export var rebuild_on_ready := true

var _built := false


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_build()


func _build() -> void:
	if _built:
		return
	_built = true

	var deck_mat := floor_material if floor_material else _default_floor_material()

	var deck := MeshInstance3D.new()
	deck.name = "Deck"
	deck.mesh = _build_deck_mesh()
	deck.material_override = deck_mat
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	deck.position = Vector3(0.0, -deck_thickness * 0.5, 0.0)
	add_child(deck)

	_build_threshold_strips()
	_build_entrance_mats()
	_build_scatter_props()


func _build_deck_mesh() -> ArrayMesh:
	# Thin top slab with UVs in 0..1 mapped to meters via shader floor_size_m.
	# Sides get dark procedural look from the same shader (acceptable for 25cm slab).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx := span_x * 0.5
	var hz := span_z * 0.5
	var y0 := -deck_thickness * 0.5
	var y1 := deck_thickness * 0.5

	# Top face (y = y1), facing up. UV: u across X, v along Z.
	_add_quad(st,
		Vector3(-hx, y1, -hz), Vector2(0.0, 0.0),
		Vector3(hx, y1, -hz), Vector2(1.0, 0.0),
		Vector3(hx, y1, hz), Vector2(1.0, 1.0),
		Vector3(-hx, y1, hz), Vector2(0.0, 1.0)
	)
	# Bottom face
	_add_quad(st,
		Vector3(-hx, y0, hz), Vector2(0.0, 1.0),
		Vector3(hx, y0, hz), Vector2(1.0, 1.0),
		Vector3(hx, y0, -hz), Vector2(1.0, 0.0),
		Vector3(-hx, y0, -hz), Vector2(0.0, 0.0)
	)
	# +X side
	_add_quad(st,
		Vector3(hx, y0, -hz), Vector2(0.0, 0.0),
		Vector3(hx, y0, hz), Vector2(1.0, 0.0),
		Vector3(hx, y1, hz), Vector2(1.0, 1.0),
		Vector3(hx, y1, -hz), Vector2(0.0, 1.0)
	)
	# -X side
	_add_quad(st,
		Vector3(-hx, y0, hz), Vector2(0.0, 0.0),
		Vector3(-hx, y0, -hz), Vector2(1.0, 0.0),
		Vector3(-hx, y1, -hz), Vector2(1.0, 1.0),
		Vector3(-hx, y1, hz), Vector2(0.0, 1.0)
	)
	# +Z side (rear)
	_add_quad(st,
		Vector3(-hx, y0, hz), Vector2(0.0, 0.0),
		Vector3(hx, y0, hz), Vector2(1.0, 0.0),
		Vector3(hx, y1, hz), Vector2(1.0, 1.0),
		Vector3(-hx, y1, hz), Vector2(0.0, 1.0)
	)
	# -Z side (front)
	_add_quad(st,
		Vector3(hx, y0, -hz), Vector2(0.0, 0.0),
		Vector3(-hx, y0, -hz), Vector2(1.0, 0.0),
		Vector3(-hx, y1, -hz), Vector2(1.0, 1.0),
		Vector3(hx, y1, -hz), Vector2(0.0, 1.0)
	)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _add_quad(
	st: SurfaceTool,
	a: Vector3, uva: Vector2,
	b: Vector3, uvb: Vector2,
	c: Vector3, uvc: Vector2,
	d: Vector3, uvd: Vector2
) -> void:
	st.set_uv(uva)
	st.add_vertex(a)
	st.set_uv(uvb)
	st.add_vertex(b)
	st.set_uv(uvc)
	st.add_vertex(c)

	st.set_uv(uva)
	st.add_vertex(a)
	st.set_uv(uvc)
	st.add_vertex(c)
	st.set_uv(uvd)
	st.add_vertex(d)


func _build_threshold_strips() -> void:
	var metal := _metal_mat(Color(0.12, 0.13, 0.125, 1.0), 0.75, 0.42)
	# Rear door sill
	_add_box(
		"RearThreshold",
		Vector3(2.2, 0.03, 0.08),
		Vector3(0.0, 0.015, 4.58),
		metal
	)
	# Cab doorway sill
	_add_box(
		"CabThreshold",
		Vector3(1.45, 0.025, 0.07),
		Vector3(0.0, 0.012, -4.52),
		metal
	)


func _build_entrance_mats() -> void:
	var rear_mat := _rubber_mat(
		Color(0.07, 0.075, 0.07, 1.0),
		Color(0.03, 0.032, 0.03, 1.0),
		16.0
	)
	# Main rear entry mat — just inside the back doors.
	_add_flat(
		"RearEntryMat",
		Vector2(1.55, 0.95),
		Vector3(0.0, 0.004, 3.95),
		0.0,
		rear_mat
	)

	# Left side-door mat (player often enters / fights here).
	var side_mat := _rubber_mat(
		Color(0.1, 0.065, 0.045, 1.0),
		Color(0.045, 0.03, 0.02, 1.0),
		12.0
	)
	_add_flat(
		"LeftSideMat",
		Vector2(0.72, 1.15),
		Vector3(-1.55, 0.004, -3.35),
		8.0,
		side_mat
	)


func _build_scatter_props() -> void:
	# Keep sparse — dressing, not clutter.
	var paper_a := _paper_shader_mat(Color(0.78, 0.74, 0.62, 1.0), 12.0)
	var paper_b := _paper_shader_mat(Color(0.74, 0.72, 0.68, 1.0), 9.0)
	var paper_c := _paper_shader_mat(Color(0.7, 0.64, 0.5, 1.0), 10.0)
	var cardboard := _mat_shader_or_standard(Color(0.42, 0.30, 0.18, 1.0), 0.94, 0.0, false)
	var tape := _mat_shader_or_standard(Color(0.55, 0.48, 0.22, 1.0), 0.55, 0.05, false)
	var rag := _mat_shader_or_standard(Color(0.28, 0.22, 0.18, 1.0), 0.98, 0.0, true)

	_add_flat("PaperReceipt", Vector2(0.18, 0.26), Vector3(-0.85, 0.006, 1.55), 22.0, paper_a)
	_add_flat("PaperNote", Vector2(0.22, 0.16), Vector3(0.55, 0.006, -0.9), -14.0, paper_b)
	_add_flat("PaperFolded", Vector2(0.14, 0.2), Vector3(-1.35, 0.006, 2.6), 41.0, paper_c)
	_add_flat("CardboardScrap", Vector2(0.55, 0.4), Vector3(0.95, 0.005, 2.1), -28.0, cardboard)
	_add_flat("DuctTapeStrip", Vector2(0.42, 0.045), Vector3(-0.2, 0.007, -2.15), 7.0, tape)
	_add_flat("RagScrap", Vector2(0.38, 0.28), Vector3(1.35, 0.005, -1.75), 33.0, rag)

	# Thin oil-stain decals (dark translucent plates).
	var oil := StandardMaterial3D.new()
	oil.albedo_color = Color(0.04, 0.03, 0.02, 0.55)
	oil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	oil.roughness = 0.35
	oil.metallic = 0.15
	oil.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_flat("OilStainA", Vector2(0.55, 0.32), Vector3(-1.7, 0.003, 0.4), 18.0, oil)
	_add_flat("OilStainB", Vector2(0.35, 0.5), Vector3(1.75, 0.003, 3.2), -40.0, oil)


func _add_flat(node_name: String, size: Vector2, pos: Vector3, yaw_deg: float, material: Material) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.orientation = PlaneMesh.FACE_Y

	if material is BaseMaterial3D:
		(material as BaseMaterial3D).render_priority = 1
	elif material is ShaderMaterial:
		(material as ShaderMaterial).render_priority = 1

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = 0.02
	add_child(mi)


func _add_box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = box
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _default_floor_material() -> ShaderMaterial:
	var shader := load("res://scenes/van/van_floor.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", Color(0.11, 0.105, 0.095, 1.0))
	mat.set_shader_parameter("rib_color", Color(0.055, 0.052, 0.048, 1.0))
	mat.set_shader_parameter("wear_color", Color(0.18, 0.165, 0.14, 1.0))
	mat.set_shader_parameter("stain_color", Color(0.035, 0.028, 0.02, 1.0))
	mat.set_shader_parameter("rust_color", Color(0.22, 0.09, 0.04, 1.0))
	mat.set_shader_parameter("floor_size_m", Vector2(span_x, span_z))
	mat.set_shader_parameter("rib_spacing_m", 0.085)
	mat.set_shader_parameter("panel_spacing_m", 1.55)
	mat.set_shader_parameter("roughness_value", 0.88)
	mat.set_shader_parameter("metallic_value", 0.22)
	return mat


func _rubber_mat(base: Color, groove: Color, groove_scale: float) -> ShaderMaterial:
	var shader := load("res://scenes/van/van_floor_mat.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("groove_color", groove)
	mat.set_shader_parameter("edge_color", base.darkened(0.25))
	mat.set_shader_parameter("groove_scale", groove_scale)
	mat.set_shader_parameter("roughness_value", 0.96)
	return mat


func _paper_shader_mat(color: Color, lines: float) -> ShaderMaterial:
	var shader := load("res://scenes/van/van_floor_paper.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("paper_color", color)
	mat.set_shader_parameter("ink_color", Color(0.22, 0.2, 0.16, 1.0))
	mat.set_shader_parameter("line_count", lines)
	mat.set_shader_parameter("roughness_value", 0.92)
	return mat


func _metal_mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _mat_shader_or_standard(color: Color, roughness: float, metallic: float, fabric: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if fabric:
		mat.uv1_scale = Vector3(3.0, 3.0, 3.0)
	return mat
