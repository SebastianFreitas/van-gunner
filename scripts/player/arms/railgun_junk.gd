class_name RailgunJunk
extends RefCounted
## Flush scavenged junk on the held railgun: tape wraps, broken weld beads, empty bolt holes and a loose bolt; RailgunWear adds the rust, split seam, plate and cable.


## Adds the junk under `body` (gun space). Same arguments as RailgunBody.build.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, z_front: float,
		y_axis: float) -> void:
	rng.randf_range(0.0, 100.0)  # keeps the weld material's seed where it was
	var weld := ArmMaterials.surface(Color(0.28, 0.30, 0.21), Color(0.17, 0.18, 0.13),
			Color(0.10, 0.09, 0.06), 60.0, 6.0, 0.0, 0.7, 0.9, 0.15, rng.randf_range(0.0, 100.0))
	_tape(body, p, rng, z_front, y_axis)
	_welds(body, p, rng, z_front, y_axis, weld)
	_holes(body, p, z_front, y_axis)
	RailgunWear.build(body, p, rng, z_front, y_axis)


static func _bead(body: Node3D, node_name: String, mat: Material, at: Vector3, r: float,
		squash: Vector3 = Vector3.ONE, rot: Basis = Basis.IDENTITY) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 6
	s.rings = 3
	ArmParts.mesh(body, node_name, s, mat, at, rot).scale = squash


## Tape wraps: octagonal rings, three round the upper barrel and two round the lower one.
static func _tape(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	# Outside the coil window (zf - 1.795p to zf - 0.685p, jolt included): on the upper between its
	# rear band and cap, on the lower just ahead of the window.
	var wraps := [["Upper", true, zf - 0.288 * p, 3], ["Lower", false, zf - 1.86 * p, 2]]
	for w: Array in wraps:
		for k: int in range(w[3] as int):
			var tilt := Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-1.5, 1.5)))
			RailgunWear._wrap(body, "Tape%s%d" % [w[0] as String, k], ArmMaterials.tape(rng),
					w[1] as bool, (w[2] as float) - k * 0.036 * p, 0.028 * p, 0.012 * p,
					0.003 * p, p, ya, tilt)


## Weld beads along each side of the wedge's base seam, body-coloured and low. The run is
## broken: two beads gone on the right, one cracked clean through on the left, one fat blob.
static func _welds(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float, weld: Material) -> void:
	var crack := ArmMaterials.surface(Color(0.03, 0.025, 0.02), Color(0.02, 0.02, 0.02),
			Color(0.02, 0.02, 0.02), 60.0, 6.0, 0.0, 0.6, 0.9, 0.0, 0.0)
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		for k: int in range(5):
			var z := lerpf(0.30 * p - 0.02 * p, zf - 0.13 * p, k / 4.0) \
					+ rng.randf_range(-0.01, 0.01) * p
			if side > 0.0 and (k == 1 or k == 3):
				continue
			var big := 1.5 if side > 0.0 and k == 2 else 1.0
			# On the base plate's top edge, against the wedge's flank.
			var at := Vector3(side * RailgunBarrels.UP_HW * p, ya + 0.165 * p, z)
			_bead(body, "WeldWedge%s%d" % [tag, k], weld, at, 0.03 * p * big,
					Vector3(1.0, 0.7, 3.0))
			if side < 0.0 and k == 2:
				ArmParts.mesh(body, "WeldCrack", ArmParts.box(Vector3(0.05 * p, 0.05 * p, 0.012 * p)),
						crack, at + Vector3(-0.01 * p, 0.0, 0.0))


## Bolt heads gone: a dark pit over the head of one band bolt on each barrel, and a loose bolt
## backing out of the left strut.
static func _holes(body: Node3D, p: float, zf: float, ya: float) -> void:
	var pit := ArmMaterials.surface(Color(0.02, 0.018, 0.016), Color(0.015, 0.015, 0.015),
			Color(0.02, 0.02, 0.02), 60.0, 6.0, 0.0, 0.6, 0.9, 0.0, 0.0)
	var holes := [
		["PitLower", -RailgunBarrels.LOW_HW * p, ya + RailgunBarrels.LOW_Y * p, zf - 1.55 * p],
		["PitUpper", RailgunBarrels.UP_HW * p, ya + RailgunBarrels.UP_Y * p, zf - 1.5 * p],
	]
	for h: Array in holes:
		var x := h[1] as float
		var dir := Vector3(signf(x), 0.0, 0.0)
		# Over the bolt head on the band's flank: the band stands 0.025p off, the head 0.015p more.
		ArmParts.mesh(body, h[0] as String, ArmParts.cyl(0.036 * p, 0.006 * p, 0.036 * p, 8), pit,
				Vector3(x + signf(x) * 0.043 * p, h[2] as float, h[3] as float),
				ArmParts.along(dir))
	var steel := ArmMaterials.steel(11.0)
	var strut_z := zf - 0.15 * p - 0.17 * p
	ArmParts.mesh(body, "LooseBolt", ArmParts.cyl(0.012 * p, 0.09 * p, 0.012 * p, 6), steel,
			Vector3(-0.19 * p, ya + 0.28 * p, strut_z + 0.07 * p),
			Basis(Vector3.BACK, deg_to_rad(-20.0)) * ArmParts.along(Vector3.LEFT))
	ArmParts.mesh(body, "LooseBoltHead", ArmParts.cyl(0.028 * p, 0.02 * p, 0.028 * p, 6), steel,
			Vector3(-0.235 * p, ya + 0.28 * p + 0.015 * p, strut_z + 0.07 * p),
			Basis(Vector3.BACK, deg_to_rad(-20.0)) * ArmParts.along(Vector3.LEFT))
