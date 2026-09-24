extends Node3D

## Open auto-repair bay — workbench, hoist, tires. No shop counter.

const _INDUSTRIAL_SHADER := preload("res://scenes/corridor/industrial_surface.gdshader")


func _ready() -> void:
	_build()


func _exit_tree() -> void:
	for child in get_children():
		if child is Light3D:
			(child as Light3D).visible = false


func _build() -> void:
	var steel := _steel_material()
	var dirty_steel := _dirty_steel_material()
	var wood := _wood_material()
	var rubber := _rubber_material()
	var rust := _rust_material()
	var oil := _oil_material()
	var lamp := _lamp_material()
	var primer := _primer_material()

	# Packed just behind the roll-up — the van docks in the vestibule.
	_build_back_cabinets(dirty_steel, steel, Vector3(7.35, 0.0, 0.0))
	_build_workbench(wood, dirty_steel, steel, Vector3(6.55, 0.0, 0.0))
	_build_pegboard(dirty_steel, steel, Vector3(7.55, 2.35, 0.0))
	_build_lift_and_car(steel, dirty_steel, primer, rubber, Vector3(4.85, 0.0, 0.0))
	_build_engine_stand(dirty_steel, rust, Vector3(6.1, 0.0, -3.15))
	_build_hoist(steel, dirty_steel, Vector3(5.55, 0.0, 3.15))
	_build_tires(rubber, Vector3(6.35, 0.0, -3.55))
	_build_drums(rust, steel, oil, Vector3(6.45, 0.0, 3.55))
	_build_jack(steel, Vector3(3.85, 0.0, -2.15))
	_build_lamps(lamp, steel)

	var work_light := OmniLight3D.new()
	work_light.name = "WorkGlow"
	work_light.position = Vector3(5.2, 3.6, 0.0)
	work_light.light_color = Color(0.95, 0.82, 0.52, 1.0)
	work_light.light_energy = 2.4
	work_light.omni_range = 10.0
	work_light.shadow_enabled = false
	add_child(work_light)

	var keeper_light := OmniLight3D.new()
	keeper_light.name = "KeeperGlow"
	keeper_light.position = Vector3(4.1, 2.2, 2.45)
	keeper_light.light_color = Color(1.0, 0.88, 0.62, 1.0)
	keeper_light.light_energy = 1.1
	keeper_light.omni_range = 4.5
	keeper_light.shadow_enabled = false
	add_child(keeper_light)

	var spill := OmniLight3D.new()
	spill.name = "OilSpillGlow"
	spill.position = Vector3(4.6, 0.8, -2.2)
	spill.light_color = Color(0.55, 0.32, 0.12, 1.0)
	spill.light_energy = 0.45
	spill.omni_range = 3.2
	spill.shadow_enabled = false
	add_child(spill)


func _build_back_cabinets(dirty_steel: Material, steel: Material, origin: Vector3) -> void:
	# Tall cabinet run against the back wall — same job as the shop hatch wall.
	var body := StaticBody3D.new()
	body.name = "BackCabinets"
	body.position = origin
	add_child(body)
	_add_box(body, "Run", Vector3(0.55, 3.4, 7.6), Vector3(0.0, 1.7, 0.0), dirty_steel)
	_add_box(body, "Counter", Vector3(0.72, 0.08, 7.6), Vector3(-0.08, 1.08, 0.0), steel)
	_add_box(body, "Kick", Vector3(0.5, 0.12, 7.6), Vector3(0.0, 0.06, 0.0), steel)
	for i in 5:
		var z := lerpf(-3.2, 3.2, float(i) / 4.0)
		_add_box(body, "Door_%d" % i, Vector3(0.04, 1.55, 1.15), Vector3(-0.3, 2.05, z), steel)
		_add_box(body, "Handle_%d" % i, Vector3(0.06, 0.22, 0.04), Vector3(-0.34, 2.05, z + 0.42), steel)
	_add_collision(body, Vector3(0.8, 3.45, 7.7), Vector3(0.0, 1.72, 0.0))


