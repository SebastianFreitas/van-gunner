class_name RailgunJunk
extends RefCounted
## Scavenged hardware on the held railgun: tire tread, tape wraps, welds, a chained padlock, scrap plates and a bent bracket.

## Clamp z offsets from the guard front, in palms (RailgunBody puts its clamps there).
const CLAMP_DZ: Array[float] = [0.7, 1.5, 2.3]


## Adds the junk under `body` (gun space). Same arguments as RailgunBody.build.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, z_front: float,
		y_axis: float) -> void:
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var weld := ArmMaterials.surface(Color(0.24, 0.25, 0.25), Color(0.13, 0.13, 0.14),
			Color(0.10, 0.10, 0.08), 60.0, 6.0, 0.0, 0.6, 0.7, 0.4, rng.randf_range(0.0, 100.0))
	_tread(body, p, z_front, y_axis, steel)
	_tape(body, p, rng, z_front, y_axis)
	_clamp_welds(body, p, rng, z_front, y_axis, weld)
	_plates(body, p, rng, z_front, y_axis, steel, weld)
	_chain(body, p, y_axis, steel)


static func _bead(body: Node3D, node_name: String, mat: Material, at: Vector3, r: float,
		squash: Vector3 = Vector3.ONE) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 6
	s.rings = 3
	ArmParts.mesh(body, node_name, s, mat, at).scale = squash


## Half-shell of tire rubber under the spine with tread blocks, one torn end and two hose clamps.
static func _tread(body: Node3D, p: float, zf: float, ya: float, steel: Material) -> void:
	var rubber := ArmMaterials.grip_rubber()
	var z0 := zf - 0.9 * p
	var z1 := zf - 2.1 * p
	# The bottom skips the middle clamp's base, so it is two pieces.
	var pieces: Array[Vector2] = [Vector2(z0, zf - 1.43 * p), Vector2(zf - 1.57 * p, z1)]
	for i: int in range(2):
		var za := pieces[i].x
		var zb := pieces[i].y
		ArmParts.mesh(body, "TreadBottom%d" % i,
				ArmParts.box(Vector3(0.46 * p, 0.03 * p, za - zb)), rubber,
				Vector3(0.0, ya - 0.217 * p, (za + zb) * 0.5))
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		var ze := z1 if side < 0.0 else zf - 1.95 * p  # the right flank is torn short
		ArmParts.mesh(body, "TreadFlank" + tag,
				ArmParts.box(Vector3(0.028 * p, 0.062 * p, z0 - ze)), rubber,
				Vector3(side * 0.216 * p, ya - 0.171 * p, (z0 + ze) * 0.5))
	var rows := [[-0.15, [0.98, 1.18, 1.78, 1.98]], [0.15, [1.08, 1.28, 1.68, 1.88]]]
	for row: Array in rows:
		var rx: float = row[0]
		var zs: Array = row[1]
		for k: int in range(zs.size()):
			ArmParts.mesh(body, "TreadBlock%s%d" % ["L" if rx < 0.0 else "R", k],
					ArmParts.box(Vector3(0.06 * p, 0.04 * p, 0.14 * p)), rubber,
					Vector3(rx * p, ya - 0.252 * p, zf - (zs[k] as float) * p))
	for i: int in range(2):
		var z := zf - (1.13 + 0.6 * i) * p
		ArmParts.mesh(body, "HoseClampBottom%d" % i,
				ArmParts.box(Vector3(0.52 * p, 0.02 * p, 0.07 * p)), steel,
				Vector3(0.0, ya - 0.285 * p, z))
		for side: float in [-1.0, 1.0]:
			var tag := "L" if side < 0.0 else "R"
			ArmParts.mesh(body, "HoseClampSide%s%d" % [tag, i],
					ArmParts.box(Vector3(0.03 * p, 0.152 * p, 0.07 * p)), steel,
					Vector3(side * 0.245 * p, ya - 0.216 * p, z))
		ArmParts.mesh(body, "HoseClampScrew%d" % i, ArmParts.cyl(0.03 * p, 0.05 * p, 0.03 * p, 6),
				steel, Vector3(-0.275 * p, ya - 0.15 * p, z), ArmParts.along(Vector3.LEFT))


