extends FacadeSetPiece
## A commercial tower stretched to its full height, capped with a glowing crown band and a red
## beacon on a roof mast.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const _BASE_Y := _FacadePlan.BASE_Y
const _CROWN_HEIGHT := 40.0


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
	params[&"style"] = 3
	plan[&"height"] = _CROWN_HEIGHT
	params[&"facade_height"] = _CROWN_HEIGHT
	var floors_raw := (
		(_CROWN_HEIGHT - _FacadePlan.GROUND_HEIGHT - _FacadePlan.PARAPET) / _FacadePlan.FLOOR_HEIGHT
	)
	plan[&"floors"] = maxi(1, int(floor(floors_raw)))
	params[&"lit_ratio"] = 0.45
	params[&"lit_color"] = Color(0.8, 0.88, 1.0)
	plan[&"rare"] = id
	plan[&"suppress"] = [&"fire_escape", &"balconies", &"ac_units", &"roof_clutter"]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var ss: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var width := float(plan[&"width"])
	var xf := _FacadePlan.face_x(plan, ss)
	var mid_z := _z_at(plan, ss, width * 0.5)

	var band_center := Vector3(_out_x(xf, ss, 0.3), _BASE_Y + 38.5, mid_z)
	var band_st := SurfaceTool.new()
	band_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if _FacadeMeshKit.add_box(band_st, band_center, Vector3(0.3, 2.0, width), keep_out):
		_FacadeMeshKit.commit(
			host, band_st, "Crown",
			_FacadeMaterials.prop_material(
				&"crown_glow", Color(0.5, 0.7, 0.9), 0.3, 0.2, Color(0.6, 0.8, 1.0), 2.4
			),
			false
		)

	var y_top := _FacadePlan.roofline_y(plan)
	var mast_x := xf + ss * 0.6
	var mast_center := Vector3(mast_x, y_top + 1.5, mid_z)
	var mast_st := SurfaceTool.new()
	mast_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if _FacadeMeshKit.add_box(mast_st, mast_center, Vector3(0.1, 3.0, 0.1), keep_out):
		_FacadeMeshKit.commit(host, mast_st, "CrownBeacon", _FacadeMaterials.iron_material(), true)
		var beacon_mat := _FacadeMaterials.prop_material(
			&"beacon_red", Color(0.6, 0.05, 0.05), 0.5, 0.0, Color(1.0, 0.1, 0.1), 3.0
		)
		_FacadeMeshKit.add_box_node(
			host, "Beacon", Vector3(0.3, 0.3, 0.3), Vector3(mast_x, y_top + 3.15, mid_z),
			Vector3.ZERO, beacon_mat, false, keep_out
		)


## Widest plan; the crown stretches whichever building it lands on to full height.
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
		var width := float(plans[i].get(&"width", 0.0))
		if width > best_width:
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
