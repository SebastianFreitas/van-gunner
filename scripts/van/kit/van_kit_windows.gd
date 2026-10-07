class_name VanKitWindows
extends RefCounted
## Pass 8: one salvaged wall piece around each side window, a solid ring from the wall hole edge
## out to the rolled piece outline, placed as its four side strips.

const REASON := &"window_piece"
## Outer face off the liner, over seam beads (5.6) and straps (6.4 + 1.2); back face BACK_M off it.
const DEPTH := 0.076
const BACK_M := 0.003
const STOP_M := 0.03
const MIN_M := 0.1
## The ring's inner edge stands this far (cm) off the hole edge.
const INNER_CM := 1.0
## The bulkhead frame's wall posts (z 1.0, 0.08 half-depth, D26) and the gap kept short of them.
const POST_Z_M := 1.0
const POST_M := 0.08 + 0.03
const _DEFS_DIR := "res://resources/van/kit/windows/"


static func place(ctx: VanKitBuilder.Ctx) -> Array[VanKitPlaced]:
	var out: Array[VanKitPlaced] = []
	if ctx.keep_out == null or ctx.keep_out.walls == null:
		return out
	VanKitSurface.walls = ctx.keep_out.walls
	ctx.rng(&"windows")
	for entry: Dictionary in ctx.donors.windows:
		var surface: StringName = entry[&"surface"]
		var outer := ring_outline(entry)
		if surface == &"rear" or outer.size() < 3:
			continue
		var hole := hole_cm(ctx.keep_out.walls, entry)
		var def := def_of(entry)
		var donor := _donor_at(ctx.donors, surface, outer)
		for strip in strips(outer, inner_cm(hole)):
			for trimmed in _trim_posts(strip):
				for kept in _fit(ctx, surface, trimmed, 3, String(entry[&"window_id"])):
					var p := _piece(surface, kept)
					if def.use_region_paint:
						p.origin_kind = &"DONOR"
						p.origin_id = donor
					else:
						p.origin_kind = &"SCRAP"
						p.origin_id = def.id
					p.def_id = def.id
					out.append(p)
	return out


## The rolled piece outline made simple (no self-crossing from the rough edge), as one cm polygon.
static func ring_outline(entry: Dictionary) -> PackedVector2Array:
	var outer: PackedVector2Array = entry[&"piece_outline"]
	var best := PackedVector2Array()
	var best_area := 0.0
	for poly in Geometry2D.merge_polygons(outer, PackedVector2Array()):
		var area := absf(_area(poly))
		if not Geometry2D.is_polygon_clockwise(poly) and area > best_area:
			best = poly
			best_area = area
	return best if best.size() >= 3 else outer


## The ring's inner edge: the hole edge grown INNER_CM, since the window stop covers past the hole.
static func inner_cm(hole: PackedVector2Array) -> PackedVector2Array:
	var grown := Geometry2D.offset_polygon(hole, INNER_CM, Geometry2D.JOIN_MITER)
	return grown[0] if not grown.is_empty() else hole


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5


## The strip minus the band around the bulkhead wall posts (D26), as cm polygons.
static func _trim_posts(strip: PackedVector2Array) -> Array[PackedVector2Array]:
	var band := _rect(Vector2((POST_Z_M - POST_M) * 100.0, -1000.0),
		Vector2((POST_Z_M + POST_M) * 100.0, 1000.0))
	var out: Array[PackedVector2Array] = []
	for part in Geometry2D.clip_polygons(strip, band):
		if Geometry2D.is_polygon_clockwise(part):
			part.reverse()
		if part.size() >= 3:
			out.append(part)
	return out


static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced], parent: Node3D) -> void:
	if ctx.keep_out != null:
		VanKitSurface.walls = ctx.keep_out.walls
	VanKitWindowsMesh.build(ctx, placed, parent)


static func def_of(entry: Dictionary) -> VanWindowAssetDef:
	return load(_DEFS_DIR + String(entry[&"asset_id"]) + ".tres") as VanWindowAssetDef


## The wall hole of a window entry in wall cm (z, y); its opening grown 2 cm when no wall.
static func hole_cm(walls: VanSideWall, entry: Dictionary) -> PackedVector2Array:
	var id: StringName = entry[&"window_id"]
	var cz: float = VanKitFootprint.WINDOW_ZC[id]
	var sign_x := -1.0 if String(id).begins_with("left") else 1.0
	var out := PackedVector2Array()
	for p in walls.cut_poly_for(sign_x, cz):
		out.append(Vector2((p.x + cz) * 100.0, (p.y + walls.window_center_y) * 100.0))
	return out


