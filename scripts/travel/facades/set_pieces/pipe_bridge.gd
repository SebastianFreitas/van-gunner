extends FacadeSetPiece
## Three rusty pipes slung across the street on a shared industrial gantry: valve wheels on the
## middle pipe, hanger straps dropping onto the top one. A span piece: corridor_facades never
## calls can_apply/pick_plan/apply_plans on it, only build.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const _BASE_Y := _FacadePlan.BASE_Y
## A quarter turn about z lays a cylinder's height axis along x (see add_cylinder_node).
const _ALONG_X := Vector3(0.0, 0.0, PI * 0.5)
const _PIPE_YS := [10.0, 11.5, 13.0]
const _PIPE_ZS := [0.0, 1.4, -1.4]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var rust := _FacadeMaterials.rust_pipe_material()
	var pipes: Array[Vector3] = []
	for i in 3:
		var z: float = _PIPE_ZS[i] + rng.randf_range(-0.3, 0.3)
		var center := Vector3(0.0, _BASE_Y + _PIPE_YS[i], z)
		pipes.append(center)
		_FacadeMeshKit.add_cylinder_node(
			host, "Pipe%d" % i, 0.6, 0.6, 18.4, center, rust, true, keep_out, _ALONG_X
		)
	var iron := _FacadeMaterials.iron_material()
	var mid := pipes[1]
	for i in 2:
		var x := -3.0 if i == 0 else 3.0
		_FacadeMeshKit.add_cylinder_node(
			host, "Valve%d" % i, 0.5, 0.5, 0.1, Vector3(x, mid.y, mid.z), iron, false, keep_out,
			_ALONG_X
		)
	var top := pipes[2]
	var hanger_st := SurfaceTool.new()
	hanger_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hanger_added := false
	for i in 4:
		var center := Vector3(-6.0 + float(i) * 4.0, _BASE_Y + 13.6, top.z)
		var ok := _FacadeMeshKit.add_box(hanger_st, center, Vector3(0.1, 1.2, 0.1), keep_out)
		hanger_added = ok or hanger_added
	if hanger_added:
		_FacadeMeshKit.commit(host, hanger_st, "Hangers", iron, false)
