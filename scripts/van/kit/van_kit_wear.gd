class_name VanKitWear
extends RefCounted
## Pass 8: fastener wear on pieces the earlier passes placed: weld beads along each patch's rough
## outline, bolt rows on the arch boxes' flanges and tie-wire lacing on round braces. One merged
## grime-shader mesh per surface; no colliders.

const SURFACES: Array[StringName] = [VanKitSurface.LEFT_WALL, VanKitSurface.RIGHT_WALL,
	VanKitSurface.LEFT_LEAF, VanKitSurface.RIGHT_LEAF]
const STEP_CM := 2.0
const BEAD_BASE_M := 0.012
const BEAD_CREST_M := Vector2(0.008, 0.012)
const STITCH_RUN_CM := Vector2(6.0, 15.0)
const STITCH_GAP_CM := Vector2(2.0, 5.0)
const WOBBLE_HAND_CM := 0.4
const WOBBLE_FACTORY_CM := 0.15
const BOLT_PITCH_M := Vector2(0.20, 0.30)
const BOLT_ACROSS_M := 0.03
const BOLT_PROUD_M := Vector2(0.012, 0.018)
const WIRE_R_M := 0.0017
const WIRE_TURNS := Vector2i(3, 5)
const WIRE_BAND_M := 0.04
const WIRE_TAIL_M := Vector2(0.02, 0.04)
## A fastening stays within its host's box grown by this much.
const CLIP_M := 0.03

## placed piece -> {kind: &"bead"/&"bolts"/&"lace", ...the geometry, in the host's space}.
static var _made := {}


static func place(ctx: VanKitBuilder.Ctx) -> Array[VanKitPlaced]:
	var out: Array[VanKitPlaced] = []
	_made.clear()
	if ctx.keep_out == null or ctx.keep_out.walls == null:
		return out
	VanKitSurface.walls = ctx.keep_out.walls
	for surface in SURFACES:
		var rng := ctx.rng(&"wear", surface)
		for host in ctx.placed:
			if host.surface != surface:
				continue
			var p: VanKitPlaced = null
			if not VanKitPatches.made_of(host).is_empty():
				p = _beads(ctx, host, rng)
			elif not VanKitArch.made_of(host).is_empty():
				p = _bolts(ctx, host, rng)
			elif not VanKitBraces.made_of(host).is_empty():
				p = _laces(ctx, host, rng)
			if p != null:
				out.append(p)
	return out


static func _beads(ctx: VanKitBuilder.Ctx, host: VanKitPlaced, rng: RandomNumberGenerator
		) -> VanKitPlaced:
	var centre := Vector2.ZERO
	for pt in host.outline:
		centre += pt / host.outline.size()
	var donor := VanKitStructure._donor(ctx.donors, VanKitArch.donor_at(ctx, host.surface, centre))
	var hand := donor != null and donor.fastener_era == VanDonor.FastenerEra.HAND
	var wobble := WOBBLE_HAND_CM if hand else WOBBLE_FACTORY_CM
	var samples := _walk(host.outline, wobble, rng)
	var crest := rng.randf_range(BEAD_CREST_M.x, BEAD_CREST_M.y)
	var pos := rng.randf_range(0.0, STITCH_RUN_CM.x)
	var total: float = samples[0][samples[0].size() - 1]
	var runs: Array = []
	if hand:
		while pos < total:
			var run := rng.randf_range(STITCH_RUN_CM.x, STITCH_RUN_CM.y)
			runs.append(Vector2(pos, minf(pos + run, total)))
			pos += run + rng.randf_range(STITCH_GAP_CM.x, STITCH_GAP_CM.y)
	else:
		runs.append(Vector2(0.0, total))
	var host_box := VanKitPatches.box_of(host).grow(CLIP_M)
	var kind := _kind(host.surface)
	var segs: Array = []
	var pts: Array[Vector3] = []
	var dists: Array = samples[0]
	var cm: Array = samples[1]
	for run: Vector2 in runs:
		for i in dists.size() - 1:
			if dists[i] < run.x - 0.001 or dists[i + 1] > run.y + 0.001:
				continue
			var a := VanKitSurface.point(host.surface, cm[i].x, cm[i].y, host.size.y)
			var b := VanKitSurface.point(host.surface, cm[i + 1].x, cm[i + 1].y, host.size.y)
			var box := AABB(a, Vector3.ZERO).expand(b).grow(BEAD_BASE_M)
			if not host_box.encloses(box) or ctx.keep_out.why(box, kind) != "":
				continue
			segs.append([a, b, VanKitSurface.normal(host.surface, cm[i].x, cm[i].y)])
			pts.append(a)
			pts.append(b)
	if segs.is_empty():
		return null
	var p := _piece(ctx, host, &"wear/bead", pts, BEAD_BASE_M)
	if p != null:
		_made[p] = {&"kind": &"bead", &"segs": segs, &"crest": crest}
	return p


