class_name VanFloorSkin
extends RefCounted
## Floor steel material and the face tags the floor mesh builders write into vertex COLOR.r.

const SHADER_PATH := "res://scenes/van/van_floor_steel.gdshader"
## Face tags, in the shader's order (COLOR.r = index / 8); they only colour, they add no geometry.
const TAGS: Array[StringName] = [&"top", &"crest", &"valley", &"edge", &"weld", &"cavity", &"checker"]
## Donor tints (the rear door's paint_color, oxide, primer_color, steel).
const TINT_A := Color(0.187, 0.209, 0.2035)
## Plate tints in 30 % value steps off TINT_A (luminance ~0.2): B orange rust x0.7, D blue-grey
## x1.3, C bare grey steel x1.6. The floor's own patches keep the old B and D below.
const TINT_B := Color(0.50, 0.19, 0.03)
const TINT_C := Color(0.32, 0.32, 0.31)
const TINT_D := Color(0.20, 0.25, 0.34)
## P4 oxblood red-oxide primer, P5 faded olive-khaki.
const TINT_E := Color(0.45, 0.11, 0.08)
const TINT_F := Color(0.25, 0.24, 0.14)
const TINT_B_OLD := Color(0.0855, 0.036, 0.027)
const TINT_D_OLD := Color(0.132, 0.143, 0.165)


@warning_ignore("shadowed_global_identifier")
static func material(tint: Color, seed: float, paint: float, donor: float = 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH) as Shader
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("seed", seed)
	mat.set_shader_parameter("paint", paint)
	mat.set_shader_parameter("donor", donor)
	return mat


## The value a builder writes into COLOR.r for the named face tag.
static func tag(tag_name: StringName) -> float:
	return float(TAGS.find(tag_name)) / 8.0


## Marks every vertex added after this call with the named face tag.
static func set_tag(st: SurfaceTool, tag_name: StringName) -> void:
	st.set_color(Color(tag(tag_name), 0.0, 0.0, 1.0))