## The ring minus the hole cut into top, bottom, left and right strips (cm polygons).
static func strips(outer: PackedVector2Array, hole: PackedVector2Array) -> Array[PackedVector2Array]:
	var ob := VanKitSkin._bounds(outer)
	var hb := VanKitSkin._bounds(hole)
	var cx := (hb[0].x + hb[1].x) * 0.5
	# The rects tile the bounds (shared edges only, margin outward only), so strips never overlap.
	var m := Vector2.ONE * 2.0
	var rects: Array[PackedVector2Array] = [
		_rect(Vector2(ob[0].x, hb[1].y) - Vector2(2.0, 0.0), ob[1] + m),
		_rect(ob[0] - m, Vector2(ob[1].x + 2.0, hb[0].y)),
		_rect(Vector2(ob[0].x - 2.0, hb[0].y), Vector2(cx, hb[1].y)),
		_rect(Vector2(cx, hb[0].y), Vector2(ob[1].x + 2.0, hb[1].y))]
	var out: Array[PackedVector2Array] = []
	for rect in rects:
		for part in Geometry2D.intersect_polygons(rect, outer):
			for ring in Geometry2D.clip_polygons(part, hole):
				if Geometry2D.is_polygon_clockwise(ring):
					ring.reverse()
				if ring.size() >= 3:
					out.append(ring)
	return out


## The strip, or what is left of it after stopping STOP_M short of the box-only volume refusing it
## (from either side; a remainder under MIN_M along the run is dropped), as cm polygons (D45).
static func _fit(ctx: VanKitBuilder.Ctx, surface: StringName, poly: PackedVector2Array,
		tries: int, window: String) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var p := _piece(surface, poly)
	var box := p.transform * AABB(-p.size * 0.5, p.size)
	if ctx.keep_out.why_strip(box, &"window", poly) == "":
		out.append(poly)
		return out
	var b := VanKitSkin._bounds(poly)
	var axis := 0 if b[1].x - b[0].x >= b[1].y - b[0].y else 1
	var vol := ctx.keep_out.blocker_box(box, &"window", poly)
	if tries <= 0 or vol.size == Vector3.ZERO:
		return out
	var lo := vol.position.z * 100.0 if axis == 0 else vol.position.y * 100.0
	var hi := vol.end.z * 100.0 if axis == 0 else vol.end.y * 100.0
	for span in [Vector2(b[0][axis] - 1.0, lo - STOP_M * 100.0),
			Vector2(hi + STOP_M * 100.0, b[1][axis] + 1.0)]:
		var s: Vector2 = span
		if s.y - s.x < MIN_M * 100.0:
			continue
		var lo_v := Vector2(s.x, b[0].y - 1.0) if axis == 0 else Vector2(b[0].x - 1.0, s.x)
		var hi_v := Vector2(s.y, b[1].y + 1.0) if axis == 0 else Vector2(b[1].x + 1.0, s.y)
		for part in Geometry2D.intersect_polygons(poly, _rect(lo_v, hi_v)):
			var pb := VanKitSkin._bounds(part)
			if pb[1][axis] - pb[0][axis] >= MIN_M * 100.0 and part.size() >= 3:
				out.append_array(_fit(ctx, surface, part, tries - 1, window))
	return out


static func _rect(lo: Vector2, hi: Vector2) -> PackedVector2Array:
	return PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])


## The donor whose wall region holds the window centre.
static func _donor_at(donors: VanDonorSet, surface: StringName,
		outer: PackedVector2Array) -> StringName:
	var b := VanKitSkin._bounds(outer)
	var centre := (b[0] + b[1]) * 0.5
	for region: Dictionary in donors.regions:
		if region[&"surface"] == surface \
				and Geometry2D.is_point_in_polygon(centre, region[&"outline"]):
			return region[&"donor_id"]
	return &""


static func _piece(surface: StringName, poly: PackedVector2Array) -> VanKitPlaced:
	var b := VanKitSkin._bounds(poly)
	var centre := (b[0] + b[1]) * 0.5
	var normal := VanKitSurface.normal(surface, centre.x, centre.y)
	var tangent := normal.cross(Vector3.BACK)
	var p := VanKitPlaced.new()
	p.surface = surface
	p.reason = REASON
	p.transform = Transform3D(Basis(tangent, normal, Vector3.BACK),
		VanKitSurface.point(surface, centre.x, centre.y, 0.0) + normal * (DEPTH * 0.5))
	p.size = Vector3((b[1].y - b[0].y) * 0.01 / maxf(absf(tangent[1]), 0.2), DEPTH,
		(b[1].x - b[0].x) * 0.01)
	p.outline = poly
	p.gen = VanKit.GEN
	return p
