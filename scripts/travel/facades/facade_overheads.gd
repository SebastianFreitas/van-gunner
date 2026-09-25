extends RefCounted
## Cross-street industrial dressing (pipe bridges, catwalks, ribs) built under Facades/Overhead
## when both sides are plain; it never reaches below 9 m over the road, so a bay mouth is never
## touched, and it is dropped the moment either side opens.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const _LENGTH := 18.4
## A quarter turn about z lays a cylinder's height axis along x (see add_cylinder_node).
const _ALONG_X := Vector3(0.0, 0.0, PI * 0.5)


## Only when district.overhead_chance passes rng.randf() does one of the four kinds get built.
static func build(
	host: Node3D, _plans_left: Array, _plans_right: Array, keep_out: RefCounted,
	rng: RandomNumberGenerator, district: FacadeDistrict
) -> void:
	if rng.randf() >= district.overhead_chance:
		return
	match rng.randi() % 4:
		0:
			_build_pipe_bridge(host, keep_out, rng)
		1:
			_build_catwalk(host, keep_out)
		2:
			_build_truss(host, keep_out)
		_:
			_build_ribs(host, keep_out)


## Two rusty pipes at a shared z, with four hanger straps reaching up to a fixed point above them.
static func _build_pipe_bridge(
	host: Node3D, keep_out: RefCounted, rng: RandomNumberGenerator
) -> void:
	var z := rng.randf_range(-7.0, 7.0)
	var rust := _FacadeMaterials.rust_pipe_material()
	_FacadeMeshKit.add_cylinder_node(
		host, "OverheadPipeLow", 0.35, 0.35, _LENGTH, Vector3(0.0, 10.5, z), rust, true, keep_out,
		_ALONG_X
	)
	_FacadeMeshKit.add_cylinder_node(
		host, "OverheadPipeHigh", 0.35, 0.35, _LENGTH, Vector3(0.0, 11.6, z), rust, true, keep_out,
		_ALONG_X
	)
	var hanger_st := SurfaceTool.new()
	hanger_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added := false
	for i in 4:
		var x := -6.0 + float(i) * 4.0
		var strap := Vector3(x, 12.55, z)
		added = _FacadeMeshKit.add_box(hanger_st, strap, Vector3(0.1, 1.9, 0.1), keep_out) or added
	if added:
		var iron := _FacadeMaterials.iron_material()
		_FacadeMeshKit.commit(host, hanger_st, "OverheadHangers", iron, false)


## A steel catwalk floor with two top rails and posts every 2 m along both edges.
static func _build_catwalk(host: Node3D, keep_out: RefCounted) -> void:
	var iron := _FacadeMaterials.iron_material()
	_FacadeMeshKit.add_box_node(
		host, "OverheadCatwalkFloor", Vector3(_LENGTH, 0.15, 2.0), Vector3(0.0, 9.6, 0.0),
		Vector3.ZERO, iron, true, keep_out
	)
	var rail_st := SurfaceTool.new()
	rail_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added := false
	for edge_z: float in [-1.0, 1.0]:
		added = (
			_FacadeMeshKit.add_box(
				rail_st, Vector3(0.0, 10.7, edge_z), Vector3(_LENGTH, 0.05, 0.05), keep_out
			) or added
		)
		var x := -_LENGTH * 0.5 + 1.0
		while x < _LENGTH * 0.5:
			added = (
				_FacadeMeshKit.add_box(
					rail_st, Vector3(x, 10.15, edge_z), Vector3(0.05, 1.1, 0.05), keep_out
				) or added
			)
			x += 2.0
	if added:
		_FacadeMeshKit.commit(host, rail_st, "OverheadCatwalkRails", iron, false)


## Two horizontal chords with 8 alternating diagonal braces between them.
static func _build_truss(host: Node3D, keep_out: RefCounted) -> void:
	var iron := _FacadeMaterials.iron_material()
	var chord_st := SurfaceTool.new()
	chord_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added := false
	var chord_size := Vector3(_LENGTH, 0.4, 0.4)
	for y: float in [12.0, 13.4]:
		var c := Vector3(0.0, y, 0.0)
		added = _FacadeMeshKit.add_box(chord_st, c, chord_size, keep_out) or added
	if added:
		_FacadeMeshKit.commit(host, chord_st, "OverheadTrussChords", iron, true)
	for i in 8:
		var x := -_LENGTH * 0.5 + (_LENGTH / 8.0) * (float(i) + 0.5)
		var yaw := 0.6 if i % 2 == 0 else -0.6
		_FacadeMeshKit.add_box_node(
			host, "OverheadTrussDiag%d" % i, Vector3(0.15, 1.6, 0.15), Vector3(x, 12.7, 0.0),
			Vector3(0.0, 0.0, yaw), iron, false, keep_out
		)


## Three portal frames: ground-standing posts outside the lane's x-range plus a beam across the
## top. Posts on the left need their own keep-out; the passed-in one only covers the right side.
## Three separate meshes (right posts, left posts, beams): a merged mesh's AABB would span both
## the ground-level posts and the full-width beam at once, straddling the lane even though no
## single box in it does.
static func _build_ribs(host: Node3D, keep_out: RefCounted) -> void:
	var concrete := _FacadeMaterials.concrete_material()
	var left_keep_out := _FacadeKeepOut.new(-1.0, 0)
	var right_st := SurfaceTool.new()
	right_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var right_added := false
	var left_st := SurfaceTool.new()
	left_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left_added := false
	var beam_st := SurfaceTool.new()
	beam_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beam_added := false
	for z: float in [-7.0, 0.0, 7.0]:
		right_added = (
			_FacadeMeshKit.add_box(right_st, Vector3(8.3, 6.0, z), Vector3(0.5, 12.0, 0.5), keep_out)
			or right_added
		)
		var left_post := Vector3(-8.3, 6.0, z)
		left_added = (
			_FacadeMeshKit.add_box(left_st, left_post, Vector3(0.5, 12.0, 0.5), left_keep_out)
			or left_added
		)
		beam_added = (
			_FacadeMeshKit.add_box(beam_st, Vector3(0.0, 12.0, z), Vector3(18.0, 0.5, 0.55), keep_out)
			or beam_added
		)
	if right_added:
		_FacadeMeshKit.commit(host, right_st, "OverheadRibPostsRight", concrete, true)
	if left_added:
		_FacadeMeshKit.commit(host, left_st, "OverheadRibPostsLeft", concrete, true)
	if beam_added:
		_FacadeMeshKit.commit(host, beam_st, "OverheadRibBeams", concrete, true)
