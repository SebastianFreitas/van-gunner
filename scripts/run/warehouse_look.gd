class_name WarehouseLook
extends RefCounted

## Shared palette / mesh helpers for the warehouse bay and its hide layouts.

const MOUTH_WIDTH := 8.6
const ROOM_START_X := 0.0
const BACK_X := 20.0
const ROOM_DEPTH := 20.0
const ROOM_WIDTH := 12.0
const HALF_MOUTH := MOUTH_WIDTH * 0.5
const HALF_ROOM := 6.0
const HEIGHT := 8.0
const FLOOR_Y := -0.3
const CEILING_Y := 7.8
const TABLE := Vector3(10.0, 0.0, 0.0)
const INDUSTRIAL_SHADER := preload("res://scenes/corridor/industrial_surface.gdshader")


static func add_box(
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


static func add_collision(body: CollisionObject3D, size: Vector3, pos: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)
	return col


static func tarp_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.38, 0.3, 1.0)
	mat.roughness = 0.94
	return mat


static func tarp_dark_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.26, 0.22, 1.0)
	mat.roughness = 0.92
	return mat


static func canvas_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.5, 0.4, 1.0)
	mat.roughness = 0.9
	return mat


static func wood_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.15, 0.08, 1.0)
	mat.roughness = 0.8
	return mat


static func crate_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.22, 0.12, 1.0)
	mat.roughness = 0.84
	return mat


static func rope_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.36, 0.22, 1.0)
	mat.roughness = 0.88
	return mat


static func steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.095, 1.0)
	mat.metallic = 0.78
	mat.roughness = 0.5
	return mat


static func dust_floor_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = INDUSTRIAL_SHADER
	mat.set_shader_parameter("base_color", Color(0.18, 0.16, 0.13, 1.0))
	mat.set_shader_parameter("seam_color", Color(0.05, 0.045, 0.035, 1.0))
	mat.set_shader_parameter("rust_color", Color(0.3, 0.14, 0.05, 1.0))
	mat.set_shader_parameter("tile_count", Vector2(12.0, 8.0))
	mat.set_shader_parameter("roughness_value", 0.96)
	return mat


static func plaster_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = INDUSTRIAL_SHADER
	mat.set_shader_parameter("base_color", Color(0.22, 0.2, 0.16, 1.0))
	mat.set_shader_parameter("seam_color", Color(0.08, 0.07, 0.05, 1.0))
	mat.set_shader_parameter("rust_color", Color(0.28, 0.12, 0.05, 1.0))
	mat.set_shader_parameter("tile_count", Vector2(8.0, 2.0))
	mat.set_shader_parameter("roughness_value", 0.9)
	return mat


static func rib_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.065, 0.055, 1.0)
	mat.metallic = 0.5
	mat.roughness = 0.74
	return mat


static func lamp_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.82, 0.55, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.88, 0.55, 1.0)
	mat.emission_energy_multiplier = 1.3
	return mat


static func laser_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.18, 0.14, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.12, 1.0)
	mat.emission_energy_multiplier = 2.4
	return mat
