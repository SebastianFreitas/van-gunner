class_name VanKitWindowsRear
extends RefCounted
## Pass 9: a salvaged wall piece around each rear-door window, a U on the hinge, top and bottom
## sides that rides its leaf; the seam side is left to the lip and the astragal (D51).

const _RearFit := preload("res://scripts/van/rear_window_fit.gd")
const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _MARGIN_CM := Vector2(8.0, 15.0)
## Front face off the cabin face; the rules' window depth is 0.03..0.08.
const _DEPTH_M := Vector2(0.05, 0.078)
## Back face off the cabin face: 1.4 cm over the leaf skin (0.022), so the two never share a plane.
const BACK_M := 0.036
## Leaf coords (cm, centre of the Panel): today's window centre, and the clip rect that keeps the
## piece 2 cm inside the hinge, off the astragal (|x| 2.26, its 6 cm half width + 1.2 cm) and under the vault.
const _CENTRE_CM := Vector2(12.5, 22.5)
const _CLIP_A_CM := Vector2(-117.0, 107.0)
const _CLIP_B_CM := Vector2(-151.0, 150.0)
## Plexi washers sit on the lip (0.015 proud) and stay inside the piece's inner edge.
const WASHER_FACE_M := 0.015
const WASHER_RING_CM := 1.5


static func place(ctx: VanKitBuilder.Ctx) -> Array[VanKitPlaced]:
	var out: Array[VanKitPlaced] = []
	if ctx.keep_out == null or ctx.keep_out.walls == null:
		return out
	VanKitSurface.walls = ctx.keep_out.walls
	var rng := ctx.rng(&"windows", &"rear")
	for entry: Dictionary in ctx.donors.windows:
		if entry[&"surface"] != &"rear":
			continue
		var surface := leaf_of(entry)
		var margin := rng.randf_range(_MARGIN_CM.x, _MARGIN_CM.y)
		var depth := rng.randf_range(_DEPTH_M.x, _DEPTH_M.y)
		var def := VanKitWindows.def_of(entry)
		var inner := frame_cm(entry, _RearFit.OUTER_TODAY)
		var grown := Geometry2D.offset_polygon(inner, margin, Geometry2D.JOIN_ROUND)
		if grown.is_empty():
			continue
		# The right leaf's a runs the other way (hinge-local x = a - 1.19), so its clip mirrors.
		var a_lo := _CLIP_A_CM.x if surface == VanKitSurface.LEFT_LEAF else -_CLIP_A_CM.y
		var a_hi := _CLIP_A_CM.y if surface == VanKitSurface.LEFT_LEAF else -_CLIP_A_CM.x
		var clip := VanKitWindows._rect(Vector2(a_lo, _CLIP_B_CM.x), Vector2(a_hi, _CLIP_B_CM.y))
		var shrunk := Geometry2D.offset_polygon(inner, -1.0, Geometry2D.JOIN_MITER)
		if shrunk.is_empty():
			continue
		for outer in Geometry2D.intersect_polygons(grown[0], clip):
			for strip in VanKitWindows.strips(outer, shrunk[0]):
				for kept in VanKitClip.cut(ctx.keep_out, surface, strip, depth, &"window"):
					var p := _piece(surface, kept, depth)
					p.origin_kind = &"DONOR" if def.use_region_paint else &"SCRAP"
					p.origin_id = _donor(ctx, surface) if def.use_region_paint else def.id
					p.def_id = def.id
					out.append(p)
	return out


static func leaf_of(entry: Dictionary) -> StringName:
	return VanKitSurface.LEFT_LEAF if entry[&"window_id"] == &"rear_left" \
			else VanKitSurface.RIGHT_LEAF


## The hole of a rear entry in leaf cm (a = hinge-local x less the Panel offset, b = y).
static func hole_cm(entry: Dictionary) -> PackedVector2Array:
	var hole := _LeafBuild.grown_hole(entry[&"hole_grow"] as Vector3)
	return _to_leaf(entry, hole, hole[&"poly"] as PackedVector2Array)


