class_name VanKitSkinFloor
extends RefCounted
## Kit skin pass, floor: per floor region long tread-plate runs, the donor's floor, or a few
## overlapping plates, all collider-free on top of the real floor.

const TREAD := &"skin/floor_tread"
const DONOR := &"skin/floor_donor"
const PLATE := &"skin/floor_plate"
const TREAD_ID := &"tread_plate"
## Plate tops (m) off the floor; a plate lapping another sits higher.
const TOP := 0.024
const TOP_LAPPING := 0.036
const _RUN_WIDTH_CM := Vector2(90.0, 160.0)
const _PLATE_CM := Vector2(80.0, 200.0)
const _GRID_CM := 10.0
## A cut part under this size (cm) in either dimension is dropped.
const MIN_PART_CM := 10.0
const _TILT_DEG := Vector2(1.0, 3.0)


static func place(ctx: VanKitBuilder.Ctx, out: Array[VanKitPlaced]) -> void:
	var rng := ctx.rng(&"skin", &"floor")
	for region: Dictionary in ctx.donors.regions:
		if region[&"surface"] != VanKitSurface.FLOOR:
			continue
		var outline: PackedVector2Array = region[&"outline"]
		if outline.size() < 3:
			continue
		var id: StringName = region[&"donor_id"]
		match rng.randi_range(0, 2):
			0:
				_runs(ctx, outline, rng, out)
			1:
				_add_cut(ctx, outline, TOP, DONOR, id, 0.0, Vector3.ZERO, out)
			_:
				_plates(ctx, outline, id, rng, out)


static func _runs(ctx: VanKitBuilder.Ctx, outline: PackedVector2Array,
		rng: RandomNumberGenerator, out: Array[VanKitPlaced]) -> void:
	var b := VanKitSkin._bounds(outline)
	var taken: Array[Vector2] = []
	for n in rng.randi_range(1, 2):
		var w := rng.randf_range(_RUN_WIDTH_CM.x, _RUN_WIDTH_CM.y)
		if b[1].y - b[0].y < w:
			continue
		var x0 := rng.randf_range(b[0].y, b[1].y - w)
		var span := Vector2(x0, x0 + w)
		var clash := false
		for t in taken:
			clash = clash or (span.x < t.y and span.y > t.x)
		if clash:
			continue
		taken.append(span)
		var rect := VanKitSkin._rect(Vector2(b[0].x, span.x), Vector2(b[1].x, span.y))
		for piece in Geometry2D.intersect_polygons(rect, outline):
			_add_cut(ctx, piece, TOP, TREAD, TREAD_ID, 0.0, Vector3.ZERO, out)


static func _plates(ctx: VanKitBuilder.Ctx, outline: PackedVector2Array, id: StringName,
		rng: RandomNumberGenerator, out: Array[VanKitPlaced]) -> void:
	var b := VanKitSkin._bounds(outline)
	var rects: Array[Rect2] = []
	for n in rng.randi_range(2, 3):
		var size := Vector2(rng.randf_range(_PLATE_CM.x, _PLATE_CM.y),
			rng.randf_range(_PLATE_CM.x, _PLATE_CM.y))
		size = size.min(b[1] - b[0])
		var at := Vector2(rng.randf_range(b[0].x, b[1].x - size.x),
			rng.randf_range(b[0].y, b[1].y - size.y))
		at = (at / _GRID_CM).round() * _GRID_CM + Vector2(rng.randf_range(0.0, 4.0),
			rng.randf_range(0.0, 4.0))
		var rect := Rect2(at, size)
		var top := TOP
		for other in rects:
			if rect.intersects(other):
				top = TOP_LAPPING
		rects.append(rect)
		var tilt := deg_to_rad(rng.randf_range(_TILT_DEG.x, _TILT_DEG.y))
		var pivot := Vector3(rect.get_center().y, 0.0, rect.get_center().x) * 0.01
		var poly := VanKitSkin._rect(rect.position, rect.end)
		for piece in Geometry2D.intersect_polygons(poly, outline):
			_add_cut(ctx, piece, top, PLATE, id, tilt, pivot, out)


static func _add_cut(ctx: VanKitBuilder.Ctx, poly: PackedVector2Array, depth: float,
		def_id: StringName, origin_id: StringName, tilt: float, pivot: Vector3,
		out: Array[VanKitPlaced]) -> void:
	for part in VanKitClip.cut(ctx.keep_out, VanKitSurface.FLOOR, poly, depth, &"floor"):
		var b := VanKitSkin._bounds(part)
		if minf(b[1].x - b[0].x, b[1].y - b[0].y) < MIN_PART_CM:
			continue
		var p := VanKitPlaced.new()
		p.def_id = def_id
		p.surface = VanKitSurface.FLOOR
		p.origin_kind = &"SCRAP" if def_id == TREAD else &"DONOR"
		p.origin_id = origin_id
		p.reason = &"region_skin"
		# Skewed plates yaw about the up axis at the plate's centre, so the top stays flat.
		p.transform = Transform3D(Basis(Vector3.UP, tilt), pivot)
		p.size = Vector3((b[1].y - b[0].y) * 0.01, depth, (b[1].x - b[0].x) * 0.01)
		p.outline = part
		p.gen = VanKit.GEN
		out.append(p)
