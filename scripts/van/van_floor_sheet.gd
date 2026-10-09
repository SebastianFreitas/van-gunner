class_name VanFloorSheet
extends RefCounted
## Builders for the ribbed rear floor sheet: trapezoid rib segments and the scalloped wall lips.

const RIB_BASE := 0.10
const RIB_TOP := 0.06
const RIB_HEIGHT := 0.02
## The rib base sinks this far under its host's top so no gap shows.
const RIB_SINK := 0.005
const LIP_X0 := 3.24
const LIP_X1 := 3.36
const LIP_DROP := 0.02
const LIP_RISE := 0.03
const SCALLOP_PITCH := 0.25
const SCALLOP_WIDTH := 0.06
const SCALLOP_DEPTH := 0.015
## Pocket floor at y -0.10 under the sheet top at 0.
const POCKET_DEPTH := 0.10
const RIM_WIDTH := 0.04
## Half-circle steps at each rib end.
const ROUND_STEPS := 6


## Appends one closed trapezoid rib (any yaw) from `start` to `end` (xz) onto a host with top `host_top`.
static func add_rib(st: SurfaceTool, start: Vector2, end: Vector2, host_top: float) -> void:
	var dir := (end - start).normalized()
	var side := Vector2(-dir.y, dir.x)
	var yb := host_top - RIB_SINK
	var yt := host_top + RIB_HEIGHT
	# Each end is a half turn of the profile about a centre one base radius in from the tip, so
	# the footprint stays inside start..end. rings[0] sweeps -side > back > +side, rings[1] the other way.
	var rb := RIB_BASE * 0.5
	var rt := RIB_TOP * 0.5
	var ctr: Array[Vector2] = [start + dir * rb, end - dir * rb]
	var base: Array[Array] = [[], []]
	var top: Array[Array] = [[], []]
	for e in 2:
		var sgn := -1.0 if e == 0 else 1.0
		for i in ROUND_STEPS + 1:
			var phi := PI * float(i) / float(ROUND_STEPS)
			var o := (side * cos(phi) + dir * sin(phi)) * sgn
			var pb := ctr[e] + o * rb
			var pt := ctr[e] + o * rt
			base[e].append(Vector3(pb.x, yb, pb.y))
			top[e].append(Vector3(pt.x, yt, pt.y))
	VanFloorSkin.set_tag(st, &"crest")
	# Straight run: +side is end 0's last point and end 1's first, -side the reverse.
	_quad(st, top[0][ROUND_STEPS], top[1][0], top[1][ROUND_STEPS], top[0][0], Vector3.UP)
	for e in 2:
		var fan: Array[Vector3] = [Vector3(ctr[e].x, yt, ctr[e].y)]
		for p in top[e]:
			fan.append(p)
		_fan(st, fan, Vector3.UP)
	VanFloorSkin.set_tag(st, &"edge")
	var left := Vector3(side.x, 0.0, side.y)
	_quad(st, base[0][ROUND_STEPS], top[0][ROUND_STEPS], top[1][0], base[1][0], left + Vector3.UP * 0.5)
	_quad(st, base[0][0], top[0][0], top[1][ROUND_STEPS], base[1][ROUND_STEPS],
			left * -1.0 + Vector3.UP * 0.5)
	for e in 2:
		for i in ROUND_STEPS:
			var mid := (Vector3(base[e][i].x + base[e][i + 1].x, 0.0, base[e][i].z + base[e][i + 1].z)
					* 0.5 - Vector3(ctr[e].x, 0.0, ctr[e].y))
			_quad(st, base[e][i], top[e][i], top[e][i + 1], base[e][i + 1], mid + Vector3.UP * 0.5)


