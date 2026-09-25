extends RefCounted
## Facade spans for walls that are not corridor tile sides (junction stems, branches, the T far
## wall, side-street flanks): a host node maps the tile body builder's frame onto any wall plane.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeBody := preload("res://scripts/travel/facades/facade_body.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")


## Builds one wall's worth of buildings on the plane through face_mid with outward normal
## `normal`, spanning `length` metres along it; the host node is parented to `parent` and returned.
static func build_span(
	parent: Node3D, span_name: String, face_mid: Vector3, normal: Vector3, length: float,
	rng: RandomNumberGenerator, district: FacadeDistrict, neighborhood_seed: int
) -> Node3D:
	var into := -normal.normalized()
	var along := into.cross(Vector3.UP)
	var host := Node3D.new()
	host.name = span_name
	host.transform = Transform3D(
		Basis(into, Vector3.UP, along), face_mid - into * _FacadePlan.FACE_X
	)
	parent.add_child(host)
	var plans := _FacadePlan.plan_length(rng, district, length, neighborhood_seed)
	for i in plans.size():
		_FacadeBody.build(host, plans[i], 1.0, i)
	for child in host.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).visibility_range_end = 64.0
	return host


## A plain concrete post that hides the seam where two spans meet at a junction corner.
static func build_corner_tower(
	parent: Node3D, tower_name: String, position: Vector3, height: float
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = tower_name
	var box := BoxMesh.new()
	box.size = Vector3(0.8, height, 0.8)
	mi.mesh = box
	mi.material_override = _FacadeMaterials.concrete_material()
	mi.position = position + Vector3(0.0, height * 0.5 - 0.4, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.visibility_range_end = 64.0
	parent.add_child(mi)
	return mi
