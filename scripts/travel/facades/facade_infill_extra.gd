extends RefCounted
## Hoarding, corrugated fence and street furniture for street gaps.


const _FacadeBody := preload("res://scripts/travel/facades/facade_body.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeGrimeMaterials := preload("res://scripts/travel/facades/facade_grime_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeStreetArt := preload("res://scripts/travel/facades/facade_street_art.gd")
const _FacadeInfill := preload("res://scripts/travel/facades/facade_infill.gd")

const PANEL_W := 1.22
const PANEL_H := 2.4
## The ground the gap fillers stand on (the yard's top).
const BOTTOM := -0.06
const PLY_COLORS: Array[Color] = [
	Color(0.16, 0.12, 0.08), Color(0.14, 0.11, 0.075), Color(0.12, 0.10, 0.07),
]


static func _timber(key: StringName, color: Color) -> ShaderMaterial:
	return _FacadeGrimeMaterials.from_prop(
		_FacadeMaterials.prop_material(key, color, 0.9, 0.0, Color.BLACK, 0.0)
	)


## Plywood panels on posts with seam strips and street-art posters over them.
static func hoarding(
	root: Node3D, sx: float, z_a: float, z_b: float, gi: int, g: float, keep_out: RefCounted,
	rng: RandomNumberGenerator, district: FacadeDistrict
) -> void:
	var xf := _FacadePlan.FACE_X + g
	var w := z_b - z_a
	var n := maxi(1, ceili(w / PANEL_W))
	var panels: Array[SurfaceTool] = []
	for _i in 3:
		var pst := SurfaceTool.new()
		pst.begin(Mesh.PRIMITIVE_TRIANGLES)
		panels.append(pst)
	var seams := SurfaceTool.new()
	seams.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cy := BOTTOM + PANEL_H * 0.5
	for k in n:
		var p0 := z_a + float(k) * PANEL_W
		var p1 := minf(p0 + PANEL_W, z_b)
		var pick := rng.randi_range(0, 2)
		if p1 - p0 >= 0.005:
			_FacadeMeshKit.add_box(panels[pick],
				Vector3(sx * (xf + 0.015), cy, (p0 + p1) * 0.5), Vector3(0.03, PANEL_H, p1 - p0),
				keep_out)
		if k > 0:
			_FacadeMeshKit.add_box(seams, Vector3(sx * (xf - 0.005), cy, p0),
				Vector3(0.01, PANEL_H, 0.04), keep_out)
	var keys: Array[StringName] = [&"infill_ply_a", &"infill_ply_b", &"infill_ply_c"]
	var ply_names: Array[String] = ["InfillHoardingA%d", "InfillHoardingB%d", "InfillHoardingC%d"]
	for i in 3:
		if not _FacadeMeshKit.has_geometry(panels[i]):
			continue
		_FacadeMeshKit.commit(root, panels[i], ply_names[i] % gi,
			_timber(keys[i], PLY_COLORS[i]), false)
	if _FacadeMeshKit.has_geometry(seams):
		_FacadeMeshKit.commit(root, seams, "InfillHoardingSeams%d" % gi,
			_timber(&"infill_ply_seam", Color(0.07, 0.055, 0.04)), false)
	var posts := SurfaceTool.new()
	posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var np := maxi(1, ceili((w - 0.1) / 2.4))
	for k in np + 1:
		_FacadeMeshKit.add_box(posts, Vector3(sx * (xf + 0.08), cy,
			lerpf(z_a + 0.05, z_b - 0.05, float(k) / float(np))), Vector3(0.1, PANEL_H, 0.1),
			keep_out)
	if _FacadeMeshKit.has_geometry(posts):
		_FacadeMeshKit.commit(root, posts, "InfillHoardingPosts%d" % gi,
			_timber(&"ruin_joist", Color(0.09, 0.07, 0.05)), false)
	var pseudo := {
		&"z0": z_a, &"z1": z_b, &"width": w, &"height": PANEL_H, &"setback": 0.0,
		&"recess": g,
		&"mouth": false, &"rare": &"", &"suppress": [], &"ground_kind": _FacadePlan.GROUND_BLANK,
		&"ruin": 0, &"floors": 0, &"ruin_holes": [], &"ruin_cols": [],
		&"params": {
			&"style": 0, &"seed": rng.randf() * 1000.0, &"ground_height": 4.6,
			&"window_pitch": 2.6, &"collapse_y": 0.0,
		},
	}
	_FacadeStreetArt.build(root, pseudo, pseudo, sx, 100 + gi, keep_out, district)


## Overlapping rusted corrugated sheets, each a slightly yawed quad, on thin posts.
static func corrugated(
	root: Node3D, sx: float, z_a: float, z_b: float, gi: int, g: float, keep_out: RefCounted,
	rng: RandomNumberGenerator
) -> void:
	var xf := _FacadePlan.FACE_X + g
	var w := z_b - z_a
	var h := rng.randf_range(2.0, 2.3)
	var posts := SurfaceTool.new()
	posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var np := maxi(1, ceili((w - 0.08) / 2.0))
	for k in np + 1:
		_FacadeMeshKit.add_box(posts, Vector3(sx * (xf + 0.09), BOTTOM + h * 0.5,
			lerpf(z_a + 0.04, z_b - 0.04, float(k) / float(np))), Vector3(0.08, h, 0.08),
			keep_out)
	if _FacadeMeshKit.has_geometry(posts):
		_FacadeMeshKit.commit(root, posts, "InfillPosts%d" % gi, _FacadeInfill._rust(), false)
	var params := _FacadeInfill._params(&"corrugated_rust", w, h, rng.randf() * 1000.0, {
		&"soot": 0.6, &"peel": 0.4, &"overgrowth": 0.4, &"growth_height": 0.6,
	})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos := z_a
	var i := 0
	while pos < z_b - 0.01:
		var sw := rng.randf_range(0.9, 1.1)
		var s0 := z_a if i == 0 else pos - 0.08
		var s1 := minf(pos + sw, z_b)
		var y0 := BOTTOM + rng.randf_range(0.0, 0.1)
		var y1 := BOTTOM + h + rng.randf_range(-0.1, 0.1)
		var yaw := rng.randf_range(-0.05, 0.05)
		# Each sheet sits 0.01 further back than the one before, cycling, so neighbours differ.
		var x := sx * (xf + 0.01 * float(i % 3))
		_sheet(st, x, sx, s0, s1, y0, y1, yaw, z_a, keep_out)
		pos += sw
		i += 1
	if _FacadeMeshKit.has_geometry(st):
		_FacadeMeshKit.commit(root, st, "InfillSheets%d" % gi,
			_FacadeMaterials.facade_material(params), false)


## One front quad centred on (x, z mid) yawed about the vertical; skipped when keep-out refuses.
static func _sheet(
	st: SurfaceTool, x: float, sx: float, z0: float, z1: float, y0: float, y1: float,
	yaw: float, u_z: float, keep_out: RefCounted
) -> void:
	var zc := (z0 + z1) * 0.5
	var hw := (z1 - z0) * 0.5
	var rot := Basis(Vector3.UP, yaw)
	var pts: Array[Vector3] = []
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for c: Vector2 in [Vector2(-hw, y0), Vector2(hw, y0), Vector2(hw, y1), Vector2(-hw, y1)]:
		var p := Vector3(x, 0.0, zc) + rot * Vector3(0.0, c.y, c.x)
		p.y = c.y
		pts.append(p)
		lo = lo.min(p)
		hi = hi.max(p)
	var aabb := AABB(lo - Vector3(0.01, 0.0, 0.0), hi - lo + Vector3(0.02, 0.0, 0.0))
	if not keep_out.allows(aabb):
		return
	_FacadeBody.add_quad(
		st, pts[0], pts[1], pts[2], pts[3],
		Vector2(z0 - u_z, y0 - BOTTOM), Vector2(z1 - u_z, y0 - BOTTOM),
		Vector2(z1 - u_z, y1 - BOTTOM), Vector2(z0 - u_z, y1 - BOTTOM),
		rot * Vector3(-sx, 0.0, 0.0)
	)


## In 30% of gaps, either a utility box or a wooden pole in front of the filler.
static func furniture(
	root: Node3D, sx: float, z_a: float, z_b: float, gi: int, g: float, keep_out: RefCounted,
	rng: RandomNumberGenerator
) -> void:
	if rng.randf() >= 0.3:
		return
	if rng.randf() < 0.5:
		_utility_box(root, sx, z_a, z_b, gi, g, keep_out, rng)
	else:
		_pole(root, sx, z_a, z_b, gi, g, keep_out, rng)


static func _utility_box(
	root: Node3D, sx: float, z_a: float, z_b: float, gi: int, g: float, keep_out: RefCounted,
	rng: RandomNumberGenerator
) -> void:
	if z_b - z_a < 1.4:
		return
	var z := rng.randf_range(z_a + 0.4, z_b - 0.4)
	var mat := _FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
		&"infill_utility", Color(0.09, 0.10, 0.09), 0.85, 0.3, Color.BLACK, 0.0
	))
	var box := _FacadeMeshKit.add_box_node(root, "InfillUtility%d" % gi, Vector3(0.4, 1.2, 0.6),
		Vector3(sx * (8.4 + g), BOTTOM + 0.6, z), Vector3.ZERO, mat, false, keep_out)
	if box == null:
		return
	var handle := _FacadeMaterials.prop_material(
		&"infill_handle", Color(0.04, 0.04, 0.035), 0.85, 0.3, Color.BLACK, 0.0
	)
	_FacadeMeshKit.add_box_node(root, "InfillUtilityHandle%d" % gi, Vector3(0.02, 0.03, 0.5),
		Vector3(sx * (8.19 + g), BOTTOM + 0.6, z), Vector3.ZERO, handle, false, keep_out)


