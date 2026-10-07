extends RefCounted
## Rolls the six window pieces of a donor set: asset, glazing, and for the side windows the
## opening and the wall part outline in wall cm (z, y).

const _WINDOW_PATHS: Array[String] = [
	"res://resources/van/kit/windows/donor_side_panel.tres",
	"res://resources/van/kit/windows/bus_side_section.tres",
	"res://resources/van/kit/windows/torch_cut_plate.tres",
]
## [window id, surface, z centre in metres]; the rear leaves have no side z.
const _SIDE: Array = [
	[&"left_rear", &"left_wall", 2.835], [&"left_front", &"left_wall", -0.375],
	[&"right_rear", &"right_wall", 2.835], [&"right_front", &"right_wall", -0.375],
]
const _REAR: Array[StringName] = [&"rear_left", &"rear_right"]
const CENTER_Y_CM := 177.5
const HALF_MIN_CM := Vector2(120.2, 68.7)
const HALF_MAX_CM := Vector2(126.2, 74.0)
## The hole is the opening + 2 cm and has to hold the glass + 2 cm.
const HOLE_GROW_CM := 2.0
## Most a rear hole grows on each of its hinge side, top and bottom edges.
const HOLE_GROW_MAX_M := 0.04
const _CORNER_STEPS := 5
## Hull-hole limits (metres, wall z and y) every side piece must stay inside.
const _Z_RANGES: Array[Vector2] = [Vector2(142.3, 424.7), Vector2(-178.7, 103.7)]
const _Y_RANGE := Vector2(88.5, 266.5)

## SideWindows.GLASS_POLY (metres, window-local), copied because that one is a node field.
const _GLASS_M := [
	Vector2(-0.861, -0.617), Vector2(-1.017, -0.56), Vector2(-1.1, -0.455),
	Vector2(-1.1, 0.455), Vector2(-1.017, 0.56), Vector2(-0.861, 0.617),
	Vector2(0.861, 0.617), Vector2(1.017, 0.56), Vector2(1.1, 0.455),
	Vector2(1.1, -0.455), Vector2(1.017, -0.56), Vector2(0.861, -0.617),
]


static func load_assets() -> Array[VanWindowAssetDef]:
	var defs: Array[VanWindowAssetDef] = []
	for path in _WINDOW_PATHS:
		defs.append(load(path) as VanWindowAssetDef)
	defs.sort_custom(func(a: VanWindowAssetDef, b: VanWindowAssetDef) -> bool:
		return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
	return defs


## The six window entries in a fixed order.
static func roll(van_seed: int) -> Array[Dictionary]:
	var defs := load_assets()
	var out: Array[Dictionary] = []
	for side: Array in _SIDE:
		out.append(_roll_one(van_seed, side[0], side[1], side[2] * 100.0, defs))
	for id in _REAR:
		out.append(_roll_one(van_seed, id, &"rear", 0.0, defs))
	return out


static func _roll_one(van_seed: int, id: StringName, surface: StringName, zc_cm: float,
		defs: Array[VanWindowAssetDef]) -> Dictionary:
	var rng := VanLook.rng_for_seed(van_seed, StringName("kit/window/" + String(id)))
	var def := defs[rng.randi_range(0, defs.size() - 1)]
	var glazing := &"glass" if rng.randf() < 0.5 else &"plexi"
	var entry := {
		&"window_id": id, &"surface": surface, &"asset_id": def.id,
		&"opening": PackedVector2Array(), &"piece_outline": PackedVector2Array(),
		&"glazing": glazing,
	}
	if surface == &"rear":
		# Own stream so every other roll stays as it was.
		var grow := VanLook.rng_for_seed(van_seed, StringName("kit/window/" + String(id) + "/hole"))
		entry[&"hole_grow"] = Vector3(grow.randf_range(0.0, HOLE_GROW_MAX_M),
			grow.randf_range(0.0, HOLE_GROW_MAX_M), grow.randf_range(0.0, HOLE_GROW_MAX_M))
		return entry
	var half := Vector2(rng.randf_range(HALF_MIN_CM.x, HALF_MAX_CM.x),
		rng.randf_range(HALF_MIN_CM.y, HALF_MAX_CM.y))
	var margin := rng.randf_range(def.wall_part_margin_min_m, def.wall_part_margin_max_m) * 100.0
	var radius := def.corner_radius_m * 100.0
	var rough := def.shape == VanWindowAssetDef.Shape.ROUGH_RECT
	var opening := _shape(rng, half, radius, rough)
	var piece := _shape(rng, half + Vector2(margin, margin), radius + margin, rough)
	_check(id, zc_cm, opening, piece)
	entry[&"opening"] = _shift(opening, zc_cm)
	entry[&"piece_outline"] = _shift(piece, zc_cm)
	return entry


## Rounded rectangle, or a rough one with points every 10..15 cm pulled inward by up to 1 cm.
static func _shape(rng: RandomNumberGenerator, half: Vector2, radius: float,
		rough: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not rough:
		var r := minf(radius, minf(half.x, half.y))
		var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
		for i in 4:
			var c: Vector2 = corners[i]
			var centre := Vector2(c.x * (half.x - r), c.y * (half.y - r))
			var a0 := atan2(c.y, c.x) - PI * 0.25
			for s in _CORNER_STEPS + 1:
				var a := a0 + (PI * 0.5) * float(s) / _CORNER_STEPS
				pts.append(centre + Vector2(cos(a), sin(a)) * r)
		return pts
	var cs: Array[Vector2] = [Vector2(half.x, half.y), Vector2(-half.x, half.y),
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y)]
	for i in 4:
		var p0 := cs[i]
		var p1 := cs[(i + 1) % 4]
		var n := maxi(1, roundi(p0.distance_to(p1) / rng.randf_range(10.0, 15.0)))
		for s in n:
			var p := p0.lerp(p1, float(s) / n)
			if absf(p.x) > half.x - 0.001:
				p.x -= signf(p.x) * rng.randf_range(0.0, 1.0)
			if absf(p.y) > half.y - 0.001:
				p.y -= signf(p.y) * rng.randf_range(0.0, 1.0)
			pts.append(p)
	return pts


static func _shift(poly: PackedVector2Array, zc_cm: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(Vector2(p.x + zc_cm, p.y + CENTER_Y_CM))
	return out


static func _check(id: StringName, zc_cm: float, opening: PackedVector2Array,
		piece: PackedVector2Array) -> void:
	var hole := Geometry2D.offset_polygon(opening, HOLE_GROW_CM, Geometry2D.JOIN_MITER)
	var glass := Geometry2D.offset_polygon(_cm(PackedVector2Array(_GLASS_M)), HOLE_GROW_CM, Geometry2D.JOIN_MITER)
	if hole.is_empty() or glass.is_empty():
		push_error("VanDonorWindows: %s hole or glass offset failed" % id)
		return
	for p in glass[0]:
		if not Geometry2D.is_point_in_polygon(p, hole[0]):
			push_error("VanDonorWindows: %s hole misses the glass at %s" % [id, p])
			return
	var zr: Vector2 = _Z_RANGES[0] if zc_cm > 0.0 else _Z_RANGES[1]
	for p in piece:
		var z := p.x + zc_cm
		var y := p.y + CENTER_Y_CM
		if z < zr.x or z > zr.y or y < _Y_RANGE.x or y > _Y_RANGE.y:
			push_error("VanDonorWindows: %s piece point (%s, %s) is outside the hull hole" %
				[id, z, y])
			return


static func _cm(poly_m: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly_m:
		out.append(p * 100.0)
	return out
