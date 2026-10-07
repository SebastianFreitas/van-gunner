class_name VanKitSeams
extends RefCounted
## Kit pass 3: lap welds where one donor's skin meets another's (spec 4-4). Each cut gets a lap strip
## in the later donor's skin, an irregular weld bead and, on about half, a strap or channel.

const LAP := &"lap_weld"
const LAP_CM := 6.0
const LAP_DEPTH := 0.042
const BEAD_RUN_CM := Vector2(8.0, 15.0)
const BEAD_RUNS := 5
const STRAP_DEPTH := 0.064
const STRAP_LEN_CM := Vector2(30.0, 60.0)
const STRAP_WIDTH_CM := Vector2(5.0, 8.0)
const STRAP_ANGLE_DEG := Vector2(5.0, 15.0)
const STRAP_END_CM := 15.0
const _SURFACES: Array[StringName] = [&"left_wall", &"right_wall", &"ceiling"]
## Pieces placed so far: laps, beads, straps, dropped.
const _LAPS := 0
const _BEADS := 1
const _STRAPS := 2
const _DROPPED := 3


static func place(ctx: VanKitBuilder.Ctx) -> Array[VanKitPlaced]:
	var out: Array[VanKitPlaced] = []
	if ctx.keep_out == null or ctx.keep_out.walls == null:
		return out
	VanKitSurface.walls = ctx.keep_out.walls
	var rng := ctx.rng(&"seams")
	var stats: Array[int] = [0, 0, 0, 0]
	var env := {}
	for surface in _SURFACES:
		env[surface] = _env(ctx, surface)
	for b: Dictionary in ctx.donors.boundaries:
		var surface: StringName = b[&"surface"]
		var ia := _index(ctx.donors, b[&"donor_a"])
		var ib := _index(ctx.donors, b[&"donor_b"])
		if not _SURFACES.has(surface) or ia < 0 or ib < 0 or ia == ib:
			continue
		var later: StringName = b[&"donor_a"] if ia > ib else b[&"donor_b"]
		var earlier: StringName = b[&"donor_b"] if ia > ib else b[&"donor_a"]
		var centre := _region_centre(ctx.donors, surface, earlier)
		for part: PackedVector2Array in b[&"parts"]:
			if part.size() >= 2:
				_seam(env[surface], surface, part, centre - part[part.size() >> 1], later, true,
					rng, stats, out)
	_corners(ctx, env, rng, stats, out)
	print("seams seed %d laps %d beads %d straps %d dropped %d" % [ctx.van_seed,
		stats[_LAPS], stats[_BEADS], stats[_STRAPS], stats[_DROPPED]])
	return out


static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced], parent: Node3D) -> void:
	if ctx.keep_out != null:
		VanKitSurface.walls = ctx.keep_out.walls
	VanKitSeamsMesh.build(ctx.donors, placed, parent, ctx.van_seed)


## Per surface: its outline, the keep-out rectangles (windows, ribs, fixtures) laps stay off, ctx.
static func _env(ctx: VanKitBuilder.Ctx, surface: StringName) -> Dictionary:
	var sctx := VanKitBuilder.Ctx.new()
	sctx.donors = ctx.donors
	sctx.rig = ctx.rig
	for p in ctx.placed:
		if String(p.def_id).begins_with("structure/"):
			sctx.placed.append(p)
	var all := PackedVector2Array()
	for region: Dictionary in ctx.donors.regions:
		if region[&"surface"] == surface:
			all.append_array(region[&"outline"])
	var holes := VanKitSkin._holes(ctx.donors, surface)
	holes.append_array(VanKitSkin._blocks(sctx, surface))
	return {&"outline": _hull(all), &"holes": holes, &"ctx": ctx}


## The bounding rectangle of every region point (the surfaces' own outline is empty).
static func _hull(pts: PackedVector2Array) -> PackedVector2Array:
	var b := VanKitSkin._bounds(pts)
	return VanKitSkin._rect(b[0], b[1])


static func _index(donors: VanDonorSet, id: StringName) -> int:
	for i in donors.donors.size():
		if donors.donors[i].id == id:
			return i
	return -1


static func _region_centre(donors: VanDonorSet, surface: StringName, id: StringName) -> Vector2:
	for region: Dictionary in donors.regions:
		if region[&"surface"] == surface and region[&"donor_id"] == id:
			var b := VanKitSkin._bounds(region[&"outline"])
			return (b[0] + b[1]) * 0.5
	return Vector2.ZERO


