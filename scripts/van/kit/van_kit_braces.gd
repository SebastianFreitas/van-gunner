class_name VanKitBraces
extends RefCounted
## Pass 5: welded scrap braces (angle iron, scaffold pipe, rebar) across strap-less seams and
## beside stripped gaps on the side walls, each fixed at two points and given a box collider (D7).

const DEFS_DIR := "res://resources/van_kit/braces"
const LENGTH_M := Vector2(0.6, 1.4)
const ANGLE_DEG := Vector2(5.0, 20.0)
const CUT_DEG := 15.0
const TRIES := 8
const SHRINK := 0.85
## Back face off the liner, clear of the ribs' 7 cm front and the patches' fronts.
const BACK_M := Vector2(0.10, 0.14)
## Fastener heads stand this far proud of the brace's front face.
const HEAD_M := 0.012
const PLANE_CLEAR_M := 0.012
const REACH_MAX := 0.235
const PARALLEL_DEG := 5.0
## Floor top is y 0; a brace (collider box included) stays this far above it.
const FLOOR_TOP_M := 0.0
const FLOOR_CLEAR_M := 0.02
const SURFACES: Array[StringName] = [VanKitSurface.LEFT_WALL, VanKitSurface.RIGHT_WALL]
const _COLLIDER_LAYER := 1

## `dropped brace <seed> <def>` lines of the last place(), for the rules check's info.
static var dropped: Array[String] = []
## placed piece -> {cut_a, cut_b, fixes: Array of {s: float, kind: int}, section: StringName}.
static var _made := {}


## The build data of a placed brace (see _made); empty for any other piece.
static func made_of(p: VanKitPlaced) -> Dictionary:
	return _made.get(p, {})


static func place(ctx: VanKitBuilder.Ctx) -> Array[VanKitPlaced]:
	var out: Array[VanKitPlaced] = []
	dropped.clear()
	_made.clear()
	if ctx.keep_out == null or ctx.keep_out.walls == null:
		return out
	VanKitSurface.walls = ctx.keep_out.walls
	var defs: Array[VanBraceDef] = []
	for def in VanKitDefs.load_dir(DEFS_DIR):
		if def is VanBraceDef and def.since_gen <= VanKit.GEN:
			defs.append(def)
	if defs.is_empty():
		return out
	var rng := ctx.rng(&"braces")
	for target: Dictionary in _targets(ctx, rng):
		var def := _pick(defs, rng)
		var placed: VanKitPlaced = null
		var pairs := _rib_pairs(ctx, target)
		for attempt in TRIES:
			if (attempt >> 1) >= pairs.size():
				break
			placed = _try(ctx, def, target, rng, attempt, out,
					_span(ctx, pairs[(attempt >> 1)], rng))
			if placed != null:
				break
		if placed == null:
			for attempt in TRIES:
				placed = _try(ctx, def, target, rng, attempt, out)
				if placed != null:
					break
		if placed != null:
			out.append(placed)
		if placed == null:
			dropped.append("dropped brace %d %s" % [ctx.van_seed, def.id])
	return out


static func _pick(defs: Array[VanBraceDef], rng: RandomNumberGenerator) -> VanBraceDef:
	var total := 0.0
	for def in defs:
		total += def.weight
	var roll := rng.randf() * total
	for def in defs:
		roll -= def.weight
		if roll <= 0.0:
			return def
	return defs[defs.size() - 1]


## Where braces go: {surface, at (cm), reason}; one per strap-less seam part, one per gap.
static func _targets(ctx: VanKitBuilder.Ctx, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for surface in SURFACES:
		var laps: Array[Rect2] = []
		var straps: Array[Rect2] = []
		for e in ctx.placed:
			if e.surface != surface or e.def_id != VanKitSeams.LAP or e.outline.is_empty():
				continue
			var b := VanKitSkin._bounds(e.outline)
			var rect := Rect2(b[0], b[1] - b[0])
			if e.origin_id == &"strap" or e.origin_id == &"channel":
				straps.append(rect)
			elif e.origin_kind == &"DONOR":
				laps.append(rect.grow(2.0))
		var merged: Array[Rect2] = []
		for rect in laps:
			var hit := true
			while hit:
				hit = false
				for i in range(merged.size() - 1, -1, -1):
					if merged[i].intersects(rect):
						rect = rect.merge(merged[i])
						merged.remove_at(i)
						hit = true
			merged.append(rect)
		for part in merged:
			var bare := true
			for s in straps:
				bare = bare and not part.grow(12.0).intersects(s)
			if bare:
				out.append({&"surface": surface, &"at": part.get_center(),
					&"reason": &"seam_brace"})
		for gap in VanKitGaps.of(surface):
			var z: Vector2 = gap[&"z"]
			var y: Vector2 = gap[&"y"]
			var above := rng.randi_range(0, 1) == 0
			out.append({&"surface": surface, &"reason": &"gap_brace",
				&"at": Vector2((z.x + z.y) * 0.5, y.y + 14.0 if above else y.x - 14.0)})
	return out


## Rib pairs on the target's surface, adjacent by z, nearest the site first; pairs too far apart
## for LENGTH_M.y are skipped. Each is {z0, z1} in metres.
static func _rib_pairs(ctx: VanKitBuilder.Ctx, target: Dictionary) -> Array[Vector2]:
	var zs: Array[float] = []
	for e in ctx.placed:
		if e.def_id == VanKitStructure.RIB and e.surface == target[&"surface"]:
			zs.append(e.transform.origin.z)
	zs.sort()
	var site_z: float = (target[&"at"] as Vector2).x * 0.01
	var pairs: Array[Vector2] = []
	for i in zs.size() - 1:
		if zs[i + 1] - zs[i] >= 0.1 and zs[i + 1] - zs[i] <= LENGTH_M.y - 0.08:
			pairs.append(Vector2(zs[i], zs[i + 1]))
	pairs.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return absf((a.x + a.y) * 0.5 - site_z) < absf((b.x + b.y) * 0.5 - site_z))
	return pairs


