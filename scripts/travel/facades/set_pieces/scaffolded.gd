extends FacadeSetPiece
## A construction scaffold over the lower floors: two rows of standards joined by ledgers and
## transoms, a work plank on each level, and a green safety net over the whole rig.


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
	plans[target][&"rare"] = id
	plans[target][&"suppress"] = [
		&"balconies", &"fire_escape", &"ac_units", &"wall_pipes", &"signs",
	]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var ss: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var width := float(plan[&"width"])
	var xf := _FacadePlan.face_x(plan, ss)
	# Set-back relative offsets (not absolute x): a max setback still clears the lane box, see
	# docs/tasks/buildings/spec_08b_notes.md's geometry correction for the exact numbers.
	var mid_x := xf - ss * 0.575
	var lines: Array[float] = []
	for k in 4:
		lines.append(_BASE_Y + _GROUND_H + float(k) * _FLOOR_H)
	var mid_y := (lines[0] + lines[3]) * 0.5
	var posts: Array[float] = []
	var u := 1.0
	while u < width:
		posts.append(_z_at(plan, ss, u))
		u += 2.0
	var mid_z := _z_at(plan, ss, width * 0.5)
	var tube_st := SurfaceTool.new()
	tube_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tube_added := false
	for row_x: float in [xf - ss * 0.35, xf - ss * 0.8]:
		for z: float in posts:
			var post_c := Vector3(row_x, mid_y, z)
			var post_size := Vector3(0.05, 9.6, 0.05)
			var post_ok := _FacadeMeshKit.add_box(tube_st, post_c, post_size, keep_out)
			tube_added = post_ok or tube_added
		for line_y: float in lines:
			var ledger_c := Vector3(row_x, line_y, mid_z)
			var ledger_size := Vector3(0.05, 0.05, width)
			var ledger_ok := _FacadeMeshKit.add_box(tube_st, ledger_c, ledger_size, keep_out)
			tube_added = ledger_ok or tube_added
	for line_y: float in lines:
		for z: float in posts:
			var transom_c := Vector3(mid_x, line_y, z)
			var transom_size := Vector3(0.5, 0.05, 0.05)
			var transom_ok := _FacadeMeshKit.add_box(tube_st, transom_c, transom_size, keep_out)
			tube_added = transom_ok or tube_added
	if tube_added:
		_FacadeMeshKit.commit(
			host, tube_st, "ScaffoldTubes", _FacadeMaterials.iron_material(), false
		)
	var plank_st := SurfaceTool.new()
	plank_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plank_added := false
	for k in 3:
		var added := _FacadeMeshKit.add_box(
			plank_st, Vector3(mid_x, lines[k], mid_z), Vector3(0.5, 0.04, width), keep_out
		)
		plank_added = added or plank_added
	if plank_added:
		_FacadeMeshKit.commit(
			host, plank_st, "ScaffoldPlanks",
			_FacadeMaterials.prop_material(&"plank", Color(0.45, 0.35, 0.2), 0.95, 0.0), false
		)
	var net_mat := _FacadeMaterials.prop_material(&"net", Color(0.2, 0.5, 0.3, 0.55), 0.9, 0.0)
	net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var net_st := SurfaceTool.new()
	net_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var net_c := Vector3(xf - ss * 0.85, mid_y, mid_z)
	if _FacadeMeshKit.add_box(net_st, net_c, Vector3(0.01, 9.6, width), keep_out):
		_FacadeMeshKit.commit(host, net_st, "ScaffoldNet", net_mat, false)


## Widest plan at least 8 m wide: the scaffold needs room for two rows of standards.
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
		var width := float(plans[i].get(&"width", 0.0))
		if width >= 8.0 and width > best_width:
			best_width = width
			best = i
	return best


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u
