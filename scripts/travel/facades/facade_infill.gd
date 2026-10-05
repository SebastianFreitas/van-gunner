extends RefCounted
## Fills the gaps between street buildings: yard, party wall and a fence or wall on the face line.


const _FacadeBody := preload("res://scripts/travel/facades/facade_body.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeGrimeMaterials := preload("res://scripts/travel/facades/facade_grime_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadeInfillWall := preload("res://scripts/travel/facades/facade_infill_wall.gd")
const _FacadeInfillExtra := preload("res://scripts/travel/facades/facade_infill_extra.gd")

## How far the dark yard reaches behind the face line (the deepest body ends at 8.8 + 0.3 + 3.5).
const YARD_DEPTH := 3.5
## Absolute x of the blank party wall that closes the yard.
const PARTY_X := 12.8
## Gaps narrower than this stay empty.
const MIN_GAP := 0.3
## Longest span between posts or pillars.
const POST_STEP := 2.5


## The empty z spans along a side, in z order; none on a mouth side or an empty one.
static func gaps(plans: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if plans.is_empty():
		return out
	for plan: Dictionary in plans:
		if plan.get(&"mouth", false):
			return out
	var first_z0 := float(plans[0][&"z0"])
	if first_z0 > -9.95:
		out.append(Vector2(-10.0, first_z0))
	for i in range(1, plans.size()):
		var a := float(plans[i - 1][&"z1"])
		var b := float(plans[i][&"z0"])
		if b - a > 0.05:
			out.append(Vector2(a, b))
	var last_z1 := float(plans[plans.size() - 1][&"z1"])
	if last_z1 < 9.95:
		out.append(Vector2(last_z1, 10.0))
	return out


## Builds yard, party wall and one filler per gap, on its own rng.
static func build(
	root: Node3D, plans: Array, side_sign: float, keep_out: RefCounted, rng: RandomNumberGenerator,
	district: FacadeDistrict
) -> void:
	var spans := gaps(plans)
	for gi in spans.size():
		var z_a := spans[gi].x
		var z_b := spans[gi].y
		var w := z_b - z_a
		var g := _FacadePlan.gap_recess(plans, (z_a + z_b) * 0.5)
		if w < MIN_GAP:
			continue
		_yard(root, side_sign, z_a, z_b, gi, g, keep_out)
		_party_wall(root, side_sign, z_a, z_b, gi, g, keep_out, rng)
		var roll := rng.randi_range(0, 99)
		if roll >= 30 and roll < 60 and w >= 1.0:
			_FacadeInfillWall._brick_wall(root, side_sign, z_a, z_b, gi, g, keep_out, rng)
		elif roll >= 60 and roll < 80:
			_FacadeInfillExtra.hoarding(root, side_sign, z_a, z_b, gi, g, keep_out, rng, district)
		elif roll >= 80:
			_FacadeInfillExtra.corrugated(root, side_sign, z_a, z_b, gi, g, keep_out, rng)
		else:
			_palisade(root, side_sign, z_a, z_b, gi, g, keep_out, rng)
		_FacadeInfillExtra.furniture(root, side_sign, z_a, z_b, gi, g, keep_out, rng)


static func _steel() -> ShaderMaterial:
	return _FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
		&"infill_palisade", Color(0.07, 0.08, 0.075), 0.82, 0.3, Color.BLACK, 0.0
	))


static func _rust() -> ShaderMaterial:
	return _FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
		&"infill_gate_rust", Color(0.14, 0.07, 0.04), 0.9, 0.2, Color.BLACK, 0.0
	))


