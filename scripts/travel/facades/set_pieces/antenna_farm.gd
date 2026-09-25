extends FacadeSetPiece
## A cluster of roof masts of random height, two tilted dish plates and a beacon light atop the
## tallest mast.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const MAX_HEIGHT := 32.0


func can_apply(plans: Array[Dictionary]) -> bool:
	return _target_index(plans) != -1


func pick_plan(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> int:
	return _target_index(plans)


func apply_plans(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	var target := _target_index(plans)
	if target != -1:
		plans[target][&"rare"] = id


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var side_sign: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var width := float(plan[&"width"])
	var x_face := _FacadePlan.face_x(plan, side_sign)
	var y_top := _FacadePlan.roofline_y(plan)
	var mast_st := SurfaceTool.new()
	mast_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tallest_h := -1.0
	var tallest_center := Vector3.ZERO
	var tallest_placed := false
	for i in rng.randi_range(6, 10):
		var h := rng.randf_range(6.0, 14.0)
		var u := rng.randf_range(1.0, width - 1.0)
		var mast_x := x_face + side_sign * rng.randf_range(0.3, 1.0)
		var center := Vector3(mast_x, y_top + h * 0.5, _z_at(plan, side_sign, u))
		var placed := _FacadeMeshKit.add_box(mast_st, center, Vector3(0.08, h, 0.08), keep_out)
		if placed and h > tallest_h:
			tallest_h = h
			tallest_center = center
			tallest_placed = true
	_FacadeMeshKit.commit(host, mast_st, "Masts", _FacadeMaterials.iron_material(), true)
	var dish_mat := _FacadeMaterials.metal_grey_material()
	for i in 2:
		var dish_u := rng.randf_range(1.0, width - 1.0)
		var dish_x := x_face + side_sign * rng.randf_range(0.3, 1.0)
		_FacadeMeshKit.add_box_node(
			host, "Dish%d" % i, Vector3(1.2, 0.08, 1.2),
			Vector3(dish_x, y_top + 1.0, _z_at(plan, side_sign, dish_u)),
			Vector3(deg_to_rad(60.0), 0.0, 0.0), dish_mat, true, keep_out
		)
	if tallest_placed:
		var beacon_center := tallest_center + Vector3(0.0, tallest_h * 0.5 + 0.125, 0.0)
		var beacon_mat := _FacadeMaterials.prop_material(
			&"beacon_red", Color(0.6, 0.05, 0.05), 0.7, 0.0, Color(1.0, 0.1, 0.1), 3.0
		)
		_FacadeMeshKit.add_box_node(
			host, "Beacon", Vector3(0.25, 0.25, 0.25), beacon_center, Vector3.ZERO, beacon_mat,
			false, keep_out
		)


func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_height := INF
	for i in plans.size():
		var height := float(plans[i].get(&"height", 0.0))
		if height <= MAX_HEIGHT and height < best_height:
			best_height = height
			best = i
	return best


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u
