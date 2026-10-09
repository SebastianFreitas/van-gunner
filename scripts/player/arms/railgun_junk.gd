class_name RailgunJunk
extends RefCounted
## Flush scavenged junk on the held railgun: tape wraps on the rails and receiver, and weld beads at the seams.


## Adds the junk under `body` (gun space). Same arguments as RailgunBody.build.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, z_front: float,
		y_axis: float) -> void:
	rng.randf_range(0.0, 100.0)  # keeps the weld material's seed where it was
	var weld := ArmMaterials.surface(Color(0.28, 0.30, 0.21), Color(0.17, 0.18, 0.13),
			Color(0.10, 0.09, 0.06), 60.0, 6.0, 0.0, 0.7, 0.9, 0.15, rng.randf_range(0.0, 100.0))
	_tape(body, p, rng, z_front, y_axis)
	_clamp_welds(body, p, rng, z_front, y_axis, weld)


static func _bead(body: Node3D, node_name: String, mat: Material, at: Vector3, r: float,
		squash: Vector3 = Vector3.ONE, rot: Basis = Basis.IDENTITY) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 6
	s.rings = 3
	ArmParts.mesh(body, node_name, s, mat, at, rot).scale = squash


## Tape wraps: two boxy rings on the flat-sided rails and three 8-segment rings round the receiver.
static func _tape(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var wraps := [
		["RailL", Vector3(-0.16 * p, ya + 0.71 * p, zf - 1.25 * p), Vector2(0.162, 0.192), 4],
		["RailR", Vector3(0.16 * p, ya + 0.71 * p, zf - 1.95 * p), Vector2(0.162, 0.192), 3],
	]
	for w: Array in wraps:
		var at: Vector3 = w[1]
		var size: Vector2 = w[2]
		for k: int in range(w[3] as int):
			var rot := Basis(Vector3.UP, deg_to_rad(rng.randf_range(-8.0, 8.0))) 					* Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-3.0, 3.0)))
			ArmParts.mesh(body, "Tape%s%d" % [w[0] as String, k],
					ArmParts.box(Vector3(size.x * p, size.y * p, 0.028 * p)),
					ArmMaterials.tape(rng), at + Vector3(0.0, 0.0, k * 0.036 * p), rot)
	# Receiver: same octagon and y stretch as RailgunBody's Receiver, 4% wider, a hair of tilt.
	var rh := ya + 0.40 * p - 0.03
	var oct_r := 0.22 * p / cos(deg_to_rad(22.5)) * 1.04
	for k: int in range(3):
		var tilt := Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-1.5, 1.5)))
		ArmParts.mesh(body, "TapeReceiver%d" % k, ArmParts.cyl(oct_r, 0.028 * p, oct_r, 8),
				ArmMaterials.tape(rng), Vector3(0.0, 0.03 + rh * 0.5, zf + (0.5 + k * 0.036) * p),
				tilt * Basis.from_scale(Vector3(1.0, rh / (0.44 * p), 1.0))
				* ArmParts.along(Vector3.BACK) * Basis(Vector3.UP, deg_to_rad(22.5)))


## Weld beads, body-coloured and low: eight runs round the receiver to spine seam, and five along
## each rail web's outer foot where it meets the receiver.
static func _clamp_welds(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float, weld: Material) -> void:
	for k: int in range(8):
		var a := TAU * (k + rng.randf_range(-0.2, 0.2)) / 8.0
		_bead(body, "WeldSeam%d" % k, weld, Vector3(sin(a) * 0.215 * p,
				ya + 0.009 * p + cos(a) * 0.215 * p, zf - 0.04 * p), 0.03 * p,
				Vector3(2.6, 0.7, 1.0), Basis(Vector3.BACK, -a))
	# The web's outer face (x 0.205 p) meets the receiver's 45 degree flat, which sits
	# 0.106 p of the 0.22 p apothem above the axis, stretched like the receiver.
	var rh := ya + 0.40 * p - 0.03
	var y := 0.03 + rh * 0.5 + 0.106 * rh / 0.44
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		for k: int in range(5):
			var z := lerpf(0.30 * p, zf + 0.1 * p, k / 4.0) + rng.randf_range(-0.01, 0.01) * p
			_bead(body, "WeldRail%s%d" % [tag, k], weld, Vector3(side * 0.205 * p, y, z),
					0.03 * p, Vector3(1.0, 0.7, 3.0))
