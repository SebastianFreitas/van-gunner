extends FacadeSetPiece
## A tenement mid-fire: flickering, broken upper windows (soot is shader-only, nothing to build),
## a few glowing flame slabs behind the glass, and one warm light at the building's base.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const _BASE_Y := _FacadePlan.BASE_Y
const _GROUND_H := _FacadePlan.GROUND_HEIGHT
const _FLOOR_H := _FacadePlan.FLOOR_HEIGHT
const MAX_LIGHTS := 12
const LIGHT_GROUP := &"facade_lights"


func can_apply(plans: Array[Dictionary]) -> bool:
	return _target_index(plans) != -1


func pick_plan(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> int:
	return _target_index(plans)


func apply_plans(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	var target := _target_index(plans)
	if target == -1:
		return
	var params: Dictionary = plans[target][&"params"]
	params[&"flicker"] = 1.0
	params[&"lit_ratio"] = 0.55
	params[&"lit_color"] = Color(1.0, 0.45, 0.12)
	params[&"soot"] = 0.9
	params[&"boarded_ratio"] = 0.0
	params[&"broken_ratio"] = 0.25
	params[&"emission_energy"] = 3.0
	plans[target][&"rare"] = id
	(plans[target][&"tags"] as Array[StringName]).append(&"burning")


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var side_sign: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var width := float(plan[&"width"])
	var floors := int(plan[&"floors"])
	var pitch := _param_f(plan, &"window_pitch", 2.6)
	var sill := _param_f(plan, &"window_sill", 0.9)
	var wh := _param_f(plan, &"window_h", 1.7)
	var cols := maxi(0, floori((width - 0.3) / pitch))
	var x_face := _FacadePlan.face_x(plan, side_sign)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added := false
	if cols > 0 and floors >= 2:
		for i in rng.randi_range(3, 5):
			var col := rng.randi_range(0, cols - 1)
			var k := rng.randi_range(2, floors)
			var u := (float(col) + 0.5) * pitch
			var y := _BASE_Y + _GROUND_H + float(k - 1) * _FLOOR_H + sill + wh * 0.5
			var center := Vector3(x_face + side_sign * 0.05, y, _z_at(plan, side_sign, u))
			added = _FacadeMeshKit.add_box(st, center, Vector3(0.03, 1.1, 0.7), keep_out) or added
	if added:
		_FacadeMeshKit.commit(
			host, st, "Flames",
			_FacadeMaterials.prop_material(
				&"flame", Color(1.0, 0.5, 0.1), 0.5, 0.0, Color(1.0, 0.45, 0.1), 5.0
			),
			false
		)
	var light_center := Vector3(
		x_face - side_sign * 1.0, _BASE_Y + 9.0, _z_at(plan, side_sign, width * 0.5)
	)
	if not keep_out.allows(_FacadeKeepOut.box_aabb(light_center, Vector3(0.2, 0.2, 0.2))):
		return
	if (
		not host.is_inside_tree()
		or host.get_tree().get_nodes_in_group(LIGHT_GROUP).size() >= MAX_LIGHTS
	):
		return
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 2.5
	light.omni_range = 12.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.light_cull_mask = 1
	light.position = light_center
	light.add_to_group(LIGHT_GROUP)
	host.add_child(light)


## Widest plan whose windows are on and whose style isn't glass or bare-frame (no window recesses).
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
		var params: Dictionary = plans[i][&"params"]
		var style := int(params[&"style"])
		if float(params.get(&"windows_on", 1.0)) <= 0.5 or style == 3 or style == 6:
			continue
		var width := float(plans[i][&"width"])
		if width > best_width:
			best_width = width
			best = i
	return best


static func _param_f(plan: Dictionary, key: StringName, default: float) -> float:
	return float(plan[&"params"].get(key, default))


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u
