class_name VanKitPatches
extends RefCounted
## Pass 4: three to six salvage patches (road signs, car doors, fridge doors, scrap steel) cut by
## VanKitPatchCut, placed in the patch zones of the walls and rear leaves; the first one tells.

const DEFS_DIR := "res://resources/van_kit/patches"
const COUNT := Vector2i(6, 9)
const MAX_PER_DEF := 3
const TRIES := 24
const SHRINK := 0.85
## An overlapping patch sits this much deeper than the one it covers (D21).
const STEP_M := 0.012
const OVERLAP_SHARE := Vector2(0.1, 0.3)
## A patch stays this far (cm) off the rear window piece, and its face planes this far (m) off
## the front face of a piece they cross (1.2 cm less a hair: a rib lift sits exactly STEP_M off).
const WINDOW_CLEAR_CM := 17.0
const PLANE_CLEAR_M := 0.0119
## Deepest a wall patch stands: rib front 0.08 + STEP_M + the deepest source thickness 0.06, up.
const WALL_DEPTH_MAX := 0.16
## Highest a patch's top-most face stands off the liner (plan: patches 3..8 cm).
const TOP_MAX_M := 0.08
## Highest raised-plate level of a patch mesh.
const MAX_LEVEL := 3
const SURFACES: Array[StringName] = [VanKitSurface.LEFT_WALL, VanKitSurface.RIGHT_WALL,
	VanKitSurface.LEFT_LEAF, VanKitSurface.RIGHT_LEAF]

## `dropped patch <seed> <def>` lines of the last place(), for the rules check's info.
static var dropped: Array[String] = []
## Rear axle z of the last place(), for the rules check's zone test.
static var axles: Array[float] = []
## placed piece -> {res: VanKitPatchCut.Result, xf: Transform2D} for build().
static var _made := {}


## The build data of a placed patch (see _made); empty for any other piece.
static func made_of(p: VanKitPlaced) -> Dictionary:
	return _made.get(p, {})


static func place(ctx: VanKitBuilder.Ctx) -> Array[VanKitPlaced]:
	var out: Array[VanKitPlaced] = []
	dropped.clear()
	axles = []
	_made.clear()
	if ctx.keep_out == null or ctx.keep_out.walls == null:
		return out
	VanKitSurface.walls = ctx.keep_out.walls
	if ctx.look is VanLook:
		axles = VanWheels.rear_axles_for(ctx.look as VanLook)
	var defs: Array[VanPatchDef] = []
	for def in VanKitDefs.load_dir(DEFS_DIR):
		if def is VanPatchDef and def.since_gen <= VanKit.GEN:
			defs.append(def)
	var rng := ctx.rng(&"patches")
	var counts := {}
	var n := rng.randi_range(COUNT.x, COUNT.y)
	for i in n:
		var want_overlap := i > 0 and rng.randi_range(0, 2) == 0
		var def := _pick(defs, counts, rng, i == 0)
		var placed: VanKitPlaced = null
		var tried: VanPatchDef = def
		for attempt in TRIES:
			if i == 0 and attempt > 0:
				tried = _pick(defs, counts, rng, true)
			if tried == null:
				break
			var res := VanKitPatchCut.roll(tried, _rng(ctx, rng, tried), pow(SHRINK, floori(attempt / 3.0)))
			placed = _try(ctx, tried, res, rng, out, want_overlap, attempt < TRIES / 2.0)
			if placed != null:
				counts[tried.id] = counts.get(tried.id, 0) + 1
				out.append(placed)
				break
		if placed == null and tried != null:
			dropped.append("dropped patch %d %s" % [ctx.van_seed, tried.id])
	return out


## The cut stream of a def: the pass stream, or its own `since_gen` stream for a later def.
static func _rng(ctx: VanKitBuilder.Ctx, base: RandomNumberGenerator,
		def: VanPatchDef) -> RandomNumberGenerator:
	if def.since_gen <= 1:
		return base
	return VanLook.rng_for_seed(ctx.van_seed, VanKitDefs.stream_key(&"patches", def))


## A weighted def with fewer than MAX_PER_DEF placed; `telling` limits it to the telling sources.
static func _pick(defs: Array[VanPatchDef], counts: Dictionary, rng: RandomNumberGenerator,
		telling: bool) -> VanPatchDef:
	var pool: Array[VanPatchDef] = []
	var total := 0.0
	for def in defs:
		if counts.get(def.id, 0) < MAX_PER_DEF \
				and (not telling or VanKitPatchCut.TELLING.has(def.source)):
			pool.append(def)
			total += def.weight
	if pool.is_empty():
		return null
	var roll := rng.randf() * total
	for def in pool:
		roll -= def.weight
		if roll <= 0.0:
			return def
	return pool[pool.size() - 1]


