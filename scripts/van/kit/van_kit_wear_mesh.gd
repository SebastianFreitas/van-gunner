class_name VanKitWearMesh
extends RefCounted
## Geometry of the kit's fastenings: weld bead ridges, bolt heads and tie-wire tubes, added to a
## SurfaceTool in the frame the points are given in. Backs stay open (sunk into the host).


## A gable ridge from `a` to `b` standing on a face with normal `n`: base `base_w` wide
## straddling the line, crest `crest` over the face, sunk 3 mm; ends closed.
static func bead(st: SurfaceTool, a: Vector3, b: Vector3, n: Vector3, base_w: float,
		crest: float) -> void:
	var e := (b - a).normalized()
	var side := n.cross(e).normalized() * (base_w * 0.5)
	var up := n * crest
	var sink := -n * 0.003
	var al := a + side + sink
	var ar := a - side + sink
	var ac := a + up
	var bl := b + side + sink
	var br := b - side + sink
	var bc := b + up
	_tri(st, al, bl, bc, (up + side).normalized())
	_tri(st, al, bc, ac, (up + side).normalized())
	_tri(st, ar, br, bc, (up - side).normalized())
	_tri(st, ar, bc, ac, (up - side).normalized())
	_tri(st, al, ac, ar, -e)
	_tri(st, bl, bc, br, e)


## A bolt head (`sides` 4 = square, 6 = hex) `across` wide at `at` on a face with normal `n`,
## sunk 3 mm and standing `proud` over it; the back is left open.
static func head(st: SurfaceTool, at: Vector3, n: Vector3, tangent: Vector3, sides: int,
		across: float, proud: float) -> void:
	var u := (tangent - n * tangent.dot(n)).normalized()
	var v := n.cross(u)
	var radius := across * 0.5 / cos(PI / sides)
	var turn := PI / sides if sides == 4 else 0.0
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for i in sides:
		var ang := TAU * i / sides + turn
		var rim := u * cos(ang) * radius + v * sin(ang) * radius
		lo.append(at + rim - n * 0.003)
		hi.append(at + rim + n * proud)
	for i in sides:
		var j := (i + 1) % sides
		var out := ((lo[i] + lo[j]) * 0.5 - at + n * 0.003).normalized()
		_tri(st, lo[i], lo[j], hi[j], out)
		_tri(st, lo[i], hi[j], hi[i], out)
		_tri(st, hi[0], hi[i], hi[j], n)


## A tube of `radius` with `sides` sides along `pts` (at least two), ends capped.
static func tube(st: SurfaceTool, pts: Array[Vector3], radius: float, sides: int) -> void:
	var rings: Array[Array] = []
	var u := Vector3.ZERO
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if i == 0:
			u = t.cross(Vector3.UP if absf(t.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT)
		u = (u - t * u.dot(t)).normalized()
		var v := t.cross(u)
		var ring: Array[Vector3] = []
		for k in sides:
			var ang := TAU * k / sides
			ring.append(pts[i] + (u * cos(ang) + v * sin(ang)) * radius)
		rings.append(ring)
	for i in pts.size() - 1:
		for k in sides:
			var j := (k + 1) % sides
			var mid: Vector3 = (rings[i][k] + rings[i][j]) * 0.5 - pts[i]
			_tri(st, rings[i][k], rings[i][j], rings[i + 1][j], mid)
			_tri(st, rings[i][k], rings[i + 1][j], rings[i + 1][k], mid)
	var end := pts.size() - 1
	for k in range(1, sides - 1):
		_tri(st, rings[0][0], rings[0][k], rings[0][k + 1], pts[0] - pts[1])
		_tri(st, rings[end][0], rings[end][k], rings[end][k + 1], pts[end] - pts[end - 1])


## A triangle wound so its front face looks along `want`.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	var flip := (b - a).cross(c - a).dot(want) > 0.0
	for v in ([a, c, b] if flip else [a, b, c]):
		st.add_vertex(v)
