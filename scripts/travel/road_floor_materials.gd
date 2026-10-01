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


## Sidewalk shader for the real slab mesh: COLOR.r carries the wreck amount. The mesh writes
## UV.x 0..1 across the walk and UV.y in metres along it, hence size (width, 1).
static func sidewalk_wreck_mat(width: float) -> ShaderMaterial:
	var m := sidewalk_mat(Vector2(width, 1.0))
	m.set_shader_parameter(&"vertex_wreck", true)
	return m


## Sidewalk shader for the soil bed under the slabs: only the missing-slab fill is drawn.
static func sidewalk_pit_mat(surface_size_m: Vector2) -> ShaderMaterial:
	var m := sidewalk_mat(surface_size_m)
	m.set_shader_parameter(&"pit_fill", true)
	return m


## Worn concrete kerb with joints, chips, scuffs and faded paint (box long side along z).
static func curb_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/corridor/curb_surface.gdshader") as Shader
	mat.set_shader_parameter("mode", 0)
	return mat


## Gutter sludge, wet patches and leaf litter: the kerb shader in mode 1.
static func gutter_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/corridor/curb_surface.gdshader") as Shader
	mat.set_shader_parameter("mode", 1)
	mat.set_shader_parameter("base_color", Color(0.04, 0.042, 0.038, 1.0))
	return mat


static func std(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
