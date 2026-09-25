extends FacadeSetPiece
## A gas station canopy grafted onto a low storefront: a lit slab on two posts over the pumps, a
## price pole and one warm light underneath.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeSigns := preload("res://scripts/travel/facades/facade_signs.gd")

const _BASE_Y := _FacadePlan.BASE_Y
const LIGHT_GROUP := &"facade_lights"
const MAX_LIGHTS := 12
## Ground(4.6) + one floor(3.2) + parapet(0.6): the natural height for a single-floor building.
const CANOPY_HEIGHT := 8.4


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
	plan[&"height"] = CANOPY_HEIGHT
	params[&"facade_height"] = CANOPY_HEIGHT
	plan[&"floors"] = 1
	params[&"windows_on"] = 0.0
	params[&"ground_kind"] = _FacadePlan.GROUND_STOREFRONT
	plan[&"ground_kind"] = _FacadePlan.GROUND_STOREFRONT
	params[&"ground_units"] = 1.0
	plan[&"ground_units"] = 1
	plan[&"rare"] = id
	plan[&"suppress"] = [
		&"ac_units", &"fire_escape", &"balconies", &"roof_clutter", &"wall_pipes", &"signs",
		&"awnings", &"furniture",
	]


## Every box here sits at abs(x) >= 7.6 or above the lane's LANE_TOP_Y, so add_box_node's own gate
## check is the only guard any of them needs (no piece here builds while a mouth is open).
func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var ss: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var width := float(plan[&"width"])
	var mid := width * 0.5
	var xf := _FacadePlan.face_x(plan, ss)
	var z_mid := _z_at(plan, ss, mid)
	var cx := xf - ss * 1.5

	# Canopy bottom at tile y 6.2 (y0 + 6.6): centre y0 + 6.85 with the 0.5 m slab.
	_FacadeMeshKit.add_box_node(
		host, "Canopy", Vector3(3.0, 0.5, 8.0), Vector3(cx, _BASE_Y + 6.85, z_mid), Vector3.ZERO,
		_FacadeMaterials.concrete_material(), true, keep_out
	)
	# Glow strip flush under the canopy: tile y 6.15..6.2, centre tile y 6.175 = y0 + 6.575.
	var glow_mat := _FacadeMaterials.prop_material(
		&"canopy_glow", Color(0.4, 0.36, 0.28), 0.7, 0.0, Color(1.0, 0.82, 0.55), 2.2
	)
	_FacadeMeshKit.add_box_node(
		host, "CanopyGlow", Vector3(2.8, 0.05, 7.8), Vector3(cx, _BASE_Y + 6.575, z_mid),
		Vector3.ZERO, glow_mat, false, keep_out
	)

	var post_mat := _FacadeMaterials.concrete_material()
	var pump_mat := _FacadeMaterials.prop_material(&"pump", Color(0.7, 0.1, 0.1), 0.7, 0.2)
	for i in 2:
		var pu := mid + (2.0 * float(i) - 1.0) * 3.0
		_FacadeMeshKit.add_box_node(
			host, "CanopyPost%d" % i, Vector3(0.3, 6.6, 0.3),
			Vector3(ss * 8.0, _BASE_Y + 3.3, _z_at(plan, ss, pu)), Vector3.ZERO, post_mat, true,
			keep_out
		)
		var qu := mid + (2.0 * float(i) - 1.0) * 1.5
		_FacadeMeshKit.add_box_node(
			host, "Pump%d" % i, Vector3(0.5, 1.2, 0.4),
			Vector3(ss * 8.2, _BASE_Y + 0.6, _z_at(plan, ss, qu)), Vector3.ZERO, pump_mat, true,
			keep_out
		)

	var pole_c := Vector3(ss * 8.3, _BASE_Y + 3.5, _z_at(plan, ss, 1.0))
	var pole_mi := _FacadeMeshKit.add_box_node(
		host, "PricePole", Vector3(0.15, 7.0, 0.15), pole_c, Vector3.ZERO,
		_FacadeMaterials.iron_material(), true, keep_out
	)
	if pole_mi:
		var panel_size := Vector3(0.1, 1.2, 0.8)
		var panel_c := Vector3(pole_c.x, _BASE_Y + 7.6, pole_c.z)
		_FacadeSigns.build_boxed(
			host, "PriceSign", panel_c, panel_size, [Vector3(-ss, 0.0, 0.0)], keep_out,
			func(st: SurfaceTool) -> void:
				_FacadeSigns.emit_face_x(
					st, panel_c.x - ss * panel_size.x * 0.5, panel_c.y + panel_size.y * 0.5,
					panel_c.y - panel_size.y * 0.5, panel_c.z, panel_size.z, ss
				),
			_FacadeMaterials.sign_material(
				"0.95", 3, false, Color(1, 0.9, 0.7), 2.0, 0, 0.0, 0.0, 0.0, 4.0
			)
		)

	var light_c := Vector3(cx, _BASE_Y + 6.5, z_mid)
	if not keep_out.allows(_FacadeKeepOut.box_aabb(light_c, Vector3(0.2, 0.05, 0.2))):
		return
	if (
		not host.is_inside_tree()
		or host.get_tree().get_nodes_in_group(LIGHT_GROUP).size() >= MAX_LIGHTS
	):
		return
	var light := OmniLight3D.new()
	light.name = "CanopyLight"
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 1.5
	light.omni_range = 10.0
	light.shadow_enabled = false
	light.light_cull_mask = 1
	light.position = light_c
	light.add_to_group(LIGHT_GROUP)
	host.add_child(light)


## Widest plan at least 10 m wide: the canopy and its two pump bays need road frontage.
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