## Vertical laps on the side wall's 6 cm at the cab corner and the rear corner (D29).
static func _corners(ctx: VanKitBuilder.Ctx, env: Dictionary, rng: RandomNumberGenerator,
		stats: Array[int], out: Array[VanKitPlaced]) -> void:
	if ctx.donors.donors.is_empty():
		return
	var cab_id: StringName = ctx.donors.donors[0].id
	var leaf_id: StringName = ctx.donors.donors[ctx.donors.donors.size() - 1].id
	for surface: StringName in [VanKitSurface.LEFT_WALL, VanKitSurface.RIGHT_WALL]:
		var wall := VanKitSkin._bounds(env[surface][&"outline"])
		for region: Dictionary in ctx.donors.regions:
			if region[&"surface"] != surface:
				continue
			var b := VanKitSkin._bounds(region[&"outline"])
			var id: StringName = region[&"donor_id"]
			if b[0].x <= wall[0].x + 1.0 and id != cab_id:
				_seam(env[surface], surface, PackedVector2Array([Vector2(b[0].x, b[0].y),
					Vector2(b[0].x, b[1].y)]), Vector2.RIGHT, id, false, rng, stats, out)
			if b[1].x >= wall[1].x - 1.0 and id != leaf_id:
				_seam(env[surface], surface, PackedVector2Array([Vector2(b[1].x, b[0].y),
					Vector2(b[1].x, b[1].y)]), Vector2.LEFT, leaf_id, false, rng, stats, out)


## One seam along `part`: the lap on its `toward` side, the bead on the lap's far edge, a strap.
static func _seam(env: Dictionary, surface: StringName, part: PackedVector2Array, toward: Vector2,
		later: StringName, strap: bool, rng: RandomNumberGenerator, stats: Array[int],
		out: Array[VanKitPlaced]) -> void:
	var chord := part[part.size() - 1] - part[0]
	var side := Vector2(-chord.y, chord.x).normalized()
	if side.dot(toward) < 0.0:
		side = -side
	var near := PackedVector2Array()
	var far := PackedVector2Array()
	for i in part.size():
		var d := part[mini(i + 1, part.size() - 1)] - part[maxi(i - 1, 0)]
		var n := Vector2(-d.y, d.x).normalized()
		if n.dot(side) < 0.0:
			n = -n
		near.append(part[i])
		far.append(part[i] + n * LAP_CM)
	var lap := near.duplicate()
	for i in range(far.size() - 1, -1, -1):
		lap.append(far[i])
	stats[_LAPS] += _emit(env, surface, lap, LAP_DEPTH, &"DONOR", later, stats, out)
	var total := _length(far)
	# One bead piece per BEAD_RUNS runs (a piece under VanKitClip.MIN_AREA is dropped): the ridge
	# height, and so the footprint width, changes at every run vertex.
	var s := 0.0
	while s < total - 0.5:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for k in BEAD_RUNS + 1:
			var w := _walk(far, s)
			var perp := Vector2(-w[1].y, w[1].x)
			if perp.dot(side) < 0.0:
				perp = -perp
			var runs := VanKitSeamsMesh.ridge_runs(rng.randf_range(
				VanKitSeamsMesh.RIDGE_M.x, VanKitSeamsMesh.RIDGE_M.y))
			left.append(w[0] - perp * runs.x)
			right.append(w[0] + perp * runs.y)
			if s >= total - 0.5:
				break
			s = minf(total, s + rng.randf_range(BEAD_RUN_CM.x, BEAD_RUN_CM.y))
		right.reverse()
		left.append_array(right)
		stats[_BEADS] += _emit(env, surface, left, VanKitSeamsMesh.RIDGE_M.y, &"SCRAP",
			&"weld_bead", stats, out)
	if strap and rng.randf() < 0.5:
		_strap(env, surface, part, rng, stats, out)


