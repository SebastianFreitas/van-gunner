extends Node3D

## Sparse garage furniture — sofa and a TV in one corner, empty floor otherwise.

const _INDUSTRIAL_SHADER := preload("res://scenes/corridor/industrial_surface.gdshader")


func _ready() -> void:
	_build()


func _exit_tree() -> void:
	for child in get_children():
		if child is Light3D:
			(child as Light3D).visible = false


func _build() -> void:
	var fabric := _fabric_material()
	var wood := _wood_material()
	var steel := _steel_material()
	var screen := _screen_material()
	var rust := _drum_material()

	# Lounge sits just behind the roll-up; the van docks in the vestibule.
	_build_sofa(fabric, wood, Vector3(5.4, 0.0, -3.15))
	_build_tv(steel, wood, screen, Vector3(5.4, 0.0, -1.05))
	_build_drums(rust, steel, Vector3(6.4, 0.0, 3.35))
	_build_lamps(steel)

	var bay_light := OmniLight3D.new()
	bay_light.name = "BayGlow"
	bay_light.position = Vector3(4.0, 5.1, 0.0)
	bay_light.light_color = Color(0.95, 0.88, 0.7, 1.0)
	bay_light.light_energy = 2.4
	bay_light.omni_range = 12.0
	bay_light.shadow_enabled = false
	add_child(bay_light)

	var back_light := OmniLight3D.new()
	back_light.name = "LoungeGlow"
	back_light.position = Vector3(5.2, 3.8, -1.4)
	back_light.light_color = Color(0.9, 0.78, 0.55, 1.0)
	back_light.light_energy = 1.8
	back_light.omni_range = 8.5
	back_light.shadow_enabled = false
	add_child(back_light)

	var tv_light := OmniLight3D.new()
	tv_light.name = "TvGlow"
	tv_light.position = Vector3(5.4, 1.05, -1.15)
	tv_light.light_color = Color(0.35, 0.55, 0.85, 1.0)
	tv_light.light_energy = 0.85
	tv_light.omni_range = 5.5
	tv_light.shadow_enabled = false
	add_child(tv_light)


func _build_sofa(fabric: Material, wood: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Sofa"
	body.position = origin
	add_child(body)

	_add_box(body, "Seat", Vector3(2.05, 0.38, 0.82), Vector3(0.0, 0.42, 0.0), fabric)
	_add_box(body, "Back", Vector3(2.05, 0.72, 0.16), Vector3(0.0, 0.78, -0.38), fabric)
	_add_box(body, "ArmL", Vector3(0.16, 0.48, 0.82), Vector3(-0.945, 0.58, 0.0), fabric)
	_add_box(body, "ArmR", Vector3(0.16, 0.48, 0.82), Vector3(0.945, 0.58, 0.0), fabric)
	_add_box(body, "Cushion", Vector3(1.55, 0.1, 0.62), Vector3(0.0, 0.64, 0.04), fabric)
	_add_box(body, "LegFL", Vector3(0.08, 0.22, 0.08), Vector3(-0.88, 0.11, 0.32), wood)
	_add_box(body, "LegFR", Vector3(0.08, 0.22, 0.08), Vector3(0.88, 0.11, 0.32), wood)
	_add_box(body, "LegBL", Vector3(0.08, 0.22, 0.08), Vector3(-0.88, 0.11, -0.32), wood)
	_add_box(body, "LegBR", Vector3(0.08, 0.22, 0.08), Vector3(0.88, 0.11, -0.32), wood)
	_add_collision(body, Vector3(2.1, 0.95, 0.88), Vector3(0.0, 0.5, 0.0))


func _build_tv(steel: Material, wood: Material, screen: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Television"
	body.position = origin
	add_child(body)

	_add_box(body, "Crate", Vector3(0.72, 0.42, 0.48), Vector3(0.0, 0.21, 0.0), wood)
	_add_box(body, "Bezel", Vector3(1.18, 0.7, 0.08), Vector3(0.0, 0.82, -0.06), steel)
	_add_box(body, "Screen", Vector3(1.04, 0.56, 0.03), Vector3(0.0, 0.82, -0.01), screen)
	_add_box(body, "Stand", Vector3(0.22, 0.08, 0.18), Vector3(0.0, 0.46, 0.0), steel)
	_add_collision(body, Vector3(1.2, 1.15, 0.52), Vector3(0.0, 0.58, 0.0))


func _build_drums(rust: Material, steel: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Drums"
	body.position = origin
	add_child(body)
	_add_box(body, "DrumA", Vector3(0.52, 0.88, 0.52), Vector3(0.0, 0.44, 0.0), rust)
	_add_box(body, "DrumB", Vector3(0.48, 0.72, 0.48), Vector3(0.62, 0.36, 0.18), rust)
	_add_box(body, "LidA", Vector3(0.54, 0.04, 0.54), Vector3(0.0, 0.9, 0.0), steel)
	_add_collision(body, Vector3(1.2, 0.92, 0.8), Vector3(0.28, 0.46, 0.08))


func _build_lamps(steel: Material) -> void:
	var lamp := _lamp_material()
	for i in 2:
		var z := lerpf(-2.2, 2.2, float(i))
		_add_box(self, "Cage_%d" % i, Vector3(0.42, 0.12, 0.7), Vector3(4.0, 6.85, z), steel)
		_add_box(self, "Bulb_%d" % i, Vector3(0.32, 0.08, 0.55), Vector3(4.0, 6.78, z), lamp)
	_add_box(self, "CageBack", Vector3(0.42, 0.12, 0.7), Vector3(5.2, 6.85, -1.2), steel)
	_add_box(self, "BulbBack", Vector3(0.32, 0.08, 0.55), Vector3(5.2, 6.78, -1.2), lamp)


func _add_box(
	parent: Node3D, node_name: String, size: Vector3, pos: Vector3, material: Material
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi


func _add_collision(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)


func _fabric_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.16, 0.14, 1.0)
	mat.roughness = 0.92
	return mat


func _wood_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.14, 0.08, 1.0)
	mat.roughness = 0.78
	return mat


func _steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.085, 0.08, 1.0)
	mat.metallic = 0.82
	mat.roughness = 0.45
	return mat


func _screen_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.12, 0.22, 0.38, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.32, 0.55, 1.0)
	mat.emission_energy_multiplier = 0.85
	return mat


func _lamp_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.86, 0.68, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.65, 1.0)
	mat.emission_energy_multiplier = 1.4
	return mat


func _drum_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _INDUSTRIAL_SHADER
	mat.set_shader_parameter("base_color", Color(0.28, 0.12, 0.06, 1.0))
	mat.set_shader_parameter("seam_color", Color(0.08, 0.04, 0.02, 1.0))
	mat.set_shader_parameter("rust_color", Color(0.42, 0.16, 0.05, 1.0))
	mat.set_shader_parameter("tile_count", Vector2(3.0, 4.0))
	mat.set_shader_parameter("roughness_value", 0.88)
	return mat
