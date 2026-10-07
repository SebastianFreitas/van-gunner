class_name VanKitSkin
extends RefCounted
## Kit pass 2: sheet panels on the side walls and the ceiling, each region in its donor's style.
## `place` is data only; `build` hands the pieces to VanKitSkinMesh.

const PANEL := &"skin/panel"
## `reason` of a panel whose hi z end is a factory edge (not a clip end): the rules read these.
const PANEL_EDGE := &"panel_edge"
## Same for the lap-side lo z end, and for a piece with both ends factory edges.
const PANEL_EDGE_LO := &"panel_edge_lo"
const PANEL_EDGE_BOTH := &"panel_edge_both"
const THICK := 0.006
## Outer face off the liner of even and odd panels (same-facing faces at least 1.2 cm apart).
const DEPTH_EVEN := 0.012
const DEPTH_ODD := 0.026
## Each panel laps the previous one by this much (cm, rolled).
const LAP_CM := Vector2(4.0, 8.0)
## The skin runs this far (cm) under a window piece's edge.
const UNDER_CM := 4.0
const SHIFT_STEP_CM := 5.0
const CLEAR_CM := 60.0
const _SURFACES: Array[StringName] = [&"left_wall", &"right_wall", &"ceiling"]
const _GAP_Z_CM := Vector2(10.0, 40.0)
const _GAP_Y_CM := Vector2(30.0, 120.0)
## Stripped gaps keep this far (cm) off a window piece.
const _GAP_CLEAR_CM := 5.0
const _GAP_TRIES := 12
## Panels stop this far (cm) short of a rib, pillar, bow or shell fixture.
const _STOP_CM := 0.5
const _FIXTURE_NODES: Array[String] = ["CargoRail_", "DoorStop_", "WindowStop", "WallPost_"]
## The bulkhead's vault rails: the only shell fixtures that reach the ceiling.
const _CEILING_FIXTURES: Array[String] = ["TopRail_"]


static func place(ctx: VanKitBuilder.Ctx) -> Array[VanKitPlaced]:
	var out: Array[VanKitPlaced] = []
	if ctx.keep_out == null or ctx.keep_out.walls == null:
		return out
	VanKitSurface.walls = ctx.keep_out.walls
	var gap_counts := {}
	var dropped: Array[int] = [0]
	VanKitGaps.reset()
	for surface in _SURFACES:
		var rng := ctx.rng(&"skin", surface)
		var wall := surface != VanKitSurface.CEILING
		var gaps: Array[PackedVector2Array] = []
		if wall:
			gaps = _gaps(ctx, surface, rng)
			VanKitGaps.record(surface, gaps)
		gap_counts[surface] = gaps.size()
		for region: Dictionary in ctx.donors.regions:
			if region[&"surface"] != surface:
				continue
			var donor := VanKitStructure._donor(ctx.donors, region[&"donor_id"])
			if donor != null:
				_region(ctx, region, donor, gaps, rng, out, dropped)
	VanKitSkinFloor.place(ctx, out)
	VanKitSkinEnds.place(ctx, out)
	print("skin seed %d gaps L %d R %d dropped %d" % [ctx.van_seed,
		gap_counts[VanKitSurface.LEFT_WALL], gap_counts[VanKitSurface.RIGHT_WALL], dropped[0]])
	return out


static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced], parent: Node3D) -> void:
	if ctx.keep_out != null:
		VanKitSurface.walls = ctx.keep_out.walls
	VanKitSkinMesh.build(ctx.donors, placed, parent, ctx.van_seed)


