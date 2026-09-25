extends FacadeSetPiece
## A stone chapel front: a stained-glass rose window over the arcade, and a bell tower standing
## on the roof with a clock face and a pointed cap.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const _BASE_Y := _FacadePlan.BASE_Y
## A quarter turn about z lays a cylinder's height axis along x (see add_cylinder_node): a thin
## height makes a disc that faces the road instead of standing upright.
const _ALONG_X := Vector3(0.0, 0.0, PI * 0.5)


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
	params[&"style"] = 5
	params[&"window_h"] = 2.8
	params[&"window_pitch"] = 3.4
	params[&"lit_ratio"] = 0.3
	params[&"lit_color"] = Color(1.0, 0.75, 0.45)
	params[&"ground_kind"] = _FacadePlan.GROUND_ARCADE
	plan[&"ground_kind"] = _FacadePlan.GROUND_ARCADE
	params[&"band_every"] = 0.0
	var height: float = maxf(float(plan[&"height"]), 18.0)
	plan[&"height"] = height
	params[&"facade_height"] = height
	var floors_raw := (
		(height - _FacadePlan.GROUND_HEIGHT - _FacadePlan.PARAPET) / _FacadePlan.FLOOR_HEIGHT
	)
	plan[&"floors"] = maxi(1, int(floor(floors_raw)))
	plan[&"rare"] = id
	plan[&"suppress"] = [
		&"ac_units", &"fire_escape", &"balconies", &"wall_pipes", &"roof_clutter", &"signs",
		&"awnings",
	]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var ss: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var width := float(plan[&"width"])
	var x_face := _FacadePlan.face_x(plan, ss)
	var y_top := _FacadePlan.roofline_y(plan)
	var mid_z := _z_at(plan, ss, width * 0.5)

	var glass := _FacadeMaterials.prop_material(
		&"stained_glass", Color(0.4, 0.15, 0.25), 0.4, 0.1, Color(0.9, 0.5, 0.35), 2.2
	)
	var trim := _FacadeMaterials.trim_material(plan[&"preset"])
	_FacadeMeshKit.add_cylinder_node(
		host, "RoseRing", 1.7, 1.7, 0.06, Vector3(x_face - ss * 0.05, _BASE_Y + 9.5, mid_z), trim,
		false, keep_out, _ALONG_X
	)
	_FacadeMeshKit.add_cylinder_node(
		host, "RoseWindow", 1.5, 1.5, 0.1, Vector3(x_face - ss * 0.11, _BASE_Y + 9.5, mid_z), glass,
		false, keep_out, _ALONG_X
	)

	var tower_h := rng.randf_range(8.0, 14.0)
	var tower_size := Vector3(1.6, tower_h, 6.0)
	var tower_center := Vector3(
		x_face + ss * 0.8, y_top + tower_h * 0.5, _z_at(plan, ss, width - 4.0)
	)
	var tower_mi := _FacadeMeshKit.add_box_node(
		host, "Tower", tower_size, tower_center, Vector3.ZERO, trim, true, keep_out
	)
	if tower_mi == null:
		return

	var clock_center := Vector3(x_face - ss * 0.07, tower_center.y, tower_center.z)
	_FacadeMeshKit.add_cylinder_node(
		host, "ClockFace", 1.0, 1.0, 0.06, clock_center,
		_FacadeMaterials.prop_material(
			&"clock_face", Color(0.9, 0.88, 0.8), 0.6, 0.0, Color(1.0, 0.95, 0.8), 1.4
		),
		false, keep_out, _ALONG_X
	)
	var iron := _FacadeMaterials.iron_material()
	_FacadeMeshKit.add_box_node(
		host, "ClockHourHand", Vector3(0.02, 0.6, 0.06), clock_center,
		Vector3(0.0, 0.0, rng.randf_range(0.0, TAU)), iron, false, keep_out
	)
	_FacadeMeshKit.add_box_node(
		host, "ClockMinuteHand", Vector3(0.02, 0.4, 0.06), clock_center,
		Vector3(0.0, 0.0, rng.randf_range(0.0, TAU)), iron, false, keep_out
	)

	var tower_top := tower_center.y + tower_h * 0.5
	_FacadeMeshKit.add_cylinder_node(
		host, "TowerCap", 0.05, 1.3, 2.0, Vector3(tower_center.x, tower_top + 1.0, tower_center.z),
		_FacadeMaterials.metal_grey_material(), true, keep_out
	)


## Widest plan at least 10 m wide: the tower and rose window need road frontage.
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
		var width := float(plans[i].get(&"width", 0.0))
		if width >= 10.0 and width > best_width:
			best_width = width
			best = i
	return best


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u
