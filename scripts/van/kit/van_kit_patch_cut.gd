class_name VanKitPatchCut
extends RefCounted
## Rolls one salvage patch from its source: a torch-cut outline that keeps its telling feature.
## Pure: the same def, scale and RNG state give the same outline. Frame: cm, centred on the source.

const KEEP_MARGIN := 5.0
const JAG_MIN := 2.0
const JAG_MAX := 4.0
const KEEP_FRACTION := Vector2(0.35, 1.0)
const POINTS_MIN := 5
const POINTS_MAX := 9
const TELLING: Array[StringName] = [&"road_sign", &"car_door", &"fridge_door"]


## What spec 8-3 needs to place a patch and what `VanKitPatchMesh` draws.
class Result:
	extends RefCounted
	var source: StringName = &""
	## Sign outline shape (rectangle, disc, triangle); empty for the other sources.
	var shape: StringName = &""
	var outline := PackedVector2Array()
	## Outline bounds in metres.
	var size := Vector2.ZERO
	## The uncut source's size in metres.
	var source_size := Vector2.ZERO
	## The part of the source a cut never enters (+ 5 cm), cm; empty when `telling` is false.
	var telling_box := Rect2()
	var telling := false
	## Longest outline dimension in metres, for the tilt by size.
	var longest := 0.0
	## Source features in the source frame (clipped to the outline when drawn) and their kind.
	var plates: Array[PackedVector2Array] = []
	var plate_kinds: Array[StringName] = []


## `size_scale` is 8-3's reroll step (0.85 per try); a side never goes under the def's minimum.
static func roll(def: VanPatchDef, rng: RandomNumberGenerator,
		size_scale: float = 1.0) -> Result:
	var res := Result.new()
	res.source = def.source
	res.telling = TELLING.has(def.source)
	var dims := Vector2(
		maxf(rng.randf_range(def.size_min.x, def.size_max.x) * size_scale, def.size_min.x),
		maxf(rng.randf_range(def.size_min.y, def.size_max.y) * size_scale, def.size_min.y))
	if def.source == &"road_sign":
		dims.y = dims.x
	res.source_size = dims
	var src := _source(def, rng, dims * 100.0, res)
	var keep := res.telling_box.grow(KEEP_MARGIN) if res.telling else Rect2()
	var whole := rng.randi_range(0, 2) == 0
	res.outline = src if whole else _cut(src, dims * 100.0, keep, rng)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in res.outline:
		lo = lo.min(p)
		hi = hi.max(p)
	res.size = (hi - lo) * 0.01
	res.longest = maxf(res.size.x, res.size.y)
	return res


## The uncut source outline; fills the shape, plates and telling box.
static func _source(def: VanPatchDef, rng: RandomNumberGenerator, dims: Vector2,
		res: Result) -> PackedVector2Array:
	var h := dims * 0.5
	match def.source:
		&"road_sign":
			return _sign(def, rng, dims.x, res)
		&"car_door":
			var handle := Rect2(rng.randf_range(-15.0, 15.0) - 9.0, -11.0, 18.0, 6.0)
			_plate(res, _rect(handle), &"recess")
			_plate(res, _rect(Rect2(-40.0, 22.0, 80.0, 6.0)), &"window")
			if rng.randi_range(0, 1) == 0:
				res.telling_box = handle
			else:
				res.telling_box = Rect2(rng.randf_range(-40.0, 0.0), 22.0, 40.0, 6.0)
			return _rect(Rect2(-h, dims))
		&"fridge_door":
			var side := 1.0 if rng.randi_range(0, 1) == 0 else -1.0
			var handle := Rect2(side * (h.x - 12.0) - 2.0, rng.randf_range(10.0, 30.0) - 15.0,
					4.0, 30.0)
			_plate(res, _rect(handle), &"handle")
			res.telling_box = handle
			return _rounded(h, 8.0)
	return _rect(Rect2(-h, dims))


static func _sign(def: VanPatchDef, rng: RandomNumberGenerator, s: float,
		res: Result) -> PackedVector2Array:
	var shapes := def.symbol_shapes
	res.shape = shapes[rng.randi_range(0, shapes.size() - 1)] if not shapes.is_empty() \
			else &"rectangle"
	var h := s * 0.5
	var outline := _rect(Rect2(-h, -h, s, s))
	var centre := Vector2.ZERO
	var turns := rng.randi_range(0, 3)
	if res.shape == &"disc":
		outline = PackedVector2Array()
		for i in 12:
			outline.append(Vector2.from_angle(TAU * i / 12.0) * h)
	elif res.shape == &"triangle":
		outline = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(0.0, h)])
		centre = Vector2(0.0, -s / 6.0)
		turns = 0
	var xf := Transform2D(rng.randi_range(0, 3) * PI * 0.5, centre)
	match rng.randi_range(0, 2):
		0:
			_plate(res, xf * PackedVector2Array([Vector2(-12.5, -4.0), Vector2(2.0, -4.0),
					Vector2(2.0, -12.5), Vector2(12.5, 0.0), Vector2(2.0, 12.5),
					Vector2(2.0, 4.0), Vector2(-12.5, 4.0)]), &"symbol")
		1:
			_plate(res, xf * _rect(Rect2(-12.5, -4.0, 25.0, 8.0)), &"symbol")
		_:
			for i in 12:
				var a0 := TAU * i / 12.0
				var a1 := TAU * (i + 1) / 12.0
				_plate(res, PackedVector2Array([Vector2.from_angle(a0) * 8.0 + centre,
						Vector2.from_angle(a0) * 12.5 + centre,
						Vector2.from_angle(a1) * 12.5 + centre,
						Vector2.from_angle(a1) * 8.0 + centre]), &"symbol")
	# The symbol plus a 30 cm stretch of the border below it, turned to a rolled side.
	var box := Rect2(-15.0, -h, 30.0, centre.y + 12.5 + h)
	var turn := Transform2D(turns * PI * 0.5, Vector2.ZERO)
	res.telling_box = Rect2(turn * box.position, Vector2.ZERO).expand(turn * box.end)
	return outline