static func _region(ctx: VanKitBuilder.Ctx, region: Dictionary, donor: VanDonor,
		gaps: Array[PackedVector2Array], rng: RandomNumberGenerator,
		out: Array[VanKitPlaced], dropped: Array[int]) -> void:
	var surface: StringName = region[&"surface"]
	var outline: PackedVector2Array = region[&"outline"]
	if outline.size() < 3 or donor.rib_pitch_m <= 0.0:
		return
	var lo := _bounds(outline)[0]
	var hi := _bounds(outline)[1]
	var step := donor.rib_pitch_m * 200.0
	var laps: Array[float] = []
	for i in ceili((hi.x - lo.x) / step) + 2:
		laps.append(rng.randf_range(LAP_CM.x, LAP_CM.y))
	var holes := _holes(ctx.donors, surface)
	holes.append_array(_blocks(ctx, surface))
	holes.append_array(gaps)
	var shift := 0.0
	var best := 0.0
	var best_n := 1 << 30
	var best_clear := -1.0
	var base: Array[Dictionary] = []
	base.append_array(ctx.donors.boundaries)
	var theirs := VanKitRulesLines._panel_edges(out)
	base.append_array(theirs)
	var baseline := _lines(base)
	while shift <= step + 0.01:
		# Plan on the panels the rules will see: clipped and dropped ends are not edges.
		var trial: Array[VanKitPlaced] = []
		_panels(ctx, surface, donor, outline, _edge_zs(lo.x, hi.x, step, shift), laps, holes,
				trial, [0])
		var mine := VanKitRulesLines._panel_edges(trial)
		var all: Array[Dictionary] = []
		all.append_array(base)
		all.append_array(mine)
		var n := _lines(all)
		var clear := _clearance(surface, mine, theirs)
		if n < best_n or (n == best_n and clear > best_clear):
			best_n = n
			best_clear = clear
			best = shift
		if n <= baseline and clear >= CLEAR_CM:
			break
		shift += SHIFT_STEP_CM
	if best_n > baseline:
		print("skin seed %d %s panel shift failed" % [ctx.van_seed, surface])
	_panels(ctx, surface, donor, outline, _edge_zs(lo.x, hi.x, step, best), laps, holes, out,
			dropped)


## The region's panels for the edge zs `zs`; ends that are factory edges are tagged for the rules.
static func _panels(ctx: VanKitBuilder.Ctx, surface: StringName, donor: VanDonor,
		outline: PackedVector2Array, zs: Array[float], laps: Array[float],
		holes: Array[PackedVector2Array], out: Array[VanKitPlaced], dropped: Array[int]) -> void:
	var lo := _bounds(outline)[0]
	var hi := _bounds(outline)[1]
	var cuts: Array[float] = [lo.x]
	cuts.append_array(zs)
	cuts.append(hi.x)
	for i in cuts.size() - 1:
		var z0 := cuts[i] - (laps[i] if i > 0 else 0.0)
		var depth := DEPTH_EVEN if i % 2 == 0 else DEPTH_ODD
		var pieces: Array[PackedVector2Array] = []
		pieces.assign(Geometry2D.intersect_polygons(
				_rect(Vector2(z0, lo.y - 1.0), Vector2(cuts[i + 1], hi.y + 1.0)), outline))
		for hole in holes:
			pieces = _minus(pieces, hole)
		for piece in pieces:
			for part in VanKitClip.cut(ctx.keep_out, surface, piece, depth, &"skin"):
				_add(out, surface, donor.id, part, depth)
				# The rules test the piece's bounding box, wider than the cut on a slanted wall.
				var last: VanKitPlaced = out.back()
				var hi_edge := i + 2 < cuts.size() \
						and absf(_bounds(part)[1].x - cuts[i + 1]) < 0.01
				var lo_edge := i > 0 and absf(_bounds(part)[0].x - z0) < 0.01
				if hi_edge and lo_edge:
					last.reason = PANEL_EDGE_BOTH
				elif hi_edge:
					last.reason = PANEL_EDGE
				elif lo_edge:
					last.reason = PANEL_EDGE_LO
				if not ctx.keep_out.allows(last.transform * AABB(-last.size * 0.5, last.size),
						&"skin"):
					out.pop_back()
					dropped[0] += 1


## Z (cm) of every panel edge inside a region: first + shift + k * step, off the region's ends.
static func _edge_zs(first: float, last: float, step: float, shift: float) -> Array[float]:
	var zs: Array[float] = []
	var k := 0
	while first + shift + k * step < last - 1.0:
		var z := first + shift + k * step
		k += 1
		if z > first + 1.0:
			zs.append(z)
	return zs


## Smallest z distance (cm) from `mine` to the panel edges other surfaces already have. Two
## surfaces' edges at least 2 * 30 cm apart leave no z within the crowd reach of both, so the
## third surface cannot make a crowd.
static func _clearance(surface: StringName, mine: Array[Dictionary],
		theirs: Array[Dictionary]) -> float:
	var clear := INF
	for a in mine:
		for b in theirs:
			if b[&"surface"] != surface:
				clear = minf(clear, absf(a[&"parts"][0][0].x - b[&"parts"][0][0].x))
	return clear


static func _lines(bounds: Array[Dictionary]) -> int:
	var lines := PackedStringArray()
	VanKitRulesLines._gaps(bounds, lines, false)
	return lines.size()