## The outline walked in STEP_CM steps with its wobble: [distances, points (cm)], closed.
static func _walk(outline: PackedVector2Array, wobble: float, rng: RandomNumberGenerator
		) -> Array:
	var dists: Array[float] = []
	var pts: Array[Vector2] = []
	var run := 0.0
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var dir := (b - a).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var n := maxi(1, ceili(a.distance_to(b) / STEP_CM))
		for k in n:
			dists.append(run + a.distance_to(b) * k / n)
			pts.append(a.lerp(b, float(k) / n) + perp * rng.randf_range(-wobble, wobble))
		run += a.distance_to(b)
	dists.append(run)
	pts.append(pts[0])
	return [dists, pts]


static func _bolts(ctx: VanKitBuilder.Ctx, host: VanKitPlaced, rng: RandomNumberGenerator
		) -> VanKitPlaced:
	var geo := VanKitArch.made_of(host)
	var s: float = geo[&"xs"]
	var h: float = geo[&"y1"]
	var z0: float = geo[&"z0"]
	var z1: float = geo[&"z1"]
	var fb: float = geo[&"fb"]
	var ft: float = geo[&"ft"]
	var walls := ctx.keep_out.walls
	var heads: Array = []
	var rows := 0
	# Top row along the liner edge, then an end row up each end face.
	var top_x := maxf(ft + 0.02, walls.wall_x_at(h) - 0.045)
	for row in 3:
		var pitch := rng.randf_range(BOLT_PITCH_M.x, BOLT_PITCH_M.y)
		var sides := 4 if rng.randi_range(0, 1) == 0 else 6
		var proud := rng.randf_range(BOLT_PROUD_M.x, BOLT_PROUD_M.y)
		var along := z0 + 0.1 if row == 0 else 0.1
		var limit := z1 - 0.1 if row == 0 else h - 0.08
		var before := heads.size()
		while along <= limit:
			var at := Vector3.ZERO
			var n := Vector3.UP
			var t := Vector3.BACK
			if row == 0:
				at = Vector3(s * top_x, h, along)
			else:
				var x: float = walls.wall_x_at(along) - 0.05
				if x - 0.02 < lerpf(fb, ft, along / h) + 0.025:
					along += pitch
					continue
				n = Vector3(0.0, 0.0, -1.0 if row == 1 else 1.0)
				t = Vector3.UP
				at = Vector3(s * x, along, z0 if row == 1 else z1)
			heads.append({&"at": at, &"n": n, &"t": t, &"sides": sides, &"proud": proud})
			along += pitch
		if heads.size() > before:
			rows += 1
	var host_box := (geo[&"box"] as AABB).grow(CLIP_M)
	var kept: Array = []
	for hd: Dictionary in heads:
		var box := AABB(hd[&"at"], Vector3.ZERO).grow(0.02)
		if host_box.encloses(box) and ctx.keep_out.why(head_box(hd), _kind(host.surface)) == "":
			kept.append(hd)
	if kept.is_empty():
		return null
	var pts: Array[Vector3] = []
	for hd: Dictionary in kept:
		pts.append(hd[&"at"] + hd[&"n"] * hd[&"proud"])
		pts.append(hd[&"at"] - hd[&"n"] * 0.003)
	var p := _piece(ctx, host, &"wear/bolts", pts, BOLT_ACROSS_M * 0.5, false)
	if p != null:
		_made[p] = {&"kind": &"bolts", &"heads": kept, &"rows": rows}
	return p


## What a wear piece was built from (empty for a piece this pass did not make); the rules test
## each bolt head's `head_box` from here.
static func made_of(p: VanKitPlaced) -> Dictionary:
	return _made.get(p, {})


## One bolt head's full box: 3 mm sunk to proud, plus the head's half-width.
static func head_box(hd: Dictionary) -> AABB:
	return AABB(hd[&"at"] + hd[&"n"] * hd[&"proud"], Vector3.ZERO).expand(
			hd[&"at"] - hd[&"n"] * 0.003).grow(BOLT_ACROSS_M * 0.5)


