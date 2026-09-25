extends FacadeSetPiece
## A rooftop water tower: four legs, a wood tank, a conical lid and a ladder on the road side.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const MAX_HEIGHT := 30.0
const TANK_RADIUS := 1.6
const LADDER_HEIGHT := 5.0
const LADDER_RUNGS := 8


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
	var width := float(plan[&"width"])
	var mid := width * 0.5
	var x_face := _FacadePlan.face_x(plan, side_sign)
	var y_top := _FacadePlan.roofline_y(plan)
	var base_x := x_face + side_sign * 0.8
	var z_mid := _z_at(plan, side_sign, mid)
	var leg_st := SurfaceTool.new()
	leg_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var legs_ok := false
	for du: float in [-0.9, 0.9]:
		for dx: float in [-0.5, 0.5]:
			var center := Vector3(base_x + dx, y_top + 1.5, _z_at(plan, side_sign, mid + du))
			legs_ok = _FacadeMeshKit.add_box(leg_st, center, Vector3(0.15, 3.0, 0.15), keep_out) or legs_ok
	if legs_ok:
		_FacadeMeshKit.commit(host, leg_st, "Legs", _FacadeMaterials.iron_material(), true)
	_FacadeMeshKit.add_cylinder_node(
		host, "Tank", TANK_RADIUS, TANK_RADIUS, 3.0, Vector3(base_x, y_top + 4.5, z_mid),
		_FacadeMaterials.prop_material(&"tank_wood", Color(0.3, 0.2, 0.14), 0.85, 0.1), true, keep_out
	)
	_FacadeMeshKit.add_cylinder_node(
		host, "Lid", 0.1, 1.75, 0.8, Vector3(base_x, y_top + 6.4, z_mid),
		_FacadeMaterials.metal_grey_material(), true, keep_out
	)
	_build_ladder(host, keep_out, x_face, side_sign, y_top, z_mid)


## Two rails plus rungs, gated once as a parent box: the road-facing rail decides for both.
func _build_ladder(
	host: Node3D, keep_out: RefCounted, x_face: float, side_sign: float, y_top: float, z_mid: float
) -> void:
	var ladder_x := x_face - side_sign * (TANK_RADIUS + 0.15)
	var rail_size := Vector3(0.05, LADDER_HEIGHT, 0.05)
	var rail_y := y_top + LADDER_HEIGHT * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not _FacadeMeshKit.add_box(st, Vector3(ladder_x, rail_y, z_mid - 0.3), rail_size, keep_out):
		return
	_FacadeMeshKit.add_box_ungated(st, Vector3(ladder_x, rail_y, z_mid + 0.3), rail_size)
	for i in LADDER_RUNGS:
		var ry := y_top + (float(i) + 1.0) * LADDER_HEIGHT / float(LADDER_RUNGS + 1)
		_FacadeMeshKit.add_box_ungated(st, Vector3(ladder_x, ry, z_mid), Vector3(0.05, 0.05, 0.6))
	_FacadeMeshKit.commit(host, st, "Ladder", _FacadeMaterials.iron_material(), false)


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
