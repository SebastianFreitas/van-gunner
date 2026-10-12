class_name RailgunWear
extends RefCounted
## The railgun's wear layer: rust patches, paint flakes, a wire-bound split seam, a crooked scrap plate, a dented band and scorch near the shot, all laid flush on the box rails' flat faces and the receiver's flanks.


const TH := 0.006  # patch thickness, in p
const RUST_K := 1.22  # rust patch side scale: about 1.5x the area


## Adds the wear under `body` (gun space). Same arguments as RailgunBody.build.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	_rust(body, p, rng, zf, ya)
	_flakes(body, p, rng, zf, ya)
	_split(body, p, rng, zf, ya)
	_dent(body, p, rng, zf, ya)
	_scorch(body, p, rng, zf, ya)
	_plate(body, p, rng, zf, ya)


## Rail centre y, half-width and half-height in gun units for the upper or lower rail.
static func _dims(upper: bool, p: float, ya: float) -> Vector3:
	if upper:
		return Vector3(ya + RailgunBarrels.UP_Y * p, RailgunBarrels.UP_HW * p,
				RailgunBarrels.UP_R * p)
	return Vector3(ya + RailgunBarrels.LOW_Y * p, RailgunBarrels.LOW_HW * p,
			RailgunBarrels.LOW_R * p)


## A thin box lying flush on one flat face of a rail (`face` is top, bottom, left or right).
## `across` is x on top/bottom faces and y from the rail's centre on side faces; `w` is the
## size across, `l` the size along z. Keep `across` +- `w`/2 inside the face's flat. `lift`
## stands it off the face, for a patch on a band.
static func _face(body: Node3D, node_name: String, mat: Material, upper: bool, face: StringName,
		z: float, across: float, w: float, l: float, p: float, ya: float,
		lift: float = 0.0) -> void:
	var d := _dims(upper, p, ya)
	var th := TH * p
	match face:
		&"top":
			ArmParts.mesh(body, node_name, ArmParts.box(Vector3(w, th, l)), mat,
					Vector3(across, d.x + d.z + lift, z))
		&"bottom":
			ArmParts.mesh(body, node_name, ArmParts.box(Vector3(w, th, l)), mat,
					Vector3(across, d.x - d.z - lift, z))
		&"left":
			ArmParts.mesh(body, node_name, ArmParts.box(Vector3(th, w, l)), mat,
					Vector3(-d.y - lift, d.x + across, z))
		_:
			ArmParts.mesh(body, node_name, ArmParts.box(Vector3(th, w, l)), mat,
					Vector3(d.y + lift, d.x + across, z))


## A rectangular wrap round a rail's box section: four bars `t` thick standing `gap` off it.
static func _wrap(body: Node3D, node_name: String, mat: Material, upper: bool, z: float,
		blen: float, t: float, gap: float, p: float, ya: float, tilt: Basis = Basis.IDENTITY) -> void:
	var d := _dims(upper, p, ya)
	var hw := d.y + gap + t * 0.5
	var hr := d.z + gap + t * 0.5
	for s: float in [-1.0, 1.0]:
		var tag := "L" if s < 0.0 else "R"
		var c := Vector3(0.0, d.x, z)
		ArmParts.mesh(body, "%s%s%s" % [node_name, "Top" if s > 0.0 else "Bot", tag],
				ArmParts.box(Vector3(2.0 * (d.y + gap + t), t, blen)), mat,
				c + tilt * Vector3(0.0, s * hr, 0.0), tilt)
		ArmParts.mesh(body, "%sSide%s" % [node_name, tag],
				ArmParts.box(Vector3(t, 2.0 * (d.z + gap), blen)), mat,
				c + tilt * Vector3(s * hw, 0.0, 0.0), tilt)


