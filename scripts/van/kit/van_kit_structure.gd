class_name VanKitStructure
extends RefCounted
## Kit pass 1: where each donor van's skeleton sits (wall ribs, ceiling bows, window pillars).
## `place` is data only; `build` hands the pieces to VanKitStructureMesh.

const RIB := &"structure/rib"
const BOW := &"structure/bow"
const PILLAR := &"structure/pillar"
const DEPTH := 0.07
const RIB_W := 0.06
const PILLAR_W := 0.08
## How far a piece stops short of an outline or a window piece.
const STOP := 0.03
## Longest straight run before a rib or bow follows the wall or vault in another facet.
const FACET := 0.6
const MIN_RUN := 0.15
## Ceiling barrel, copied from VanCeiling (span_x, edge_height, peak_rise).
const _VAULT_HALF_X := 2.04
const _VAULT_EDGE := 3.05
const _VAULT_RISE := 0.38

## A piece shorter than this along its run is not worth keeping after a shortening.
const MIN_PIECE := 0.2
## The bulkhead frame's wall posts stand at z 1.0, 0.16 deep; no wall piece overlaps them.
const _BULKHEAD_Z := 1.0
const _BULKHEAD_HALF := 0.08

## Pieces the keep-out refused outright in the last place() call, by def id.
static var dropped := {RIB: 0, BOW: 0, PILLAR: 0}


static func place(ctx: VanKitBuilder.Ctx) -> Array[VanKitPlaced]:
	var out: Array[VanKitPlaced] = []
	dropped = {RIB: 0, BOW: 0, PILLAR: 0}
	if ctx.keep_out == null or ctx.keep_out.walls == null:
		return out
	for region: Dictionary in ctx.donors.regions:
		var surface: StringName = region[&"surface"]
		var donor := _donor(ctx.donors, region[&"donor_id"])
		if donor == null:
			continue
		if surface == &"left_wall" or surface == &"right_wall":
			_wall_ribs(ctx, region, donor, out)
		elif surface == &"ceiling":
			_bows(ctx, region, donor, out)
	_pillars(ctx, out)
	return out


## One profile mesh per placed piece under `parent`.
static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced], parent: Node3D) -> void:
	VanKitStructureMesh.new().build(ctx.donors, placed, parent, ctx.van_seed)


## `structure rib N bow N pillar N dropped rib N bow N pillar N` for the rules check's info lines.
static func summary(placed: Array[VanKitPlaced]) -> String:
	var counts := {RIB: 0, BOW: 0, PILLAR: 0}
	for p in placed:
		if counts.has(p.def_id):
			counts[p.def_id] += 1
	return "structure rib %d bow %d pillar %d dropped rib %d bow %d pillar %d" % [
		counts[RIB], counts[BOW], counts[PILLAR], dropped[RIB], dropped[BOW], dropped[PILLAR]]


static func _donor(donors: VanDonorSet, id: StringName) -> VanDonor:
	for d in donors.donors:
		if d.id == id:
			return d
	return null


