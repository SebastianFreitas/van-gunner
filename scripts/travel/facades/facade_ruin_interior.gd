extends RefCounted
## Floor slabs, broken stubs, rebar and joists inside a deep ruined body.


const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeGrimeMaterials := preload("res://scripts/travel/facades/facade_grime_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeRuinClutter := preload("res://scripts/travel/facades/facade_ruin_clutter.gd")

const SLAB_T := 0.22
const WALL_T := 0.35
const GROUND_TOP := -0.06
const _BAR_T := 0.03
const _JOIST_W := 0.12
const _JOIST_H := 0.22
const _MIN_SPAN := 1.2


## Builds the interior ground, floor slabs, stubs, rebar and joists under host and stores
## `ruin_slabs` (one entry per full slab) on the plan. Own rng, so no other family's draws move.
## Works in abs x and mirrors by side_sign when emitting.
static func build(
	host: Node3D, plan: Dictionary, side_sign: float, index: int, x_face: float, x_back: float,
	y0: float, keep_out: RefCounted
) -> void:
	var s := side_sign
	var params: Dictionary = plan[&"params"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([float(params[&"seed"]), &"ruin_interior"])
	var z0 := float(plan[&"z0"])
	var z1 := float(plan[&"z1"])
	var xi := absf(x_face) + WALL_T
	var xo := absf(x_back) - WALL_T
	var zi0 := z0 + WALL_T + (0.05 if absf(z0) >= 9.99 else 0.0)
	var zi1 := z1 - WALL_T - (0.05 if absf(z1) >= 9.99 else 0.0)
	var slabs: Array[Dictionary] = []
	plan[&"ruin_slabs"] = slabs

	var st_floor := _begin()
	var st_rebar := _begin()
	var st_joist := _begin()
	var st_ground := _begin()
	var counts: Array[int] = [0, 0, 0, 0]
	if xo - xi > 0.1 and zi1 - zi0 > 0.1:
		var size := Vector3(xo - xi, 0.4, zi1 - zi0)
		var center := Vector3(s * (xi + xo) * 0.5, GROUND_TOP - 0.2, (zi0 + zi1) * 0.5)
		if _box(st_ground, center, size, keep_out):
			counts[3] += 1
	var floors := int(plan.get(&"floors", 1))
	if floors > 1 and xo - xi >= _MIN_SPAN and zi1 - zi0 >= _MIN_SPAN:
		var gh := float(params.get(&"ground_height", _FacadePlan.GROUND_HEIGHT))
		var floor_h := float(params.get(
			&"floor_height", (float(plan[&"height"]) - gh) / maxf(floors - 1, 1)
		))
		var cols: Array = plan.get(&"ruin_cols", [])
		var tops: Array = plan.get(&"ruin_back_tops", [])
		var sts: Array[SurfaceTool] = [st_floor, st_rebar, st_joist]
		for i in cols.size():
			var c: Vector3 = cols[i]
			var za := maxf(c.x, zi0)
			var zb := minf(c.y, zi1)
			if zb - za < 0.2:
				continue
			var top_b := float(tops[i]) if i < tops.size() else c.z
			for j in range(1, floors):
				var y_f := y0 + gh + (j - 1) * floor_h
				_floor_line(
					sts, counts, rng, slabs, s, Vector4(za, zb, xi, xo), x_face, y_f, c.z, top_b,
					keep_out
				)

	var slab_mat := _FacadeGrimeMaterials.from_prop(_FacadeMaterials.concrete_material())
	var joist_mat := _FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
		&"ruin_joist", Color(0.09, 0.07, 0.05), 0.9, 0.0, Color.BLACK, 0.0
	))
	var ground_mat := _FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
		&"ruin_ground", Color(0.045, 0.04, 0.035), 0.95, 0.0, Color.BLACK, 0.0
	))
	if counts[0] > 0:
		_FacadeMeshKit.commit(host, st_floor, "Body%dFloors" % index, slab_mat, false)
	if counts[1] > 0:
		var rebar_mat := _FacadeMaterials.rust_pipe_material()
		_FacadeMeshKit.commit(host, st_rebar, "Body%dRebar" % index, rebar_mat, false)
	if counts[2] > 0:
		_FacadeMeshKit.commit(host, st_joist, "Body%dJoists" % index, joist_mat, false)
	if counts[3] > 0:
		_FacadeMeshKit.commit(host, st_ground, "Body%dGround" % index, ground_mat, false)
	if xo - xi >= 1.2 and zi1 - zi0 >= 1.2:
		_FacadeRuinClutter.build(host, plan, side_sign, index, xi, xo, zi0, zi1, y0, keep_out)


