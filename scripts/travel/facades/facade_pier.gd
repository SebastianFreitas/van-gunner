extends RefCounted
## A pier at a tile end beside a recessed lot: closes the slot between the neighbour tile's wall
## and the recessed face.


const _FacadeBody := preload("res://scripts/travel/facades/facade_body.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadeInfill := preload("res://scripts/travel/facades/facade_infill.gd")

const THICK := 0.3
## 5 cm inside the tile edge, like the body's deep return.
const Z_IN := 9.65
const Z_OUT := 9.95


## A pier at the low end of the first lot and the high end of the last, when that lot is recessed.
static func build(
	root: Node3D, plans: Array[Dictionary], side_sign: float, keep_out: RefCounted
) -> void:
	if plans.is_empty() or plans[0].get(&"mouth", false):
		return
	var last := plans.size() - 1
	_end(root, plans[0], side_sign, -1.0, "Pier0", keep_out)
	var high_name := "Pier%d" % last
	if last == 0:
		high_name = "Pier0High"
	_end(root, plans[last], side_sign, 1.0, high_name, keep_out)


## One pier box at the tile end zs (-1 low, +1 high) of a lot, skipped when the lot isn't recessed.
static func _end(
	root: Node3D, plan: Dictionary, side_sign: float, zs: float, node_name: String,
	keep_out: RefCounted
) -> void:
	var r := float(plan.get(&"recess", 0.0))
	if r <= 0.0:
		return
	var height := float(plan[&"height"])
	var x0 := side_sign * _FacadePlan.FACE_X
	var x1 := side_sign * (_FacadeInfill.PARTY_X + r)
	var z0 := zs * Z_IN
	var z1 := zs * Z_OUT
	var y0 := _FacadePlan.BASE_Y
	var y1 := y0 + height
	var center := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var size := Vector3(absf(x1 - x0), height, absf(z1 - z0))
	if not keep_out.allows(_FacadeKeepOut.box_aabb(center, size)):
		return
	var ax0 := absf(x0)
	var ax1 := absf(x1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Street end at the face line.
	_FacadeBody.add_quad(
		st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0),
		Vector2(z0, 0.0), Vector2(z1, 0.0), Vector2(z1, height), Vector2(z0, height),
		Vector3(-side_sign, 0.0, 0.0)
	)
	# The two z faces.
	for k in 2:
		var z := z0 if k == 0 else z1
		var nz := -zs if k == 0 else zs
		_FacadeBody.add_quad(
			st, Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z),
			Vector2(ax0, 0.0), Vector2(ax1, 0.0), Vector2(ax1, height), Vector2(ax0, height),
			Vector3(0.0, 0.0, nz)
		)
	# Top.
	_FacadeBody.add_quad(
		st, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1),
		Vector2(ax0, z0), Vector2(ax1, z0), Vector2(ax1, z1), Vector2(ax0, z1),
		Vector3(0.0, 1.0, 0.0)
	)
	if not _FacadeMeshKit.has_geometry(st):
		return
	# Party wall look with no rng draw, so the side's rng streams don't shift.
	var seed_value := float(hash([float(plan[&"params"][&"seed"]), &"pier"]) % 1000)
	var material := _FacadeMaterials.facade_material(
		_FacadeInfill._params(&"concrete_grey", 4.0 + r, height, seed_value, {})
	)
	_FacadeMeshKit.commit(root, st, node_name, material, false)
