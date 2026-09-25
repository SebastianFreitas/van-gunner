extends FacadeSetPiece
## A lattice radio mast on a low roof: three legs and cross rings every 2.5 m, two guy lines
## anchoring it to the roof, and a beacon at the top.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const MAX_HEIGHT := 30.0
const MAST_HEIGHT := 15.0
const EDGE := 0.6


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
	var side_sign: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var width := float(plan[&"width"])
	var x_face := _FacadePlan.face_x(plan, side_sign)
	var y_top := _FacadePlan.roofline_y(plan)
	var mast_x := x_face + side_sign * 0.7
	var mid_z := _z_at(plan, side_sign, width * 0.5)
	var iron := _FacadeMaterials.iron_material()

	# Legs at the corners of an EDGE-metre equilateral triangle: apex out along x, base along z.
	var tri_h := EDGE * sqrt(3.0) * 0.5
	var apex_dx := tri_h * 2.0 / 3.0
	var base_dx := -tri_h / 3.0
	var half_edge := EDGE * 0.5
	var mast_mid_y := y_top + MAST_HEIGHT * 0.5
	var mast_top := y_top + MAST_HEIGHT

	var mast_st := SurfaceTool.new()
	mast_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mast_added := false
	var leg_offsets: Array[Vector2] = [
		Vector2(apex_dx, 0.0), Vector2(base_dx, half_edge), Vector2(base_dx, -half_edge),
	]
	for off: Vector2 in leg_offsets:
		var center := Vector3(mast_x + side_sign * off.x, mast_mid_y, mid_z + off.y)
		var leg_size := Vector3(0.08, MAST_HEIGHT, 0.08)
		mast_added = _FacadeMeshKit.add_box(mast_st, center, leg_size, keep_out) or mast_added

	# Rings every 2.5 m: the base edge is flat (added to the same batch), the two edges to the
	# apex are slanted and need their own rotation, so they go through add_box_node.
	var ring_y := y_top + 2.5
	var ring_idx := 0
	var yaw := side_sign * (PI / 3.0)
	var mid_dx := (apex_dx + base_dx) * 0.5
	while ring_y < mast_top:
		var bc_center := Vector3(mast_x + side_sign * base_dx, ring_y, mid_z)
		var bc_size := Vector3(0.08, 0.08, EDGE)
		mast_added = _FacadeMeshKit.add_box(mast_st, bc_center, bc_size, keep_out) or mast_added
		_FacadeMeshKit.add_box_node(
			host, "MastRing%d" % ring_idx, Vector3(0.08, 0.08, EDGE),
			Vector3(mast_x + side_sign * mid_dx, ring_y, mid_z + half_edge * 0.5),
			Vector3(0.0, -yaw, 0.0), iron, false, keep_out
		)
		ring_idx += 1
		_FacadeMeshKit.add_box_node(
			host, "MastRing%d" % ring_idx, Vector3(0.08, 0.08, EDGE),
			Vector3(mast_x + side_sign * mid_dx, ring_y, mid_z - half_edge * 0.5),
			Vector3(0.0, yaw, 0.0), iron, false, keep_out
		)
		ring_idx += 1
		ring_y += 2.5
	if mast_added:
		_FacadeMeshKit.commit(host, mast_st, "Mast", iron, true)

	var guy_center := Vector3(mast_x, y_top + MAST_HEIGHT * 0.5, mid_z)
	for i in 2:
		var lean := 0.35 if i == 0 else -0.35
		_FacadeMeshKit.add_box_node(
			host, "GuyLine%d" % i, Vector3(0.02, 12.0, 0.02), guy_center, Vector3(0.0, 0.0, lean),
			iron, false, keep_out
		)

	var beacon_mat := _FacadeMaterials.prop_material(
		&"beacon_red", Color(0.6, 0.05, 0.05), 0.5, 0.0, Color(1.0, 0.1, 0.1), 3.0
	)
	_FacadeMeshKit.add_box_node(
		host, "Beacon", Vector3(0.25, 0.25, 0.25), Vector3(mast_x, mast_top + 0.125, mid_z),
		Vector3.ZERO, beacon_mat, false, keep_out
	)


## Lowest plan of 30 m or less: a tall roof would bury the mast against the header.
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