func _build_lift_and_car(
	steel: Material, dirty_steel: Material, primer: Material, rubber: Material, origin: Vector3
) -> void:
	var body := StaticBody3D.new()
	body.name = "LiftAndCar"
	body.position = origin
	add_child(body)

	_add_box(body, "PostA", Vector3(0.16, 3.4, 0.16), Vector3(0.55, 1.7, -2.05), steel)
	_add_box(body, "PostB", Vector3(0.16, 3.4, 0.16), Vector3(0.55, 1.7, 2.05), steel)
	_add_box(body, "Cross", Vector3(0.12, 0.12, 4.2), Vector3(0.55, 3.35, 0.0), dirty_steel)
	_add_box(body, "ArmA", Vector3(1.35, 0.08, 0.12), Vector3(-0.12, 1.05, -1.55), steel)
	_add_box(body, "ArmB", Vector3(1.35, 0.08, 0.12), Vector3(-0.12, 1.05, 1.55), steel)
	_add_box(body, "PadA", Vector3(0.22, 0.06, 0.22), Vector3(-0.62, 1.12, -1.55), dirty_steel)
	_add_box(body, "PadB", Vector3(0.22, 0.06, 0.22), Vector3(-0.62, 1.12, 1.55), dirty_steel)

	_add_box(body, "Chassis", Vector3(1.55, 0.22, 3.85), Vector3(-0.15, 1.28, 0.0), dirty_steel)
	_add_box(body, "Body", Vector3(1.62, 0.55, 3.7), Vector3(-0.15, 1.66, 0.0), primer)
	_add_box(body, "Cabin", Vector3(1.48, 0.62, 1.85), Vector3(-0.12, 2.22, -0.15), primer)
	_add_box(body, "Hood", Vector3(1.5, 0.12, 1.05), Vector3(-0.15, 1.98, 1.28), primer)
	_add_box(body, "BumperF", Vector3(1.58, 0.18, 0.12), Vector3(-0.15, 1.42, 1.92), steel)
	_add_box(body, "BumperR", Vector3(1.58, 0.18, 0.12), Vector3(-0.15, 1.42, -1.92), steel)
	_add_box(body, "WheelFL", Vector3(0.28, 0.52, 0.52), Vector3(-0.72, 1.22, 1.35), rubber)
	_add_box(body, "WheelFR", Vector3(0.28, 0.52, 0.52), Vector3(0.42, 1.22, 1.35), rubber)
	_add_box(body, "WheelRL", Vector3(0.28, 0.52, 0.52), Vector3(-0.72, 1.22, -1.35), rubber)
	_add_box(body, "WheelRR", Vector3(0.28, 0.52, 0.52), Vector3(0.42, 1.22, -1.35), rubber)
	_add_collision(body, Vector3(1.9, 2.6, 4.3), Vector3(0.0, 1.5, 0.0))