## One floor line across one column; span = (z_a, z_b, x_in, x_out), all abs in x.
static func _floor_line(
	sts: Array[SurfaceTool], counts: Array[int], rng: RandomNumberGenerator,
	slabs: Array[Dictionary], s: float, span: Vector4, x_face: float, y_f: float, top_f: float,
	top_b: float, keep_out: RefCounted
) -> void:
	var za := span.x
	var zb := span.y
	var xi := span.z
	var xo := span.w
	if top_b < y_f + 0.3:
		if rng.randf() < 0.5:
			_joist(sts[2], counts, rng, s, span, y_f, keep_out)
		return
	if top_f >= y_f + 0.3:
		var size := Vector3(xo - xi, SLAB_T, zb - za)
		var center := Vector3(s * (xi + xo) * 0.5, y_f - SLAB_T * 0.5, (za + zb) * 0.5)
		if _box(sts[0], center, size, keep_out):
			counts[0] += 1
			slabs.append({&"z_a": za, &"z_b": zb, &"y": y_f, &"x_in": xi, &"x_out": xo})
		return
	var r := rng.randf()
	if r < 0.2:
		for k in rng.randi_range(1, 2):
			_joist(sts[2], counts, rng, s, span, y_f, keep_out)
	elif r < 0.5:
		var len_s := minf(rng.randf_range(1.0, 2.0), xo - xi)
		if _stub(sts, counts, rng, s, za, zb, xo, len_s, y_f, x_face, keep_out, true):
			var xe := xo - len_s
			var hinge_l := minf(rng.randf_range(0.8, 1.6), xe - absf(x_face) + 0.1)
			var angle := rng.randf_range(0.2, 0.7)
			var pivot := Vector3(xe, y_f, 0.5 * (za + zb))
			_hinged(sts, counts, rng, s, x_face, pivot, zb - za, hinge_l, angle)
	else:
		var pieces := rng.randi_range(2, 3)
		if zb - za < pieces * 0.5:
			pieces = 1
		var w := (zb - za) / pieces
		for k in pieces:
			var len_p := minf(rng.randf_range(1.0, 4.0), xo - xi)
			var gap := 0.02 if pieces > 1 else 0.0
			_stub(
				sts, counts, rng, s, za + k * w + gap, za + (k + 1) * w - gap, xo, len_p, y_f,
				x_face, keep_out, false
			)


## A slab piece reaching `len_s` back from x_out between z_a and z_b; its street edge gets rebar
## unless a hinged piece will hang there. False when the keep-out refused it.
static func _stub(
	sts: Array[SurfaceTool], counts: Array[int], rng: RandomNumberGenerator, s: float, za: float,
	zb: float, xo: float, len_s: float, y_f: float, x_face: float, keep_out: RefCounted,
	hinged: bool
) -> bool:
	var size := Vector3(len_s, SLAB_T, zb - za)
	var center := Vector3(s * (xo - len_s * 0.5), y_f - SLAB_T * 0.5, (za + zb) * 0.5)
	if not _box(sts[0], center, size, keep_out):
		return false
	counts[0] += 1
	if not hinged:
		var edge := Transform3D(Basis(), Vector3(s * (xo - len_s), y_f - SLAB_T * 0.5, 0.0))
		_rebar(sts[1], counts, rng, s, x_face, edge, za, zb)
	return true