static func _cm_to_m(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(p * 0.01)
	return out


static func _wall_ribs(ctx: VanKitBuilder.Ctx, region: Dictionary, donor: VanDonor,
		out: Array[VanKitPlaced]) -> void:
	var surface: StringName = region[&"surface"]
	var outline := _cm_to_m(region[&"outline"])
	if outline.size() < 3 or donor.rib_pitch_m <= 0.0:
		return
	var inner := _offset(outline, -(STOP + RIB_W * 0.5))
	var holes: Array[PackedVector2Array] = []
	for entry: Dictionary in ctx.donors.windows:
		var piece: PackedVector2Array = entry[&"piece_outline"]
		if entry[&"surface"] == surface and piece.size() >= 3:
			holes.append_array(_offset(_cm_to_m(piece), STOP + RIB_W * 0.5))
	var pillar_zs := _pillar_zs(ctx.donors, surface)
	var bay := VanKitFootprint.door_bay()
	var z_first := _min_x(outline)
	var z_last := _max_x(outline)
	var k := 0
	while z_first + k * donor.rib_pitch_m <= z_last:
		var z := z_first + k * donor.rib_pitch_m
		k += 1
		if z + RIB_W * 0.5 > bay.x and z - RIB_W * 0.5 < bay.y:
			continue
		if _near_pillar(z, pillar_zs):
			continue
		for run in _runs(z, inner, holes, -1.0, 6.0):
			_wall_pieces(ctx, out, RIB, RIB_W, surface, donor.id, z, run)


## A pillar each side of every side window piece, the region's height at that z.
static func _pillars(ctx: VanKitBuilder.Ctx, out: Array[VanKitPlaced]) -> void:
	for region: Dictionary in ctx.donors.regions:
		var surface: StringName = region[&"surface"]
		if surface != &"left_wall" and surface != &"right_wall":
			continue
		var inner := _offset(_cm_to_m(region[&"outline"]), -(STOP + PILLAR_W * 0.5))
		for z in _pillar_zs(ctx.donors, surface):
			for run in _runs(z, inner, [], -1.0, 6.0):
				_wall_pieces(ctx, out, PILLAR, PILLAR_W, surface, region[&"donor_id"], z, run)


## Pillar z centres: 3 cm off each side of every side window piece on the surface.
static func _pillar_zs(donors: VanDonorSet, surface: StringName) -> Array[float]:
	var zs: Array[float] = []
	for entry: Dictionary in donors.windows:
		var piece: PackedVector2Array = entry[&"piece_outline"]
		if entry[&"surface"] != surface or piece.size() < 3:
			continue
		var poly := _cm_to_m(piece)
		zs.append(_min_x(poly) - STOP - PILLAR_W * 0.5)
		zs.append(_max_x(poly) + STOP + PILLAR_W * 0.5)
	return zs


static func _near_pillar(z: float, pillar_zs: Array[float]) -> bool:
	for pz in pillar_zs:
		if absf(z - pz) < PILLAR_W + STOP:
			return true
	return false


## The (lo, hi) spans along a straight line at `at` inside `inner` and outside every hole; the
## line runs along v from `v0` to `v1`.
static func _runs(at: float, inner: Array[PackedVector2Array],
		holes: Array[PackedVector2Array], v0: float, v1: float) -> Array[Vector2]:
	var polylines: Array[PackedVector2Array] = []
	for poly in inner:
		for line in Geometry2D.intersect_polyline_with_polygon(
				PackedVector2Array([Vector2(at, v0), Vector2(at, v1)]), poly):
			polylines.append(line)
	for hole in holes:
		var next: Array[PackedVector2Array] = []
		for line in polylines:
			for part in Geometry2D.clip_polyline_with_polygon(line, hole):
				next.append(part)
		polylines = next
	var runs: Array[Vector2] = []
	for line in polylines:
		var lo := INF
		var hi := -INF
		for p in line:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		if hi - lo >= MIN_RUN:
			runs.append(Vector2(lo, hi))
	runs.sort()
	return runs


## One wall run as facets that follow the liner's lean, each 0 degrees about its normal.
static func _wall_pieces(ctx: VanKitBuilder.Ctx, out: Array[VanKitPlaced], def_id: StringName,
		width: float, surface: StringName, donor_id: StringName, z: float, run: Vector2) -> void:
	if absf(z - _BULKHEAD_Z) < _BULKHEAD_HALF + width * 0.5 + STOP:
		return
	var walls := ctx.keep_out.walls
	var sign_x := -1.0 if surface == &"left_wall" else 1.0
	var n := maxi(1, ceili((run.y - run.x) / FACET))
	var step := (run.y - run.x) / n
	for i in n:
		var y := run.x + (i + 0.5) * step
		var dx := (walls.wall_x_at(y + 0.02) - walls.wall_x_at(y - 0.02)) / 0.04
		var slant := sqrt(1.0 + dx * dx)
		var normal := Vector3(-sign_x, dx, 0.0) / slant
		var face := Vector3(sign_x * walls.wall_x_at(y), y, z)
		var size := Vector3(step * slant, DEPTH, width)
		_add(ctx, out, def_id, surface, donor_id, face, normal, size)


static func _bows(ctx: VanKitBuilder.Ctx, region: Dictionary, donor: VanDonor,
		out: Array[VanKitPlaced]) -> void:
	var outline := _cm_to_m(region[&"outline"])
	if outline.size() < 3 or donor.rib_pitch_m <= 0.0:
		return
	var inner := _offset(outline, -(STOP + RIB_W * 0.5))
	var z_first := _min_x(outline)
	var z_last := _max_x(outline)
	var k := 0
	while z_first + k * donor.rib_pitch_m <= z_last:
		var z := z_first + k * donor.rib_pitch_m
		k += 1
		for run in _runs(z, inner, [], -4.0, 4.0):
			var n := maxi(1, ceili((run.y - run.x) / FACET))
			var step := (run.y - run.x) / n
			for i in n:
				var x := run.x + (i + 0.5) * step
				var slope := -2.0 * _VAULT_RISE * x / (_VAULT_HALF_X * _VAULT_HALF_X)
				var slant := sqrt(1.0 + slope * slope)
				var normal := Vector3(slope, -1.0, 0.0) / slant
				var y := _VAULT_EDGE + _VAULT_RISE * (1.0 - minf(x * x / (
						_VAULT_HALF_X * _VAULT_HALF_X), 1.0))
				_add(ctx, out, BOW, &"ceiling", donor.id, Vector3(x, y, z), normal,
					Vector3(step * slant, DEPTH, RIB_W))


## Adds one piece standing on `face` with its depth along `normal`; the keep-out may refuse it.
static func _add(ctx: VanKitBuilder.Ctx, out: Array[VanKitPlaced], def_id: StringName,
		surface: StringName, donor_id: StringName, face: Vector3, normal: Vector3,
		size: Vector3) -> void:
	var p := VanKitPlaced.new()
	p.def_id = def_id
	p.surface = surface
	p.origin_kind = &"DONOR"
	p.origin_id = donor_id
	p.reason = StringName(String(def_id).get_slice("/", 1))
	var basis_x := normal.cross(Vector3.BACK)
	p.transform = Transform3D(Basis(basis_x, normal, Vector3.BACK), face + normal * (DEPTH * 0.5))
	p.size = size
	p.gen = VanKit.GEN
	var axis := 0 if surface == &"ceiling" else 1
	if not _fit(ctx, p, axis, 3, out):
		dropped[def_id] += 1


## Appends `p`, or what is left of it after stopping 3 cm short of the refusing volume along the
## run `axis` (from either end; both remainders when each is at least MIN_PIECE). False when
## nothing of it survives.
static func _fit(ctx: VanKitBuilder.Ctx, p: VanKitPlaced, axis: int, tries: int,
		out: Array[VanKitPlaced]) -> bool:
	var box := p.transform * AABB(-p.size * 0.5, p.size)
	if ctx.keep_out.allows(box, &"structure"):
		out.append(p)
		return true
	var tangent := p.transform.basis.x
	if tries <= 0 or absf(tangent[axis]) < 0.5:
		return false
	var vol := ctx.keep_out.blocker_box(box, &"structure")
	var lo := box.position[axis]
	var hi := box.end[axis]
	var ratio := p.size.x / (hi - lo)
	var kept := false
	for span in [Vector2(lo, vol.position[axis] - STOP), Vector2(vol.end[axis] + STOP, hi)]:
		var s: Vector2 = span
		s = Vector2(maxf(s.x, lo), minf(s.y, hi))
		if (s.y - s.x) * ratio < MIN_PIECE:
			continue
		var q := VanKitPlaced.new()
		q.def_id = p.def_id
		q.surface = p.surface
		q.origin_kind = p.origin_kind
		q.origin_id = p.origin_id
		q.reason = p.reason
		q.gen = p.gen
		q.size = Vector3((s.y - s.x) * ratio, p.size.y, p.size.z)
		q.transform = p.transform
		q.transform.origin += tangent * (((s.x + s.y) * 0.5 - (lo + hi) * 0.5) / tangent[axis])
		kept = _fit(ctx, q, axis, tries - 1, out) or kept
	return kept


## The polygons that result from growing (delta > 0) or shrinking a poly; either winding works.
static func _offset(poly: PackedVector2Array, delta: float) -> Array[PackedVector2Array]:
	var base := absf(_area(poly))
	for variant in [poly, _reversed(poly)]:
		var res: Array[PackedVector2Array] = []
		res.assign(Geometry2D.offset_polygon(variant, delta))
		var total := 0.0
		for r in res:
			total += absf(_area(r))
		if not res.is_empty() and (total < base) == (delta < 0.0):
			return res
	return []


static func _reversed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.reverse()
	return out


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5


static func _min_x(poly: PackedVector2Array) -> float:
	var v := INF
	for p in poly:
		v = minf(v, p.x)
	return v


static func _max_x(poly: PackedVector2Array) -> float:
	var v := -INF
	for p in poly:
		v = maxf(v, p.x)
	return v
