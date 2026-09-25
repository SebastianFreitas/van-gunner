extends RefCounted

## Material factories for the shop counter booth — each call returns a fresh instance.

const _INDUSTRIAL_SHADER := preload("res://scenes/corridor/industrial_surface.gdshader")


static func steel_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _INDUSTRIAL_SHADER
	mat.set_shader_parameter("base_color", Color(0.11, 0.115, 0.11, 1.0))
	mat.set_shader_parameter("seam_color", Color(0.03, 0.032, 0.03, 1.0))
	mat.set_shader_parameter("rust_color", Color(0.26, 0.1, 0.045, 1.0))
	mat.set_shader_parameter("panel_size_m", Vector2(2.4, 2.4))
	mat.set_shader_parameter("roughness_value", 0.82)
	mat.set_shader_parameter("metallic_value", 0.28)
	mat.set_shader_parameter("grime", 0.55)
	return mat


static func deck_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _INDUSTRIAL_SHADER
	mat.set_shader_parameter("base_color", Color(0.16, 0.155, 0.14, 1.0))
	mat.set_shader_parameter("seam_color", Color(0.04, 0.04, 0.035, 1.0))
	mat.set_shader_parameter("rust_color", Color(0.28, 0.11, 0.05, 1.0))
	mat.set_shader_parameter("panel_size_m", Vector2(1.2, 0.6))
	mat.set_shader_parameter("roughness_value", 0.8)
	mat.set_shader_parameter("metallic_value", 0.25)
	mat.set_shader_parameter("grime", 0.7)
	return mat


static func panel_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _INDUSTRIAL_SHADER
	mat.set_shader_parameter("base_color", Color(0.14, 0.15, 0.14, 1.0))
	mat.set_shader_parameter("seam_color", Color(0.04, 0.045, 0.04, 1.0))
	mat.set_shader_parameter("rust_color", Color(0.32, 0.12, 0.05, 1.0))
	mat.set_shader_parameter("panel_size_m", Vector2(0.6, 0.6))
	mat.set_shader_parameter("roughness_value", 0.8)
	mat.set_shader_parameter("metallic_value", 0.22)
	return mat


static func grill_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.075, 0.07, 1.0)
	mat.metallic = 0.3
	mat.roughness = 0.75
	return mat


static func rivet_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.18, 0.1, 1.0)
	mat.metallic = 0.3
	mat.roughness = 0.75
	return mat


static func lamp_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.78, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.35, 1.0)
	mat.emission_energy_multiplier = 2.2
	return mat


static func sign_letter_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.98, 0.93, 0.72, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.88, 0.5, 1.0)
	mat.emission_energy_multiplier = 1.4
	return mat


static func sign_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.12, 0.08, 1.0)
	mat.metallic = 0.2
	mat.roughness = 0.78
	return mat