## The leaf's frame polygon (today's margins around the grown hole) in leaf cm.
static func frame_cm(entry: Dictionary, today: Array[Vector2]) -> PackedVector2Array:
	var hole := _LeafBuild.grown_hole(entry[&"hole_grow"] as Vector3)
	var poly := hole[&"poly"] as PackedVector2Array
	var out := PackedVector2Array()
	for i in poly.size():
		out.append(poly[i] + today[i] - _LeafBuild.WINDOW_HOLE[i])
	return _to_leaf(entry, hole, out)


static func _to_leaf(entry: Dictionary, hole: Dictionary,
		window_local: PackedVector2Array) -> PackedVector2Array:
	var sign_x := 1.0 if entry[&"window_id"] == &"rear_left" else -1.0
	var centre := hole[&"center"] as Vector2
	var out := PackedVector2Array()
	for p in window_local:
		out.append(Vector2(sign_x * (_CENTRE_CM.x + (centre.x + p.x) * 100.0),
			_CENTRE_CM.y + (centre.y + p.y) * 100.0))
	if sign_x < 0.0:
		out.reverse()
	return out


static func _donor(ctx: VanKitBuilder.Ctx, surface: StringName) -> StringName:
	for region: Dictionary in ctx.donors.regions:
		if region[&"surface"] == surface or region[&"surface"] == &"rear":
			return region[&"donor_id"]
	return ctx.donors.donors[0].id if not ctx.donors.donors.is_empty() else &""


static func _piece(surface: StringName, poly: PackedVector2Array, depth: float) -> VanKitPlaced:
	var b := VanKitSkin._bounds(poly)
	var centre := (b[0] + b[1]) * 0.5
	var p := VanKitPlaced.new()
	p.surface = surface
	p.attach = surface
	p.reason = VanKitWindows.REASON
	p.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP),
		VanKitSurface.point(surface, centre.x, centre.y, 0.0) + Vector3.FORWARD * (depth * 0.5))
	p.size = Vector3((b[1].x - b[0].x) * 0.01, depth, (b[1].y - b[0].y) * 0.01)
	p.outline = poly
	p.gen = VanKit.GEN
	return p


## One leaf's pieces (`placed` is one attach group): the ring mesh and the plexi washers.
static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced], parent: Node3D) -> void:
	if placed.is_empty():
		return
	var first := placed[0]
	var def := load("res://resources/van/kit/windows/%s.tres" % first.def_id) as VanWindowAssetDef
	var fronts: Array[PackedVector2Array] = []
	for p in placed:
		fronts.append(p.outline)
	var mi := VanKitWindowsMesh.node(parent, "RearWindow_" + String(first.surface),
		VanKitWindowsMesh.ring(first.surface, fronts, first.size.y, [[fronts, BACK_M]]))
	var paint := def.paint
	var primer := VanKitWindowsMesh.BUS_PAINT_PRIMER
	var rust := 0.3
	var wall_style := int(VanDonor.WallStyle.FLAT)
	var pitch := 0.0
	for d in ctx.donors.donors:
		if def.use_region_paint and d.id == first.origin_id:
			paint = d.paint
			primer = d.primer
			rust = clampf(d.fade, 0.0, 1.0)
			wall_style = int(d.wall_style)
			pitch = clampf(d.rib_pitch_m, 0.0, 1.0)
	VanKitWindowsMesh.style(mi, paint, primer, rust, wall_style, pitch, ctx.van_seed,
		first.origin_id)
	mi.set_meta(&"kit_origin", {&"kind": first.origin_kind, &"id": first.origin_id,
		&"reason": VanKitWindows.REASON})
	var rng := ctx.rng(&"windows", &"hardware" + String(first.surface))
	for entry: Dictionary in ctx.donors.windows:
		if entry[&"surface"] == &"rear" and leaf_of(entry) == first.surface:
			VanKitWindowsHardware.washers(ctx, entry, hole_cm(entry), parent, rng)
