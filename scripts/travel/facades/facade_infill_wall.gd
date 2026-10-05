extends RefCounted
## Brick gap wall with pillars and a rusted sheet gate.


const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeGrimeMaterials := preload("res://scripts/travel/facades/facade_grime_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeInfill := preload("res://scripts/travel/facades/facade_infill.gd")

const PILLAR := 0.45


## Brick wall with pillars, concrete caps and, in a wide enough gap, a rusted sheet gate.
static func _brick_wall(
	root: Node3D, sx: float, z_a: float, z_b: float, gi: int, g: float, keep_out: RefCounted,
	rng: RandomNumberGenerator
) -> void:
	var xf := _FacadePlan.FACE_X + g
	var w := z_b - z_a
	var h := rng.randf_range(2.0, 2.8)
	var half := PILLAR * 0.5
	var lo := z_a + half
	var hi := z_b - half
	var n := maxi(1, ceili((hi - lo) / _FacadeInfill.POST_STEP))
	var params := _FacadeInfill._params(&"brick_brown", w, h, rng.randf() * 1000.0, {
		&"soot": 0.6, &"overgrowth": 0.4, &"growth_height": 0.7,
	})
	var runs: Array[Vector2] = []
	var pst := SurfaceTool.new()
	pst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n + 1:
		_FacadeMeshKit.add_box(pst, Vector3(sx * (xf + 0.145), (h + 0.25) * 0.5,
			lerpf(lo, hi, float(k) / float(n))), Vector3(PILLAR, h + 0.25, PILLAR), keep_out)
		if k < n:
			runs.append(Vector2(lerpf(lo, hi, float(k) / float(n)) + half,
				lerpf(lo, hi, float(k + 1) / float(n)) - half))
	var gate_run := -1
	var gate_w := 0.0
	if w >= 1.6:
		var gate_hi := minf(w - 1.0, 2.4)
		gate_w = rng.randf_range(minf(1.2, gate_hi), gate_hi)
		var fits: Array[int] = []
		for k in runs.size():
			if runs[k].y - runs[k].x >= gate_w:
				fits.append(k)
		if not fits.is_empty():
			gate_run = fits[rng.randi_range(0, fits.size() - 1)]
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cst := SurfaceTool.new()
	cst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gst := SurfaceTool.new()
	gst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in runs.size():
		var pieces: Array[Vector2] = [runs[k]]
		if k == gate_run:
			var mid := (runs[k].x + runs[k].y) * 0.5
			pieces = [Vector2(runs[k].x, mid - gate_w * 0.5), Vector2(mid + gate_w * 0.5, runs[k].y)]
			_gate_sheet(gst, sx, g, mid, gate_w, h, keep_out)
		for pc in pieces:
			if pc.y - pc.x > 0.05:
				if _FacadeInfill._wall_quad(wst, sx, xf, pc.x, pc.y, 0.0, h, z_a, 0.0, keep_out):
					_FacadeMeshKit.add_box(cst, Vector3(sx * (xf + 0.15), h + 0.03,
						(pc.x + pc.y) * 0.5), Vector3(0.36, 0.06, pc.y - pc.x), keep_out)
	var pillar_mat := _FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
		&"infill_pillar", Color(0.13, 0.07, 0.05), 0.92, 0.0, Color.BLACK, 0.0
	))
	var cap_mat := _FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
		&"infill_cap", Color(0.17, 0.17, 0.16), 0.9, 0.0, Color.BLACK, 0.0
	))
	if _FacadeMeshKit.has_geometry(wst):
		_FacadeMeshKit.commit(root, wst, "InfillWall%d" % gi,
			_FacadeMaterials.facade_material(params), false)
	if _FacadeMeshKit.has_geometry(cst):
		_FacadeMeshKit.commit(root, cst, "InfillWallCap%d" % gi, cap_mat, false)
	if _FacadeMeshKit.has_geometry(pst):
		_FacadeMeshKit.commit(root, pst, "InfillPillars%d" % gi, pillar_mat, false)
	if _FacadeMeshKit.has_geometry(gst):
		_FacadeMeshKit.commit(root, gst, "InfillWallGate%d" % gi, _FacadeInfill._rust(), false)


## A rusted sheet in the wall plane with two frame bars on its street side.
static func _gate_sheet(
	st: SurfaceTool, sx: float, g: float, z_mid: float, width: float, h: float, keep_out: RefCounted
) -> void:
	var xf := _FacadePlan.FACE_X + g
	_FacadeMeshKit.add_box(st, Vector3(sx * (xf + 0.15), 0.05 + (h - 0.2) * 0.5, z_mid),
		Vector3(0.04, h - 0.2, width), keep_out)
	for by: float in [0.25, h - 0.35]:
		_FacadeMeshKit.add_box(st, Vector3(sx * (xf + 0.10), by, z_mid),
			Vector3(0.06, 0.08, width), keep_out)
