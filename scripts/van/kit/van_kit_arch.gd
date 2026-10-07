class_name VanKitArch
extends RefCounted
## Pass 6: a welded wheel-tub box on each side wall over the rear axles, painted with the wall
## region's donor paint and given a box collider (D7).

const DEFS_DIR := "res://resources/van_kit/arches"
## Half the z span an axle covers (2R of 1.6 m plus the clearing the plan asks for).
const HALF_SPAN_M := 0.95
const Z_END_M := 4.55
const HEIGHT_M := 0.85
const DEPTH_M := 0.25
const LEAN_DEG := Vector2(1.0, 3.0)
const MIN_SPAN_M := 1.6
const BLOCK_CLEAR_M := 0.02
const KEEP_OUT_GROW_M := 0.02
const TRIES := 8
## Spacing of the liner samples the end and top faces follow.
const WALL_STEP_M := 0.1
## Where on the wall the paint is read, in cm (wall surface, 40 cm up).
const PAINT_Y_CM := 40.0
const SURFACES: Array[StringName] = [VanKitSurface.LEFT_WALL, VanKitSurface.RIGHT_WALL]
const _COLLIDER_LAYER := 1

## `arch box skipped <seed> <left|right> <why>` lines of the last place(), for the rules check's info.
static var dropped: Array[String] = []
## placed piece -> the mesh's geometry dictionary (see VanKitArchMesh.build).
static var _made := {}
## The keep-out reason of the last blocked try in _fit.
static var _why := ""


## The mesh geometry of a placed arch box (see _made); empty for any other piece.
static func made_of(p: VanKitPlaced) -> Dictionary:
	return _made.get(p, {})


static func place(ctx: VanKitBuilder.Ctx) -> Array[VanKitPlaced]:
	var out: Array[VanKitPlaced] = []
	dropped.clear()
	_made.clear()
	var look := ctx.look as VanLook
	if ctx.keep_out == null or ctx.keep_out.walls == null or look == null:
		return out
	var def: VanArchBoxDef = null
	for d in VanKitDefs.load_dir(DEFS_DIR):
		if d is VanArchBoxDef and d.since_gen <= VanKit.GEN:
			def = d
			break
	if def == null:
		return out
	var axles := VanWheels.rear_axles_for(look)
	var lo: float = float(axles.min()) - HALF_SPAN_M
	var hi := minf(float(axles.max()) + HALF_SPAN_M, Z_END_M)
	var rng := ctx.rng(&"arch")
	for surface in SURFACES:
		var lean := rng.randf_range(LEAN_DEG.x, LEAN_DEG.y)
		var p := _fit(ctx, def, surface, Vector2(lo, hi), axles, lean)
		if p == null:
			dropped.append("arch box skipped %d %s %s" % [ctx.van_seed,
				"left" if surface == VanKitSurface.LEFT_WALL else "right", _why])
			continue
		out.append(p)
		var box: AABB = _made[p][&"box"]
		ctx.keep_out.add_piece("arch_box_%s" % surface, box.grow(KEEP_OUT_GROW_M))
	return out