static func _rust(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var rust := ArmMaterials.heavy_rust(rng.randf_range(0.0, 100.0))
	# [face, z behind zf, across, w, l, lift] in p. Top patches stay inside the flat
	# (|x| <= 0.14p) and beside the top rail (|x| < 0.045p); the 2.725 ones cover each rail's last
	# 0.15p (tip at zf - 2.8p); the lift 0.025 ones sit on a band.
	var ups := [[&"top", 1.35, 0.095, 0.07, 0.2, 0.0], [&"top", 1.61, -0.095, 0.07, 0.06, 0.0],
			[&"right", 1.00, 0.0, 0.22, 0.16, 0.0], [&"left", 0.75, 0.0, 0.2, 0.1, 0.0],
			[&"right", 1.50, 0.1, 0.15, 0.08, 0.025], [&"right", 2.725, 0.1, 0.14, 0.15, 0.0],
			[&"left", 2.725, 0.1, 0.14, 0.15, 0.0]]
	for i: int in range(ups.size()):
		var u: Array = ups[i]
		var k := 1.0 if (u[1] as float) > 2.7 else RUST_K
		_face(body, "RustUp%d" % i, rust, true, u[0] as StringName, zf - (u[1] as float) * p,
				(u[2] as float) * p, (u[3] as float) * p * k, (u[4] as float) * p * k, p, ya,
				(u[5] as float) * p)
	var lows := [[&"top", 0.84, -0.08, 0.09, 0.5, 0.0], [&"top", 1.96, 0.07, 0.07, 0.2, 0.0],
			[&"left", 1.78, 0.0, 0.2, 0.2, 0.0], [&"right", 1.8, -0.04, 0.14, 0.16, 0.0],
			[&"top", 1.55, 0.0, 0.2, 0.08, 0.025], [&"right", 2.725, 0.0, 0.14, 0.15, 0.0]]
	for i: int in range(lows.size()):
		var l: Array = lows[i]
		var k := 1.0 if (l[1] as float) > 2.7 else RUST_K
		_face(body, "RustLow%d" % i, rust, false, l[0] as StringName, zf - (l[1] as float) * p,
				(l[2] as float) * p, (l[3] as float) * p * k, (l[4] as float) * p * k, p, ya,
				(l[5] as float) * p)
	# Receiver flanks (x +-0.22p, z -1.28..0.32p; patch face 0.004p proud): clear of the plates,
	# ribs (y 0.345), bolts, slots, the paint flakes and the charge cell (left, z -0.6..-0.2).
	# [side, z, y above the guard top, h, l] in p.
	var flanks := [[-1.0, 0.10, 0.80, 0.18, 0.16], [-1.0, -0.90, 0.78, 0.14, 0.16],
			[1.0, -1.10, 0.72, 0.14, 0.20], [1.0, 0.00, 0.75, 0.16, 0.14],
			[-1.0, -0.45, 0.80, 0.14, 0.12], [1.0, -0.62, 0.80, 0.14, 0.16]]
	for i: int in range(flanks.size()):
		var f: Array = flanks[i]
		ArmParts.mesh(body, "RustFlank%d" % i,
				ArmParts.box(Vector3(TH * p, (f[3] as float) * p * RUST_K, (f[4] as float) * p * RUST_K)), rust,
				Vector3((f[0] as float) * (0.224 - TH * 0.5) * p, ya + (f[2] as float) * p, (f[1] as float) * p))


## A few flakes of old olive paint left on the receiver's flanks and the upper rail's top.
static func _flakes(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var olive := ArmMaterials.gun_paint(rng.randf_range(0.0, 100.0))
	# [side, y above the guard top, z, h, l] in p: clear of the plates, ribs and the charge cell.
	var spots := [[-1.0, 0.80, -1.10, 0.07, 0.10], [-1.0, 0.25, -0.40, 0.07, 0.08],
			[1.0, 0.75, -0.90, 0.07, 0.07], [1.0, 0.75, -0.30, 0.08, 0.07]]
	for i: int in range(spots.size()):
		var s: Array = spots[i]
		ArmParts.mesh(body, "Flake%d" % i,
				ArmParts.box(Vector3(TH * p, (s[3] as float) * p, (s[4] as float) * p)), olive,
				Vector3((s[0] as float) * (0.224 - TH * 0.5) * p, ya + (s[1] as float) * p,
				(s[2] as float) * p))
	# On the top flat's left half, between the wire wraps and clear of the rail posts.
	_face(body, "FlakeUp", olive, true, &"top", zf - 0.7 * p, -0.095 * p, 0.05 * p, 0.12 * p, p, ya)


## The upper rail's top has split open along its seam: a dark gap with raised lips, bound by
## three rectangular wire wraps. The gap runs beside the top rail, on the flat's right half.
static func _split(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var dark := ArmMaterials.surface(Color(0.02, 0.018, 0.016), Color(0.015, 0.015, 0.015),
			Color(0.02, 0.02, 0.02), 60.0, 6.0, 0.0, 0.6, 0.9, 0.0, 0.0)
	var rust := ArmMaterials.rust(rng.randf_range(0.0, 100.0))
	var wire := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var d := _dims(true, p, ya)
	var top := d.x + d.z
	var uf := zf - 1.9 * p
	var zc := uf + 0.98 * p
	var gx := 0.095 * p
	ArmParts.mesh(body, "SplitGap", ArmParts.box(Vector3(0.03 * p, 0.012 * p, 0.46 * p)), dark,
			Vector3(gx, top - 0.002 * p, zc))
	for side: float in [-1.0, 1.0]:
		ArmParts.mesh(body, "SplitLip%s" % ("L" if side < 0.0 else "R"),
				ArmParts.box(Vector3(0.016 * p, 0.012 * p, 0.44 * p)), rust,
				Vector3(gx + side * 0.026 * p, top + 0.001 * p, zc),
				Basis(Vector3.BACK, deg_to_rad(-side * 9.0)))
	for i: int in range(3):
		var tilt := Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-3.0, 3.0)))
		_wrap(body, "SplitWire%d" % i, wire, true, uf + (0.69 + 0.32 * i - (0.04 if i == 1 else 0.0)) * p, 0.014 * p,
				0.012 * p, 0.003 * p, p, ya, tilt)