## A wall lip strip on one side (-1 left, +1 right) from z0 to z1, with a half-cup scallop
## cut into its top inner edge every 0.25 m.
static func build_lip(side_sign: float, z0: float, z1: float, host_top: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0 := host_top - LIP_DROP
	var y1 := host_top + LIP_RISE
	var y_cut := y1 - SCALLOP_DEPTH
	var xa := minf(side_sign * LIP_X0, side_sign * LIP_X1)
	var xb := maxf(side_sign * LIP_X0, side_sign * LIP_X1)
	var xm := side_sign * (LIP_X0 + LIP_X1) * 0.5
	_box(st, Vector3(xa, y0, z0), Vector3(xb, y_cut, z1), false)
	var cursor := z0
	var zc := z0 + SCALLOP_PITCH * 0.5
	while zc + SCALLOP_WIDTH * 0.5 <= z1:
		_box(st, Vector3(xa, y_cut, cursor), Vector3(xb, y1, zc - SCALLOP_WIDTH * 0.5), true)
		# Outer half of the notch stays; the inner half is the cup.
		_box(st, Vector3(minf(xm, side_sign * LIP_X1), y_cut, zc - SCALLOP_WIDTH * 0.5),
				Vector3(maxf(xm, side_sign * LIP_X1), y1, zc + SCALLOP_WIDTH * 0.5), true)
		cursor = zc + SCALLOP_WIDTH * 0.5
		zc += SCALLOP_PITCH
	_box(st, Vector3(xa, y_cut, cursor), Vector3(xb, y1, z1), true)
	st.generate_tangents()
	return st.commit()


## The rear sheet box (x0..x1, z0..z1, y0..y1) whose top has each convex `pockets` polygon (world xz)
## cut out: walls down to POCKET_FLOOR tagged `cavity`, a 4 cm `edge` ring around each rim, the rest
## `top`. The top is cut into z bands at every grown rim vertex so each piece is a convex trapezoid,
## and every shared edge carries the same points, so no T-junction cracks open.
static func build_sheet(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float,
		pockets: Array[PackedVector2Array]) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(x0, y0, z0)
	var b := Vector3(x1, y0, z0)
	var c := Vector3(x1, y0, z1)
	var d := Vector3(x0, y0, z1)
	var e := Vector3(x0, y1, z0)
	var f := Vector3(x1, y1, z0)
	var g := Vector3(x1, y1, z1)
	var h := Vector3(x0, y1, z1)
	VanFloorSkin.set_tag(st, &"edge")
	_quad(st, a, b, c, d, Vector3.DOWN)
	_quad(st, a, d, h, e, Vector3.LEFT)
	_quad(st, b, c, g, f, Vector3.RIGHT)
	_quad(st, a, b, f, e, Vector3.FORWARD)
	_quad(st, d, c, g, h, Vector3.BACK)

	var grown: Array[PackedVector2Array] = []
	var zs: Array[float] = [z0, z1]
	for poly in pockets:
		var ring := _grow(poly, RIM_WIDTH)
		grown.append(ring)
		for p in ring:
			if p.y > z0 + 1e-5 and p.y < z1 - 1e-5:
				zs.append(p.y)
	zs.sort()

	VanFloorSkin.set_tag(st, &"top")
	for k in range(zs.size() - 1):
		_top_band(st, x0, x1, zs[k], zs[k + 1], y1, grown)

	for i in range(pockets.size()):
		_pocket(st, pockets[i], grown[i], zs, y1)
	st.generate_tangents()
	return st.commit()


## `poly` pushed out by `dist` with mitered corners (convex polygon, any winding).
static func _grow(poly: PackedVector2Array, dist: float) -> PackedVector2Array:
	var sgn := 1.0 if Geometry2D.is_polygon_clockwise(poly) else -1.0
	var out := PackedVector2Array()
	var n := poly.size()
	for i in range(n):
		var e0 := (poly[i] - poly[(i + n - 1) % n]).normalized()
		var e1 := (poly[(i + 1) % n] - poly[i]).normalized()
		var n0 := Vector2(-e0.y, e0.x) * sgn
		var n1 := Vector2(-e1.y, e1.x) * sgn
		out.append(poly[i] + (n0 + n1) * (dist / (1.0 + n0.dot(n1))))
	return out


## x extent (min, max) of convex `ring` on the line z; (INF, -INF) when it does not reach it.
static func _span(ring: PackedVector2Array, z: float) -> Vector2:
	var r := Vector2(INF, -INF)
	for i in range(ring.size()):
		var p := ring[i]
		var q := ring[(i + 1) % ring.size()]
		if (p.y - z) * (q.y - z) > 0.0:
			continue
		var xs: Array[float] = [p.x, q.x]
		if absf(p.y - q.y) > 1e-9:
			xs = [p.x + (q.x - p.x) * (z - p.y) / (q.y - p.y)]
		for x in xs:
			r = Vector2(minf(r.x, x), maxf(r.y, x))
	return r


## One z band of the top: trapezoids between the pockets' spans, each edge carrying the rim
## vertices that lie on it.
static func _top_band(st: SurfaceTool, x0: float, x1: float, za: float, zb: float, y: float,
		grown: Array[PackedVector2Array]) -> void:
	if zb - za < 1e-5:
		return
	var zm := (za + zb) * 0.5
	var cuts: Array[Array] = []
	for ring in grown:
		var sm := _span(ring, zm)
		if sm.x <= sm.y:
			cuts.append([sm.x, _span(ring, za), _span(ring, zb)])
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var ca := x0
	var cb := x0
	for cut in cuts:
		var sa: Vector2 = cut[1]
		var sb: Vector2 = cut[2]
		_top_piece(st, ca, sa.x, cb, sb.x, za, zb, y, grown)
		ca = sa.y
		cb = sb.y
	_top_piece(st, ca, x1, cb, x1, za, zb, y, grown)


## Convex piece from x range (xa0, xa1) at za and (xb0, xb1) at zb, fanned into triangles.
static func _top_piece(st: SurfaceTool, xa0: float, xa1: float, xb0: float, xb1: float,
		za: float, zb: float, y: float, grown: Array[PackedVector2Array]) -> void:
	var pts: Array[Vector3] = []
	_edge_points(pts, xa0, xa1, za, y, grown)
	_edge_points(pts, xb1, xb0, zb, y, grown)
	_fan(st, pts, Vector3.UP)


## Appends the points of one horizontal piece edge from xs to xe at z, plus every rim vertex on it.
static func _edge_points(pts: Array[Vector3], xs: float, xe: float, z: float, y: float,
		grown: Array[PackedVector2Array]) -> void:
	var xl: Array[float] = []
	for ring in grown:
		for p in ring:
			if absf(p.y - z) < 1e-5 and (p.x - xs) * (p.x - xe) < -1e-10:
				xl.append(p.x)
	xl.sort()
	if xe < xs:
		xl.reverse()
	xl.push_front(xs)
	xl.append(xe)
	for x in xl:
		if pts.is_empty() or pts[pts.size() - 1].distance_to(Vector3(x, y, z)) > 1e-5:
			pts.append(Vector3(x, y, z))


## One pocket: the rim ring between `poly` and `ring`, the walls and the floor.
static func _pocket(st: SurfaceTool, poly: PackedVector2Array, ring: PackedVector2Array,
		zs: Array[float], y: float) -> void:
	var n := poly.size()
	var yf := y - POCKET_DEPTH
	var mid := Vector2.ZERO
	for p in poly:
		mid += p / float(n)
	# The rim ring is tagged cavity too, so the hole's mouth reads black from above.
	VanFloorSkin.set_tag(st, &"cavity")
	for i in range(n):
		var j := (i + 1) % n
		var pts: Array[Vector3] = [Vector3(poly[i].x, y, poly[i].y), Vector3(poly[j].x, y, poly[j].y),
				Vector3(ring[j].x, y, ring[j].y)]
		# Outer edge walks from ring[j] back to ring[i], through every band z that crosses it.
		var span := ring[i].y - ring[j].y
		var cross: Array[float] = []
		for z in zs:
			var t := (z - ring[j].y) / span if absf(span) > 1e-9 else -1.0
			if t > 1e-5 and t < 1.0 - 1e-5:
				cross.append(t)
		cross.sort()
		for t in cross:
			var q := ring[j].lerp(ring[i], t)
			pts.append(Vector3(q.x, y, q.y))
		pts.append(Vector3(ring[i].x, y, ring[i].y))
		_fan(st, pts, Vector3.UP)
	VanFloorSkin.set_tag(st, &"cavity")
	for i in range(n):
		var j := (i + 1) % n
		var inward := mid - (poly[i] + poly[j]) * 0.5
		_quad(st, Vector3(poly[i].x, y, poly[i].y), Vector3(poly[j].x, y, poly[j].y),
				Vector3(poly[j].x, yf, poly[j].y), Vector3(poly[i].x, yf, poly[i].y),
				Vector3(inward.x, 0.0, inward.y))
	var floor_pts: Array[Vector3] = []
	for p in poly:
		floor_pts.append(Vector3(p.x, yf, p.y))
	_fan(st, floor_pts, Vector3.UP)


## Fans a convex point loop from its first point; each triangle faces `out`, wound clockwise.
static func _fan(st: SurfaceTool, pts: Array[Vector3], out: Vector3) -> void:
	for k in range(1, pts.size() - 1):
		var tri: Array[Vector3] = [pts[0], pts[k], pts[k + 1]]
		var n := (tri[2] - tri[1]).cross(tri[1] - tri[0])
		if n.length() < 1e-9:
			continue
		if n.dot(out) < 0.0:
			tri = [tri[0], tri[2], tri[1]]
			n = -n
		n = n.normalized()
		for p in tri:
			st.set_normal(n)
			st.set_uv(Vector2(p.x + p.z, p.y + p.z * 0.5))
			st.add_vertex(p)


## Appends a closed box; `skip_bottom` drops the underside where another box sits below.
static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, skip_bottom: bool) -> void:
	if hi.z - lo.z < 0.001:
		return
	var a := Vector3(lo.x, lo.y, lo.z)
	var b := Vector3(hi.x, lo.y, lo.z)
	var c := Vector3(hi.x, lo.y, hi.z)
	var d := Vector3(lo.x, lo.y, hi.z)
	var e := Vector3(lo.x, hi.y, lo.z)
	var f := Vector3(hi.x, hi.y, lo.z)
	var g := Vector3(hi.x, hi.y, hi.z)
	var h := Vector3(lo.x, hi.y, hi.z)
	VanFloorSkin.set_tag(st, &"top")
	_quad(st, e, f, g, h, Vector3.UP)
	VanFloorSkin.set_tag(st, &"edge")
	if not skip_bottom:
		_quad(st, a, b, c, d, Vector3.DOWN)
	_quad(st, a, d, h, e, Vector3.LEFT)
	_quad(st, b, c, g, f, Vector3.RIGHT)
	_quad(st, a, b, f, e, Vector3.FORWARD)
	_quad(st, d, c, g, h, Vector3.BACK)


## Adds a quad facing away from the box or rib interior (`out` is only a hint), wound clockwise.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		out: Vector3) -> void:
	var n := (c - b).cross(b - a).normalized()
	var pts: Array[Vector3] = [a, b, c, d]
	if n.dot(out) < 0.0:
		pts = [d, c, b, a]
		n = -n
	for k in [0, 1, 2, 0, 2, 3]:
		var p := pts[k]
		st.set_normal(n)
		st.set_uv(Vector2(p.x + p.z, p.y + p.z * 0.5))
		st.add_vertex(p)
