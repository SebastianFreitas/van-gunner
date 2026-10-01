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


## Paving kinds for paving_mat: square tile, small sett, granite curb block, rubble chunk.
const PAVING_TILE := 0
const PAVING_SETT := 1
const PAVING_CURB := 2
const PAVING_RUBBLE := 3
const PAVING_SOIL := 4

static var _paving_cache: Dictionary = {}


## Grime material for the real paving pieces (vertex colour carries wreck, tone and up),
## one cached material per kind.
static func paving_mat(kind: int) -> ShaderMaterial:
	if _paving_cache.has(kind):
		return _paving_cache[kind] as ShaderMaterial
	if kind < PAVING_TILE or kind > PAVING_SOIL:
		push_warning("paving_mat: unknown kind %d, using tile" % kind)
		return paving_mat(PAVING_TILE)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/corridor/paving_surface.gdshader") as Shader
	match kind:
		PAVING_TILE:
			mat.set_shader_parameter(&"base_color", Color(0.33, 0.32, 0.30))
		PAVING_SETT:
			mat.set_shader_parameter(&"base_color", Color(0.25, 0.25, 0.26))
			mat.set_shader_parameter(&"tone_spread", 0.45)
			mat.set_shader_parameter(&"grain_per_m", 10.0)
			mat.set_shader_parameter(&"litter", 0.3)
			mat.set_shader_parameter(&"crack_amount", 0.4)
		PAVING_CURB:
			mat.set_shader_parameter(&"base_color", Color(0.46, 0.45, 0.43))
			mat.set_shader_parameter(&"tone_spread", 0.2)
			mat.set_shader_parameter(&"litter", 0.0)
			mat.set_shader_parameter(&"crack_amount", 0.8)
			mat.set_shader_parameter(&"roughness_value", 0.85)
		PAVING_RUBBLE:
			mat.set_shader_parameter(&"base_color", Color(0.36, 0.34, 0.31))
			mat.set_shader_parameter(&"tone_spread", 0.5)
			mat.set_shader_parameter(&"litter", 0.0)
			mat.set_shader_parameter(&"crack_amount", 0.6)
			mat.set_shader_parameter(&"roughness_value", 0.95)
		PAVING_SOIL:
			mat.set_shader_parameter(&"base_color", Color(0.17, 0.15, 0.12))
			mat.set_shader_parameter(&"dirt_color", Color(0.10, 0.085, 0.07))
			mat.set_shader_parameter(&"stain_color", Color(0.07, 0.06, 0.05))
			mat.set_shader_parameter(&"tone_spread", 0.5)
			mat.set_shader_parameter(&"grain_per_m", 6.0)
			mat.set_shader_parameter(&"crack_amount", 0.0)
			mat.set_shader_parameter(&"litter", 0.25)
			mat.set_shader_parameter(&"gravel", 1.0)
			mat.set_shader_parameter(&"packed", 1.0)
			mat.set_shader_parameter(&"roughness_value", 0.97)
			mat.set_shader_parameter(&"wreck_dirt", 0.3)
	_paving_cache[kind] = mat
	return mat


static func std(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
