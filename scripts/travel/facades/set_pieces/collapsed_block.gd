extends FacadeSetPiece
## A building torn open partway up: the shader discards everything above a noisy collapse edge,
## and rubble, standing rebar and two ragged slab stubs sell the wreckage at the base.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const _BASE_Y := _FacadePlan.BASE_Y
const _GROUND_H := _FacadePlan.GROUND_HEIGHT
const _FLOOR_H := _FacadePlan.FLOOR_HEIGHT


func can_apply(plans: Array[Dictionary]) -> bool:
	return _target_index(plans) != -1


func pick_plan(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> int:
	return _target_index(plans)


func apply_plans(plans: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var target := _target_index(plans)
	if target == -1:
		return
	var plan: Dictionary = plans[target]
	var params: Dictionary = plan[&"params"]
	params[&"collapse_y"] = rng.randf_range(12.0, minf(20.0, float(plan[&"height"]) - 4.0))
	params[&"damage"] = 0.6
	params[&"broken_ratio"] = 0.4
	params[&"lit_ratio"] = 0.0
	plan[&"rare"] = id
	plan[&"suppress"] = [
		&"trim", &"ac_units", &"fire_escape", &"balconies", &"roof_clutter", &"wall_pipes",
		&"signs",
	]
	(plan[&"tags"] as Array[StringName]).append(&"collapsed")


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var side_sign: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var width := float(plan[&"width"])
	var collapse_y := float(plan[&"params"].get(&"collapse_y", 12.0))
	var rubble_x := side_sign * 8.25
	var rubble_st := SurfaceTool.new()
	rubble_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rubble_added := false
	for i in rng.randi_range(8, 14):
		var size := Vector3(
			rng.randf_range(0.3, 0.9), rng.randf_range(0.3, 0.9), rng.randf_range(0.3, 0.9)
		)
		var center := Vector3(
			rubble_x, size.y * 0.5 - 0.06, _z_at(plan, side_sign, rng.randf_range(0.3, width - 0.3))
		)
		if keep_out.allows(_FacadeKeepOut.box_aabb(center, size, rng.randf_range(0.0, TAU))):
			_FacadeMeshKit.add_box_ungated(rubble_st, center, size)
			rubble_added = true
	if rubble_added:
		_FacadeMeshKit.commit(
			host, rubble_st, "Rubble",
			_FacadeMaterials.prop_material(&"rubble", Color(0.22, 0.21, 0.2), 0.95, 0.0), true
		)
	var iron := _FacadeMaterials.iron_material()
	for i in 4:
		var center := Vector3(
			rubble_x, 0.69, _z_at(plan, side_sign, rng.randf_range(0.3, width - 0.3))
		)
		var rot := Vector3(
			rng.randf_range(-0.3, 0.3), 0.0,
			(1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.3, 0.6)
		)
		_FacadeMeshKit.add_box_node(
			host, "Rebar%d" % i, Vector3(0.03, 1.5, 0.03), center, rot, iron, true, keep_out
		)
	var lines: Array[float] = []
	var k := 0
	while _GROUND_H + float(k) * _FLOOR_H < collapse_y and k <= int(plan[&"floors"]):
		lines.append(_GROUND_H + float(k) * _FLOOR_H)
		k += 1
	if lines.size() > 2:
		lines = lines.slice(lines.size() - 2, lines.size())
	if lines.is_empty():
		return
	var x_face := _FacadePlan.face_x(plan, side_sign)
	var stub_st := SurfaceTool.new()
	stub_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stub_added := false
	var size := Vector3(0.8, 0.3, 2.0)
	for i in rng.randi_range(2, 3):
		var center := Vector3(
			x_face - side_sign * (0.02 + size.x * 0.5), _BASE_Y + lines[i % lines.size()],
			_z_at(plan, side_sign, rng.randf_range(1.0, width - 1.0))
		)
		stub_added = _FacadeMeshKit.add_box(stub_st, center, size, keep_out) or stub_added
	if stub_added:
		_FacadeMeshKit.commit(
			host, stub_st, "SlabStubs", _FacadeMaterials.concrete_material(), true
		)


## Greatest-height plan of at least 18 m; a shorter roof would leave nothing to collapse into.
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_h := -1.0
	for i in plans.size():
		var h := float(plans[i].get(&"height", 0.0))
		if h >= 18.0 and h > best_h:
			best_h = h
			best = i
	return best


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u