## A z-long brace over a rib pair: {at (cm), length, deg}; y is rolled inside the wall's free
## bands (outside the window pieces' y range where the span meets their zones).
static func _span(ctx: VanKitBuilder.Ctx, pair: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var over := rng.randf_range(0.08, 0.25)
	var before := over * rng.randf_range(0.2, 0.8)
	var length := clampf(pair.y - pair.x + over, LENGTH_M.x, LENGTH_M.y)
	var z := (pair.x + pair.y) * 0.5 + (over - before - before) * 0.5
	var lo := FLOOR_TOP_M + FLOOR_CLEAR_M + 0.2
	var hi := ctx.keep_out.walls.wall_height - 0.2
	var bands: Array[Vector2] = [Vector2(lo, hi)]
	for zone in VanKitFootprint.PIECE_ZONES:
		if pair.x - 0.1 < zone.y and pair.y + 0.1 > zone.x:
			bands = [Vector2(lo, VanKitFootprint.PIECE_Y.x - 0.15),
				Vector2(VanKitFootprint.PIECE_Y.y + 0.15, hi)]
	var total := 0.0
	for band in bands:
		total += maxf(band.y - band.x, 0.0)
	var roll := rng.randf() * total
	var y := bands[0].x
	for band in bands:
		var w := maxf(band.y - band.x, 0.0)
		y = band.x + minf(roll, w)
		if roll <= w:
			break
		roll -= w
	var deg := rng.randf_range(ANGLE_DEG.x, ANGLE_DEG.y) * (1.0 if rng.randi_range(0, 1) == 0 else -1.0)
	return {&"at": Vector2(z * 100.0, y * 100.0), &"length": length, &"deg": deg}


static func _try(ctx: VanKitBuilder.Ctx, def: VanBraceDef, target: Dictionary,
		rng: RandomNumberGenerator, attempt: int, earlier: Array[VanKitPlaced],
		span: Dictionary = {}) -> VanKitPlaced:
	var surface: StringName = target[&"surface"]
	var at: Vector2 = target[&"at"] + Vector2(rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)) * (4.0 + 4.0 * attempt)
	var length := maxf(LENGTH_M.x, rng.randf_range(LENGTH_M.x, LENGTH_M.y) * pow(SHRINK, attempt))
	var turn := span.is_empty()
	var deg := rng.randf_range(ANGLE_DEG.x, ANGLE_DEG.y) * (1.0 if rng.randi_range(0, 1) == 0 else -1.0)
	if not span.is_empty():
		at = span[&"at"]
		length = span[&"length"]
		deg = span[&"deg"]
	var sec := def.section_m
	var depth := rng.randf_range(BACK_M.x, BACK_M.y) + sec
	var normal := VanKitSurface.normal(surface, at.x, at.y)
	var basis := Basis(normal, deg_to_rad(deg) + (PI * 0.5 if turn else 0.0)) \
			* Basis(normal.cross(Vector3.BACK), normal, Vector3.BACK)
	var base := VanKitSurface.point(surface, at.x, at.y, 0.0)
	var p := VanKitPlaced.new()
	p.def_id = StringName("brace/" + String(def.id))
	p.surface = surface
	p.origin_kind = &"SCRAP"
	p.origin_id = def.section
	p.reason = target[&"reason"]
	p.transform = Transform3D(basis, base + normal * (depth * 0.5))
	p.size = Vector3(sec, depth, length)
	p.gen = VanKit.GEN
	var fixes := _fixes(ctx, p, rng)
	if fixes.is_empty():
		return null
	var box := p.transform * AABB(-p.size * 0.5, p.size)
	var reach := ctx.keep_out.walls.wall_x_at(box.get_center().y) \
			- minf(absf(box.position.x), absf(box.end.x))
	if box.position.y < FLOOR_TOP_M + FLOOR_CLEAR_M or box.end.y > ctx.keep_out.walls.wall_height:
		return null
	if reach > REACH_MAX or not ctx.keep_out.allows(box, &"brace"):
		return null
	var dir := VanKitRules.tilt_deg(p)
	for e in earlier:
		if e.surface == surface and absf(wrapf(dir - VanKitRules.tilt_deg(e), -90.0, 90.0)) \
				< PARALLEL_DEG:
			return null
	if _plane_clash(ctx, p, base, normal, box, depth):
		return null
	var cut := func() -> float:
		return deg_to_rad(rng.randf_range(0.0, CUT_DEG) * (1.0 if rng.randi_range(0, 1) == 0 else -1.0))
	_made[p] = {&"cut_a": cut.call(), &"cut_b": cut.call(), &"section": def.section,
		&"fixes": fixes}
	return p


