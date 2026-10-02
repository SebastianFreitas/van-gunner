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
	mat.set_shader_parameter(&"use_rest_pos", true)
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


## Worn T-shirt cloth shader behind the two sleeves.
const CLOTH_SHADER := preload("res://scenes/player/arm_cloth.gdshader")


## One of four dull shirts, torn and stained; its meshes carry the rest chart in CUSTOM0.
static func gear_cloth(rng: RandomNumberGenerator) -> ShaderMaterial:
	var tints: Array[Color] = [
		Color(0.20, 0.18, 0.13), # yellowed white
		Color(0.05, 0.05, 0.05), # faded black
		Color(0.16, 0.07, 0.06), # oxide red
		Color(0.11, 0.11, 0.07), # olive
	]
	var tint: Color = tints[rng.randi_range(0, 3)]
	tint = Color(tint.r * rng.randf_range(0.92, 1.08), tint.g * rng.randf_range(0.92, 1.08),
			tint.b * rng.randf_range(0.92, 1.08))
	var mat := ShaderMaterial.new()
	mat.shader = CLOTH_SHADER
	mat.set_shader_parameter(&"base_tint", tint)
	mat.set_shader_parameter(&"seed", rng.randf_range(0.0, 100.0))
	return mat


static func pipe(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.14, 0.14, 0.15), Color(0.09, 0.09, 0.10), Color(0.08, 0.08, 0.06),
			60.0, 6.0, 0.0, 0.7, 0.82, 0.3, seed_offset)


static func claw() -> StandardMaterial3D:
	return MachineParts.dark(Color(0.08, 0.07, 0.06))


static func tape(rng: RandomNumberGenerator) -> StandardMaterial3D:
	if rng.randi_range(0, 1) == 0:
		return MachineParts.dark(Color(0.28, 0.26, 0.20))
	return MachineParts.dark(Color(0.08, 0.08, 0.08))


## Grip panels and the bore: dark rubber.
static func grip_rubber() -> StandardMaterial3D:
	return MachineParts.dark(Color(0.07, 0.07, 0.065))


static func lamp_body() -> StandardMaterial3D:
	return MachineParts.dark(Color(0.22, 0.22, 0.20))


const BULB_GLOW := 1.2## emission multiplier; lamp heads may cross the 1.1 glow threshold


## Trouble-lamp bulb: the same emissive recipe as the van's machine lamps, warm like the arm light.
static func bulb() -> StandardMaterial3D:
	return MachineParts.emissive(Color(1.0, 0.8, 0.55), BULB_GLOW)


## Worn brown work glove, fingerless.
static func glove(rng: RandomNumberGenerator) -> ShaderMaterial:
	var base := Color(0.11 + rng.randf_range(-0.01, 0.01), 0.08 + rng.randf_range(-0.01, 0.01),
			0.06 + rng.randf_range(-0.01, 0.01))
	var shade := Color(base.r * 0.5, base.g * 0.5, base.b * 0.5)
	return surface(base, shade, Color(0.08, 0.08, 0.06), 60.0, 6.0, 0.0, 0.6, 0.86, 0.0,
			rng.randf_range(0.0, 100.0))


## Dirty boxer's wrap.
static func wrap_cloth(rng: RandomNumberGenerator) -> ShaderMaterial:
	var bases: Array[Color] = [Color(0.30, 0.28, 0.24), Color(0.26, 0.25, 0.20)]
	var base: Color = bases[rng.randi_range(0, 1)]
	var shade := Color(base.r * 0.55, base.g * 0.55, base.b * 0.55)
	return surface(base, shade, Color(0.08, 0.08, 0.06), 60.0, 6.0, 0.02, 0.65, 0.93, 0.0,
			rng.randf_range(0.0, 100.0))


## Cut-off sleeve: denim, flannel, olive or soot.
static func sleeve(rng: RandomNumberGenerator) -> ShaderMaterial:
	var bases: Array[Color] = [
		Color(0.10, 0.12, 0.16), # denim
		Color(0.18, 0.07, 0.06), # flannel
		Color(0.14, 0.13, 0.09), # olive
		Color(0.10, 0.10, 0.09), # soot
	]
	var base: Color = bases[rng.randi_range(0, 3)]
	var shade := Color(base.r * 0.55, base.g * 0.55, base.b * 0.55)
	return surface(base, shade, Color(0.08, 0.08, 0.06), 60.0, 6.0, 0.025, 0.6, 0.92, 0.0,
			rng.randf_range(0.0, 100.0))


## Rag knotted round the forearm.
static func rag(rng: RandomNumberGenerator) -> ShaderMaterial:
	var bases: Array[Color] = [Color(0.14, 0.12, 0.10), Color(0.17, 0.09, 0.08)]
	var base: Color = bases[rng.randi_range(0, 1)]
	var shade := Color(base.r * 0.55, base.g * 0.55, base.b * 0.55)
	return surface(base, shade, Color(0.08, 0.08, 0.06), 60.0, 6.0, 0.02, 0.75, 0.93, 0.0,
			rng.randf_range(0.0, 100.0))


## Cheap brass for rings and the chain: flat like the lamp body, a little metal.
static func brass() -> StandardMaterial3D:
	var mat := MachineParts.dark(Color(0.30, 0.22, 0.10), 0.78)
	mat.metallic = 0.3
	return mat


static func lens() -> StandardMaterial3D:
	return MachineParts.emissive(Color(1.0, 0.85, 0.6), 2.0)
