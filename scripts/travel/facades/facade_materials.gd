extends RefCounted
## Static material factories for the facade system: a ShaderMaterial per building from a
## parameter dictionary, cached StandardMaterial3D props by key, and named skin presets.


static var _facade_shader: Shader
static var _sign_shader: Shader
static var _prop_cache: Dictionary = {}
static var _label_cache: Dictionary = {}


static func facade_shader() -> Shader:
	if _facade_shader == null:
		_facade_shader = load("res://scenes/corridor/facade_surface.gdshader") as Shader
	return _facade_shader


static func sign_shader() -> Shader:
	if _sign_shader == null:
		_sign_shader = load("res://scenes/corridor/facade_sign.gdshader") as Shader
	return _sign_shader


## One ShaderMaterial per building; buildings differ enough that caching wouldn't help.
static func facade_material(params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = facade_shader()
	for key in params:
		mat.set_shader_parameter(key, params[key])
	return mat


static func prop_material(
	key: StringName,
	color: Color,
	roughness: float,
	metallic: float,
	emission: Color = Color.BLACK,
	emission_energy: float = 0.0
) -> StandardMaterial3D:
	if _prop_cache.has(key):
		return _prop_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	_prop_cache[key] = mat
	return mat


static func unshaded_material(key: StringName, color: Color) -> StandardMaterial3D:
	if _prop_cache.has(key):
		return _prop_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_prop_cache[key] = mat
	return mat


## Trim (parapet, cornice, ledges, downspout): a shade darker than the building's own accent.
static func trim_material(preset: StringName) -> StandardMaterial3D:
	var key := StringName("trim_" + String(preset))
	var accent: Color = preset(preset)[&"accent_color"]
	return prop_material(key, accent.darkened(0.1), 0.8, 0.05)


static func iron_material() -> StandardMaterial3D:
	return prop_material(&"iron", Color(0.07, 0.075, 0.075), 0.65, 0.7)


static func metal_grey_material() -> StandardMaterial3D:
	return prop_material(&"metal_grey", Color(0.42, 0.44, 0.44), 0.55, 0.6)


static func rust_pipe_material() -> StandardMaterial3D:
	return prop_material(&"rust_pipe", Color(0.24, 0.12, 0.06), 0.5, 0.75)


static func concrete_material() -> StandardMaterial3D:
	return prop_material(&"concrete", Color(0.3, 0.3, 0.29), 0.9, 0.0)


## Ground-floor prop palette: awning canvas colours, sidewalk furniture and lamp glow, each
## cached by key so repeated props across a tile share one material.
static func ground_material(key: StringName) -> StandardMaterial3D:
	match key:
		&"awning_red":
			return prop_material(key, Color(0.45, 0.12, 0.1), 0.9, 0.0)
		&"awning_green":
			return prop_material(key, Color(0.12, 0.3, 0.18), 0.9, 0.0)
		&"awning_blue":
			return prop_material(key, Color(0.12, 0.18, 0.35), 0.9, 0.0)
		&"awning_tan":
			return prop_material(key, Color(0.5, 0.42, 0.28), 0.9, 0.0)
		&"hydrant":
			return prop_material(key, Color(0.55, 0.12, 0.08), 0.6, 0.3)
		&"news_box":
			return prop_material(key, Color(0.2, 0.25, 0.4), 0.5, 0.2)
		&"dumpster":
			return prop_material(key, Color(0.1, 0.25, 0.15), 0.8, 0.4)
		&"booth":
			return prop_material(key, Color(0.08, 0.1, 0.12), 0.4, 0.4)
		&"booth_glow":
			return prop_material(key, Color(0.6, 0.8, 1.0), 0.5, 0.0, Color(0.6, 0.8, 1.0), 2.0)
		&"vending":
			return prop_material(key, Color(0.35, 0.08, 0.08), 0.4, 0.3)
		&"vending_glow":
			return prop_material(key, Color(1.0, 0.9, 0.7), 0.5, 0.0, Color(1.0, 0.9, 0.7), 2.2)
		&"bollard":
			return prop_material(key, Color(0.15, 0.15, 0.15), 0.5, 0.6)
		&"crate":
			return prop_material(key, Color(0.4, 0.3, 0.18), 0.95, 0.0)
		&"bench":
			return prop_material(key, Color(0.25, 0.18, 0.1), 0.7, 0.05)
		_:
			return prop_material(key, Color(0.3, 0.3, 0.3), 0.6, 0.0)


## Facade uniform values for a named skin. Always a fresh Dictionary so callers can
## mutate it (e.g. to override the seed) without disturbing other buildings.
static func preset(name: StringName) -> Dictionary:
	match name:
		&"brick_red":
			return {
				&"style": 0,
				&"base_color": Color(0.36, 0.17, 0.12),
				&"accent_color": Color(0.24, 0.21, 0.18),
				&"mortar_color": Color(0.17, 0.155, 0.135),
				&"lit_color": Color(1.0, 0.72, 0.42),
				&"grime": 0.5,
			}
		&"brick_brown":
			return {
				&"style": 0,
				&"base_color": Color(0.28, 0.19, 0.13),
				&"accent_color": Color(0.2, 0.18, 0.15),
				&"mortar_color": Color(0.15, 0.14, 0.12),
				&"lit_color": Color(1.0, 0.75, 0.5),
				&"grime": 0.55,
			}
		&"concrete_grey":
			return {
				&"style": 1,
				&"base_color": Color(0.30, 0.31, 0.30),
				&"accent_color": Color(0.2, 0.21, 0.2),
				&"mortar_color": Color(0.12, 0.13, 0.13),
				&"lit_color": Color(0.85, 0.9, 1.0),
				&"grime": 0.5,
				&"window_pitch": 3.0,
				&"window_w": 1.8,
				&"window_h": 1.4,
			}
		&"plaster_tan":
			return {
				&"style": 2,
				&"base_color": Color(0.42, 0.36, 0.26),
				&"accent_color": Color(0.26, 0.22, 0.17),
				&"mortar_color": Color(0.18, 0.16, 0.13),
				&"lit_color": Color(1.0, 0.78, 0.5),
				&"grime": 0.45,
			}
		&"plaster_green":
			return {
				&"style": 2,
				&"base_color": Color(0.24, 0.31, 0.25),
				&"accent_color": Color(0.16, 0.18, 0.15),
				&"mortar_color": Color(0.12, 0.14, 0.12),
				&"lit_color": Color(1.0, 0.8, 0.55),
				&"grime": 0.5,
			}
		&"glass_blue":
			return {
				&"style": 3,
				&"base_color": Color(0.05, 0.08, 0.11),
				&"accent_color": Color(0.16, 0.18, 0.2),
				&"mortar_color": Color(0.1, 0.1, 0.1),
				&"glass_color": Color(0.04, 0.06, 0.08),
				&"lit_color": Color(0.8, 0.88, 1.0),
				&"grime": 0.15,
				&"lit_ratio": 0.5,
			}
		&"corrugated_green":
			return {
				&"style": 4,
				&"base_color": Color(0.16, 0.22, 0.18),
				&"accent_color": Color(0.14, 0.15, 0.14),
				&"mortar_color": Color(0.08, 0.09, 0.08),
				&"lit_color": Color(0.9, 0.95, 1.0),
				&"grime": 0.6,
				&"windows_on": 0.0,
			}
		&"corrugated_rust":
			return {
				&"style": 4,
				&"base_color": Color(0.28, 0.17, 0.11),
				&"accent_color": Color(0.16, 0.13, 0.11),
				&"mortar_color": Color(0.1, 0.08, 0.07),
				&"lit_color": Color(0.9, 0.95, 1.0),
				&"grime": 0.7,
				&"windows_on": 0.0,
			}
		&"stone_grey":
			return {
				&"style": 5,
				&"base_color": Color(0.34, 0.33, 0.30),
				&"accent_color": Color(0.26, 0.25, 0.22),
				&"mortar_color": Color(0.14, 0.14, 0.13),
				&"lit_color": Color(1.0, 0.8, 0.5),
				&"grime": 0.4,
				&"window_pitch": 3.2,
				&"window_h": 2.2,
				&"band_every": 1.0,
			}
		&"bare_frame":
			return {
				&"style": 6,
				&"base_color": Color(0.3, 0.3, 0.29),
				&"accent_color": Color(0.2, 0.2, 0.2),
				&"mortar_color": Color(0.1, 0.1, 0.1),
				&"lit_color": Color(1.0, 0.8, 0.5),
				&"grime": 0.3,
				&"windows_on": 0.0,
			}
		_:
			return preset(&"brick_red")


static func preset_names() -> Array[StringName]:
	var names: Array[StringName] = [
		&"brick_red",
		&"brick_brown",
		&"concrete_grey",
		&"plaster_tan",
		&"plaster_green",
		&"glass_blue",
		&"corrugated_green",
		&"corrugated_rust",
		&"stone_grey",
		&"bare_frame",
	]
	return names


## A word's label texture, cached by (text, scale, vertical) so the same word across buildings
## costs one Image. Rebuilt with mipmaps so the neon halo's textureLod sample has something to read.
static func label_texture(text: String, scale: int, vertical: bool) -> ImageTexture:
	var key := "%s|%d|%s" % [text, scale, vertical]
	if _label_cache.has(key):
		return _label_cache[key] as ImageTexture
	var fg := Color(1.0, 1.0, 1.0, 1.0)
	var bg := Color(0.0, 0.0, 0.0, 1.0)
	var tex: ImageTexture
	if vertical:
		tex = BlockGlyphs.make_vertical_label(text, scale, fg, bg, 2)
	else:
		tex = BlockGlyphs.make_label(text, scale, fg, bg, 2)
	var img := tex.get_image()
	img.generate_mipmaps()
	tex = ImageTexture.create_from_image(img)
	_label_cache[key] = tex
	return tex


## One sign's material; a fresh ShaderMaterial each call since every sign's uniforms differ.
static func sign_material(
	text: String, scale: int, vertical: bool, color: Color, energy: float, mode: int, seed: float,
	dead_ratio: float, flicker_amount: float, letter_cells: float
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = sign_shader()
	mat.set_shader_parameter(&"text_tex", label_texture(text, scale, vertical))
	mat.set_shader_parameter(&"color", color)
	mat.set_shader_parameter(&"energy", energy)
	mat.set_shader_parameter(&"mode", mode)
	mat.set_shader_parameter(&"seed", seed)
	mat.set_shader_parameter(&"dead_ratio", dead_ratio)
	mat.set_shader_parameter(&"flicker_amount", flicker_amount)
	mat.set_shader_parameter(&"letter_cells", letter_cells)
	return mat