## Per window on the surface, the rectangle round its opening and its piece (shrunk 4 cm), so no
## panel covers an open window until the window pieces exist.
static func _holes(donors: VanDonorSet, surface: StringName) -> Array[PackedVector2Array]:
	var holes: Array[PackedVector2Array] = []
	for entry: Dictionary in donors.windows:
		if entry[&"surface"] != surface:
			continue
		var all := PackedVector2Array()
		all.append_array(entry[&"opening"])
		var piece: PackedVector2Array = entry[&"piece_outline"]
		if piece.size() >= 3:
			for poly in VanKitStructure._offset(piece, -UNDER_CM):
				all.append_array(poly)
		if all.size() >= 3:
			var b := _bounds(all)
			holes.append(_rect(b[0], b[1]))
	return holes


## Rectangles (surface cm) of the ribs, pillars and bows placed before the skin and of the shell
## fixtures on this surface, each grown _STOP_CM.
static func _blocks(ctx: VanKitBuilder.Ctx, surface: StringName) -> Array[PackedVector2Array]:
	var boxes: Array[AABB] = []
	for p in ctx.placed:
		if p.surface == surface:
			boxes.append(p.transform * AABB(-p.size * 0.5, p.size))
	if surface == VanKitSurface.CEILING and ctx.rig != null:
		boxes.append_array(_fixtures(ctx.rig, _CEILING_FIXTURES))
	if surface != VanKitSurface.CEILING and ctx.rig != null:
		var sign_x := -1.0 if surface == VanKitSurface.LEFT_WALL else 1.0
		for box in _fixtures(ctx.rig, _FIXTURE_NODES):
			if signf(box.get_center().x) == sign_x:
				boxes.append(box)
	var out: Array[PackedVector2Array] = []
	for box in boxes:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for i in 8:
			var ab := VanKitClip._ab(surface, box.get_endpoint(i))
			lo = lo.min(ab)
			hi = hi.max(ab)
		out.append(_rect(lo - Vector2.ONE * _STOP_CM, hi + Vector2.ONE * _STOP_CM))
	return out


## Rig-space boxes of the wall rails, door and window stops and the bulkhead's wall posts.
static func _fixtures(rig: Node3D, names: Array[String]) -> Array[AABB]:
	var out: Array[AABB] = []
	var to_rig := rig.global_transform.affine_inverse()
	for path in ["Interior/Shell/SideWalls", "Interior/Shell/SideWindows", "Interior/Bulkhead"]:
		var root := rig.get_node_or_null(path)
		if root == null:
			continue
		for node in root.find_children("*", "GeometryInstance3D", true, false):
			var inst := node as GeometryInstance3D
			var key := String(inst.name)
			for part in names:
				if key.contains(part):
					out.append(VanKitKeepOut.snap_box(
						(to_rig * inst.global_transform) * inst.get_aabb()))
					break
	return out


## 0..2 torch-rough stripped gaps (cm) on a wall, off the window pieces and the door bay.
static func _gaps(ctx: VanKitBuilder.Ctx, surface: StringName,
		rng: RandomNumberGenerator) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var span := Vector2(INF, -INF)
	for region: Dictionary in ctx.donors.regions:
		if region[&"surface"] == surface:
			span = Vector2(minf(span.x, _bounds(region[&"outline"])[0].x),
				maxf(span.y, _bounds(region[&"outline"])[1].x))
	var want := rng.randi_range(0, 2)
	var bay := VanKitFootprint.door_bay() * 100.0
	for n in want:
		for t in _GAP_TRIES:
			var size := Vector2(rng.randf_range(_GAP_Z_CM.x, _GAP_Z_CM.y),
				rng.randf_range(_GAP_Y_CM.x, _GAP_Y_CM.y))
			if span.y - span.x < size.x + 20.0:
				continue
			var at := Vector2(rng.randf_range(span.x + 10.0, span.y - size.x - 10.0),
				rng.randf_range(20.0, 280.0 - size.y))
			var rect := _rect(at - Vector2.ONE * (_GAP_CLEAR_CM + 5.0),
				at + size + Vector2.ONE * (_GAP_CLEAR_CM + 5.0))
			if rect[1].x > bay.x and rect[0].x < bay.y:
				continue
			if not _in_region(ctx.donors, surface, rect) or _near_piece(ctx.donors, surface, rect):
				continue
			var poly := _rough(_rect(at, at + size), rng)
			if Geometry2D.is_polygon_clockwise(poly):
				poly.reverse()
			out.append(poly)
			break
	return out