## One placement try: a surface and centre, a turn, tilt and depth; null when anything fails.
static func _try(ctx: VanKitBuilder.Ctx, def: VanPatchDef, res: VanKitPatchCut.Result,
		rng: RandomNumberGenerator, earlier: Array[VanKitPlaced], want_overlap: bool,
		off_blue: bool) -> VanKitPlaced:
	var surface: StringName
	var target: Vector2
	var zone: StringName = &""
	var flat: Array[VanKitPlaced] = []
	for f in earlier:
		if f.origin_id == &"sheet_steel":
			flat.append(f)
	want_overlap = want_overlap and not flat.is_empty()
	if want_overlap:
		var e := flat[rng.randi_range(0, flat.size() - 1)]
		surface = e.surface
		var eb := VanKitSkin._bounds(e.outline)
		var reach := ((eb[1] - eb[0]) + res.size * 100.0) * 0.4
		target = (eb[0] + eb[1]) * 0.5 + Vector2(rng.randf_range(-1.0, 1.0) * reach.x,
				rng.randf_range(-1.0, 1.0) * reach.y)
	else:
		surface = SURFACES[rng.randi_range(0, SURFACES.size() - 1)]
		var zones := VanKitPatchZones.available(surface, axles)
		zone = zones[rng.randi_range(0, zones.size() - 1)]
		for _i in 8:
			target = VanKitPatchZones.sample(surface, zone, axles, rng)
			if VanKitPatchZones.in_zone(surface, target, zone, axles) \
					and not VanKitPatchZones.in_bay(surface, target):
				break
	target += Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
	var turn := rng.randi_range(0, 1)
	var tilt := _tilt_deg(res.longest, rng)
	# Never within 1.6 cm of a skin plate's face (D21): the odd plates stand 2.6 cm off the liner.
	var depth := rng.randf_range(def.depth_min, def.depth_max)
	if VanKitSurface.is_leaf(surface):
		depth = maxf(depth, 0.067)
	var rb := VanKitSkin._bounds(res.outline)
	var xf := Transform2D(turn * PI * 0.5 + deg_to_rad(tilt), target) \
			* Transform2D(0.0, -(rb[0] + rb[1]) * 0.5)
	var world: PackedVector2Array = xf * res.outline
	var wb := VanKitSkin._bounds(world)
	var shift := VanKitPatchZones.nudge(surface, wb[0], wb[1])
	if shift != Vector2.ZERO:
		xf = Transform2D(0.0, shift) * xf
		world = xf * res.outline
		wb = VanKitSkin._bounds(world)
	var centre := (wb[0] + wb[1]) * 0.5
	if not VanKitPatchZones.fits(surface, wb[0], wb[1]):
		return null
	# A sign's blue field vanishes on the faded-blue donor wall: it first looks for another wall.
	if off_blue and def.source == &"road_sign" and _blue_wall(ctx, surface, centre):
		return null
	var reason := zone
	if reason == &"" or not VanKitPatchZones.in_zone(surface, centre, reason, axles):
		reason = VanKitPatchZones.zone_of(surface, centre, axles)
	if reason == &"":
		return null
	var share := 0.0
	var area := absf(VanKitPatchCut._area(world))
	for e in earlier:
		if e.surface != surface:
			continue
		var hit := 0.0
		for part in Geometry2D.intersect_polygons(world, e.outline):
			hit += absf(VanKitPatchCut._area(part))
		if hit > 1.0:
			# Raised plates are 1.2 cm steps: only a plain sheet keeps every face 1 cm clear (audit).
			if e.origin_id != &"sheet_steel":
				return null
			share += hit / maxf(area, 1.0)
			depth = maxf(depth, e.size.y + STEP_M)
	var is_leaf := VanKitSurface.is_leaf(surface)
	# The top-most face (a sign's symbol, a car door's handle) stands within 8 cm of the liner
	# before any rib lift; a leaf's 6.7 cm floor leaves no room for raised plates.
	var top_level := 2 if def.source == &"road_sign" or def.source == &"car_door" else 1
	if not is_leaf and depth + top_level * VanKitPatchMesh.RAISE > TOP_MAX_M:
		return null
	if not is_leaf:
		var lift := _rib_lift(ctx, _piece(def, res, surface, world, centre, tilt, turn, depth,
				reason), centre, maxf(depth, VanKitPatchMesh.WALL_THICK))
		depth = maxf(depth, lift)
	if depth > (0.08 if is_leaf else WALL_DEPTH_MAX):
		return null
	if want_overlap:
		if share <OVERLAP_SHARE.x or share > OVERLAP_SHARE.y:
			return null
	elif share > 0.0:
		return null
	var p := _piece(def, res, surface, world, centre, tilt, turn, depth, reason)
	if not ctx.keep_out.allows(box_of(p), _kind(surface)):
		return null
	if _near_window(ctx, surface, world) or _plane_clash(ctx, p, centre, depth):
		return null
	_made[p] = {&"res": res, &"xf": xf}
	return p


