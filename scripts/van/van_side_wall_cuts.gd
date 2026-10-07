class_name VanSideWallCuts
extends RefCounted
## The side windows' wall holes: the rolled per-wall outlines the kit fit hands in (or the
## fixed WINDOW_CUT_POLY when none), and the point queries that punch the panel cells with them.

## How far the hole grows past the rolled opening, in cm.
const HOLE_GROW_CM := 2.0

var wall: Node3D  # the VanSideWall; reads its window exports when called
## Vector2i(wall sign, window index) -> hole outline, metres, offsets from the window centre.
var _holes: Dictionary = {}


func _init(owner: Node3D) -> void:
	wall = owner


## Takes the donor set's window entries (side ones only matter); an empty array is the fixed cut.
func set_holes(windows: Array) -> void:
	_holes.clear()
	for entry: Dictionary in windows:
		var surface: StringName = entry[&"surface"]
		if surface != &"left_wall" and surface != &"right_wall":
			continue
		var opening: PackedVector2Array = entry[&"opening"]
		var grown := Geometry2D.offset_polygon(opening, HOLE_GROW_CM, Geometry2D.JOIN_MITER)
		if grown.is_empty():
			continue
		var mid_z := 0.0
		for p in opening:
			mid_z += p.x / float(opening.size())
		var idx := _index_for(mid_z * 0.01)
		var cz: float = wall.window_centers_z[idx]
		var local := PackedVector2Array()
		for p in grown[0]:
			local.append(Vector2(p.x * 0.01 - cz, p.y * 0.01 - wall.window_center_y))
		_holes[Vector2i(-1 if surface == &"left_wall" else 1, idx)] = local


## The hole of the window centred near cz on this wall.
func cut_poly_for(wall_sign: float, cz: float) -> PackedVector2Array:
	return _poly(wall_sign, _index_for(cz))


## The wall's z extent (min, max) of window idx's hole, world z.
func z_range(wall_sign: float, idx: int) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in _poly(wall_sign, idx):
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	var cz: float = wall.window_centers_z[idx]
	return Vector2(cz + lo, cz + hi)


## Belt rail spans on this wall: between its window holes and the door bay, 3 cm off each.
func solid_ranges_mid(wall_sign: float) -> Array:
	var half: float = wall.span_z * 0.5
	var gaps: Array = []
	for i in wall.window_centers_z.size():
		var zr := z_range(wall_sign, i)
		gaps.append([zr.x, zr.y])
	gaps.append([wall.door_center_z - wall.door_half_length, wall.door_center_z + wall.door_half_length])
	gaps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var ranges: Array = []
	var cursor := -half + 0.1
	for gap in gaps:
		var c0: float = gap[0]
		var c1: float = gap[1]
		if c0 > cursor + 0.3:
			ranges.append([cursor, c0 - 0.03])
		cursor = maxf(cursor, c1 + 0.03)
	if cursor < half - 0.4:
		ranges.append([cursor, half - 0.1])
	return ranges


func in_window_cut(wall_sign: float, y: float, z: float) -> bool:
	for i in wall.window_centers_z.size():
		var local := Vector2(z - wall.window_centers_z[i], y - wall.window_center_y)
		if wall.point_in_poly(local, _poly(wall_sign, i)):
			return true
	return false


## Only punch a wall cell when every corner is inside the rounded cut: keeps
## liner metal under the frame lip the way the rear door panel surrounds its pane.
func cell_fully_in_window_cut(wall_sign: float, y0: float, y1: float, z0: float, z1: float) -> bool:
	return (
		in_window_cut(wall_sign, y0, z0)
		and in_window_cut(wall_sign, y0, z1)
		and in_window_cut(wall_sign, y1, z0)
		and in_window_cut(wall_sign, y1, z1)
	)


## Returns Vector2(world_y, world_z) on the nearest window cut edge.
func nearest_on_window_cut(wall_sign: float, y: float, z: float) -> Vector2:
	var best := Vector2(y, z)
	var best_d := INF
	for i in wall.window_centers_z.size():
		var cz: float = wall.window_centers_z[i]
		var local := Vector2(z - cz, y - wall.window_center_y)
		var poly := _poly(wall_sign, i)
		var n := poly.size()
		for k in range(n):
			var a: Vector2 = poly[k]
			var b: Vector2 = poly[(k + 1) % n]
			var ab := b - a
			var t := 0.0
			var denom := ab.dot(ab)
			if denom > 0.0000001:
				t = clampf((local - a).dot(ab) / denom, 0.0, 1.0)
			var q := a.lerp(b, t)
			var d := local.distance_squared_to(q)
			if d < best_d:
				best_d = d
				best = Vector2(wall.window_center_y + q.y, cz + q.x)
	return best


func _poly(wall_sign: float, idx: int) -> PackedVector2Array:
	return _holes.get(Vector2i(int(signf(wall_sign)), idx), wall.WINDOW_CUT_POLY)


func _index_for(cz: float) -> int:
	var best := 0
	for i in wall.window_centers_z.size():
		if absf(wall.window_centers_z[i] - cz) < absf(wall.window_centers_z[best] - cz):
			best = i
	return best
