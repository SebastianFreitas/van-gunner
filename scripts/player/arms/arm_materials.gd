class_name ArmMaterials
extends RefCounted
## Materials for the first-person goblin arms and pipe rifle: grime-shaded skin, cloth and steel, flat darks for the rest.

## Triplanar grime shader behind skin, cloth, steel and pipe.
const SHADER := preload("res://scenes/player/arm_surface.gdshader")


## A fresh grime material; never cached, because the arms rebuild per run.
static func surface(base: Color, shade: Color, dirt: Color, grain_m: float, mottle_m: float,
		rib_m: float, grime: float, rough: float, metal: float, seed_offset: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"base_color", base)
	mat.set_shader_parameter(&"shade_color", shade)
	mat.set_shader_parameter(&"dirt_color", dirt)
	mat.set_shader_parameter(&"grain_m", grain_m)
	mat.set_shader_parameter(&"mottle_m", mottle_m)
	mat.set_shader_parameter(&"rib_m", rib_m)
	mat.set_shader_parameter(&"grime", grime)
	mat.set_shader_parameter(&"roughness_value", rough)
	mat.set_shader_parameter(&"metallic_value", metal)
	mat.set_shader_parameter(&"seed_offset", seed_offset)
	return mat


## Grime skin; the only material with raised veins (the others keep vein_strength 0).
static func skin(rng: RandomNumberGenerator) -> ShaderMaterial:
	var bases: Array[Color] = [
		Color(0.27, 0.32, 0.25), # grey-green
		Color(0.25, 0.31, 0.27), # green-blue
		Color(0.29, 0.31, 0.23), # moss
	]
	var base: Color = bases[rng.randi_range(0, 2)]
	base = Color(base.r + rng.randf_range(-0.02, 0.02), base.g + rng.randf_range(-0.02, 0.02),
			base.b + rng.randf_range(-0.02, 0.02))
	var mat := surface(base, Color(0.13, 0.17, 0.14), Color(0.08, 0.08, 0.06), 60.0, 6.0, 0.0,
			0.45, 0.88, 0.0, rng.randf_range(0.0, 100.0))
	mat.set_shader_parameter(&"vein_strength", rng.randf_range(0.7, 1.0))
	return mat


static func cloth(rng: RandomNumberGenerator) -> ShaderMaterial:
	var bases: Array[Color] = [
		Color(0.14, 0.13, 0.09), # olive drab
		Color(0.10, 0.10, 0.09), # soot
		Color(0.16, 0.08, 0.07), # oxblood
	]
	var base: Color = bases[rng.randi_range(0, 2)]
	var shade := Color(base.r * 0.55, base.g * 0.55, base.b * 0.55)
	return surface(base, shade, Color(0.08, 0.08, 0.06), 60.0, 6.0, 0.025, 0.55, 0.92, 0.0,
			rng.randf_range(0.0, 100.0))


static func steel(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.16, 0.17, 0.17), Color(0.09, 0.09, 0.10), Color(0.08, 0.08, 0.06),
			60.0, 6.0, 0.0, 0.7, 0.82, 0.3, seed_offset)


static func pipe(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.14, 0.14, 0.15), Color(0.09, 0.09, 0.10), Color(0.08, 0.08, 0.06),
			60.0, 6.0, 0.0, 0.7, 0.82, 0.3, seed_offset)


static func claw() -> StandardMaterial3D:
	return MachineParts.dark(Color(0.08, 0.07, 0.06))


static func tape(rng: RandomNumberGenerator) -> StandardMaterial3D:
	if rng.randi_range(0, 1) == 0:
		return MachineParts.dark(Color(0.28, 0.26, 0.20))
	return MachineParts.dark(Color(0.08, 0.08, 0.08))


static func grip_wood() -> StandardMaterial3D:
	return MachineParts.dark(Color(0.18, 0.12, 0.07))


static func lamp_body() -> StandardMaterial3D:
	return MachineParts.dark(Color(0.22, 0.22, 0.20))


static func leather() -> StandardMaterial3D:
	return MachineParts.dark(Color(0.10, 0.07, 0.05))


## Built directly: dark() would clamp the roughness up to 0.78.
static func wound() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.04, 0.03)
	mat.roughness = 0.6
	mat.metallic = 0.0
	return mat


## Built directly like wound(): scar tissue is skin, so no metallic and softer than dark() allows.
static func scar() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.15, 0.13)
	mat.roughness = 0.85
	mat.metallic = 0.0
	return mat


static func shrapnel() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.31, 0.32)
	mat.roughness = 0.8
	mat.metallic = 0.3
	return mat


static func lens() -> StandardMaterial3D:
	return MachineParts.emissive(Color(1.0, 0.85, 0.6), 2.0)