## True when the donor whose region holds `at` (cm) is a blue paint (hue 190..250, S over 0.2).
static func _blue_wall(ctx: VanKitBuilder.Ctx, surface: StringName, at: Vector2) -> bool:
	var id := VanKitArch.donor_at(ctx, surface, at)
	for d in ctx.donors.donors:
		if d.id == id:
			var hue: float = d.paint.h * 360.0
			return hue >= 190.0 and hue <= 250.0 and d.paint.s > 0.2
	return false


## A car door's paint: a donor other than the one its wall region wears; a lightened wall paint
## when the van has only one donor.
static func _door_paint(ctx: VanKitBuilder.Ctx, p: VanKitPlaced, wall_paint: Color) -> Color:
	var b := VanKitSkin._bounds(p.outline)
	var here := VanKitArch.donor_at(ctx, p.surface, (b[0] + b[1]) * 0.5)
	var others: Array[VanDonor] = []
	for d in ctx.donors.donors:
		if d.id != here:
			others.append(d)
	if others.is_empty():
		return wall_paint.lightened(0.2)
	return others[int(absf(b[0].x + b[0].y)) % others.size()].paint


## True when the outline lies within 2 cm of the rear window piece on this leaf (its ring is
## at most 15 cm wide, cut in pass 9 after this pass, so it is not in `ctx.placed` yet).
static func _near_window(ctx: VanKitBuilder.Ctx, surface: StringName,
		world: PackedVector2Array) -> bool:
	if not VanKitSurface.is_leaf(surface):
		return false
	for entry: Dictionary in ctx.donors.windows:
		if entry[&"surface"] != &"rear" or VanKitWindowsRear.leaf_of(entry) != surface:
			continue
		var inner := VanKitWindowsRear.frame_cm(entry, RearWindowFit.OUTER_TODAY)
		var ring := Geometry2D.offset_polygon(inner, WINDOW_CLEAR_CM, Geometry2D.JOIN_ROUND)
		if not ring.is_empty() and not Geometry2D.intersect_polygons(world, ring[0]).is_empty():
			return true
	return false


## True when a patch face plane lies within PLANE_CLEAR_M of the front face of an earlier piece
## the patch crosses (a rib or pillar): the audit flickers there.
static func _plane_clash(ctx: VanKitBuilder.Ctx, p: VanKitPlaced, centre: Vector2,
		depth: float) -> bool:
	var normal := VanKitSurface.normal(p.surface, centre.x, centre.y)
	var base := VanKitSurface.point(p.surface, centre.x, centre.y, 0.0)
	var box := box_of(p).grow(0.002)
	var thick := VanKitPatchMesh.LEAF_THICK if VanKitSurface.is_leaf(p.surface) \
			else VanKitPatchMesh.WALL_THICK
	var planes: Array[float] = [depth, depth - thick]
	for level in range(1, MAX_LEVEL + 1):
		planes.append(depth + level * VanKitPatchMesh.RAISE)
		planes.append(depth - level * VanKitPatchMesh.SPACE)
	for e in ctx.placed:
		if e.surface != p.surface or String(e.def_id).begins_with("patch/"):
			continue
		if not e.outline.is_empty():
			# Skin plates and laps: faces at their depth and depth + THICK where outlines overlap.
			if e.origin_id == &"sheet_steel" or Geometry2D.intersect_polygons(
					p.outline, e.outline).is_empty():
				continue
			for plane in planes:
				if absf(plane - e.size.y) < PLANE_CLEAR_M \
						or absf(plane - e.size.y - VanKitSkin.THICK) < PLANE_CLEAR_M:
					return true
			continue
		if not box.intersects(e.transform * AABB(-e.size * 0.5, e.size)):
			continue
		var front := (e.transform.origin - base).dot(normal) + e.size.y * 0.5
		for plane in planes:
			if absf(plane - front) < PLANE_CLEAR_M:
				return true
	return false