## A facade-shader params dict for a window-less blank wall: `extra` overrides the defaults.
static func _params(
	preset: StringName, width: float, height: float, seed_value: float, extra: Dictionary
) -> Dictionary:
	var p := _FacadeMaterials.preset(preset)
	p[&"facade_width"] = width
	p[&"facade_height"] = height
	p[&"floor_height"] = _FacadePlan.FLOOR_HEIGHT
	p[&"ground_height"] = height
	p[&"ground_kind"] = 0
	p[&"ground_units"] = 0.0
	p[&"windows_on"] = 0.0
	p[&"lit_ratio"] = 0.0
	p[&"boarded_ratio"] = 0.0
	p[&"broken_ratio"] = 0.0
	p[&"band_every"] = 0.0
	p[&"seed"] = seed_value
	p[&"soot"] = 0.7
	p[&"peel"] = 0.6
	p[&"overgrowth"] = 0.35
	p[&"growth_height"] = 0.9
	p[&"ivy"] = 0.2
	p[&"grime"] = 0.7
	p[&"damage"] = 0.3
	p.merge(extra, true)
	return p


## One street-facing quad on the plane x (absolute, mirrored by sx) from z0..z1 and y0..y1,
## UVs in metres (u along z from u_z, v above y0 + v_off). False when the keep-out refuses it.
static func _wall_quad(
	st: SurfaceTool, sx: float, x: float, z0: float, z1: float, y0: float, y1: float,
	u_z: float, v_off: float, keep_out: RefCounted
) -> bool:
	var aabb: AABB = _FacadeKeepOut.box_aabb(
		Vector3(sx * x, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(0.02, y1 - y0, z1 - z0)
	)
	if not keep_out.allows(aabb):
		return false
	var wx := sx * x
	_FacadeBody.add_quad(
		st, Vector3(wx, y0, z0), Vector3(wx, y0, z1), Vector3(wx, y1, z1), Vector3(wx, y1, z0),
		Vector2(z0 - u_z, y0 + v_off), Vector2(z1 - u_z, y0 + v_off),
		Vector2(z1 - u_z, y1 + v_off), Vector2(z0 - u_z, y1 + v_off), Vector3(-sx, 0.0, 0.0)
	)
	return true


static func _yard(
	root: Node3D, sx: float, z_a: float, z_b: float, gi: int, g: float, keep_out: RefCounted
) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_FacadeMeshKit.add_box(
		st, Vector3(sx * (_FacadePlan.FACE_X + g + YARD_DEPTH * 0.5), -0.26, (z_a + z_b) * 0.5),
		Vector3(YARD_DEPTH, 0.4, z_b - z_a), keep_out
	)
	var material := _FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
		&"infill_yard", Color(0.045, 0.04, 0.035), 0.95, 0.0, Color.BLACK, 0.0
	))
	if _FacadeMeshKit.has_geometry(st):
		_FacadeMeshKit.commit(root, st, "InfillYard%d" % gi, material, false)


## A blank concrete wall behind the yard, so the gap never shows the sky or the void.
static func _party_wall(
	root: Node3D, sx: float, z_a: float, z_b: float, gi: int, g: float, keep_out: RefCounted,
	rng: RandomNumberGenerator
) -> void:
	var h := rng.randf_range(4.0, 9.0)
	var seed_value := rng.randf() * 1000.0
	var params := _params(&"concrete_grey", z_b - z_a, h + 0.4, seed_value, {
		&"soot": 0.7, &"peel": 0.6, &"overgrowth": 0.35, &"growth_height": 0.9, &"ivy": 0.2,
		&"grime": 0.7, &"damage": 0.3,
	})
	var z0 := maxf(z_a - 0.2, -9.95)
	var z1 := minf(z_b + 0.2, 9.95)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wall_quad(st, sx, PARTY_X + g, z0, z1, -0.4, h, z0, 0.4, keep_out)
	if _FacadeMeshKit.has_geometry(st):
		_FacadeMeshKit.commit(
			root, st, "InfillParty%d" % gi, _FacadeMaterials.facade_material(params), false
		)