static func _laces(ctx: VanKitBuilder.Ctx, host: VanKitPlaced, rng: RandomNumberGenerator
		) -> VanKitPlaced:
	var made := VanKitBraces.made_of(host)
	if not [&"rebar", &"scaffold_pipe"].has(StringName(made[&"section"])):
		return null
	var radius := host.size.x * 0.5
	var mid := host.size.y * 0.5 - radius
	var host_box := (host.transform * AABB(-host.size * 0.5, host.size)).grow(CLIP_M)
	var tubes: Array = []
	var pts: Array[Vector3] = []
	for fix: Dictionary in made[&"fixes"]:
		var turns := rng.randi_range(WIRE_TURNS.x, WIRE_TURNS.y)
		var sides := rng.randi_range(4, 6)
		var slope := WIRE_BAND_M / (TAU * turns)
		var line: Array[Vector3] = []
		var steps := turns * 10
		for k in steps + 1:
			var ang := TAU * turns * k / steps
			line.append(host.transform * Vector3(radius * cos(ang), mid + radius * sin(ang),
					float(fix[&"s"]) - WIRE_BAND_M * 0.5 + slope * ang))
		# Tails leave along the wire's tangent, halved until they sit inside the host's box.
		var head_dir: Vector3 = (line[0] - line[1]).normalized()
		var tail_dir: Vector3 = (line[steps] - line[steps - 1]).normalized()
		var tube: Array[Vector3] = line
		for dir: Vector3 in [tail_dir, head_dir]:
			var length := rng.randf_range(WIRE_TAIL_M.x, WIRE_TAIL_M.y)
			var from := tube[tube.size() - 1] if dir == tail_dir else tube[0]
			for tries in 3:
				if host_box.has_point(from + dir * length):
					if dir == tail_dir:
						tube.append(from + dir * length)
					else:
						tube.insert(0, from + dir * length)
					break
				length *= 0.5
		var box := AABB(tube[0], Vector3.ZERO)
		for pt in tube:
			box = box.expand(pt)
		if ctx.keep_out.why(box.grow(WIRE_R_M), _kind(host.surface)) != "":
			continue
		tubes.append({&"pts": tube, &"sides": sides})
		pts.append_array(tube)
	if tubes.is_empty():
		return null
	var p := _piece(ctx, host, &"wear/lace", pts, WIRE_R_M)
	if p != null:
		_made[p] = {&"kind": &"lace", &"tubes": tubes}
	return p


## A wear piece in the host's frame, sized to the bounds of `pts` plus `grow`; null when the whole
## box is still refused by the keep-out (`whole` false skips that: bolt heads are tested one by one,
## and the rules re-test each head, since their union box spans the gaps between the heads).
static func _piece(ctx: VanKitBuilder.Ctx, host: VanKitPlaced, def_id: StringName,
		pts: Array[Vector3], grow: float, whole := true) -> VanKitPlaced:
	var inv := host.transform.affine_inverse()
	var local := AABB(inv * pts[0], Vector3.ZERO)
	for pt in pts:
		local = local.expand(inv * pt)
	local = local.grow(grow)
	var p := VanKitPlaced.new()
	p.def_id = def_id
	p.surface = host.surface
	p.attach = host.attach
	p.origin_kind = &"SCRAP"
	p.origin_id = &"fastener"
	p.reason = StringName("wear:" + String(host.def_id))
	p.transform = host.transform * Transform3D(Basis.IDENTITY, local.get_center())
	p.size = local.size
	p.gen = VanKit.GEN
	if whole and not ctx.keep_out.allows(p.transform * AABB(-p.size * 0.5, p.size),
			_kind(host.surface)):
		return null
	return p


static func _kind(surface: StringName) -> StringName:
	return StringName(VanKitClip.LEAF_PREFIX + "wear") if VanKitSurface.is_leaf(surface) \
			else &"wear"


## Adds one merged mesh per surface under `parent`.
static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced], parent: Node3D) -> void:
	var paint := Color(0.3, 0.29, 0.28)
	if not ctx.donors.donors.is_empty():
		paint = ctx.donors.donors[0].paint
	var tone := paint.darkened(0.55).lerp(Color(0.3, 0.16, 0.09), 0.4)
	var tools := {}
	for p in placed:
		if not _made.has(p):
			continue
		if not tools.has(p.surface):
			var fresh := SurfaceTool.new()
			fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[p.surface] = fresh
		var st: SurfaceTool = tools[p.surface]
		var made: Dictionary = _made[p]
		match made[&"kind"]:
			&"bead":
				for seg: Array in made[&"segs"]:
					VanKitWearMesh.bead(st, seg[0], seg[1], seg[2], BEAD_BASE_M, made[&"crest"])
			&"bolts":
				for hd: Dictionary in made[&"heads"]:
					VanKitWearMesh.head(st, hd[&"at"], hd[&"n"], hd[&"t"], hd[&"sides"],
							BOLT_ACROSS_M, hd[&"proud"])
			&"lace":
				for tube: Dictionary in made[&"tubes"]:
					VanKitWearMesh.tube(st, tube[&"pts"], WIRE_R_M, tube[&"sides"])
	for surface: StringName in tools:
		var st: SurfaceTool = tools[surface]
		st.generate_normals()
		var mi := VanKitWindowsMesh.node(parent, "Wear_" + String(surface), st.commit())
		VanKitWindowsMesh.style(mi, tone, tone.darkened(0.3), 0.8, int(VanDonor.WallStyle.FLAT),
				1.0, ctx.van_seed, &"wear")
		mi.set_meta(&"kit_origin", {&"kind": &"SCRAP", &"id": &"fastener", &"reason": &"wear"})