static func _strap(env: Dictionary, surface: StringName, part: PackedVector2Array,
		rng: RandomNumberGenerator, stats: Array[int], out: Array[VanKitPlaced]) -> void:
	var total := _length(part)
	var channel := rng.randf() < 0.5
	var at := rng.randf_range(STRAP_END_CM, maxf(STRAP_END_CM, total - STRAP_END_CM))
	var length := rng.randf_range(STRAP_LEN_CM.x, STRAP_LEN_CM.y)
	var width := rng.randf_range(STRAP_WIDTH_CM.x, STRAP_WIDTH_CM.y)
	var tilt := rng.randf_range(STRAP_ANGLE_DEG.x, STRAP_ANGLE_DEG.y) * (1.0 if rng.randf() < 0.5 \
			else -1.0)
	if total < STRAP_END_CM * 2.0:
		stats[_DROPPED] += 1
		return
	var walk := _walk(part, at)
	var dir: Vector2 = walk[1]
	var axis := Vector2(-dir.y, dir.x).rotated(deg_to_rad(tilt))
	var across := Vector2(-axis.y, axis.x) * width * 0.5
	var c: Vector2 = walk[0]
	var poly := PackedVector2Array([c - axis * length * 0.5 - across, c + axis * length * 0.5 - across,
		c + axis * length * 0.5 + across, c - axis * length * 0.5 + across])
	var before := out.size()
	var id := &"channel" if channel else &"strap"
	var area := absf(VanKitClip._area(poly))
	var inside := Geometry2D.intersect_polygons(poly, env[&"outline"])
	var whole := inside.size() == 1 and absf(absf(VanKitClip._area(inside[0])) - area) < 1.0
	for hole: PackedVector2Array in env[&"holes"]:
		if not Geometry2D.intersect_polygons(poly, hole).is_empty():
			whole = false
	if whole:
		_emit(env, surface, poly, STRAP_DEPTH, &"SCRAP", id, stats, out)
		if out.size() - before != 1 or absf(absf(VanKitClip._area(out.back().outline)) - area) > 1.0:
			while out.size() > before:
				out.pop_back()
			whole = false
	if whole:
		stats[_STRAPS] += 1
	else:
		stats[_DROPPED] += 1


## Clips `poly` to the surface, the keep-out rectangles and the keep-out; adds what is left.
static func _emit(env: Dictionary, surface: StringName, poly: PackedVector2Array, depth: float,
		origin_kind: StringName, origin_id: StringName, stats: Array[int],
		out: Array[VanKitPlaced]) -> int:
	var ctx: VanKitBuilder.Ctx = env[&"ctx"]
	var pieces: Array[PackedVector2Array] = []
	for piece in Geometry2D.intersect_polygons(poly, env[&"outline"]):
		if not Geometry2D.is_polygon_clockwise(piece):
			pieces.append(piece)
	for hole: PackedVector2Array in env[&"holes"]:
		pieces = VanKitSkin._minus(pieces, hole)
	var n := 0
	for piece in pieces:
		for part in VanKitClip.cut(ctx.keep_out, surface, piece, depth, &"seam"):
			var p := _piece(surface, part, depth, origin_kind, origin_id)
			if ctx.keep_out.allows(p.transform * AABB(-p.size * 0.5, p.size), &"seam"):
				out.append(p)
				n += 1
			else:
				stats[_DROPPED] += 1
	return n


static func _piece(surface: StringName, poly: PackedVector2Array, depth: float,
		origin_kind: StringName, origin_id: StringName) -> VanKitPlaced:
	var b := VanKitSkin._bounds(poly)
	var centre := (b[0] + b[1]) * 0.5
	var normal := VanKitSurface.normal(surface, centre.x, centre.y)
	var tangent := normal.cross(Vector3.BACK)
	var p := VanKitPlaced.new()
	p.def_id = LAP
	p.surface = surface
	p.origin_kind = origin_kind
	p.origin_id = origin_id
	p.reason = &"splice_cover"
	p.transform = Transform3D(Basis(tangent, normal, Vector3.BACK),
		VanKitSurface.point(surface, centre.x, centre.y, 0.0) + normal * (depth * 0.5))
	var axis := 0 if surface == VanKitSurface.CEILING else 1
	p.size = Vector3((b[1].y - b[0].y) * 0.01 / maxf(absf(tangent[axis]), 0.2), depth,
		(b[1].x - b[0].x) * 0.01)
	p.outline = poly
	p.gen = VanKit.GEN
	return p


static func _length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


## [position, unit direction] at arclength `s` (cm) along `pts`.
static func _walk(pts: PackedVector2Array, s: float) -> Array[Vector2]:
	var left := s
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if left <= seg or i == pts.size() - 2:
			var dir := (pts[i + 1] - pts[i]).normalized()
			return [pts[i] + dir * minf(left, seg), dir]
		left -= seg
	return [pts[0], Vector2.RIGHT]