static func _pole(
	root: Node3D, sx: float, z_a: float, z_b: float, gi: int, g: float, keep_out: RefCounted,
	rng: RandomNumberGenerator
) -> void:
	var h := rng.randf_range(7.0, 9.0)
	var z := rng.randf_range(z_a + 0.3, z_b - 0.3) if z_b - z_a >= 0.6 else (z_a + z_b) * 0.5
	var timber := _timber(&"infill_pole", Color(0.08, 0.065, 0.05))
	var pole := _FacadeMeshKit.add_cylinder_node(root, "InfillPole%d" % gi, 0.125, 0.125, h,
		Vector3(sx * (8.0 + g), BOTTOM + h * 0.5, z), timber, false, keep_out)
	if pole == null:
		return
	var bar_y := BOTTOM + h - 0.6
	_FacadeMeshKit.add_box_node(root, "InfillPoleBar%d" % gi, Vector3(0.12, 0.12, 1.6),
		Vector3(sx * (8.0 + g), bar_y, z), Vector3.ZERO, timber, false, keep_out)
	var glass := _FacadeMaterials.prop_material(
		&"infill_insulator", Color(0.12, 0.12, 0.11), 0.85, 0.0, Color.BLACK, 0.0
	)
	for dz: float in [-0.6, 0.6]:
		_FacadeMeshKit.add_box_node(root, "InfillPoleInsulator%d" % gi, Vector3(0.1, 0.15, 0.1),
			Vector3(sx * (8.0 + g), bar_y + 0.135, z + dz), Vector3.ZERO, glass, false, keep_out)