## Three tape wraps of slightly rotated rings: left rail, right rail and the receiver top.
static func _tape(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var wraps := [
		["RailL", Vector3(-0.16 * p, ya + 0.31 * p, zf - 1.25 * p), Vector2(0.162, 0.192), 4],
		["RailR", Vector3(0.16 * p, ya + 0.31 * p, zf - 1.95 * p), Vector2(0.162, 0.192), 3],
		["Receiver", Vector3(0.0, ya + 0.256 * p, zf + 0.5 * p), Vector2(0.456, 0.30), 3],
	]
	for w: Array in wraps:
		var at: Vector3 = w[1]
		var size: Vector2 = w[2]
		for k: int in range(w[3] as int):
			var rot := Basis(Vector3.UP, deg_to_rad(rng.randf_range(-8.0, 8.0))) \
					* Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-3.0, 3.0)))
			ArmParts.mesh(body, "Tape%s%d" % [w[0] as String, k],
					ArmParts.box(Vector3(size.x * p, size.y * p, 0.028 * p)),
					ArmMaterials.tape(rng), at + Vector3(0.0, 0.0, k * 0.036 * p), rot)


## Bead rows down every clamp arm's front edge plus three blobs where a weld failed.
static func _clamp_welds(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float, weld: Material) -> void:
	for i: int in range(3):
		var zc := zf - CLAMP_DZ[i] * p
		for side: float in [-1.0, 1.0]:
			var tag := "L" if side < 0.0 else "R"
			var n := rng.randi_range(6, 10)
			for k: int in range(n):
				var t := clampf((k + rng.randf_range(-0.3, 0.3)) / float(n - 1), 0.0, 1.0)
				var y := ya + lerpf(-0.18, 0.33, t) * p
				_bead(body, "Weld%s%d_%d" % [tag, i, k], weld,
						Vector3(side * (0.245 if y > ya + 0.22 * p else 0.27) * p, y,
						zc - 0.07 * p + rng.randf_range(-0.01, 0.01) * p), 0.03 * p)
	_bead(body, "WeldBlob0", weld, Vector3(-0.27 * p, ya + 0.26 * p, zf - 0.77 * p), 0.07 * p,
			Vector3(0.5, 1.2, 1.0))
	_bead(body, "WeldBlob1", weld, Vector3(0.265 * p, ya - 0.1 * p, zf - 1.43 * p), 0.07 * p,
			Vector3(0.5, 1.0, 1.3))
	_bead(body, "WeldBlob2", weld, Vector3(-0.2 * p, ya + 0.43 * p, zf - 1.95 * p), 0.065 * p,
			Vector3(1.2, 0.7, 1.0))


## Two scrap plates on the left flank (one rust, one dull alu) and a bent bracket on the rails.
static func _plates(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float, ya: float,
		steel: Material, weld: Material) -> void:
	var rusty := rng.randi_range(0, 1) == 0
	var rust := ArmMaterials.rust(rng.randf_range(0.0, 100.0))
	var alu := ArmMaterials.dull_alu(rng.randf_range(0.0, 100.0))
	_plate(body, "PlateUp", p, rng, rust if rusty else alu,
			Vector3(-0.255 * p, ya + 0.27 * p, zf - 1.1 * p), Vector3(0.02, 0.2, 0.42), 4.0, 0,
			steel, weld)
	_plate(body, "PlateLow", p, rng, alu if rusty else rust,
			Vector3(-0.255 * p, ya - 0.20 * p, zf - 1.97 * p), Vector3(0.02, 0.11, 0.34), -4.0, 2,
			steel, weld)
	# Bent bracket: the top leaf is yawed off the leg so it does not quite line up.
	var bz := zf - 1.95 * p
	ArmParts.mesh(body, "BracketTop", ArmParts.box(Vector3(0.2 * p, 0.02 * p, 0.2 * p)), steel,
			Vector3(-0.18 * p, ya + 0.412 * p, bz), Basis(Vector3.UP, deg_to_rad(7.0)))
	ArmParts.mesh(body, "BracketLeg", ArmParts.box(Vector3(0.02 * p, 0.12 * p, 0.2 * p)), steel,
			Vector3(-0.2475 * p, ya + 0.35 * p, bz))


