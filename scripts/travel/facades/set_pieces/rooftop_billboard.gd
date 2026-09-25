extends FacadeSetPiece
## A lit billboard panel on two posts atop the shortest eligible roof, with flood lights at its
## base; the panel's text face reuses facade_signs.gd's two-surface box-sign technique.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeSigns := preload("res://scripts/travel/facades/facade_signs.gd")

const MAX_HEIGHT := 28.0
const MAX_TOP_Y := 40.0
const WORDS: Array[String] = [
	"DRINK COLA", "MOTEL", "NEW HOMES", "GAS", "SMILE", "VOTE NOW", "BIG SALE", "LOTTO",
]
const _COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.3), Color(1.0, 0.75, 0.2), Color(0.3, 0.9, 1.0), Color(0.4, 1.0, 0.5),
	Color(1.0, 0.4, 0.8),
]


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
	var mid := width * 0.5
	var wide := width >= 10.0
	var x_face := _FacadePlan.face_x(plan, side_sign)
	var y_top := _FacadePlan.roofline_y(plan)
	var post_x := x_face + side_sign * 0.6
	var panel_size := Vector3(0.15, 4.0, 9.0) if wide else Vector3(0.15, 3.0, 6.0)
	var panel_center := Vector3(post_x, y_top + 4.5, _z_at(plan, side_sign, mid))
	if panel_center.y + panel_size.y * 0.5 > MAX_TOP_Y:
		return
	if not keep_out.allows(_FacadeKeepOut.box_aabb(panel_center, panel_size)):
		return
	var offset := 3.5 if wide else 2.0
	var post_st := SurfaceTool.new()
	post_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for u: float in [mid - offset, mid + offset]:
		_FacadeMeshKit.add_box_ungated(
			post_st, Vector3(post_x, y_top + 1.25, _z_at(plan, side_sign, u)),
			Vector3(0.2, 2.5, 0.2)
		)
	_FacadeMeshKit.commit(host, post_st, "Posts", _FacadeMaterials.iron_material(), true)
	var word: String = WORDS[rng.randi() % WORDS.size()]
	var color: Color = _COLORS[rng.randi() % _COLORS.size()]
	var sign_mat := _FacadeMaterials.sign_material(
		word, 5, false, color, 2.0, 0, float(ctx[&"tile_seed"]), 0.0, 0.0, 8.0
	)
	_FacadeSigns.build_boxed(
		host, "Panel", panel_center, panel_size, [Vector3(-side_sign, 0.0, 0.0)], keep_out,
		func(st: SurfaceTool) -> void:
			_FacadeSigns.emit_face_x(
				st, panel_center.x - side_sign * panel_size.x * 0.5,
				panel_center.y + panel_size.y * 0.5, panel_center.y - panel_size.y * 0.5,
				panel_center.z, panel_size.z, side_sign
			),
		sign_mat
	)
	var flood_st := SurfaceTool.new()
	flood_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flood_y := panel_center.y - panel_size.y * 0.5
	for dz: float in [-panel_size.z * 0.5 + 0.5, panel_size.z * 0.5 - 0.5]:
		_FacadeMeshKit.add_box_ungated(
			flood_st, Vector3(post_x, flood_y, panel_center.z + dz), Vector3(0.15, 0.15, 0.5)
		)
	var flood_mat := _FacadeMaterials.prop_material(
		&"flood", Color(0.4, 0.36, 0.28), 0.7, 0.2, Color(1.0, 0.8, 0.5), 2.5
	)
	_FacadeMeshKit.commit(host, flood_st, "Floods", flood_mat, false)


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
