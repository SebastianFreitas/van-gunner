extends RefCounted
## Rear door leaf: a flat outer plate on the street side and, on the cabin side, an exposed welded
## skeleton (rear_door_skeleton.gd). Hinge-local XY, +x toward the centre seam, z cabin to street.

## Loaded at build time: the skeleton preloads this script for its mesh helpers.
const _SKELETON_PATH := "res://scripts/van/rear_door_skeleton.gd"

const PLATE_T := 0.02
## The street face stands back from the leaf's nominal plane so seals and the hull skin never share it.
const STREET_SETBACK := 0.04
## Outer corner radii: the top corner on the hinge side rolls like the portal's, the rest barely.
const CORNER_TOP := preload("res://scripts/van/rear_door_flange.gd").RADIUS_TOP
const CORNER := 0.05
## Height of the rolled window lip over the street face.
const WINDOW_LIP_H := 0.03


## Builds the left leaf. `window` is the window outline around `window_c`.
static func build(x_max: float, y_lo: float, y_hi: float, z_cab: float, z_street: float,
		window: PackedVector2Array, window_c: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z_plate_back := z_street - PLATE_T
	var rect := Rect2(0.0, y_lo, x_max, y_hi - y_lo)
	var win := PackedVector2Array()
	for p in window:
		win.append(p + window_c)
	var outline := leaf_outline(rect)
	for poly in _clip(_pieces(rect, [win]), outline):
		_poly(st, poly, z_street, Vector3.BACK)
		_poly(st, poly, z_plate_back, Vector3.FORWARD)
	_walls(st, outline, z_cab, z_street, false)
	# The window hole is a tunnel through the whole slab.
	_walls(st, win, z_cab, z_street, true)
	var skeleton := load(_SKELETON_PATH)
	skeleton.build(st, rect, win, z_cab, z_plate_back)
	# The street edge of the window is rolled like the skeleton's holes: a pressed lip standing
	# proud of the plate (under the dark WindowLip, whose face is 1.5 cm proud).
	skeleton._flange(st, win, z_street, z_street, z_street + WINDOW_LIP_H)
	return st.commit()


## The leaf's outline, counter-clockwise: rounded corners, the larger one top-left (hinge side).
static func leaf_outline(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [[r.position, CORNER, PI], [Vector2(r.end.x, r.position.y), CORNER, PI * 1.5],
			[r.end, CORNER, 0.0], [Vector2(r.position.x, r.end.y), CORNER_TOP, PI * 0.5]]
	for c in corners:
		var at: Vector2 = c[0]
		var rad: float = c[1]
		var sx := 1.0 if at.x == r.position.x else -1.0
		var sy := 1.0 if at.y == r.position.y else -1.0
		var mid := at + Vector2(sx * rad, sy * rad)
		for i in 6:
			var a: float = float(c[2]) + PI * 0.5 * float(i) / 5.0
			pts.append(mid + Vector2(cos(a), sin(a)) * rad)
	return pts


## Each polygon of `polys` cut to `outline` (the rounded leaf shape).
static func _clip(polys: Array, outline: PackedVector2Array) -> Array:
	var out: Array = []
	for p in polys:
		out.append_array(Geometry2D.intersect_polygons(p, outline))
	return out


static func _box(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])


## Octagon-ish round/oval with half sizes `hw`, `hh` (a stadium when they differ much).
static func _oval(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(c + Vector2(cos(a) * hw, sin(a) * hh))
	return pts


## Convex-ish pieces of `rect` minus the holes: the rect is cut along every hole's centre lines
## so each cell minus a hole is one simple polygon the triangulator can take.
static func _pieces(rect: Rect2, holes: Array) -> Array:
	var xs: Array[float] = [rect.position.x, rect.end.x]
	var ys: Array[float] = [rect.position.y, rect.end.y]
	var boxes: Array[Rect2] = []
	for h in holes:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p: Vector2 in h:
			lo = lo.min(p)
			hi = hi.max(p)
		boxes.append(Rect2(lo, hi - lo))
		xs.append((lo.x + hi.x) * 0.5)
		ys.append((lo.y + hi.y) * 0.5)
	xs.sort()
	ys.sort()
	var out: Array = []
	for i in xs.size() - 1:
		for j in ys.size() - 1:
			if xs[i + 1] - xs[i] < 0.001 or ys[j + 1] - ys[j] < 0.001:
				continue
			var cell := Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			var polys: Array = [_box(cell)]
			for k in holes.size():
				if not boxes[k].intersects(cell):
					continue
				var next: Array = []
				for p in polys:
					next.append_array(Geometry2D.clip_polygons(p, holes[k]))
				polys = next
			out.append_array(polys)
	return out


## Outline offset by `d` away from the hole interior, mitred, same vertex count.
static func _ring(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var count := poly.size()
	var pts := PackedVector2Array()
	for i in count:
		var p := poly[(i + count - 1) % count]
		var v := poly[i]
		var q := poly[(i + 1) % count]
		var n1 := _out_normal(poly, p, v)
		var n2 := _out_normal(poly, v, q)
		var m := (n1 + n2).normalized()
		pts.append(v + m * d / maxf(m.dot(n1), 0.5))
	return pts


static func _out_normal(poly: PackedVector2Array, a: Vector2, b: Vector2) -> Vector2:
	var seg := b - a
	var n := Vector2(seg.y, -seg.x).normalized()
	if Geometry2D.is_point_in_polygon((a + b) * 0.5 + n * 0.003, poly):
		n = -n
	return n


## Vertical strips on every edge of `poly` between z0 and z1; `inward` faces the polygon's inside
## (a hole wall), else away from it.
static func _walls(st: SurfaceTool, poly: PackedVector2Array, z0: float, z1: float,
		inward: bool) -> void:
	var count := poly.size()
	for k in count:
		var a := poly[k]
		var b := poly[(k + 1) % count]
		var n := _out_normal(poly, a, b)
		if inward:
			n = -n
		_tri(st, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1),
				Vector3(n.x, n.y, 0.0))
		_tri(st, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1),
				Vector3(n.x, n.y, 0.0))


## Convex prism: top face at z_top facing the cabin, sides down to z_bot, no bottom.
static func _prism(st: SurfaceTool, poly: PackedVector2Array, z_top: float, z_bot: float) -> void:
	_poly(st, poly, z_top, Vector3.FORWARD)
	_walls(st, poly, z_top, z_bot, false)


static func _quad_xy(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2, z: float,
		out: Vector3) -> void:
	_tri(st, Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(c.x, c.y, z), out)
	_tri(st, Vector3(a.x, a.y, z), Vector3(c.x, c.y, z), Vector3(d.x, d.y, z), out)


static func _poly(st: SurfaceTool, poly: PackedVector2Array, z: float, out: Vector3) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for t in int(idx.size() / 3.0):
		var a := poly[idx[t * 3]]
		var b := poly[idx[t * 3 + 1]]
		var c := poly[idx[t * 3 + 2]]
		_tri(st, Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(c.x, c.y, z), out)


## Godot front faces are clockwise seen from outside, so flip any triangle that isn't.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var second := b
	var third := c
	if (c - a).cross(b - a).dot(out) < 0.0:
		second = c
		third = b
	for p in [a, second, third]:
		st.set_normal(out)
		st.add_vertex(p)