## Steel palisade: posts, 0.25 m pitch pales with points, two rails, and a rusted gate ajar
## into the yard when the gap is 2 m or wider.
static func _palisade(
	root: Node3D, sx: float, z_a: float, z_b: float, gi: int, g: float, keep_out: RefCounted,
	rng: RandomNumberGenerator
) -> void:
	var xf := _FacadePlan.FACE_X + g
	var w := z_b - z_a
	var h := rng.randf_range(2.0, 2.4)
	var has_gate := w >= 2.0
	var d := 1.0
	var hinge := 0.0
	var g0 := 0.0
	var g1 := 0.0
	var angle := 0.0
	if has_gate:
		d = 1.0 if rng.randf() < 0.5 else -1.0
		hinge = z_a + 0.05 if d > 0.0 else z_b - 0.05
		g0 = minf(hinge - d * 0.05, hinge + d * 1.35)
		g1 = maxf(hinge - d * 0.05, hinge + d * 1.35)
		angle = rng.randf_range(0.15, 0.35) * d * sx
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post_h := h + 0.11
	var n := maxi(1, ceili((w - 0.1) / POST_STEP))
	for k in n + 1:
		var pz := lerpf(z_a + 0.05, z_b - 0.05, float(k) / float(n))
		if has_gate and k > 0 and k < n and pz > g0 - 0.1 and pz < g1 + 0.1:
			continue
		_FacadeMeshKit.add_box(st, Vector3(sx * (xf + 0.04), (h - 0.01) * 0.5, pz),
			Vector3(0.1, post_h, 0.1), keep_out)
	if has_gate:
		_FacadeMeshKit.add_box(st, Vector3(sx * (xf + 0.04), (h - 0.01) * 0.5, hinge + d * 1.3),
			Vector3(0.1, post_h, 0.1), keep_out)
	var zc := z_a + 0.13
	while zc <= z_b - 0.13:
		if not (has_gate and zc + 0.03 > g0 and zc - 0.03 < g1):
			_FacadeMeshKit.add_box(st, Vector3(sx * (xf + 0.015), (h - 0.06) * 0.5, zc),
				Vector3(0.03, h + 0.06, 0.06), keep_out)
			_FacadeMeshKit.add_box_xf(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.25),
				Vector3(sx * (xf + 0.015), h + 0.01, zc)), Vector3(0.03, 0.06, 0.06), keep_out)
		zc += 0.25
	var r_lo := z_a
	var r_hi := z_b
	if has_gate:
		if d > 0.0:
			r_lo = g1
		else:
			r_hi = g0
	if r_hi - r_lo > 0.1:
		for ry: float in [0.35, h - 0.35]:
			_FacadeMeshKit.add_box(st, Vector3(sx * (xf + 0.04), ry, (r_lo + r_hi) * 0.5),
				Vector3(0.04, 0.08, r_hi - r_lo), keep_out)
	if _FacadeMeshKit.has_geometry(st):
		_FacadeMeshKit.commit(root, st, "InfillFence%d" % gi, _steel(), false)
	if not has_gate:
		return
	var gst := SurfaceTool.new()
	gst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gx := Transform3D(Basis(Vector3.UP, angle), Vector3(sx * (xf + 0.04), 0.0, hinge))
	var dist := 0.17
	while dist <= 1.15:
		var local := Vector3(sx * -0.025, (h - 0.06) * 0.5, d * dist)
		_FacadeMeshKit.add_box_xf(gst, gx * Transform3D(Basis.IDENTITY, local),
			Vector3(0.03, h + 0.06, 0.06), keep_out)
		local.y = h + 0.01
		_FacadeMeshKit.add_box_xf(gst, gx * Transform3D(Basis(Vector3.RIGHT, PI * 0.25), local),
			Vector3(0.03, 0.06, 0.06), keep_out)
		dist += 0.25
	for ry: float in [0.35, h - 0.35]:
		_FacadeMeshKit.add_box_xf(gst, gx * Transform3D(Basis.IDENTITY,
			Vector3(0.0, ry, d * 0.6)), Vector3(0.04, 0.08, 1.2), keep_out)
	if _FacadeMeshKit.has_geometry(gst):
		_FacadeMeshKit.commit(root, gst, "InfillGate%d" % gi, _rust(), false)
