class_name ArmMaterials
extends RefCounted
## Materials for the first-person goblin arms and pipe rifle: grime-shaded skin, cloth and steel, flat darks for the rest.

## Triplanar grime shader behind skin, cloth, steel and pipe.
const SHADER := preload("res://scenes/player/arm_surface.gdshader")
## The skin's noise offset: it places the wart domes the shader lifts out of the skin, so it is
## shape (seed 1337's draw; seed 7's 2.32 put domes on three fingertips and buried the claws).
const HAND_SKIN_OFFSET := 91.1654968261719
## Size of the shader's `vein_pts` array (`VEIN_MAX` in arm_vein.gdshaderinc); both sets pack under it.
const VEIN_MAX := 160


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
static func skin() -> ShaderMaterial:
	# One fixed tone and vein strength: the values the hand look seed drew (owner: one design).
	var base := Color(0.2806945, 0.3307963, 0.2565564)
	var mat := surface(base, Color(0.13, 0.17, 0.14), Color(0.08, 0.08, 0.06), 60.0, 6.0, 0.0,
			0.45, 0.88, 0.0, HAND_SKIN_OFFSET)
	mat.set_shader_parameter(&"vein_strength", 1.0)
	mat.set_shader_parameter(&"vein_shade", 1.8)
	mat.set_shader_parameter(&"vein_under", 1.8)
	# Measured palm bone length 0.125 rest units, so a finger is about 0.11: sag_scale 36 gives
	# about 4 big folds per finger, wrinkle_scale 280 the fine ones (older, creased skin).
	mat.set_shader_parameter(&"skin_bump", 1.0)
	mat.set_shader_parameter(&"sag_scale", 36.0)
	mat.set_shader_parameter(&"wrinkle_scale", 280.0)
	mat.set_shader_parameter(&"hand_blight_gain", 9.0) # age spots and blotches on the hands
	mat.set_shader_parameter(&"use_rest_pos", true)
	return mat


## Hands the arm's packed vein paths to the skin shader (`vein_pts`, `VEIN_MAX` points at most).
static func set_veins(mat: ShaderMaterial, side: String) -> void:
	var vein_set := load("res://resources/arms/vein_set_%s.tres" % side) as ArmVeinSet
	var packed := vein_set.pack()
	if packed.size() > VEIN_MAX:
		push_warning("Vein set %s packs %d points, over the shader cap %d." % [
				side, packed.size(), VEIN_MAX])
	var count := mini(packed.size(), VEIN_MAX)
	packed.resize(VEIN_MAX)
	mat.set_shader_parameter(&"vein_pts", packed)
	mat.set_shader_parameter(&"vein_count", count)


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
## No specular: the warm lights' sheen would wash its near-black albedo to the body's tan.
static func heavy_rust(seed_offset: float) -> ShaderMaterial:
	var mat := surface(Color(0.085, 0.05, 0.035), Color(0.06, 0.035, 0.025),
			Color(0.06, 0.04, 0.03), 60.0, 6.0, 0.0, 0.5, 1.0, 0.0, seed_offset)
	mat.set_shader_parameter(&"specular_value", 0.0)
	return mat


## Dull grey cloth tape: lighter and greyer than the rusty body, so wraps stand out.
static func gun_tape(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.21, 0.235, 0.25), Color(0.18, 0.2, 0.215), Color(0.18, 0.2, 0.21),
			60.0, 6.0, 0.0, 0.4, 1.0, 0.0, seed_offset)


## Heat-discoloured steel near the shot: blue-black with a brown cast.
static func scorched_steel(seed_offset: float) -> ShaderMaterial:
	var mat := surface(Color(0.035, 0.034, 0.038), Color(0.025, 0.024, 0.027),
			Color(0.03, 0.028, 0.026), 60.0, 6.0, 0.0, 0.5, 0.85, 0.0, seed_offset)
	mat.set_shader_parameter(&"specular_value", 0.0)
	return mat


## Old body paint worn down to rusty olive: only the flakes `RailgunWear` lays on top stay olive.
## A low specular keeps the warm lights from washing it into the rust and tape beside it.
static func gun_paint(seed_offset: float) -> ShaderMaterial:
	var mat := surface(Color(0.24, 0.20, 0.11), Color(0.13, 0.10, 0.06), Color(0.09, 0.07, 0.05),
			60.0, 6.0, 0.0, 0.95, 0.88, 0.15, seed_offset)
	mat.set_shader_parameter(&"specular_value", 0.15)
	return mat


## Turns on the shader's soft wear masks (soot, rust, tape band) on `mat`. `spots` are
## (centre xyz, radius) and `info` (kind: 0 soot, 1 rust, 2 tape band; band z0, z1), in gun space.
static func with_wear(mat: ShaderMaterial, spots: PackedVector4Array,
		info: PackedVector4Array) -> ShaderMaterial:
	mat.set_shader_parameter(&"wear_on", 1.0)
	mat.set_shader_parameter(&"wear_count", info.size())
	spots.resize(6)
	info.resize(6)
	mat.set_shader_parameter(&"wear_spot", spots)
	mat.set_shader_parameter(&"wear_info", info)
	mat.set_shader_parameter(&"wear_tape_color", Color(0.40, 0.425, 0.45))
	return mat


## Bare dull steel for the railgun's rails: lighter than the body so two bars frame the channel.
static func rail_steel(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.40, 0.41, 0.42), Color(0.24, 0.24, 0.25), Color(0.12, 0.11, 0.09),
			60.0, 6.0, 0.0, 0.5, 0.6, 0.4, seed_offset)


## Worn rail steel: dark, dull grey with rust-brown dirt, under the albedo and metallic caps.
static func worn_steel(seed_offset: float) -> ShaderMaterial:
	return surface(Color(0.24, 0.235, 0.22), Color(0.12, 0.11, 0.10), Color(0.14, 0.08, 0.05),
			60.0, 6.0, 0.0, 0.75, 0.82, 0.3, seed_offset)


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
