extends FacadeSetPiece
## A bare-frame parking structure: open waist bands at every deck level, fluorescent strip
## lighting under most slabs, and a hazard stripe marking the ramp entrance.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const _BASE_Y := _FacadePlan.BASE_Y


func can_apply(plans: Array[Dictionary]) -> bool:
	return _target_index(plans) != -1


func pick_plan(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> int:
	return _target_index(plans)


func apply_plans(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	var target := _target_index(plans)
	if target == -1:
		return
	var plan: Dictionary = plans[target]
	var params: Dictionary = plan[&"params"]
	params[&"style"] = 6
	params[&"windows_on"] = 0.0
	params[&"lit_ratio"] = 0.0
	params[&"base_color"] = Color(0.32, 0.32, 0.31)
	params[&"floor_height"] = 3.0
	params[&"ground_height"] = 3.0
	params[&"ground_kind"] = _FacadePlan.GROUND_BLANK
	plan[&"ground_kind"] = _FacadePlan.GROUND_BLANK
	plan[&"rare"] = id
	plan[&"suppress"] = [
		&"ac_units", &"fire_escape", &"balconies", &"wall_pipes", &"signs", &"awnings",
	]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var ss: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var width := float(plan[&"width"])
	var floors := int(plan[&"floors"])
	var xf := _FacadePlan.face_x(plan, ss)
	var y_top := _FacadePlan.roofline_y(plan)
	var mid_z := _z_at(plan, ss, width * 0.5)

	var band_st := SurfaceTool.new()
	band_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var band_added := false
	var light_st := SurfaceTool.new()
	light_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var light_added := false
	var k := 0
	while k < floors:
		var level_y := _BASE_Y + 3.0 + float(k) * 3.0
		if level_y >= y_top - 1.0:
			break
		var band_center := Vector3(_out_x(xf, ss, 0.3), level_y + 0.9, mid_z)
		band_added = (
			_FacadeMeshKit.add_box(band_st, band_center, Vector3(0.3, 0.5, width - 1.0), keep_out)
			or band_added
		)
		if rng.randf() < 0.7:
			var light_center := Vector3(xf - ss * 0.1, level_y + 2.6, mid_z)
			var light_size := Vector3(0.15, 0.08, width - 2.0)
			var light_ok := _FacadeMeshKit.add_box(light_st, light_center, light_size, keep_out)
			light_added = light_ok or light_added
		k += 1
	if band_added:
		_FacadeMeshKit.commit(
			host, band_st, "DeckBands", _FacadeMaterials.concrete_material(), true
		)
	if light_added:
		_FacadeMeshKit.commit(
			host, light_st, "DeckLights",
			_FacadeMaterials.prop_material(
				&"fluoro", Color(0.8, 0.9, 0.95), 0.4, 0.1, Color(0.75, 0.9, 1.0), 2.0
			),
			false
		)

	var stripe_center := Vector3(_out_x(xf, ss, 0.02), _BASE_Y + 0.075, _z_at(plan, ss, 2.0))
	var stripe_st := SurfaceTool.new()
	stripe_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if _FacadeMeshKit.add_box(stripe_st, stripe_center, Vector3(0.02, 0.15, 3.0), keep_out):
		_FacadeMeshKit.commit(
			host, stripe_st, "RampStripe",
			_FacadeMaterials.prop_material(&"hazard", Color(0.9, 0.75, 0.1), 0.8, 0.0), false
		)


## Widest plan at least 10 m wide and 14 m tall: room for a ramp and a couple of deck levels.
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
		var width := float(plans[i].get(&"width", 0.0))
		var height := float(plans[i].get(&"height", 0.0))
		if width >= 10.0 and height >= 14.0 and width > best_width:
			best_width = width
			best = i
	return best


## A box centred `depth` out from the face, toward the road (mirrors facade_props_ground._out_x).
static func _out_x(xf: float, ss: float, depth: float) -> float:
	return xf - ss * (_FacadeMeshKit.FACE_GAP + depth * 0.5)


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u
