extends FacadeSetPiece
## A building half-swallowed by growth: the shader crops it at a collapse edge, ivy hangs from
## the sills below that line, and a couple of saplings have taken root on the exposed roofline.


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


func apply_plans(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	var target := _target_index(plans)
	if target == -1:
		return
	var plan: Dictionary = plans[target]
	var params: Dictionary = plan[&"params"]
	params[&"overgrowth"] = 0.7
	params[&"collapse_y"] = float(plan[&"height"]) * 0.6
	params[&"lit_ratio"] = 0.0
	params[&"broken_ratio"] = 0.5
	params[&"damage"] = 0.5
	plan[&"rare"] = id
	plan[&"suppress"] = [
		&"trim", &"ac_units", &"fire_escape", &"balconies", &"roof_clutter", &"wall_pipes",
		&"signs",
	]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var side_sign: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var width := float(plan[&"width"])
	var floors := int(plan[&"floors"])
	var params: Dictionary = plan[&"params"]
	var pitch := float(params.get(&"window_pitch", 2.6))
	var sill := float(params.get(&"window_sill", 0.9))
	var cols := maxi(1, floori((width - 0.3) / pitch))
	var collapse_y := float(params.get(&"collapse_y", 12.0))
	var x_face := _FacadePlan.face_x(plan, side_sign)

	var vine_st := SurfaceTool.new()
	vine_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vine_added := false
	for i in rng.randi_range(4, 8):
		var col := rng.randi_range(0, cols - 1)
		var k := rng.randi_range(1, floors)
		var u := (float(col) + 0.5) * pitch
		var sill_y := _GROUND_H + float(k - 1) * _FLOOR_H + sill
		if sill_y >= collapse_y:
			continue
		var vine_h := rng.randf_range(1.0, 3.0)
		var center := Vector3(
			x_face - side_sign * 0.04, _BASE_Y + sill_y - vine_h * 0.5, _z_at(plan, side_sign, u)
		)
		var vine_ok := _FacadeMeshKit.add_box(vine_st, center, Vector3(0.06, vine_h, 0.5), keep_out)
		vine_added = vine_ok or vine_added
	if vine_added:
		_FacadeMeshKit.commit(
			host, vine_st, "Vines",
			_FacadeMaterials.prop_material(&"vine", Color(0.08, 0.14, 0.05), 0.95, 0.0), true
		)

	var sap_st := SurfaceTool.new()
	sap_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sap_added := false
	for i in rng.randi_range(2, 3):
		var u := rng.randf_range(1.0, width - 1.0)
		var base_x := x_face + side_sign * 0.5
		var z := _z_at(plan, side_sign, u)
		var trunk_center := Vector3(base_x, _BASE_Y + collapse_y + 0.6, z)
		var passed := _FacadeMeshKit.add_box(sap_st, trunk_center, Vector3(0.1, 1.2, 0.1), keep_out)
		if passed:
			_FacadeMeshKit.add_box_ungated(
				sap_st, Vector3(base_x, _BASE_Y + collapse_y + 1.65, z), Vector3(0.8, 0.9, 0.8)
			)
		sap_added = passed or sap_added
	if sap_added:
		_FacadeMeshKit.commit(
			host, sap_st, "Saplings",
			_FacadeMaterials.prop_material(&"sapling", Color(0.12, 0.22, 0.08), 0.95, 0.0), true
		)


## Widest plan; a collapse crop suits any size.
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
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
