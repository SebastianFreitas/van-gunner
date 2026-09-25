extends RefCounted
## Cached grime ShaderMaterials for large facade props, one per flat prop material, so big
## slabs (awnings, lintels, docks, set-piece bodies) share the road's grime recipe.

static var _shader: Shader
## Keyed by the source StandardMaterial3D.
static var _cache: Dictionary = {}


static func grime_shader() -> Shader:
	if _shader == null:
		_shader = load("res://scenes/corridor/facade_prop_grime.gdshader") as Shader
	return _shader


## A grime ShaderMaterial for a prop already through `prop_material()`: colour, roughness and
## metallic come from it, with roughness lifted into the base-surface range 0.78..0.95. The
## cache key is the prop only, so the first call's `grime` wins; every call site below uses the
## default, so that is fine.
static func from_prop(prop: StandardMaterial3D, grime: float = 0.6) -> ShaderMaterial:
	if _cache.has(prop):
		return _cache[prop] as ShaderMaterial
	var mat := ShaderMaterial.new()
	mat.shader = grime_shader()
	mat.set_shader_parameter(&"base_color", prop.albedo_color)
	mat.set_shader_parameter(&"roughness_value", clampf(prop.roughness, 0.78, 0.95))
	mat.set_shader_parameter(&"metallic_value", clampf(prop.metallic, 0.0, 0.3))
	mat.set_shader_parameter(&"grime", clampf(grime, 0.0, 1.0))
	_cache[prop] = mat
	return mat