static func _plate(res: Result, poly: PackedVector2Array, kind: StringName) -> void:
	res.plates.append(poly)
	res.plate_kinds.append(kind)


static func _rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])


static func _rounded(h: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for k in 4:
		var c: Vector2 = corners[k] * (h - Vector2(radius, radius))
		for i in 3:
			out.append(c + Vector2.from_angle((k + i * 0.5) * PI * 0.5) * radius)
	return out


## Each edge keeps 0.35..1.0 of its half size; a cut edge is a torch-rough polyline that
## never goes inside `keep`.
static func _cut(src: PackedVector2Array, dims: Vector2, keep: Rect2,
		rng: RandomNumberGenerator) -> PackedVector2Array:
	var h := dims * 0.5
	var far := 20.0
	var left := -h.x * rng.randf_range(KEEP_FRACTION.x, KEEP_FRACTION.y)
	var right := h.x * rng.randf_range(KEEP_FRACTION.x, KEEP_FRACTION.y)
	var bottom := -h.y * rng.randf_range(KEEP_FRACTION.x, KEEP_FRACTION.y)
	var top := h.y * rng.randf_range(KEEP_FRACTION.x, KEEP_FRACTION.y)
	if keep.has_area():
		left = minf(left, keep.position.x - JAG_MAX)
		right = maxf(right, keep.end.x + JAG_MAX)
		bottom = minf(bottom, keep.position.y - JAG_MAX)
		top = maxf(top, keep.end.y + JAG_MAX)
	var cut := [left > -h.x + 0.5, right < h.x - 0.5, bottom > -h.y + 0.5, top < h.y - 0.5]
	if not (cut[0] or cut[1] or cut[2] or cut[3]):
		return src
	var l := left if cut[0] else -h.x - far
	var r := right if cut[1] else h.x + far
	var b := bottom if cut[2] else -h.y - far
	var t := top if cut[3] else h.y + far
	var corners := [Vector2(l, b), Vector2(r, b), Vector2(r, t), Vector2(l, t)]
	var sides := [cut[2], cut[1], cut[3], cut[0]]
	var poly := PackedVector2Array()
	for i in 4:
		var a: Vector2 = corners[i]
		var c: Vector2 = corners[(i + 1) % 4]
		poly.append(a)
		if not sides[i]:
			continue
		var nrm := Vector2((c - a).y, -(c - a).x).normalized()
		var jags := rng.randi_range(1, 2)
		for j in jags:
			var t01 := (j + rng.randf_range(0.3, 0.7)) / jags
			var amp := rng.randf_range(JAG_MIN, JAG_MAX)
			if rng.randi_range(0, 1) == 0:
				amp = -amp
			poly.append(a.lerp(c, t01) + nrm * amp)
	var best := PackedVector2Array()
	var best_area := 0.0
	for part in Geometry2D.intersect_polygons(src, poly):
		var area := absf(_area(part))
		if area > best_area:
			best = part
			best_area = area
	if best.size() < 3:
		return src
	return _fit_points(best, keep)


## Drops the least visible vertices down to 9 (never one that would nick `keep`), pads to 5.
static func _fit_points(poly: PackedVector2Array, keep: Rect2) -> PackedVector2Array:
	var pts := poly.duplicate()
	var keep_poly := _rect(keep) if keep.has_area() else PackedVector2Array()
	while pts.size() > POINTS_MAX:
		var order: Array[int] = []
		var areas := {}
		for i in pts.size():
			order.append(i)
			areas[i] = absf((pts[(i + 1) % pts.size()] - pts[i]).cross(
					pts[(i + pts.size() - 1) % pts.size()] - pts[i]))
		order.sort_custom(func(a: int, b: int) -> bool: return areas[a] < areas[b])
		var dropped := false
		for i in order:
			var tri := PackedVector2Array([pts[(i + pts.size() - 1) % pts.size()], pts[i],
					pts[(i + 1) % pts.size()]])
			if not keep_poly.is_empty() \
					and not Geometry2D.intersect_polygons(tri, keep_poly).is_empty():
				continue
			pts.remove_at(i)
			dropped = true
			break
		if not dropped:
			break
	while pts.size() < POINTS_MIN:
		var at := 0
		var longest := 0.0
		for i in pts.size():
			var gap := pts[i].distance_to(pts[(i + 1) % pts.size()])
			if gap > longest:
				longest = gap
				at = i
		pts.insert(at + 1, pts[at].lerp(pts[(at + 1) % pts.size()], 0.5))
	return pts


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5