## A slab piece of length `hinge_l` hanging from the pivot (abs x, y, z), rotated about z so its
## free end drops toward the street, with rebar from its free edge.
static func _hinged(
	sts: Array[SurfaceTool], counts: Array[int], rng: RandomNumberGenerator, s: float,
	x_face: float, pivot: Vector3, width: float, hinge_l: float, angle: float
) -> void:
	if hinge_l < 0.5:
		return
	var basis := Basis(Vector3.BACK, s * angle)
	var origin := Vector3(s * pivot.x, pivot.y - SLAB_T * 0.5, pivot.z)
	var xf := Transform3D(basis, origin + basis * Vector3(-s * hinge_l * 0.5, 0.0, 0.0))
	_FacadeMeshKit.add_box_xf_ungated(sts[0], xf, Vector3(hinge_l, SLAB_T, width))
	counts[0] += 1
	var tip := Transform3D(basis, origin + basis * Vector3(-s * hinge_l, 0.0, 0.0))
	_rebar(sts[1], counts, rng, s, x_face, tip, pivot.z - width * 0.5, pivot.z + width * 0.5)


## 3-6 rebar bars poking toward the street from `edge` (its origin is the slab edge mid-thickness,
## z taken from z_a..z_b), each bent down; stays within 0.2 m of the facade plane in x.
static func _rebar(
	st: SurfaceTool, counts: Array[int], rng: RandomNumberGenerator, s: float, x_face: float,
	edge: Transform3D, za: float, zb: float
) -> void:
	for k in rng.randi_range(3, 6):
		var bar_l := rng.randf_range(0.3, 0.8)
		var bend := rng.randf_range(0.1, 0.6)
		var z := rng.randf_range(za + 0.03, maxf(za + 0.03, zb - 0.03))
		var basis := edge.basis * Basis(Vector3.BACK, s * bend)
		var anchor := edge * Vector3(0.0, 0.0, z - edge.origin.z)
		var xf := Transform3D(basis, anchor + basis * Vector3(-s * bar_l * 0.5, 0.0, 0.0))
		if absf(xf.origin.x) - bar_l * 0.5 < absf(x_face) - 0.2:
			continue
		_FacadeMeshKit.add_box_xf_ungated(st, xf, Vector3(bar_l, _BAR_T, _BAR_T))
		counts[1] += 1


## A timber joist from the back wall at y_f: level, or hanging toward the street.
static func _joist(
	st: SurfaceTool, counts: Array[int], rng: RandomNumberGenerator, s: float, span: Vector4,
	y_f: float, keep_out: RefCounted
) -> void:
	var z := rng.randf_range(span.x + 0.1, span.y - 0.1)
	var level := rng.randf() < 0.5
	var reach := minf(rng.randf_range(1.5, 3.0), span.w - span.z)
	if level:
		var center := Vector3(s * (span.w - reach * 0.5), y_f - _JOIST_H * 0.5, z)
		if _box(st, center, Vector3(reach, _JOIST_H, _JOIST_W), keep_out):
			counts[2] += 1
		return
	var drop := minf(rng.randf_range(1.0, 3.0), y_f - (GROUND_TOP + 0.2))
	if drop < 0.2:
		return
	var angle := atan2(drop, reach)
	var basis := Basis(Vector3.BACK, s * angle)
	var pivot := Vector3(s * span.w, y_f - _JOIST_H * 0.5, z)
	var length := sqrt(reach * reach + drop * drop)
	var xf := Transform3D(basis, pivot + basis * Vector3(-s * length * 0.5, 0.0, 0.0))
	var size := Vector3(length, _JOIST_H, _JOIST_W)
	if keep_out == null or keep_out.allows(xf * AABB(-size * 0.5, size)):
		_FacadeMeshKit.add_box_xf_ungated(st, xf, size)
		counts[2] += 1


## Gated box when there is a keep-out, else ungated (spans have none).
static func _box(
	st: SurfaceTool, center: Vector3, size: Vector3, keep_out: RefCounted
) -> bool:
	if keep_out == null:
		_FacadeMeshKit.add_box_ungated(st, center, size)
		return true
	return _FacadeMeshKit.add_box(st, center, size, keep_out)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st