static func _in_region(donors: VanDonorSet, surface: StringName, rect: PackedVector2Array) -> bool:
	for region: Dictionary in donors.regions:
		if region[&"surface"] == surface \
				and Geometry2D.clip_polygons(rect, region[&"outline"]).is_empty():
			return true
	return false


static func _near_piece(donors: VanDonorSet, surface: StringName,
		rect: PackedVector2Array) -> bool:
	for entry: Dictionary in donors.windows:
		var piece: PackedVector2Array = entry[&"piece_outline"]
		if entry[&"surface"] == surface and piece.size() >= 3 \
				and not Geometry2D.intersect_polygons(rect, piece).is_empty():
			return true
	return false


## A rectangle's outline with a point every 8..15 cm, each pushed 2..5 cm in or out.
static func _rough(rect: PackedVector2Array, rng: RandomNumberGenerator) -> PackedVector2Array:
	var centre := (rect[0] + rect[2]) * 0.5
	var out := PackedVector2Array()
	for i in 4:
		var a := rect[i]
		var b := rect[(i + 1) % 4]
		var edge_len := a.distance_to(b)
		var d := 0.0
		while d < edge_len - 4.0:
			var p := a.lerp(b, d / edge_len)
			var push := rng.randf_range(2.0, 5.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			out.append(p + (p - centre).normalized() * push)
			d += rng.randf_range(8.0, 15.0)
	return out


## `pieces` minus `hole`; a hole inside a piece splits it at the hole's centre first.
static func _minus(pieces: Array[PackedVector2Array],
		hole: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var hb := _bounds(hole)
	if hole.size() == 4 and hole[0].y == hole[1].y and hole[1].x == hole[2].x:
		# A rectangle: keep the four bands round it, which never leaves a hole polygon.
		for poly in pieces:
			var pb := _bounds(poly)
			for band in [_rect(pb[0], Vector2(hb[0].x, pb[1].y)),
					_rect(Vector2(hb[1].x, pb[0].y), pb[1]),
					_rect(Vector2(hb[0].x, pb[0].y), Vector2(hb[1].x, hb[0].y)),
					_rect(Vector2(hb[0].x, hb[1].y), Vector2(hb[1].x, pb[1].y))]:
				if band[0].x < band[2].x and band[0].y < band[2].y:
					out.append_array(Geometry2D.intersect_polygons(poly, band))
		return out
	for poly in pieces:
		var parts: Array[PackedVector2Array] = []
		parts.assign(Geometry2D.clip_polygons(poly, hole))
		for part in parts:
			if Geometry2D.is_polygon_clockwise(part):
				parts = []
				var pb := _bounds(poly)
				var cut_at := (hb[0].x + hb[1].x) * 0.5
				for half in [_rect(pb[0], Vector2(cut_at, pb[1].y)),
						_rect(Vector2(cut_at, pb[0].y), pb[1])]:
					for side in Geometry2D.intersect_polygons(poly, half):
						parts.append_array(Geometry2D.clip_polygons(side, hole))
				break
		out.append_array(parts)
	return out


static func _add(out: Array[VanKitPlaced], surface: StringName, donor_id: StringName,
		poly: PackedVector2Array, depth: float) -> void:
	var b := _bounds(poly)
	var centre := (b[0] + b[1]) * 0.5
	var normal := VanKitSurface.normal(surface, centre.x, centre.y)
	var tangent := normal.cross(Vector3.BACK)
	var face := VanKitSurface.point(surface, centre.x, centre.y, 0.0)
	var p := VanKitPlaced.new()
	p.def_id = PANEL
	p.surface = surface
	p.origin_kind = &"DONOR"
	p.origin_id = donor_id
	p.reason = &"region_skin"
	p.transform = Transform3D(Basis(tangent, normal, Vector3.BACK), face + normal * (depth * 0.5))
	var axis := 0 if surface == VanKitSurface.CEILING else 1
	p.size = Vector3((b[1].y - b[0].y) * 0.01 / maxf(absf(tangent[axis]), 0.2), depth,
		(b[1].x - b[0].x) * 0.01)
	p.outline = poly
	p.gen = VanKit.GEN
	out.append(p)


static func _bounds(poly: PackedVector2Array) -> Array[Vector2]:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	return [lo, hi]


static func _rect(lo: Vector2, hi: Vector2) -> PackedVector2Array:
	return PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])