## The depth that puts a wall patch's back face STEP_M in front of the highest rib or pillar
## front it crosses (so it crosses the rib); 0 when it crosses none.
static func _rib_lift(ctx: VanKitBuilder.Ctx, p: VanKitPlaced, centre: Vector2,
		thick: float) -> float:
	var normal := VanKitSurface.normal(p.surface, centre.x, centre.y)
	var base := VanKitSurface.point(p.surface, centre.x, centre.y, 0.0)
	var box := box_of(p).grow(0.002)
	var top := -1.0
	for e in ctx.placed:
		if e.surface != p.surface or String(e.def_id).begins_with("patch/") \
				or not e.outline.is_empty():
			continue
		if box.intersects(e.transform * AABB(-e.size * 0.5, e.size)):
			top = maxf(top, (e.transform.origin - base).dot(normal) + e.size.y * 0.5)
	return 0.0 if top < 0.0 else top + STEP_M + thick


## D13: the larger the patch, the straighter; a random sign.
static func _tilt_deg(longest: float, rng: RandomNumberGenerator) -> float:
	var lo := 2.0
	var hi := 6.0
	if longest >= 0.75:
		lo = 0.0
		hi = 2.0
	elif longest > 0.4:
		hi = 6.0 - 4.0 * (longest - 0.4) / 0.35
		lo = hi / 3.0
	var deg := rng.randf_range(lo, hi)
	return deg if rng.randi_range(0, 1) == 0 else -deg


static func _kind(surface: StringName) -> StringName:
	return StringName(VanKitClip.LEAF_PREFIX + "patch") if VanKitSurface.is_leaf(surface) \
			else &"patch"


## The keep-out box of a placed patch, the one the rules check tests.
static func box_of(p: VanKitPlaced) -> AABB:
	if VanKitSurface.is_leaf(p.surface):
		return VanKitClip._box(p.surface, p.outline, p.size.y)
	return p.transform * AABB(-p.size * 0.5, p.size)


static func _piece(def: VanPatchDef, res: VanKitPatchCut.Result, surface: StringName,
		world: PackedVector2Array, centre: Vector2, tilt: float, turn: int, depth: float,
		reason: StringName) -> VanKitPlaced:
	var normal := VanKitSurface.normal(surface, centre.x, centre.y)
	var basis := Basis(Vector3.DOWN, normal, Vector3.RIGHT)
	if not VanKitSurface.is_leaf(surface):
		basis = Basis(normal.cross(Vector3.BACK), normal, Vector3.BACK)
	var p := VanKitPlaced.new()
	p.def_id = StringName("patch/" + String(def.id))
	p.surface = surface
	p.attach = surface if VanKitSurface.is_leaf(surface) else &""
	p.origin_kind = &"SCRAP"
	p.origin_id = def.source
	p.reason = reason
	p.transform = Transform3D(Basis(normal, deg_to_rad(tilt)) * basis,
			VanKitSurface.point(surface, centre.x, centre.y, 0.0) + normal * (depth * 0.5))
	var along := res.size.x if turn == 0 else res.size.y
	var across := res.size.y if turn == 0 else res.size.x
	p.size = Vector3(across, depth, along)
	p.outline = world
	p.gen = VanKit.GEN
	return p


## Adds each patch's meshes under `parent` (the root, or the leaf's hinge).
static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced], parent: Node3D) -> void:
	if ctx.keep_out != null:
		VanKitSurface.walls = ctx.keep_out.walls
	var paint := Color(0.3, 0.3, 0.3)
	var rust := 0.3
	if not ctx.donors.donors.is_empty():
		paint = ctx.donors.donors[0].paint
		rust = clampf(ctx.donors.donors[0].fade, 0.0, 1.0)
	for p in placed:
		if not _made.has(p):
			continue
		var made: Dictionary = _made[p]
		var def := load("%s/%s.tres" % [DEFS_DIR, String(p.def_id).trim_prefix("patch/")]) \
				as VanPatchDef
		var door := _door_paint(ctx, p, paint) if def.source == &"car_door" else paint
		var nodes := VanKitPatchMesh.build(parent, p.surface, def,
				made[&"res"] as VanKitPatchCut.Result, made[&"xf"] as Transform2D, p.size.y,
				door, rust, ctx.van_seed)
		for mi in nodes:
			mi.set_meta(&"kit_origin", {&"kind": p.origin_kind, &"id": p.origin_id,
				&"reason": p.reason})
