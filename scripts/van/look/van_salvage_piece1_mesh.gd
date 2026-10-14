extends RefCounted
## Salvage piece 1, mesh emitters: bevelled prisms and flat quads and triangles into one SurfaceTool.

const _Surround := preload("res://scripts/van/rear_door_surround.gd")

var st := SurfaceTool.new()
## Set while building: quads (as point arrays) it accepts are replaced by a pressed sheet.
var skip := Callable()


## Starts a fresh triangle list.
func begin() -> void:
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


## Extrudes `poly` (u, v) along w from w0 to w1 through axis map `m`; a bevelled end rings in
## quarter-arc steps over BEVEL.
func solid(poly: PackedVector2Array, m: Basis, w0: float, w1: float, bev0: bool,
		bev1: bool) -> void:
	var bev := _Surround.BEVEL
	var steps := _Surround.BEVEL_STEPS
	var rings: Array = []
	if bev0:
		for k in range(steps + 1):
			var th := PI * 0.5 * float(k) / float(steps)
			rings.append([_inset(poly, bev * (1.0 - sin(th))), w0 + bev * (1.0 - cos(th))])
	else:
		rings.append([poly, w0])
	if bev1:
		for k in range(steps, -1, -1):
			var th2 := PI * 0.5 * float(k) / float(steps)
			rings.append([_inset(poly, bev * (1.0 - sin(th2))), w1 - bev * (1.0 - cos(th2))])
	else:
		rings.append([poly, w1])
	var sign_a := 1.0 if _area(poly) > 0.0 else -1.0
	for end in 2:
		var ring: Array = rings[0] if end == 0 else rings[rings.size() - 1]
		var rp: PackedVector2Array = ring[0]
		var idx := Geometry2D.triangulate_polygon(rp)
		var cap_n := (m * Vector3(0, 0, -1 if end == 0 else 1)).normalized()
		for i in range(0, idx.size(), 3):
			tri(pt(m, rp[idx[i]], ring[1]), pt(m, rp[idx[i + 1]], ring[1]),
					pt(m, rp[idx[i + 2]], ring[1]), cap_n)
	for r in range(rings.size() - 1):
		var pa: PackedVector2Array = rings[r][0]
		var pb: PackedVector2Array = rings[r + 1][0]
		var wa: float = rings[r][1]
		var wb: float = rings[r + 1][1]
		for i in pa.size():
			var j := (i + 1) % pa.size()
			var e := poly[j] - poly[i]
			if e.length() < 0.0001:
				continue
			var ref := (m * Vector3(e.y, -e.x, 0.0)) * sign_a
			var a0 := pt(m, pa[i], wa)
			var b0 := pt(m, pa[j], wa)
			var b1 := pt(m, pb[j], wb)
			var a1 := pt(m, pb[i], wb)
			if skip.is_valid() and skip.call([a0, b0, b1, a1]):
				continue
			quad(a0, b0, b1, a1, ref)


func pt(m: Basis, p: Vector2, w: float) -> Vector3:
	return m * Vector3(p.x, p.y, w)


## Two triangles a-b-c-d with their own flat normal, flipped to face along `ref`.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ref: Vector3) -> void:
	for t: Array in [[a, b, c], [a, c, d]]:
		var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0])
		if n.length() < 0.000001:
			continue
		n = n.normalized()
		if n.dot(ref) < 0.0:
			n = -n
		tri(t[0], t[1], t[2], n)


## One flat triangle, wound clockwise seen from `out` (Godot's front).
func tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var v: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(out) > 0.0:
		v = [a, c, b]
	for p in v:
		st.set_normal(out)
		st.set_uv(Vector2(p.x / VanInteriorSize.LENGTH + 0.5, p.y / VanInteriorSize.WALL_HEIGHT))
		st.add_vertex(p)


## One triangle with per-vertex normals, wound clockwise seen from their sum (as rear_door_ramp._tri).
func tri_n(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var v: Array[Vector3] = [a, b, c]
	var nn: Array[Vector3] = [na, nb, nc]
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		v = [a, c, b]
		nn = [na, nc, nb]
	for k in 3:
		st.set_normal(nn[k])
		st.set_uv(Vector2(v[k].x / VanInteriorSize.LENGTH + 0.5, v[k].y / VanInteriorSize.WALL_HEIGHT))
		st.add_vertex(v[k])


## Outline moved inward by `d` along each corner's miter.
func _inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	if d <= 0.0:
		return poly
	var sign_a := 1.0 if _area(poly) > 0.0 else -1.0
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var e0 := (poly[i] - poly[(i + n - 1) % n]).normalized()
		var e1 := (poly[(i + 1) % n] - poly[i]).normalized()
		var n0 := Vector2(-e0.y, e0.x) * sign_a
		var n1 := Vector2(-e1.y, e1.x) * sign_a
		out.append(poly[i] + (n0 + n1) / maxf(1.0 + n0.dot(n1), 0.2) * d)
	return out


func _area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return area
