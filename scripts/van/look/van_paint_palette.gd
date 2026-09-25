class_name VanPaintPalette
extends RefCounted
## Seeded paint schemes for the war rig's exterior shader: base, accent, primer and lettering.

const SCHEMES: Array[Dictionary] = [
	{
		&"id": &"olive_drab",
		&"base": Color(0.29, 0.30, 0.22),
		&"accent": Color(0.20, 0.21, 0.16),
		&"primer": Color(0.36, 0.33, 0.30),
		&"lettering": Color(0.62, 0.60, 0.54),
	},
	{
		&"id": &"desert_sand",
		&"base": Color(0.42, 0.38, 0.30),
		&"accent": Color(0.30, 0.27, 0.21),
		&"primer": Color(0.33, 0.31, 0.29),
		&"lettering": Color(0.18, 0.16, 0.14),
	},
	{
		&"id": &"gunmetal",
		&"base": Color(0.25, 0.26, 0.27),
		&"accent": Color(0.17, 0.17, 0.18),
		&"primer": Color(0.38, 0.34, 0.30),
		&"lettering": Color(0.60, 0.58, 0.52),
	},
	{
		&"id": &"navy_grey",
		&"base": Color(0.22, 0.25, 0.29),
		&"accent": Color(0.30, 0.31, 0.32),
		&"primer": Color(0.36, 0.33, 0.30),
		&"lettering": Color(0.62, 0.60, 0.54),
	},
	{
		&"id": &"primer_brown",
		&"base": Color(0.36, 0.24, 0.18),
		&"accent": Color(0.24, 0.18, 0.14),
		&"primer": Color(0.40, 0.37, 0.33),
		&"lettering": Color(0.60, 0.58, 0.52),
	},
	{
		&"id": &"oxide_green",
		&"base": Color(0.27, 0.31, 0.28),
		&"accent": Color(0.19, 0.22, 0.20),
		&"primer": Color(0.36, 0.33, 0.30),
		&"lettering": Color(0.60, 0.58, 0.52),
	},
	{
		&"id": &"faded_bone",
		&"base": Color(0.50, 0.48, 0.42),
		&"accent": Color(0.34, 0.32, 0.28),
		&"primer": Color(0.33, 0.31, 0.29),
		&"lettering": Color(0.16, 0.14, 0.12),
	},
	{
		&"id": &"soot_black",
		&"base": Color(0.16, 0.16, 0.15),
		&"accent": Color(0.26, 0.25, 0.23),
		&"primer": Color(0.36, 0.33, 0.30),
		&"lettering": Color(0.60, 0.58, 0.52),
	},
]


## Picks a random scheme from SCHEMES.
static func pick(rng: RandomNumberGenerator) -> Dictionary:
	return SCHEMES[rng.randi_range(0, SCHEMES.size() - 1)]


## Sets a scheme's colours and a fresh wear/seed roll onto a van exterior ShaderMaterial.
static func apply(material: ShaderMaterial, scheme: Dictionary, rng: RandomNumberGenerator) -> void:
	material.set_shader_parameter(&"paint_color", scheme[&"base"])
	material.set_shader_parameter(&"accent_color", scheme[&"accent"])
	material.set_shader_parameter(&"primer_color", scheme[&"primer"])
	material.set_shader_parameter(&"wear", rng.randf_range(0.35, 0.8))
	material.set_shader_parameter(
		&"seed_offset", Vector2(rng.randf_range(0.0, 100.0), rng.randf_range(0.0, 100.0)))