## A dented lower band: a dark pressed-in ellipse on its right flank and one torn corner bent up.
static func _dent(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var dark := ArmMaterials.scorched_steel(rng.randf_range(0.0, 100.0))
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var d := _dims(false, p, ya)
	var z := zf - 1.55 * p
	var s := SphereMesh.new()
	s.radius = 0.06 * p
	s.height = 0.12 * p
	s.radial_segments = 8
	s.rings = 4
	# The band stands 0.025p proud of the flank; the dent sits on its face.
	ArmParts.mesh(body, "BandDent", s, dark, Vector3(d.y + 0.025 * p, d.x + 0.04 * p, z)).scale = \
			Vector3(0.3, 1.0, 1.2)
	# The torn corner lifts off the band's top face.
	ArmParts.mesh(body, "BandCurl", ArmParts.box(Vector3(0.05 * p, 0.012 * p, 0.09 * p)), steel,
			Vector3(0.06 * p, d.x + d.z + 0.031 * p, z), Basis(Vector3.BACK, deg_to_rad(18.0)))


## Heat discolouration where the shot leaves the gap: a square band round the lower rail at the
## coil band (zf - 1.9p), and patches on the gap's floor, the upper rail's belly and the lower top
## before the brake.
static func _scorch(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var hot := ArmMaterials.scorched_steel(rng.randf_range(0.0, 100.0))
	var uf := zf - 1.9 * p
	_wrap(body, "ScorchBand", hot, false, zf - 1.9 * p, 0.08 * p, 0.012 * p, 0.0, p, ya)
	_face(body, "ScorchUnder", hot, true, &"bottom", uf + 0.55 * p, 0.0, 0.22 * p, 0.2 * p, p, ya)
	_face(body, "ScorchLow", hot, false, &"top", uf + 0.45 * p, 0.0, 0.2 * p, 0.7 * p, p, ya)
	_face(body, "ScorchMuzzle", hot, false, &"top", zf - 2.36 * p, 0.07 * p, 0.12 * p, 0.16 * p,
			p, ya)
	# Sooty patches on each receiver flank at the breech end, where the player view sees them
	# (z 0.17..0.31p, y 0.45..0.65p above the guard top: clear of the rust patches and the breech).
	for s: float in [-1.0, 1.0]:
		ArmParts.mesh(body, "ScorchFlank%s" % ("L" if s < 0.0 else "R"),
				ArmParts.box(Vector3(TH * p, 0.20 * p, 0.14 * p)), hot,
				Vector3(s * (0.224 - TH * 0.5) * p, ya + 0.55 * p, 0.24 * p))


## A scrap plate hanging crooked off the front lower bolt of the right flank, swung 16 degrees.
static func _plate(body: Node3D, p: float, rng: RandomNumberGenerator, _zf: float,
		ya: float) -> void:
	var rust := ArmMaterials.rust(rng.randf_range(0.0, 100.0))
	var bolt := Vector3(0.215 * p, ya + 0.28 * p, -0.35 * p)
	var b := Basis(Vector3.RIGHT, deg_to_rad(16.0))
	ArmParts.mesh(body, "HangPlate", ArmParts.box(Vector3(0.012 * p, 0.13 * p, 0.17 * p)), rust,
			bolt + b * Vector3(0.022 * p, -0.06 * p, 0.0), b)
	ArmParts.mesh(body, "HangPlateHole", ArmParts.cyl(0.022 * p, 0.016 * p, 0.022 * p, 6),
			ArmMaterials.steel(rng.randf_range(0.0, 100.0)),
			bolt + Vector3(0.026 * p, 0.0, 0.0), ArmParts.along(Vector3.RIGHT))