## The box for one wall over `span` (z lo, hi), shrunk away from a blocker until it is allowed or
## shorter than MIN_SPAN_M; null when it has no room or no longer holds an axle.
static func _fit(ctx: VanKitBuilder.Ctx, def: VanArchBoxDef, surface: StringName, span: Vector2,
		axles: Array[float], lean_deg: float) -> VanKitPlaced:
	var s := -1.0 if surface == VanKitSurface.LEFT_WALL else 1.0
	var walls := ctx.keep_out.walls
	# The liner bows outward going up, so depth is measured from it at each height.
	var wall := PackedVector2Array()
	var y := 0.0
	while y < HEIGHT_M - 0.001:
		wall.append(Vector2(walls.wall_x_at(y), y))
		y += WALL_STEP_M
	wall.append(Vector2(walls.wall_x_at(HEIGHT_M), HEIGHT_M))
	var wall0 := wall[0].x
	var wall1 := wall[wall.size() - 1].x
	var fb := wall0
	var ft := wall0 + HEIGHT_M * tan(deg_to_rad(lean_deg))
	# Shift the front so the largest liner-to-front gap over the height is DEPTH_M.
	var shift := maxf(wall0 - fb, wall1 - ft) - DEPTH_M
	fb += shift
	ft += shift
	var x_in := minf(fb, ft)
	var depth := maxf(wall0, wall1) - x_in
	var z0 := span.x
	var z1 := span.y
	for attempt in TRIES:
		var box := AABB(Vector3(minf(s * x_in, s * (x_in + depth)), 0.0, z0),
				Vector3(depth, HEIGHT_M, z1 - z0))
		var block := ctx.keep_out.blocker_box(box, &"arch_box")
		_why = ctx.keep_out.why(box, &"arch_box")
		if _why == "":
			break
		if z1 - z0 <= MIN_SPAN_M or attempt == TRIES - 1:
			return null
		if block.get_center().z > (z0 + z1) * 0.5:
			z1 = block.position.z - BLOCK_CLEAR_M
		else:
			z0 = block.end.z + BLOCK_CLEAR_M
		if z1 - z0 < MIN_SPAN_M:
			return null
	var held := false
	for axle in axles:
		held = held or (axle > z0 and axle < z1)
	if not held:
		_why = "no axle"
		return null
	var inward := Vector3(-s, 0.0, 0.0)
	var along := Vector3(0.0, 0.0, 1.0 if s > 0.0 else -1.0)
	var p := VanKitPlaced.new()
	p.def_id = def.id
	p.surface = surface
	p.origin_kind = &"DONOR"
	p.origin_id = _donor_id(ctx, surface, (z0 + z1) * 0.5)
	p.reason = &"axle"
	p.size = Vector3(HEIGHT_M, DEPTH_M, z1 - z0)
	p.transform = Transform3D(Basis(Vector3.UP, inward, along),
		Vector3(s * (ft + DEPTH_M * 0.5), HEIGHT_M * 0.5, (z0 + z1) * 0.5))
	p.gen = VanKit.GEN
	_made[p] = {&"xs": s, &"fb": fb, &"ft": ft, &"y1": HEIGHT_M, &"z0": z0, &"z1": z1,
		&"wall": wall, &"depth": depth,
		&"off": ft + (DEPTH_M - depth) * 0.5 - x_in, &"box": AABB(Vector3(minf(s * x_in, s * (x_in + depth)), 0.0, z0),
			Vector3(depth, HEIGHT_M, z1 - z0))}
	return p


## The donor whose region outline on this wall holds the wall surface at `z` (m), v 40 cm.
static func _donor_id(ctx: VanKitBuilder.Ctx, surface: StringName, z: float) -> StringName:
	return donor_at(ctx, surface, Vector2(z * 100.0, PAINT_Y_CM))


## The donor whose region outline on `surface` holds `at` (cm); the first region's, else the first donor's.
static func donor_at(ctx: VanKitBuilder.Ctx, surface: StringName, at: Vector2) -> StringName:
	for region: Dictionary in ctx.donors.regions:
		if region[&"surface"] == surface and Geometry2D.is_point_in_polygon(at, region[&"outline"]):
			return region[&"donor_id"]
	for region: Dictionary in ctx.donors.regions:
		if region[&"surface"] == surface:
			return region[&"donor_id"]
	return ctx.donors.donors[0].id if not ctx.donors.donors.is_empty() else &""


## Adds each tub's mesh and its box collider under `parent`.
static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced], parent: Node3D) -> void:
	for p in placed:
		if not _made.has(p):
			continue
		var paint := Color(0.3, 0.29, 0.28)
		var rust := 0.4
		var style := int(VanDonor.WallStyle.FLAT)
		var pitch := 1.0
		var donor := VanKitStructure._donor(ctx.donors, p.origin_id)
		if donor != null:
			paint = donor.paint
			rust = clampf(donor.fade, 0.0, 1.0)
			style = int(donor.wall_style)
			pitch = donor.rib_pitch_m if donor.rib_pitch_m > 0.0 else 1.0
		var mi := VanKitArchMesh.build(parent, p, _made[p], paint, rust, style, pitch,
				ctx.van_seed)
		mi.set_meta(&"kit_origin", {&"kind": p.origin_kind, &"id": p.origin_id,
			&"reason": p.reason})
		var body := StaticBody3D.new()
		body.name = "ArchBody"
		body.collision_layer = _COLLIDER_LAYER
		body.collision_mask = 0
		body.transform = p.transform
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var depth: float = _made[p][&"depth"]
		box.size = Vector3(p.size.x, depth, p.size.z)
		# The collider reaches from the front face to the liner's outermost point.
		shape.position = Vector3(0.0, _made[p][&"off"], 0.0)
		shape.shape = box
		body.add_child(shape)
		parent.add_child(body)
