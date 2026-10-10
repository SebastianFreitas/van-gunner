class_name RailgunBody
extends RefCounted
## Held gun body: a long lower barrel, a short fat upper barrel with an open gap between them, and a capacitor wedge butted against the upper barrel's rear, its slope (with the charge window) falling toward the player.

## The wedge's base height above the guard top and its rear z, in palm units p.
const WEDGE_YB := 0.14
const WEDGE_ZR := 0.30


## Builds barrels + wedge under `body` (the gun's "Body" node, gun space, -Z forward, +Y up).
## `p` is the palm length, `z_front` the trigger guard's front z, `y_axis` = trigger_y + 0.25 p
## (the guard's top). Returns the muzzle point in gun space.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, z_front: float,
		y_axis: float) -> Vector3:
	# Geometry never depends on rng: the aim must not depend on the seed.
	var muzzle := RailgunBarrels.build(body, p, rng, z_front, y_axis)
	var paint := ArmMaterials.gun_paint(rng.randf_range(0.0, 100.0))
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var cable := ArmMaterials.surface(Color(0.04, 0.04, 0.035), Color(0.02, 0.02, 0.02),
			Color(0.03, 0.03, 0.02), 60.0, 6.0, 0.0, 0.6, 0.9, 0.0, rng.randf_range(0.0, 100.0))
	var ya := y_axis
	var uy := ya + RailgunBarrels.UP_Y * p
	var ur := z_front - 0.15 * p
	var zr := WEDGE_ZR * p
	var yb := ya + WEDGE_YB * p
	var yt := uy + RailgunBarrels.UP_R * p
	var hw := RailgunBarrels.UP_HW * p
	var wlen := zr - ur
	var hgt := yt - yb
	# Point on the slope at fraction f from the peak (0) to the rear base (1), lifted by `lift`.
	var slope_n := Vector3(0.0, wlen, hgt).normalized()
	var on_slope := func(f: float, lift: float) -> Vector3:
		return Vector3(0.0, yt - hgt * f, ur + wlen * f) + slope_n * lift

	# The wedge: a triangle in side view; its vertical face butts the upper barrel's rear and
	# the slope falls to the base at the rear, toward the player.
	ArmParts.mesh(body, "Wedge", _wedge_mesh(ur, zr, yb, yt, hw), paint, Vector3.ZERO)
	# Two thin rods on the slope's side edges, so nothing crosses the charge window.
	for side: float in [-1.0, 1.0]:
		ArmParts.limb(body, "WedgeEdge%s" % ("L" if side < 0.0 else "R"),
				Vector3(side * hw, yt, ur), Vector3(side * hw, yb, zr),
				0.01 * p, 0.01 * p, steel, 6)
	ArmParts.mesh(body, "WedgeBase", ArmParts.box(Vector3(0.40 * p, 0.04 * p, wlen)), steel,
			Vector3(0.0, yb - 0.01 * p, (zr + ur) * 0.5))
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		for k: int in range(2):
			ArmParts.mesh(body, "WedgeBolt%s%d" % [tag, k],
					ArmParts.cyl(0.03 * p, 0.03 * p, 0.03 * p, 6), steel,
					Vector3(side * hw, ya + 0.28 * p, ur + (0.30 + 0.45 * k) * p),
					ArmParts.along(Vector3(side, 0.0, 0.0)))
	# Charge window on the slope (facing up and back), in a steel frame.
	var tilt := Basis(Vector3.RIGHT, -atan2(slope_n.y, slope_n.z))
	ArmParts.mesh(body, "WindowFrame", ArmParts.box(Vector3(0.20 * p, 0.14 * p, 0.012 * p)),
			steel, on_slope.call(0.45, 0.004 * p), tilt)
	ArmParts.mesh(body, "Lamp0", ArmParts.box(Vector3(0.14 * p, 0.08 * p, 0.012 * p)),
			ArmMaterials.ember(0.0), on_slope.call(0.45, 0.012 * p), tilt)

	# Two cables over the slope: the upper one runs up to the upper barrel's rear beside the
	# wedge's peak, the lower one dives into the lower barrel.
	var cu_a: Vector3 = on_slope.call(0.75, 0.02 * p)
	ArmParts.limb(body, "CableUpper", Vector3(-0.14 * p, cu_a.y, cu_a.z),
			Vector3(-0.14 * p, yt - 0.02 * p, ur), 0.02 * p, 0.02 * p, cable, 6)
	var cl_a: Vector3 = on_slope.call(0.55, 0.02 * p)
	ArmParts.limb(body, "CableLower", Vector3(0.10 * p, cl_a.y, cl_a.z),
			Vector3(0.10 * p, ya + 0.10 * p, ur + 0.30 * p), 0.02 * p, 0.02 * p, cable, 6)

	RailgunCoils.build(body, p, rng, muzzle.y, muzzle.z + 0.05 * p, 1.28)
	# Sockets snap before the wear exists, so its thin parts never move them.
	GunSockets.place(body, p, z_front, ya)
	RailgunJunk.build(body, p, rng, z_front, ya)
	body.add_child(RailGlow.new())
	body.add_child(GunAttachments.new())
	return muzzle


## A triangular prism, +-hw wide: vertical face from yb to yt at zv, sloping down to yb at zs.
static func _wedge_mesh(zv: float, zs: float, yb: float, yt: float, hw: float) -> ArrayMesh:
	var v: Array[Vector3] = []
	for s: float in [-hw, hw]:
		v.append_array([Vector3(s, yb, zv), Vector3(s, yt, zv), Vector3(s, yb, zs)])
	var c := Vector3.ZERO
	for q: Vector3 in v:
		c += q / 6.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Left cap, right cap, vertical face, bottom, slope.
	var tris: Array = [[0, 1, 2], [3, 5, 4], [0, 3, 1], [3, 4, 1], [0, 2, 3], [3, 2, 5],
			[1, 4, 2], [4, 5, 2]]
	for t: Array in tris:
		var a: Vector3 = v[t[0] as int]
		var b: Vector3 = v[t[1] as int]
		var d: Vector3 = v[t[2] as int]
		# Godot's front face is clockwise: flip any triangle that is counter-clockwise outside.
		if (b - a).cross(d - a).dot((a + b + d) / 3.0 - c) > 0.0:
			var tmp := b
			b = d
			d = tmp
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(d)
	st.generate_normals()
	return st.commit()
