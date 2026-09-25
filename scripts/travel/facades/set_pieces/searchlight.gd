extends FacadeSetPiece
## A rooftop searchlight sweeping a tilted cone over the street: a pedestal and housing on the
## roof, with a beam mesh spun by scripts/travel/facades/set_pieces/searchlight_pivot.gd.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const MAX_HEIGHT := 34.0
const _PIVOT_SCRIPT := preload("res://scripts/travel/facades/set_pieces/searchlight_pivot.gd")


func can_apply(plans: Array[Dictionary]) -> bool:
	return _target_index(plans) != -1


func pick_plan(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> int:
	return _target_index(plans)


func apply_plans(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	var target := _target_index(plans)
	if target != -1:
		plans[target][&"rare"] = id
		plans[target][&"suppress"] = [&"roof_clutter"]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var ss: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var width := float(plan[&"width"])
	var x_face := _FacadePlan.face_x(plan, ss)
	var y_top := _FacadePlan.roofline_y(plan)
	var z_mid := _z_at(plan, ss, width * 0.5)
	var post_x := x_face + ss * 0.6

	_FacadeMeshKit.add_box_node(
		host, "SearchlightPedestal", Vector3(1.0, 1.0, 1.0), Vector3(post_x, y_top + 0.5, z_mid),
		Vector3.ZERO, _FacadeMaterials.concrete_material(), true, keep_out
	)
	_FacadeMeshKit.add_cylinder_node(
		host, "SearchlightHousing", 0.5, 0.5, 0.8, Vector3(post_x, y_top + 1.4, z_mid),
		_FacadeMaterials.metal_grey_material(), true, keep_out
	)

	# The beam is 30 m tall and starts at roof height, so a conservative box centred on the pivot
	# and reaching upward (never downward) is enough to gate it.
	var pivot_pos := Vector3(post_x, y_top + 1.8, z_mid)
	var gate := AABB(pivot_pos + Vector3(-15.0, 0.0, -15.0), Vector3(30.0, 30.0, 30.0))
	if not keep_out.allows(gate):
		return
	var pivot := Node3D.new()
	pivot.name = "SearchlightPivot"
	pivot.set_script(_PIVOT_SCRIPT)
	pivot.set(&"tilt", -ss * 0.6)
	pivot.position = pivot_pos
	host.add_child(pivot)

	var beam := MeshInstance3D.new()
	beam.name = "SearchlightBeam"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.0
	cyl.bottom_radius = 0.3
	cyl.height = 30.0
	beam.mesh = cyl
	beam.material_override = _FacadeMaterials.beam_material()
	beam.position = Vector3(0.0, 15.0, 0.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(beam)


## Lowest plan of MAX_HEIGHT or less: a taller roof would put the pivot out of scale.
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
