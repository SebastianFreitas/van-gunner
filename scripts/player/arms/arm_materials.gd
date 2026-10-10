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
	# 4.5 times the shader default, with shaded flanks, so the veins read at arm's length.
	mat.set_shader_parameter(&"vein_height", 0.0036)
	mat.set_shader_parameter(&"vein_shade", 0.45)
	mat.set_shader_parameter(&"vein_wrist", 1.2)
	mat.set_shader_parameter(&"vein_wrap", 0.9)
	mat.set_shader_parameter(&"vein_width", 0.028)
	# Measured palm bone length 0.125 rest units, so a finger is about 0.11: sag_scale 36 gives
	# about 4 big folds per finger, wrinkle_scale 216 (6x) the fine ones.
	mat.set_shader_parameter(&"skin_bump", 0.85)
	mat.set_shader_parameter(&"sag_scale", 36.0)
	mat.set_shader_parameter(&"wrinkle_scale", 216.0)
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


## Rusted plate: oxide brown, rough.
static func rust(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.20, 0.12, 0.08), Color(0.10, 0.06, 0.05), Color(0.08, 0.08, 0.06),
			60.0, 6.0, 0.0, 0.95, 0.9, 0.2, seed_offset)


## Flaking, pitted rust for patches laid over the body: darker and redder than `rust`, all grime.
static func heavy_rust(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.24, 0.115, 0.06), Color(0.09, 0.045, 0.03), Color(0.06, 0.05, 0.04),
			60.0, 6.0, 0.0, 1.0, 0.95, 0.1, seed_offset)


## Heat-discoloured steel near the shot: blue-black with a brown cast.
static func scorched_steel(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.06, 0.055, 0.065), Color(0.03, 0.025, 0.03), Color(0.05, 0.035, 0.025),
			60.0, 6.0, 0.0, 0.8, 0.5, 0.5, seed_offset)


## Old body paint worn down to rusty olive: only the flakes `RailgunWear` lays on top stay olive.
static func gun_paint(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.24, 0.20, 0.11), Color(0.13, 0.10, 0.06), Color(0.09, 0.07, 0.05),
			60.0, 6.0, 0.0, 0.95, 0.88, 0.15, seed_offset)


## Bare dull steel for the railgun's rails: lighter than the body so two bars frame the channel.
static func rail_steel(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.40, 0.41, 0.42), Color(0.24, 0.24, 0.25), Color(0.12, 0.11, 0.09),
			60.0, 6.0, 0.0, 0.5, 0.6, 0.4, seed_offset)


## Dull scavenged aluminium: pale grey, matte.
static func dull_alu(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.30, 0.31, 0.30), Color(0.15, 0.15, 0.15), Color(0.08, 0.08, 0.06),
			60.0, 6.0, 0.0, 0.75, 0.85, 0.3, seed_offset)


## Claw nails: colour comes from the mesh's per-vertex grime gradient (linear), with a dull horn sheen.
static func claw() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.55
	mat.metallic = 0.0
	mat.metallic_specular = 0.4
	return mat


static func tape(rng: RandomNumberGenerator) -> StandardMaterial3D:
	if rng.randi_range(0, 1) == 0:
		return MachineParts.dark(Color(0.28, 0.26, 0.20))
	return MachineParts.dark(Color(0.08, 0.08, 0.08))


## Grip panels and the bore: dark rubber.
static func grip_rubber() -> StandardMaterial3D:
	return MachineParts.dark(Color(0.07, 0.07, 0.065))


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


## Orange glow of the railgun's charge channel and capacitor lamps.
static func ember(_seed_offset: float) -> StandardMaterial3D:
	return MachineParts.emissive(Color(1.0, 0.45, 0.12), 1.6)