## A brace face plane within PLANE_CLEAR_M of an earlier piece's front face it overlaps flickers.
static func _plane_clash(ctx: VanKitBuilder.Ctx, p: VanKitPlaced, base: Vector3, normal: Vector3,
		box: AABB, depth: float) -> bool:
	var planes: Array[float] = [depth - p.size.x, depth, depth + HEAD_M]
	var grown := box.grow(0.002)
	for e in ctx.placed:
		if e.surface != p.surface or not grown.intersects(e.transform * AABB(-e.size * 0.5, e.size)):
			continue
		var front := (e.transform.origin - base).dot(normal) + e.size.y * 0.5
		# A patch's raised plates stand RAISE steps above its front, up to MAX_LEVEL of them.
		var levels := VanKitPatches.MAX_LEVEL if String(e.def_id).begins_with("patch/") else 0
		for plane in planes:
			for level in range(0, levels + 1):
				if absf(plane - front - level * VanKitPatchMesh.RAISE) < PLANE_CLEAR_M:
					return true
	return false


## Two fixing points along the brace (metres from its centre) at the two structure pieces nearest
## its centre that its line crosses; the brace grows to reach them (up to LENGTH_M.y). Empty when
## it crosses fewer than two apart (the try rerolls).
static func _fixes(ctx: VanKitBuilder.Ctx, p: VanKitPlaced, rng: RandomNumberGenerator) -> Array:
	var half := LENGTH_M.y * 0.5 - 0.07
	var o := Vector2(p.transform.origin.y, p.transform.origin.z)
	var d := Vector2(p.transform.basis.z.y, p.transform.basis.z.z)
	var at: Array[float] = []
	for e in ctx.placed:
		if not String(e.def_id).begins_with("structure/") or e.surface != p.surface:
			continue
		var box := e.transform * AABB(-e.size * 0.5, e.size)
		var lo := -half
		var hi := half
		for k in 2:
			var bmin := box.position.y if k == 0 else box.position.z
			var bmax := box.end.y if k == 0 else box.end.z
			if absf(d[k]) < 0.0001:
				if o[k] < bmin or o[k] > bmax:
					hi = lo - 1.0
				continue
			var t0 := (bmin - o[k]) / d[k]
			var t1 := (bmax - o[k]) / d[k]
			lo = maxf(lo, minf(t0, t1))
			hi = minf(hi, maxf(t0, t1))
		if lo <= hi:
			at.append((lo + hi) * 0.5)
	at.sort_custom(func(a: float, b: float) -> bool: return absf(a) < absf(b))
	var out: Array = []
	if at.size() < 2 or absf(at[0] - at[1]) < 0.1:
		return out
	p.size.z = maxf(p.size.z, (maxf(absf(at[0]), absf(at[1])) + 0.07) * 2.0)
	for s in [at[0], at[1]]:
		out.append({&"s": s, &"kind": rng.randi_range(0, 2)})
	return out


## Adds each brace's mesh and its box collider under `parent`.
static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced], parent: Node3D) -> void:
	var paint := Color(0.3, 0.29, 0.28)
	var rust := 0.4
	if not ctx.donors.donors.is_empty():
		rust = clampf(ctx.donors.donors[0].fade, 0.0, 1.0)
	for p in placed:
		if not _made.has(p):
			continue
		var made: Dictionary = _made[p]
		var tint := paint.lightened(float(hash(p.def_id) % 5) * 0.03)
		var mi := VanKitBracesMesh.build(parent, p, made, tint, rust, ctx.van_seed)
		mi.set_meta(&"kit_origin", {&"kind": p.origin_kind, &"id": p.origin_id,
			&"reason": p.reason})
		var body := StaticBody3D.new()
		body.name = "BraceBody"
		body.collision_layer = _COLLIDER_LAYER
		body.collision_mask = 0
		body.transform = p.transform
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = p.size
		shape.shape = box
		body.add_child(shape)
		parent.add_child(body)
