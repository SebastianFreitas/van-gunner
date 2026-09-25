extends FacadeSetPiece
## A storefront gutted by fire: a charred black-out panel behind the first unit's glass, rubble
## kicked out onto the sidewalk, and police tape strung across the doorway.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
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
	var params: Dictionary = plans[target][&"params"]
	params[&"lit_ratio"] = 0.05
	params[&"soot"] = 0.8
	plans[target][&"rare"] = id
	plans[target][&"suppress"] = [&"awnings", &"furniture", &"signs"]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var side_sign: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var width := float(plan[&"width"])
	var units: int = plan[&"ground_units"]
	var unit_w := width / float(units)
	var x_face := _FacadePlan.face_x(plan, side_sign)
	var z_mid := _z_at(plan, side_sign, unit_w * 0.5)

	var panel_center := Vector3(x_face - side_sign * 0.03, _BASE_Y + 1.95, z_mid)
	var panel_st := SurfaceTool.new()
	panel_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if _FacadeMeshKit.add_box(panel_st, panel_center, Vector3(0.02, 2.9, unit_w - 1.0), keep_out):
		_FacadeMeshKit.commit(
			host, panel_st, "Charred",
			_FacadeMaterials.prop_material(&"charred", Color(0.02, 0.02, 0.02), 0.95, 0.0), false
		)

	var debris_x := side_sign * 8.25
	var debris_st := SurfaceTool.new()
	debris_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var debris_added := false
	for i in 3:
		var size := Vector3(
			rng.randf_range(0.4, 0.8), rng.randf_range(0.4, 0.8), rng.randf_range(0.4, 0.8)
		)
		var z := _z_at(plan, side_sign, rng.randf_range(0.3, unit_w - 0.3))
		var center := Vector3(debris_x, size.y * 0.5 - 0.06, z)
		if keep_out.allows(_FacadeKeepOut.box_aabb(center, size, rng.randf_range(0.0, TAU))):
			_FacadeMeshKit.add_box_ungated(debris_st, center, size)
			debris_added = true
	if debris_added:
		_FacadeMeshKit.commit(
			host, debris_st, "ShopDebris",
			_FacadeMaterials.prop_material(&"rubble", Color(0.22, 0.21, 0.2), 0.95, 0.0), true
		)

	var tape_center := Vector3(side_sign * 7.75, _BASE_Y + 1.2, z_mid)
	var tape_st := SurfaceTool.new()
	tape_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if _FacadeMeshKit.add_box(tape_st, tape_center, Vector3(0.02, 0.08, unit_w), keep_out):
		_FacadeMeshKit.commit(
			host, tape_st, "Tape",
			_FacadeMaterials.prop_material(&"tape", Color(0.95, 0.85, 0.1), 0.6, 0.0), false
		)
		var post_st := SurfaceTool.new()
		post_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for dz: float in [-unit_w * 0.5, unit_w * 0.5]:
			_FacadeMeshKit.add_box_ungated(
				post_st, Vector3(side_sign * 7.75, _BASE_Y + 0.6, z_mid + dz),
				Vector3(0.05, 1.2, 0.05)
			)
		_FacadeMeshKit.commit(host, post_st, "TapePosts", _FacadeMaterials.iron_material(), true)


## Widest storefront plan; a boarded or dock unit has no glass to blow out.
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
		if int(plans[i].get(&"ground_kind", -1)) != _FacadePlan.GROUND_STOREFRONT:
			continue
		var width := float(plans[i].get(&"width", 0.0))
		if width > best_width:
			best_width = width
			best = i
	return best


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u
