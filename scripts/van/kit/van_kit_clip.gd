class_name VanKitClip
extends RefCounted
## Cuts keep-out blockers out of an outline in surface cm, so a skin never covers a volume.

const MAX_DEPTH := 8
## Pieces under this area (cm^2) are dropped.
const MIN_AREA := 100.0
## How far (cm) a blocker's footprint grows before it is subtracted.
const GROW_CM := 3.0
## Kinds on a leaf surface test as this prefix + kind: the keep-out exempts them from the swing.
const LEAF_PREFIX := "leaf:"


## The pieces of `poly_cm` the keep-out allows for `kind` at `depth_m` off the liner.
static func cut(keep_out: VanKitKeepOut, surface: StringName, poly_cm: PackedVector2Array,
		depth_m: float, kind: StringName) -> Array[PackedVector2Array]:
	VanKitSurface.walls = keep_out.walls
	var test := kind
	if VanKitSurface.is_leaf(surface):
		test = StringName(LEAF_PREFIX + String(kind))
	var out: Array[PackedVector2Array] = []
	_cut(keep_out, surface, poly_cm, depth_m, test, 0, out)
	return out


static func _cut(keep_out: VanKitKeepOut, surface: StringName, poly: PackedVector2Array,
		depth: float, kind: StringName, level: int, out: Array[PackedVector2Array]) -> void:
	if poly.size() < 3 or absf(_area(poly)) < MIN_AREA:
		return
	var box := _box(surface, poly, depth)
	if keep_out.allows(box, kind):
		out.append(poly)
		return
	if level >= MAX_DEPTH:
		return
	var block := keep_out.blocker_box(box, kind)
	var hole := _project(surface, block)
	var pieces := Geometry2D.clip_polygons(poly, hole)
	if not _changed(pieces, poly):
		pieces = _split(poly, hole)
	for piece in pieces:
		_cut(keep_out, surface, piece, depth, kind, level + 1, out)


static func _changed(pieces: Array[PackedVector2Array], poly: PackedVector2Array) -> bool:
	# A blocker inside the poly leaves a hole polygon (clockwise): no simple piece, so split.
	for piece in pieces:
		if Geometry2D.is_polygon_clockwise(piece):
			return false
	if pieces.size() != 1:
		return true
	return absf(absf(_area(pieces[0])) - absf(_area(poly))) > 1e-3


## Van-space AABB of the poly at `depth` (leaf polys convert with the closed leaf).
static func _box(surface: StringName, poly: PackedVector2Array, depth: float) -> AABB:
	var box := AABB()
	var first := true
	var shift := VanKitSurface.hinge_origin(surface) if VanKitSurface.is_leaf(surface) \
			else Vector3.ZERO
	for p in poly:
		for d: float in [0.0, depth]:
			var v := VanKitSurface.point(surface, p.x, p.y, d) + shift
			if first:
				box = AABB(v, Vector3.ZERO)
				first = false
			else:
				box = box.expand(v)
	return box


## The blocker's footprint on the surface, grown GROW_CM, as a rectangle in surface cm.
static func _project(surface: StringName, block: AABB) -> PackedVector2Array:
	var shift := VanKitSurface.hinge_origin(surface) if VanKitSurface.is_leaf(surface) \
			else Vector3.ZERO
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var v := block.get_endpoint(i) - shift
		var ab := _ab(surface, v)
		lo = lo.min(ab)
		hi = hi.max(ab)
	lo -= Vector2.ONE * GROW_CM
	hi += Vector2.ONE * GROW_CM
	return PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])


## Surface cm (a, b) of a point; the inverse of VanKitSurface.point along the normal.
static func _ab(surface: StringName, v: Vector3) -> Vector2:
	match surface:
		VanKitSurface.LEFT_WALL, VanKitSurface.RIGHT_WALL:
			return Vector2(v.z, v.y) * 100.0
		VanKitSurface.FLOOR, VanKitSurface.CEILING:
			return Vector2(v.z, v.x) * 100.0
		VanKitSurface.LEFT_LEAF:
			return Vector2(v.x - 1.19, v.y) * 100.0
		VanKitSurface.RIGHT_LEAF:
			return Vector2(v.x + 1.19, v.y) * 100.0
	return Vector2(v.x, v.y) * 100.0


## Splits the poly in two at the blocker's centre across the poly's long axis.
static func _split(poly: PackedVector2Array, hole: PackedVector2Array) -> Array[PackedVector2Array]:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var centre := (hole[0] + hole[2]) * 0.5
	var out: Array[PackedVector2Array] = []
	var along_x := hi.x - lo.x >= hi.y - lo.y
	var cut_at := centre.x if along_x else centre.y
	var span_lo := lo.x if along_x else lo.y
	var span_hi := hi.x if along_x else hi.y
	if cut_at <= span_lo or cut_at >= span_hi:
		cut_at = (span_lo + span_hi) * 0.5
	var halves: Array[PackedVector2Array] = []
	if along_x:
		halves.append(_rect(lo, Vector2(cut_at, hi.y)))
		halves.append(_rect(Vector2(cut_at, lo.y), hi))
	else:
		halves.append(_rect(lo, Vector2(hi.x, cut_at)))
		halves.append(_rect(Vector2(lo.x, cut_at), hi))
	for half in halves:
		for part in Geometry2D.intersect_polygons(poly, half):
			out.append(part)
	return out


static func _rect(lo: Vector2, hi: Vector2) -> PackedVector2Array:
	return PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5