func _build_workbench(wood: Material, dirty_steel: Material, steel: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Workbench"
	body.position = origin
	add_child(body)

	_add_box(body, "Top", Vector3(1.35, 0.1, 5.4), Vector3(0.0, 0.92, 0.0), wood)
	_add_box(body, "Lip", Vector3(0.12, 0.08, 5.4), Vector3(-0.62, 0.99, 0.0), steel)
	_add_box(body, "Apron", Vector3(1.28, 0.22, 5.3), Vector3(0.0, 0.78, 0.0), dirty_steel)
	for i in 4:
		var z := lerpf(-2.35, 2.35, float(i) / 3.0)
		_add_box(body, "Leg_%d" % i, Vector3(0.1, 0.86, 0.1), Vector3(-0.52, 0.43, z), steel)
		_add_box(body, "LegBack_%d" % i, Vector3(0.1, 0.86, 0.1), Vector3(0.52, 0.43, z), steel)
	_add_box(body, "Shelf", Vector3(1.15, 0.06, 5.1), Vector3(0.0, 0.28, 0.0), dirty_steel)
	_add_box(body, "Vice", Vector3(0.28, 0.16, 0.42), Vector3(-0.42, 1.08, -1.85), steel)
	_add_box(body, "PartsCrate", Vector3(0.55, 0.22, 0.7), Vector3(0.18, 1.08, 1.7), wood)
	_add_collision(body, Vector3(1.4, 1.05, 5.5), Vector3(0.0, 0.52, 0.0))


func _build_pegboard(dirty_steel: Material, steel: Material, origin: Vector3) -> void:
	var body := Node3D.new()
	body.name = "Pegboard"
	body.position = origin
	add_child(body)

	_add_box(body, "Board", Vector3(0.06, 1.85, 4.6), Vector3(0.0, 0.0, 0.0), dirty_steel)
	for i in 6:
		var z := lerpf(-1.9, 1.9, float(i) / 5.0)
		_add_box(body, "Wrench_%d" % i, Vector3(0.04, 0.42, 0.08), Vector3(-0.08, 0.15, z), steel)
	_add_box(body, "Bar", Vector3(0.05, 0.06, 3.8), Vector3(-0.06, -0.72, 0.0), steel)


func _build_engine_stand(dirty_steel: Material, rust: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "EngineStand"
	body.position = origin
	add_child(body)

	_add_box(body, "Base", Vector3(0.95, 0.08, 0.7), Vector3(0.0, 0.04, 0.0), dirty_steel)
	_add_box(body, "Post", Vector3(0.1, 0.7, 0.1), Vector3(0.0, 0.42, 0.0), dirty_steel)
	_add_box(body, "Block", Vector3(0.62, 0.48, 0.42), Vector3(0.0, 0.92, 0.0), rust)
	_add_box(body, "Head", Vector3(0.58, 0.16, 0.38), Vector3(0.0, 1.22, 0.0), rust)
	_add_box(body, "Pan", Vector3(0.5, 0.1, 0.3), Vector3(0.0, 0.64, 0.0), dirty_steel)
	_add_collision(body, Vector3(1.0, 1.3, 0.75), Vector3(0.0, 0.65, 0.0))


func _build_hoist(steel: Material, dirty_steel: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Hoist"
	body.position = origin
	add_child(body)

	_add_box(body, "Mast", Vector3(0.14, 2.6, 0.14), Vector3(0.35, 1.3, 0.0), steel)
	_add_box(body, "Boom", Vector3(1.55, 0.1, 0.1), Vector3(-0.28, 2.42, 0.0), steel)
	_add_box(body, "Brace", Vector3(0.08, 0.9, 0.08), Vector3(0.05, 1.95, 0.0), dirty_steel)
	_add_box(body, "Hook", Vector3(0.08, 0.28, 0.08), Vector3(-0.92, 2.18, 0.0), steel)
	_add_box(body, "BaseLegA", Vector3(1.4, 0.08, 0.1), Vector3(-0.1, 0.04, -0.35), dirty_steel)
	_add_box(body, "BaseLegB", Vector3(1.4, 0.08, 0.1), Vector3(-0.1, 0.04, 0.35), dirty_steel)
	_add_collision(body, Vector3(1.7, 2.6, 0.85), Vector3(-0.1, 1.3, 0.0))


func _build_tires(rubber: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Tires"
	body.position = origin
	add_child(body)
	for i in 3:
		_add_box(
			body,
			"Tire_%d" % i,
			Vector3(0.62, 0.22, 0.62),
			Vector3(0.0, 0.12 + float(i) * 0.23, 0.0),
			rubber
		)
	_add_box(body, "TireLean", Vector3(0.18, 0.72, 0.62), Vector3(0.48, 0.36, 0.12), rubber)
	_add_collision(body, Vector3(0.95, 0.85, 0.75), Vector3(0.15, 0.42, 0.04))


func _build_drums(rust: Material, steel: Material, oil: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Drums"
	body.position = origin
	add_child(body)
	_add_box(body, "DrumA", Vector3(0.52, 0.88, 0.52), Vector3(0.0, 0.44, 0.0), rust)
	_add_box(body, "DrumB", Vector3(0.48, 0.62, 0.48), Vector3(0.58, 0.31, 0.16), rust)
	_add_box(body, "LidA", Vector3(0.54, 0.04, 0.54), Vector3(0.0, 0.9, 0.0), steel)
	_add_box(body, "Puddle", Vector3(0.85, 0.02, 0.7), Vector3(0.15, 0.01, 0.22), oil)
	_add_collision(body, Vector3(1.2, 0.92, 0.85), Vector3(0.28, 0.46, 0.08))


func _build_jack(steel: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "FloorJack"
	body.position = origin
	add_child(body)
	_add_box(body, "Rail", Vector3(0.85, 0.08, 0.28), Vector3(0.0, 0.08, 0.0), steel)
	_add_box(body, "Arm", Vector3(0.45, 0.08, 0.12), Vector3(-0.12, 0.18, 0.0), steel)
	_add_box(body, "Pad", Vector3(0.16, 0.06, 0.16), Vector3(-0.28, 0.24, 0.0), steel)
	_add_collision(body, Vector3(0.9, 0.28, 0.32), Vector3(0.0, 0.14, 0.0))


func _build_lamps(lamp: Material, steel: Material) -> void:
	for i in 2:
		var z := lerpf(-2.1, 2.1, float(i))
		_add_box(self, "Cage_%d" % i, Vector3(0.42, 0.12, 0.7), Vector3(5.2, 6.85, z), steel)
		_add_box(self, "Bulb_%d" % i, Vector3(0.32, 0.08, 0.55), Vector3(5.2, 6.78, z), lamp)


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


func _steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.17, 0.15, 1.0)
	mat.metallic = 0.78
	mat.roughness = 0.52
	return mat


func _dirty_steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.18, 0.12, 1.0)
	mat.metallic = 0.55
	mat.roughness = 0.72
	return mat


func _primer_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.38, 0.16, 1.0)
	mat.roughness = 0.78
	return mat


func _wood_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.16, 0.08, 1.0)
	mat.roughness = 0.86
	return mat


func _rubber_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.06, 0.06, 1.0)
	mat.roughness = 0.95
	return mat


func _oil_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.04, 1.0)
	mat.metallic = 0.35
	mat.roughness = 0.22
	return mat


func _lamp_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.82, 0.52, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.45, 1.0)
	mat.emission_energy_multiplier = 1.6
	return mat


func _rust_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _INDUSTRIAL_SHADER
	mat.set_shader_parameter("base_color", Color(0.32, 0.14, 0.06, 1.0))
	mat.set_shader_parameter("seam_color", Color(0.09, 0.04, 0.02, 1.0))
	mat.set_shader_parameter("rust_color", Color(0.48, 0.18, 0.05, 1.0))
	mat.set_shader_parameter("tile_count", Vector2(3.0, 4.0))
	mat.set_shader_parameter("roughness_value", 0.9)
	return mat
