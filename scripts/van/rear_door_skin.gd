extends RefCounted
## Rear door leaf as two pressed-steel skins: a flat outer plate on the street side and a cabin
## inner sheet with a raised frame, ribs, a pressing and rolled-lip holes (blind, the plate shows
## behind them). Hinge-local XY, +x toward the centre seam, z -half_t cabin to +half_t street.

const SHEET_T := 0.004
const PLATE_T := 0.02
## The street face stands back from the leaf mid-thickness so seals and the hull skin never share its plane.
const STREET_SETBACK := 0.04
const LIP_W := 0.03
const FRAME_W := 0.07
const RIB_W := 0.05
## Window centre in leaf-local x; the y comes from the caller.
const SLOT := Rect2(0.55, 1.18, 1.6, 0.14)
## Bottom panel hole, stepped on its seam side (image 1), then the scattered small holes (image 2).
const PANEL_HOLE: Array[Vector2] = [
	Vector2(0.40, -1.38), Vector2(1.85, -1.38), Vector2(1.90, -1.33), Vector2(1.90, -1.12),
	Vector2(1.68, -1.12), Vector2(1.68, -0.92), Vector2(1.46, -0.92), Vector2(1.46, -0.72),
	Vector2(0.45, -0.72), Vector2(0.35, -0.82), Vector2(0.35, -1.28),
]
## Pressed triangle by the seam, under the window's chamfer.
const TRIANGLE: Array[Vector2] = [Vector2(2.58, -0.30), Vector2(2.58, -0.90), Vector2(2.05, -0.90)]
## Small holes: centre, half size (round when equal), lip width.
const SMALL: Array[Vector3] = [
	Vector3(0.45, 1.415, 0.035), Vector3(1.0, 1.415, 0.035), Vector3(2.30, -1.12, 0.04),
	Vector3(2.30, -1.28, 0.04),
]
const SMALL_OVALS: Array[Rect2] = [Rect2(1.55, 1.395, 0.5, 0.04), Rect2(2.42, -1.38, 0.05, 0.3)]


## Builds the left leaf. `window` is the window outline around `window_c`.
static func build(x_max: float, y_lo: float, y_hi: float, half_t: float,
		window: PackedVector2Array, window_c: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z_cab := -half_t
	var z_sheet := -half_t + SHEET_T
	var z_sheet_back := -half_t + 2.0 * SHEET_T
	var z_street := half_t - STREET_SETBACK
	var z_plate_back := z_street - PLATE_T
	var rect := Rect2(0.0, y_lo, x_max, y_hi - y_lo)
	var win := PackedVector2Array()
	for p in window:
		win.append(p + window_c)
	# [outline, lip width, through both skins]
	var holes: Array = [[win, LIP_W, true], [_slot(), LIP_W, false],
			[PackedVector2Array(PANEL_HOLE), LIP_W, false]]
	for s in SMALL:
		holes.append([_oval(Vector2(s.x, s.y), s.z, s.z), 0.02, false])
	for r in SMALL_OVALS:
		holes.append([_oval(r.get_center(), r.size.x * 0.5, r.size.y * 0.5), 0.02, false])
	var outlines: Array = []
	for h in holes:
		outlines.append(h[0])

	# Outer plate (window hole only) and inner sheet (every hole).
	for poly in _pieces(rect, [win]):
		_poly(st, poly, z_street, Vector3.BACK)
		_poly(st, poly, z_plate_back, Vector3.FORWARD)
	for poly in _pieces(rect, outlines):
		_poly(st, poly, z_sheet, Vector3.FORWARD)
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)])
	_walls(st, corners, z_plate_back, z_street, false)

	for h in holes:
		var outline: PackedVector2Array = h[0]
		var ring := _ring(outline, h[1])
		var count := outline.size()
		for k in count:
			var n := (k + 1) % count
			_quad_xy(st, outline[k], outline[n], ring[n], ring[k], z_cab, Vector3.FORWARD)
		_walls(st, ring, z_cab, z_sheet, false)
		_walls(st, outline, z_cab, z_street if h[2] else z_sheet_back, true)

	# Perimeter frame reaches the plate, so the cavity is closed at the leaf edge.
	var f := FRAME_W
	for box in [Rect2(0.0, y_lo, f, y_hi - y_lo), Rect2(x_max - f, y_lo, f, y_hi - y_lo),
			Rect2(f, y_lo, x_max - 2.0 * f, f), Rect2(f, y_hi - f, x_max - 2.0 * f, f)]:
		_prism(st, _box(box), z_cab, z_plate_back)
	# Ribs between the hole groups: hinge stile, two horizontal.
	for rib in [Rect2(0.10, y_lo + f, RIB_W, y_hi - y_lo - 2.0 * f),
			Rect2(f, 1.07, x_max - 2.0 * f, RIB_W), Rect2(f, -0.655, 1.9, 0.04)]:
		_prism(st, _box(rib), z_cab, z_sheet)
	_prism(st, PackedVector2Array(TRIANGLE), z_cab, z_sheet)
	return st.commit()


static func _box(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])


static func _slot() -> PackedVector2Array:
	var c := SLOT.get_center()
	var hw := SLOT.size.x * 0.5
	var hh := SLOT.size.y * 0.5
	var pts := PackedVector2Array()
	for i in 7:
		var a := -PI * 0.5 + PI * float(i) / 6.0
		pts.append(c + Vector2(hw - hh + cos(a) * hh, sin(a) * hh))
	for i in 7:
		var a := PI * 0.5 + PI * float(i) / 6.0
		pts.append(c + Vector2(-hw + hh + cos(a) * hh, sin(a) * hh))
	return pts


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
