extends RefCounted

## Static material factories for RoadFloor: procedural street shaders plus a
## generic StandardMaterial3D helper, shared by the core and the detail builders.


static func asphalt_mat(_surface_size_m: Vector2) -> ShaderMaterial:
	var shader := load("res://scenes/corridor/asphalt_surface.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("washout", 0.32)
	mat.set_shader_parameter("trash", 1.0)
	mat.set_shader_parameter("roughness_value", 0.94)
	return mat


static func sidewalk_mat(surface_size_m: Vector2) -> ShaderMaterial:
	var shader := load("res://scenes/corridor/sidewalk_surface.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("surface_size_m", surface_size_m)
	mat.set_shader_parameter("slab_spacing_m", 1.2)
	mat.set_shader_parameter("washout", 0.5)
	mat.set_shader_parameter("trash", 0.65)
	mat.set_shader_parameter("roughness_value", 0.92)
	return mat


static func std(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
