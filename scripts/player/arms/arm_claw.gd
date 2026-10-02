class_name ArmClaw
extends RefCounted
## Swept goblin claw mesh: a thin nail plate that thickens into a horn, reaches past the fingertip and hooks toward the pad.

## Bezier parameters of the seven rings; a pole at u = 1.0 closes the tip.
const RING_U: Array[float] = [0.00, 0.12, 0.26, 0.42, 0.58, 0.74, 0.88]
## Ring half-width (lateral) and height (dorsal) as shares of base_w and base_h.
const HALF_W: Array[float] = [0.50, 0.50, 0.47, 0.42, 0.34, 0.24, 0.12]
const HEIGHT: Array[float] = [0.50, 0.75, 1.00, 1.00, 0.85, 0.60, 0.30]
const SECTORS := 6


## Origin at the nail bed base, +Y along the finger, +Z dorsal (off the skin), X lateral. The
## underside of every ring sits on the curve, so the plate lies on the skin; the base is open
## because it is buried in the finger.
static func mesh(bed_len: float, reach: float, base_w: float, base_h: float,
		curve_deg: float) -> ArrayMesh:
	var th := deg_to_rad(curve_deg)
	var p1 := Vector3(0.0, bed_len + 0.55 * reach, 0.0)
	var p2 := Vector3(0.0, bed_len + reach * cos(th), -reach * sin(th))
	var rings: Array[PackedVector3Array] = []
	for r in RING_U.size():
		var u := RING_U[r]
		var bez := 2.0 * (1.0 - u) * u * p1 + u * u * p2
		var tng := (2.0 * (1.0 - u) * p1 + 2.0 * u * (p2 - p1)).normalized()
		var dorsal := (Vector3.BACK - tng * tng.dot(Vector3.BACK)).normalized()
		var lateral := tng.cross(dorsal)
		var h := HEIGHT[r] * base_h
		var centre := bez + dorsal * h
		var pts := PackedVector3Array()
		for s in SECTORS:
			var a := TAU * float(s) / float(SECTORS)
			pts.append(centre + lateral * (cos(a) * HALF_W[r] * base_w) + dorsal * (sin(a) * h))
		rings.append(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Hard edges. Godot's front face is clockwise seen from outside, which is the order below
	# (sectors turn from lateral toward dorsal, rings step toward the tip).
	st.set_smooth_group(-1)
	for r in rings.size() - 1:
		for s in SECTORS:
			var s2 := (s + 1) % SECTORS
			var a: Vector3 = rings[r][s]
			var b: Vector3 = rings[r][s2]
			var c: Vector3 = rings[r + 1][s2]
			var d: Vector3 = rings[r + 1][s]
			for v: Vector3 in [a, b, d, b, c, d]:
				st.add_vertex(v)
	var last: PackedVector3Array = rings[rings.size() - 1]
	for s in SECTORS:
		for v: Vector3 in [last[s], last[(s + 1) % SECTORS], p2]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()
