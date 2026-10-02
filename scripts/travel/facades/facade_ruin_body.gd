extends RefCounted
## Builds a ruined street building's body from its plan's ruin columns and holes: stepped tops,
## wall caps or roof plates, hole reveals over a dark back wall, then the debris meshes.


const _FacadeBody := preload("res://scripts/travel/facades/facade_body.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeRuinDebris := preload("res://scripts/travel/facades/facade_ruin_debris.gd")
const _FacadeRuinShell := preload("res://scripts/travel/facades/facade_ruin_shell.gd")
const _FacadeRuinInterior := preload("res://scripts/travel/facades/facade_ruin_interior.gd")

const WALL_T := 0.35
const ROOF_DEPTH := 1.2
## Safety under the lowest front opening: nothing deeper than this is built behind the front.
const CUT_MARGIN := 0.3
const ROOFED_DROP := _FacadeRuinDebris.ROOFED_DROP
const HOLE_DEPTH := _FacadeRuinDebris.HOLE_DEPTH
## A collapsed top on a shallow body gets a dark pocket at least this tall above its cap, up to
## this share of the drop to the full height (mirrors the shell's numbers).
const POCKET_RISE_MIN := 0.6
const POCKET_RISE_SHARE := 0.5
const RUBBLE_Y0 := _FacadeRuinDebris.RUBBLE_Y0


## The ruined body (facade material, one mesh) plus its interior and debris meshes under host;
## keep_out null emits ungated (spans). Returns the main body mesh.
static func build(
	host: Node3D, plan: Dictionary, side_sign: float, index: int, keep_out: RefCounted
) -> MeshInstance3D:
	var cols: Array = plan.get(&"ruin_cols", [])
	if cols.is_empty():
		return _FacadeBody.build(host, plan, side_sign, index)
	var holes: Array = plan.get(&"ruin_holes", [])
	var hole_of := {}
	for h: Vector3 in holes:
		hole_of[int(h.x)] = h
	var s := side_sign
	var x_face := _FacadePlan.face_x(plan, s)
	var y0 := _FacadePlan.BASE_Y
	var full := y0 + float(plan[&"height"])
	var z0 := float(plan[&"z0"])
	var z1 := float(plan[&"z1"])
	var body_depth := float(plan.get(&"depth", 0.0))
	var deep := body_depth > 0.0
	var x_back := s * (absf(x_face) + body_depth) if deep else s * 9.6
	# A deep body's holes open onto the shell's real interior: a thin reveal, no dark back quad.
	var hole_d := WALL_T if deep else HOLE_DEPTH
	var roof_d := maxf(ROOF_DEPTH, absf(x_back) - absf(x_face)) if deep else ROOF_DEPTH
	var st := _begin()
	var st_dark := _begin()
	var n_dark := 0
	var pocket_rng := RandomNumberGenerator.new()
	pocket_rng.seed = hash([float(plan[&"params"][&"seed"]), &"ruin_pocket"])
	for i in cols.size():
		var c: Vector3 = cols[i]
		var u_a := _u(c.x, z0, z1, s)
		var u_b := _u(c.y, z0, z1, s)
		if hole_of.has(i):
			var h: Vector3 = hole_of[i]
			var xd := x_face + s * hole_d
			_front(st, x_face, s, c.x, c.y, u_a, u_b, 0.0, h.y - y0)
			_front(st, x_face, s, c.x, c.y, u_a, u_b, h.z - y0, c.z - y0)
			# Sill and head, then the two jambs (v runs along the depth, u is the wall's).
			_quad(st, Vector3(x_face, h.y, c.x), Vector3(x_face, h.y, c.y), Vector3(xd, h.y, c.y),
				Vector3(xd, h.y, c.x), Vector3.UP, u_a, u_b, 0.0, hole_d)
			_quad(st, Vector3(x_face, h.z, c.x), Vector3(x_face, h.z, c.y), Vector3(xd, h.z, c.y),
				Vector3(xd, h.z, c.x), Vector3.DOWN, u_a, u_b, 0.0, hole_d)
			_quad(st, Vector3(x_face, h.y, c.x), Vector3(xd, h.y, c.x), Vector3(xd, h.z, c.x),
				Vector3(x_face, h.z, c.x), Vector3.BACK, u_a, u_a + hole_d, h.y - y0, h.z - y0)
			_quad(st, Vector3(x_face, h.y, c.y), Vector3(xd, h.y, c.y), Vector3(xd, h.z, c.y),
				Vector3(x_face, h.z, c.y), Vector3.FORWARD, u_b, u_b + hole_d, h.y - y0,
				h.z - y0)
			if not deep:
				_quad(st_dark, Vector3(xd, h.y, c.x), Vector3(xd, h.y, c.y),
					Vector3(xd, h.z, c.y), Vector3(xd, h.z, c.x), Vector3(-s, 0.0, 0.0),
					0.0, 1.0, 0.0, 1.0)
				n_dark += 1
		else:
			_front(st, x_face, s, c.x, c.y, u_a, u_b, 0.0, c.z - y0)
		# A roofed column keeps its roof plate; a collapsed one only a thin wall-top cap.
		var depth := roof_d if full - c.z < ROOFED_DROP else WALL_T
		var x_in := x_face + s * depth
		_quad(st, Vector3(x_face, c.z, c.x), Vector3(x_face, c.z, c.y), Vector3(x_in, c.z, c.y),
			Vector3(x_in, c.z, c.x), Vector3.UP, 0.0, c.y - c.x, 0.0, depth)
		if not deep and full - c.z >= ROOFED_DROP:
			# One draw per collapsed column, even when the keep-out refuses it, to keep the stream.
			var y_hi := clampf(
				full - pocket_rng.randf_range(0.0, POCKET_RISE_SHARE) * (full - c.z),
				c.z + POCKET_RISE_MIN, full
			)
			var box := AABB(
				Vector3(minf(x_face, x_face + s * HOLE_DEPTH), c.z - 0.2, c.x),
				Vector3(HOLE_DEPTH, y_hi - c.z + 0.2, c.y - c.x)
			)
			if keep_out == null or keep_out.allows(box):
				_pocket(st_dark, x_face, s, c.x, c.y, c.z - 0.2, y_hi)
				n_dark += 1
		if i + 1 < cols.size():
			_step_face(st, x_face, s, y0, full, roof_d, c, cols[i + 1] as Vector3)
	var first: Vector3 = cols[0]
	var last: Vector3 = cols[cols.size() - 1]
	_end_returns(st, x_face, x_back, deep, z0, y0, first.z, z1 - z0, -1.0)
	_end_returns(st, x_face, x_back, deep, z1, y0, last.z, z1 - z0, 1.0)
	var mi := _FacadeBody.commit_body(
		host, st, "Body%d" % index, _FacadeMaterials.facade_material(plan[&"params"])
	)
	if n_dark > 0:
		var dark := _FacadeMaterials.prop_material(
			&"ruin_interior", Color(0.085, 0.08, 0.072), 0.95, 0.0
		)
		_FacadeMeshKit.commit(host, st_dark, "Body%dInterior" % index, dark, false)
	if deep:
		# The front is opaque and every camera is low, so nothing under the lowest opening shows.
		var y_cut := opening_cut(plan, full) - CUT_MARGIN
		if y_cut != INF:
			_FacadeRuinShell.build(host, plan, side_sign, index, x_face, x_back, y0, false, y_cut)
			_FacadeRuinInterior.build(
				host, plan, side_sign, index, x_face, x_back, y0, keep_out, y_cut
			)
	_FacadeRuinDebris.build_body_debris(host, plan, side_sign, index, keep_out)
	return mi


## The lowest front opening's bottom edge: a collapsed column's top (it has no roof plate) or a
## hole's sill. INF when the front is closed.
static func opening_cut(plan: Dictionary, full: float) -> float:
	var cut := INF
	for c: Vector3 in plan.get(&"ruin_cols", []):
		if full - c.z >= ROOFED_DROP:
			cut = minf(cut, c.z)
	for h: Vector3 in plan.get(&"ruin_holes", []):
		cut = minf(cut, h.y)
	return cut


## Sidewalk rubble under a collapse (tile sides only); lives in the debris helper.
static func build_rubble(
	host: Node3D, plan: Dictionary, side_sign: float, index: int, keep_out: RefCounted
) -> void:
	_FacadeRuinDebris.build_rubble(host, plan, side_sign, index, keep_out)


## A dark pocket above a collapsed column's cap: a back quad HOLE_DEPTH behind the face and two
## jambs back to it. No sill or lid: they face where nothing looks, and the cap already exists.
static func _pocket(
	st: SurfaceTool, x_face: float, s: float, z0: float, z1: float, y_lo: float, y_hi: float
) -> void:
	var xd := x_face + s * HOLE_DEPTH
	var xj := x_face + s * WALL_T
	_quad(st, Vector3(xd, y_lo, z0), Vector3(xd, y_lo, z1), Vector3(xd, y_hi, z1),
		Vector3(xd, y_hi, z0), Vector3(-s, 0.0, 0.0), 0.0, 1.0, 0.0, 1.0)
	_quad(st, Vector3(xj, y_lo, z0), Vector3(xd, y_lo, z0), Vector3(xd, y_hi, z0),
		Vector3(xj, y_hi, z0), Vector3.BACK, 0.0, 1.0, 0.0, 1.0)
	_quad(st, Vector3(xj, y_lo, z1), Vector3(xd, y_lo, z1), Vector3(xd, y_hi, z1),
		Vector3(xj, y_hi, z1), Vector3.FORWARD, 0.0, 1.0, 0.0, 1.0)


## The step where column `c` meets the next one: a face from the lower top to the higher, deep
## as the taller column's roof plate or wall cap.
static func _step_face(
	st: SurfaceTool, x_face: float, s: float, y0: float, full: float, roof_d: float, c: Vector3,
	nx: Vector3
) -> void:
	if absf(c.z - nx.z) <= 0.05:
		return
	var c_taller := c.z > nx.z
	var taller_top := maxf(c.z, nx.z)
	var depth := roof_d if full - taller_top < ROOFED_DROP else WALL_T
	var x_in := x_face + s * depth
	var lo := minf(c.z, nx.z)
	_quad(st, Vector3(x_face, lo, c.y), Vector3(x_in, lo, c.y), Vector3(x_in, taller_top, c.y),
		Vector3(x_face, taller_top, c.y), Vector3.BACK if c_taller else Vector3.FORWARD,
		0.0, depth, lo - y0, taller_top - y0)


## A wall quad on the facade plane between z_a..z_b and y_a..y_b (v measured from y0 by caller).
static func _front(
	st: SurfaceTool, x_face: float, s: float, z_a: float, z_b: float, u_a: float, u_b: float,
	v_a: float, v_b: float
) -> void:
	var y0 := _FacadePlan.BASE_Y
	_quad(st, Vector3(x_face, y0 + v_a, z_a), Vector3(x_face, y0 + v_a, z_b),
		Vector3(x_face, y0 + v_b, z_b), Vector3(x_face, y0 + v_b, z_a), Vector3(-s, 0.0, 0.0),
		u_a, u_b, v_a, v_b)


## An end return at z; a deep body keeps the old one to the 9.6 wall plane at a tile edge (|z| 10,
## where the neighbour's side-street flank plate lies) and continues to its deep back 5 cm inside.
static func _end_returns(
	st: SurfaceTool, x_face: float, x_back: float, deep: bool, z: float, y0: float, top: float,
	w: float, normal_z: float
) -> void:
	if not deep or absf(z) < 9.99:
		_end_return(st, x_face, x_back, z, y0, top, w, normal_z)
		return
	var x_wall := signf(x_back) * 9.6
	_end_return(st, x_face, x_wall, z, y0, top, w, normal_z)
	_end_return(st, x_wall, x_back, z - normal_z * 0.05, y0, top, w + absf(x_wall - x_face),
		normal_z)


## End return from the face to the wall plane at z, up to `top`; same UV as facade_body's.
static func _end_return(
	st: SurfaceTool, x_face: float, x_back: float, z: float, y0: float, top: float, w: float,
	normal_z: float
) -> void:
	var reach := absf(x_back - x_face)
	_quad(st, Vector3(x_face, y0, z), Vector3(x_back, y0, z), Vector3(x_back, top, z),
		Vector3(x_face, top, z), Vector3(0.0, 0.0, normal_z), w, w + reach, 0.0, top - y0)


## add_quad with UV (u_a, v_a) at a, (u_b, v_a) at b, (u_b, v_b) at c and (u_a, v_b) at d.
static func _quad(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
	u_a: float, u_b: float, v_a: float, v_b: float
) -> void:
	_FacadeBody.add_quad(
		st, a, b, c, d, Vector2(u_a, v_a), Vector2(u_b, v_a), Vector2(u_b, v_b),
		Vector2(u_a, v_b), normal
	)


## u along the facade, as facade_body's (private there): from the left end seen from the road.
static func _u(z: float, z0: float, z1: float, side_sign: float) -> float:
	if side_sign > 0.0:
		return z - z0
	return z1 - z


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st