## One tilted plate with three hex bolt heads and a dark disc where the fourth is missing.
static func _plate(body: Node3D, node_name: String, p: float, rng: RandomNumberGenerator,
		mat: Material, at: Vector3, size: Vector3, tilt: float, missing: int, steel: Material,
		weld: Material) -> void:
	var rot := Basis(Vector3.RIGHT, deg_to_rad(tilt))
	ArmParts.mesh(body, node_name, ArmParts.box(size * p), mat, at, rot)
	var corners: Array[Vector2] = [Vector2(0.7, 0.4), Vector2(-0.7, 0.4), Vector2(0.7, -0.4),
			Vector2(-0.7, -0.4)]
	for k: int in range(4):
		var c := corners[k]
		var ly := c.x * size.y * 0.5 * p
		var lz := c.y * size.z * p
		if k == missing:
			ArmParts.mesh(body, "%sHole" % node_name,
					ArmParts.cyl(0.03 * p, 0.004 * p, 0.03 * p, 8), ArmMaterials.grip_rubber(),
					at + rot * Vector3(-(size.x * 0.5 + 0.0015) * p, ly, lz),
					rot * ArmParts.along(Vector3.LEFT))
		else:
			ArmParts.mesh(body, "%sBolt%d" % [node_name, k],
					ArmParts.cyl(0.03 * p, 0.02 * p, 0.03 * p, 6), steel,
					at + rot * Vector3(-(size.x * 0.5 + 0.008) * p, ly, lz),
					rot * ArmParts.along(Vector3.LEFT))
	for k: int in range(6):
		var z := (-0.45 + 0.9 * (k + rng.randf_range(-0.3, 0.3)) / 5.0) * size.z * p
		_bead(body, "%sWeld%d" % [node_name, k], weld,
				at + rot * Vector3(-size.x * 0.5 * p, -size.y * 0.5 * p, z), 0.025 * p)


## Oval chain from the receiver's top-left over the capacitor bank's rear to a padlock.
static func _chain(body: Node3D, p: float, ya: float, steel: Material) -> void:
	var q := ya / p
	var pts: Array[Vector3] = [
		Vector3(-0.20, q + 0.437, 0.20), Vector3(-0.22, q + 0.40, 0.46),
		Vector3(-0.10, q + 0.13, 0.49), Vector3(-0.30, q - 0.14, 0.42)]
	var total := 0.0
	for i: int in range(3):
		total += pts[i].distance_to(pts[i + 1])
	var count := 13
	var pitch := total / float(count)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.014 * p
	torus.outer_radius = 0.027 * p
	torus.rings = 8
	torus.ring_segments = 6
	for k: int in range(count):
		var d := (k + 0.5) * pitch
		var seg := 0
		while seg < 2 and d > pts[seg].distance_to(pts[seg + 1]):
			d -= pts[seg].distance_to(pts[seg + 1])
			seg += 1
		var t := (pts[seg + 1] - pts[seg]).normalized()
		var at := (pts[seg] + t * d) * p
		var u := t.cross(Vector3.UP).normalized()
		var n := u if k % 2 == 0 else t.cross(u).normalized()
		var rot := Basis(t, n, t.cross(n)) * Basis.from_scale(Vector3(1.5, 1.0, 1.0))
		ArmParts.mesh(body, "ChainLink%d" % k, torus, steel, at, rot)
	var lock := pts[3] * p
	ArmParts.mesh(body, "PadlockBody", ArmParts.box(Vector3(0.06, 0.12, 0.12) * p),
			ArmMaterials.brass(), lock + Vector3(0.0, -0.14 * p, 0.0))
	for side: float in [-1.0, 1.0]:
		ArmParts.mesh(body, "PadlockShackle%s" % ("L" if side < 0.0 else "R"),
				ArmParts.cyl(0.012 * p, 0.08 * p, 0.012 * p, 6), steel,
				lock + Vector3(0.0, -0.04 * p, side * 0.035 * p))
	ArmParts.mesh(body, "PadlockBend", ArmParts.cyl(0.012 * p, 0.094 * p, 0.012 * p, 6), steel,
			lock, ArmParts.along(Vector3.BACK))
