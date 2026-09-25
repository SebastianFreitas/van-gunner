extends FacadeSetPiece
## A tower crane grafted onto a bare industrial frame: a green safety net over the low floors, a
## lattice mast standing on the roof, a jib and counter-jib, a hanging hook, and a roof beacon.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const _BASE_Y := _FacadePlan.BASE_Y
const _GROUND_H := _FacadePlan.GROUND_HEIGHT
const _FLOOR_H := _FacadePlan.FLOOR_HEIGHT
## The mast always tops out at tile y 44.0, whatever the building's clamped height ends up being.
const _MAST_TOP := 44.0


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
	params[&"ground_kind"] = _FacadePlan.GROUND_BLANK
	plan[&"ground_kind"] = _FacadePlan.GROUND_BLANK
	var height: float = clampf(float(plan[&"height"]), 16.0, 28.0)
	plan[&"height"] = height
	params[&"facade_height"] = height
	var floors_raw := (
		(height - _FacadePlan.GROUND_HEIGHT - _FacadePlan.PARAPET) / _FacadePlan.FLOOR_HEIGHT
	)
	plan[&"floors"] = maxi(1, int(floor(floors_raw)))
	plan[&"rare"] = id
	plan[&"suppress"] = [
		&"ac_units", &"fire_escape", &"balconies", &"wall_pipes", &"roof_clutter", &"signs",
	]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var ss: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var width := float(plan[&"width"])
	var height := float(plan[&"height"])
	var xf := _FacadePlan.face_x(plan, ss)
	var y_top := _FacadePlan.roofline_y(plan)
	var mid_z := _z_at(plan, ss, width * 0.5)

	# Set-back relative to xf (not absolute x), so a setback building still clears the lane box.
	var net_mat := _FacadeMaterials.prop_material(&"net", Color(0.2, 0.5, 0.3, 0.55), 0.9, 0.0)
	net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var net_y := _BASE_Y + _GROUND_H + 1.5 * _FLOOR_H
	_FacadeMeshKit.add_box_node(
		host, "CraneNet", Vector3(0.02, 9.6, width - 1.0), Vector3(xf - ss * 0.6, net_y, mid_z),
		Vector3.ZERO, net_mat, false, keep_out
	)

	var mast_h := _MAST_TOP - height
	var mast_c := Vector3(xf + ss * 1.0, y_top + mast_h * 0.5, _z_at(plan, ss, width - 3.0))
	var mast_st := SurfaceTool.new()
	mast_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mast_added := _FacadeMeshKit.add_box(mast_st, mast_c, Vector3(0.5, mast_h, 0.5), keep_out)
	if mast_added:
		for k in 6:
			var cy := mast_c.y - mast_h * 0.5 + mast_h / 7.0 * float(k + 1)
			_FacadeMeshKit.add_box_ungated(
				mast_st, Vector3(mast_c.x, cy, mast_c.z), Vector3(0.5, 0.06, 0.5)
			)
		_FacadeMeshKit.commit(host, mast_st, "CraneMast", _FacadeMaterials.iron_material(), true)

	var iron := _FacadeMaterials.iron_material()
	var yellow := _FacadeMaterials.prop_material(&"crane_yellow", Color(0.85, 0.6, 0.1), 0.6, 0.3)
	var jib_y := y_top + mast_h - 0.4
	var jib_yaw := rng.randf_range(-0.3, 0.3)
	var jib_c := Vector3(xf - ss * 6.0, jib_y, mast_c.z)
	_FacadeMeshKit.add_box_node(
		host, "CraneJib", Vector3(14.0, 0.8, 0.8), jib_c, Vector3(0.0, jib_yaw, 0.0), yellow, true,
		keep_out
	)
	var counter_c := Vector3(mast_c.x + ss * 2.5, jib_y, mast_c.z)
	_FacadeMeshKit.add_box_node(
		host, "CraneCounterJib", Vector3(5.0, 0.8, 0.8), counter_c, Vector3(0.0, jib_yaw, 0.0),
		yellow, true, keep_out
	)

	var hook_x := jib_c.x - ss * 4.5
	_FacadeMeshKit.add_box_node(
		host, "HookCable", Vector3(0.03, 12.0, 0.03), Vector3(hook_x, jib_y - 6.0, mast_c.z),
		Vector3.ZERO, iron, false, keep_out
	)
	_FacadeMeshKit.add_box_node(
		host, "HookBlock", Vector3(0.4, 0.6, 0.4), Vector3(hook_x, jib_y - 12.3, mast_c.z),
		Vector3.ZERO, iron, true, keep_out
	)

	var beacon_mat := _FacadeMaterials.prop_material(
		&"beacon_red", Color(0.6, 0.05, 0.05), 0.5, 0.0, Color(1.0, 0.1, 0.1), 3.0
	)
	_FacadeMeshKit.add_box_node(
		host, "Beacon", Vector3(0.25, 0.25, 0.25),
		Vector3(mast_c.x, mast_c.y + mast_h * 0.5 + 0.125, mast_c.z), Vector3.ZERO, beacon_mat,
		false, keep_out
	)


## Widest plan at least 10 m wide: the crane rig needs road frontage.
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
