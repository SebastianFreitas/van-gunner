extends FacadeSetPiece
## An enclosed pedestrian bridge crossing the street: a floor and roof well above the lane, two
## glazed side walls, and end portals closing the gap against the facades on either side. A span
## piece: corridor_facades never calls can_apply/pick_plan/apply_plans on it, only build.


const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const _BASE_Y := _FacadePlan.BASE_Y


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var z_mid := rng.randf_range(-3.0, 3.0)
	var wall_y := _BASE_Y + 10.5
	var shell_st := SurfaceTool.new()
	shell_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shell_added := false
	shell_added = _FacadeMeshKit.add_box(
		shell_st, Vector3(0.0, _BASE_Y + 9.125, z_mid), Vector3(18.4, 0.25, 3.0), keep_out
	) or shell_added
	shell_added = _FacadeMeshKit.add_box(
		shell_st, Vector3(0.0, _BASE_Y + 12.0, z_mid), Vector3(18.4, 0.2, 3.0), keep_out
	) or shell_added
	var wall_size := Vector3(18.4, 2.6, 0.15)
	var glow_st := SurfaceTool.new()
	glow_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow_added := false
	for wall_sign: float in [-1.0, 1.0]:
		var wz := z_mid + wall_sign * 1.45
		if _FacadeMeshKit.add_box(shell_st, Vector3(0.0, wall_y, wz), wall_size, keep_out):
			shell_added = true
			var glow_z := wz + wall_sign * (wall_size.z * 0.5 + 0.01)
			glow_added = _FacadeMeshKit.add_box(
				glow_st, Vector3(0.0, wall_y, glow_z), Vector3(18.0, 0.9, 0.02), keep_out
			) or glow_added
	for portal_sign: float in [-1.0, 1.0]:
		shell_added = _FacadeMeshKit.add_box(
			shell_st, Vector3(portal_sign * 9.2, wall_y, z_mid), Vector3(0.4, 3.2, 3.2), keep_out
		) or shell_added
	if shell_added:
		_FacadeMeshKit.commit(host, shell_st, "Bridge", _FacadeMaterials.concrete_material(), true)
	if glow_added:
		_FacadeMeshKit.commit(
			host, glow_st, "BridgeGlow",
			_FacadeMaterials.prop_material(
				&"bridge_glow", Color(0.7, 0.8, 0.9), 0.4, 0.1, Color(0.8, 0.9, 1.0), 1.8
			),
			false
		)
