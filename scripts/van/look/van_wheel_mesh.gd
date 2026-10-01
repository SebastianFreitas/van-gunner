extends RefCounted
## Builds one road wheel's merged meshes in its spin pivot's space (axle along x): the lugged tyre, the deep-dish rim and the steel beadlock ring, hub and lug nuts.

## Faces around the tyre carcass and rim.
const SEGMENTS := 20
## Lugs per tread row; the two rows are staggered half a lug.
const LUGS_PER_ROW := 18


## The tyre: a carcass ring with two staggered rows of chunky lugs whose tops are the rolling radius.
static func tyre(radius: float, width: float) -> ArrayMesh:
	var st := _begin()
	_prism(st, -width * 0.5, width * 0.5, 0.56 * radius, 0.86 * radius, SEGMENTS)
	var lug_size := Vector3(0.52 * width, 0.16 * radius, 0.16 * radius)
	for k: int in range(2):
		# Each row overhangs its sidewall by 2 cm and the rows leave a 2 cm groove at x 0.
		var row_x := -width * 0.5 - 0.02 + 0.26 * width
		if k == 1:
			row_x = -row_x
		for i: int in range(LUGS_PER_ROW):
			var a: float = (i + 0.5 * k) * TAU / LUGS_PER_ROW
			var centre := Vector3(row_x, cos(a) * 0.92 * radius, sin(a) * 0.92 * radius)
			_box(st, Transform3D(Basis(Vector3.RIGHT, a), centre), lug_size)
	return _finish(st)


## The deep-dish rim: a barrel sunk 10 cm inside the outer sidewall and a hub boss on its face.
static func rim(radius: float, width: float, outer: float) -> ArrayMesh:
	var st := _begin()
	var s := outer
	_prism(st, minf(-s * 0.40 * width, s * 0.30 * width), maxf(-s * 0.40 * width, s * 0.30 * width),
			0.0, 0.58 * radius, 16)
	var boss_a := s * 0.30 * width
	var boss_b := s * (0.30 * width + 0.07)
	_prism(st, minf(boss_a, boss_b), maxf(boss_a, boss_b), 0.0, 0.24 * radius, 12)
	return _finish(st)


## The bolt-on hardware: beadlock ring and bolts, lug nuts and the centre cap.
static func steel(radius: float, width: float, outer: float) -> ArrayMesh:
	var st := _begin()
	var s := outer
	var ring_a := s * (width * 0.5 + 0.005)
	var ring_b := s * (width * 0.5 + 0.035)
	_prism(st, minf(ring_a, ring_b), maxf(ring_a, ring_b), 0.54 * radius, 0.70 * radius, 20)
	for j: int in range(12):
		var a: float = j * TAU / 12.0
		var centre := Vector3(s * (width * 0.5 + 0.045), cos(a) * 0.62 * radius,
				sin(a) * 0.62 * radius)
		_box(st, Transform3D(Basis(Vector3.RIGHT, a), centre), Vector3(0.035, 0.035, 0.035))
	for j: int in range(8):
		var a: float = j * TAU / 8.0
		var centre := Vector3(s * (0.30 * width + 0.085), cos(a) * 0.15 * radius,
				sin(a) * 0.15 * radius)
		_box(st, Transform3D(Basis(Vector3.RIGHT, a), centre), Vector3(0.045, 0.045, 0.045))
	var cap_a := s * (0.30 * width + 0.06)
	var cap_b := s * (0.30 * width + 0.11)
	_prism(st, minf(cap_a, cap_b), maxf(cap_a, cap_b), 0.0, 0.07 * radius, 8)
	return _finish(st)


## A prism along x from x0 to x1 (x0 < x1): a ring when r_in > 0, solid with capped ends otherwise.
static func _prism(st: SurfaceTool, x0: float, x1: float, r_in: float, r_out: float,
		segments: int) -> void:
	var x_mid := (x0 + x1) * 0.5
	var r_mid := (r_in + r_out) * 0.5
	for i: int in range(segments):
		var a0: float = i * TAU / segments
		var a1: float = (i + 1) * TAU / segments
		var am := (a0 + a1) * 0.5
		var c := Vector3(x_mid, cos(am) * r_mid, sin(am) * r_mid)
		VanCab._add_quad(st, _ring_pt(x0, r_out, a0), _ring_pt(x1, r_out, a0),
				_ring_pt(x1, r_out, a1), _ring_pt(x0, r_out, a1), c)
		if r_in > 0.0:
			VanCab._add_quad(st, _ring_pt(x0, r_in, a0), _ring_pt(x1, r_in, a0),
					_ring_pt(x1, r_in, a1), _ring_pt(x0, r_in, a1), c)
			for x: float in [x0, x1]:
				VanCab._add_quad(st, _ring_pt(x, r_in, a0), _ring_pt(x, r_out, a0),
						_ring_pt(x, r_out, a1), _ring_pt(x, r_in, a1), c)
		else:
			for x: float in [x0, x1]:
				VanCab._add_tri(st, Vector3(x, 0.0, 0.0), _ring_pt(x, r_out, a0),
						_ring_pt(x, r_out, a1), Vector3(x_mid, 0.0, 0.0))


## A point on the ring of radius r at angle a, at axle position x.
static func _ring_pt(x: float, r: float, a: float) -> Vector3:
	return Vector3(x, cos(a) * r, sin(a) * r)


## A box of the given size, placed by xform, as six outward quads.
static func _box(st: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for ix: int in range(2):
		for iy: int in range(2):
			for iz: int in range(2):
				p.append(xform * Vector3(h.x * (1 - 2 * ix), h.y * (1 - 2 * iy),
						h.z * (1 - 2 * iz)))
	# Index = ix * 4 + iy * 2 + iz.
	var c := xform.origin
	VanCab._add_quad(st, p[0], p[1], p[3], p[2], c)
	VanCab._add_quad(st, p[4], p[5], p[7], p[6], c)
	VanCab._add_quad(st, p[0], p[1], p[5], p[4], c)
	VanCab._add_quad(st, p[2], p[3], p[7], p[6], c)
	VanCab._add_quad(st, p[0], p[2], p[6], p[4], c)
	VanCab._add_quad(st, p[1], p[3], p[7], p[5], c)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	return st


static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()
