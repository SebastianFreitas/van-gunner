class_name RailgunWear
extends RefCounted
## The railgun's wear layer: rust patches, paint flakes, a wire-bound split seam, a crooked scrap plate, a taped sagging cable, a dented band and scorch near the shot, all laid flush on the box barrels' flat faces and the wedge's flank.


const TH := 0.006  # patch thickness, in p


## Adds the wear under `body` (gun space). Same arguments as RailgunBody.build.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	_rust(body, p, rng, zf, ya)
	_flakes(body, p, rng, zf, ya)
	_split(body, p, rng, zf, ya)
	_dent(body, p, rng, zf, ya)
	_scorch(body, p, rng, zf, ya)
	_plate(body, p, rng, zf, ya)
	_cable(body, p, rng, zf, ya)


## Barrel centre y, half-width and half-height in gun units for the upper or lower barrel.
static func _dims(upper: bool, p: float, ya: float) -> Vector3:
	if upper:
		return Vector3(ya + RailgunBarrels.UP_Y * p, RailgunBarrels.UP_HW * p,
				RailgunBarrels.UP_R * p)
	return Vector3(ya + RailgunBarrels.LOW_Y * p, RailgunBarrels.LOW_HW * p,
			RailgunBarrels.LOW_R * p)


## A thin box lying flush on one flat face of a barrel (`face` is top, bottom, left or right).
## `across` is x on top/bottom faces and y from the barrel's centre on side faces; `w` is the
## size across, `l` the size along z. Keep `across` +- `w`/2 inside the face's flat.
static func _face(body: Node3D, node_name: String, mat: Material, upper: bool, face: StringName,
		z: float, across: float, w: float, l: float, p: float, ya: float) -> void:
	var d := _dims(upper, p, ya)
	var th := TH * p
	match face:
		&"top":
			ArmParts.mesh(body, node_name, ArmParts.box(Vector3(w, th, l)), mat,
					Vector3(across, d.x + d.z, z))
		&"bottom":
			ArmParts.mesh(body, node_name, ArmParts.box(Vector3(w, th, l)), mat,
					Vector3(across, d.x - d.z, z))
		&"left":
			ArmParts.mesh(body, node_name, ArmParts.box(Vector3(th, w, l)), mat,
					Vector3(-d.y, d.x + across, z))
		_:
			ArmParts.mesh(body, node_name, ArmParts.box(Vector3(th, w, l)), mat,
					Vector3(d.y, d.x + across, z))


## A rectangular wrap round a barrel's box section: four bars `t` thick standing `gap` off it.
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


## The wedge: rear z of its vertical face, rear base z, base y, peak y, half-width (as built in
## RailgunBody).
static func _wedge(p: float, zf: float, ya: float) -> Array[float]:
	return [zf - 0.15 * p, 0.30 * p, ya + 0.14 * p,
			ya + (RailgunBarrels.UP_Y + RailgunBarrels.UP_R) * p, RailgunBarrels.UP_HW * p]


## The slope's height at z.
static func _slope_y(w: Array[float], z: float) -> float:
	return lerpf(w[3], w[2], clampf((z - w[0]) / (w[1] - w[0]), 0.0, 1.0))


static func _rust(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var rust := ArmMaterials.heavy_rust(rng.randf_range(0.0, 100.0))
	var uf := zf - 1.9 * p
	# [face, z, across, w, l] in p; z is behind the upper's front `uf` (upper) or from `zf` (lower).
	# Top patches stay inside the flat (|x| <= 0.14p) and beside the top rail (|x| < 0.045p).
	var ups := [[&"top", 0.55, 0.095, 0.07, 0.2], [&"top", 0.29, -0.095, 0.07, 0.06],
			[&"right", 0.55, 0.0, 0.22, 0.16], [&"left", 1.58, 0.0, 0.2, 0.1]]
	for i: int in range(ups.size()):
		var u: Array = ups[i]
		_face(body, "RustUp%d" % i, rust, true, u[0] as StringName, uf + (u[1] as float) * p,
				(u[2] as float) * p, (u[3] as float) * p, (u[4] as float) * p, p, ya)
	var lows := [[&"top", -0.84, -0.08, 0.09, 0.5], [&"top", -1.96, 0.07, 0.07, 0.2],
			[&"left", -1.78, 0.0, 0.2, 0.2], [&"right", -1.8, -0.04, 0.14, 0.16]]
	for i: int in range(lows.size()):
		var l: Array = lows[i]
		_face(body, "RustLow%d" % i, rust, false, l[0] as StringName, zf + (l[1] as float) * p,
				(l[2] as float) * p, (l[3] as float) * p, (l[4] as float) * p, p, ya)


## A few flakes of old olive paint left on the wedge's flanks and the upper barrel.
static func _flakes(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var olive := ArmMaterials.surface(Color(0.24, 0.27, 0.16), Color(0.14, 0.16, 0.10),
			Color(0.10, 0.09, 0.06), 60.0, 6.0, 0.0, 0.7, 0.85, 0.15, rng.randf_range(0.0, 100.0))
	var w := _wedge(p, zf, ya)
	var wlen := w[1] - w[0]
	# [side, fraction of the wedge's length from its vertical face, fraction up the flank, h, l]
	var spots := [[-1.0, 0.12, 0.9, 0.07, 0.10], [-1.0, 0.85, 0.0, 0.05, 0.06],
			[1.0, 0.2, 0.8, 0.08, 0.07], [1.0, 0.7, 0.0, 0.06, 0.05]]
	for i: int in range(spots.size()):
		var s: Array = spots[i]
		var z := w[0] + wlen * (s[1] as float)
		var h := (s[3] as float) * p
		var lo := w[2] + 0.5 * h + 0.01 * p
		var hi := _slope_y(w, z + 0.5 * (s[4] as float) * p) - 0.5 * h - 0.01 * p
		ArmParts.mesh(body, "Flake%d" % i, ArmParts.box(Vector3(TH * p, h, (s[4] as float) * p)),
				olive, Vector3((s[0] as float) * w[4], lerpf(lo, maxf(lo, hi), s[2] as float), z))
	# On the top flat's left half, between the wire wraps and clear of the rail posts.
	_face(body, "FlakeUp", olive, true, &"top", zf - 0.7 * p, -0.095 * p, 0.05 * p, 0.12 * p, p, ya)


## The upper barrel's top has split open along its seam: a dark gap with raised lips, bound by
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


## Heat discolouration where the shot leaves the gap: a square band round the lower barrel just
## ahead of the upper barrel's front, and patches on the gap's floor, the upper barrel's belly and
## the lower top before the brake.
static func _scorch(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var hot := ArmMaterials.scorched_steel(rng.randf_range(0.0, 100.0))
	var uf := zf - 1.9 * p
	_wrap(body, "ScorchBand", hot, false, uf - 0.40 * p, 0.08 * p, 0.012 * p, 0.0, p, ya)
	_face(body, "ScorchUnder", hot, true, &"bottom", uf + 0.55 * p, 0.0, 0.22 * p, 0.2 * p, p, ya)
	_face(body, "ScorchLow", hot, false, &"top", uf + 0.45 * p, 0.0, 0.2 * p, 0.7 * p, p, ya)
	_face(body, "ScorchMuzzle", hot, false, &"top", zf - 2.36 * p, 0.07 * p, 0.12 * p, 0.16 * p,
			p, ya)


## A scrap plate hanging crooked off the first wedge bolt (left flank), swung 16 degrees.
static func _plate(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var rust := ArmMaterials.rust(rng.randf_range(0.0, 100.0))
	var w := _wedge(p, zf, ya)
	var bolt := Vector3(-w[4], ya + 0.28 * p, w[0] + 0.30 * p)
	var b := Basis(Vector3.RIGHT, deg_to_rad(16.0))
	# Slid 0.12p forward so its rear corner stays out of Socket_left_a's footprint.
	var slide := Vector3(0.0, 0.0, -0.12 * p)
	ArmParts.mesh(body, "HangPlate", ArmParts.box(Vector3(0.012 * p, 0.13 * p, 0.17 * p)), rust,
			bolt + slide + b * Vector3(-0.022 * p, -0.06 * p, 0.0), b)
	ArmParts.mesh(body, "HangPlateHole", ArmParts.cyl(0.022 * p, 0.016 * p, 0.022 * p, 6),
			ArmMaterials.steel(rng.randf_range(0.0, 100.0)),
			bolt + slide + Vector3(-0.026 * p, 0.0, 0.0),
			ArmParts.along(Vector3.LEFT))


## A cable out of the wedge's left flank, under its slope, that sags over the flat flank down to
## the lower barrel's rear, patched with tape halfway.
static func _cable(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> void:
	var cable := ArmMaterials.surface(Color(0.04, 0.04, 0.035), Color(0.02, 0.02, 0.02),
			Color(0.03, 0.03, 0.02), 60.0, 6.0, 0.0, 0.6, 0.9, 0.0, rng.randf_range(0.0, 100.0))
	var w := _wedge(p, zf, ya)
	var z0 := w[0] + 0.89 * p  # behind Socket_left_a's footprint
	var a := Vector3(-w[4], _slope_y(w, z0) - 0.08 * p, z0)
	var b := Vector3(-w[4], ya + 0.08 * p, w[1] - 0.12 * p)
	var prev := a
	for i: int in range(1, 6):
		var t := i / 5.0
		var q := a.lerp(b, t) + Vector3(-0.05 * p * sin(PI * t), -0.06 * p * sin(PI * t), 0.0)
		ArmParts.limb(body, "CableSag%d" % i, prev, q, 0.02 * p, 0.02 * p, cable, 6)
		if i == 3:
			var dir := (q - prev).normalized()
			ArmParts.mesh(body, "CableTape", ArmParts.cyl(0.03 * p, 0.05 * p, 0.03 * p, 8),
					ArmMaterials.tape(rng), (prev + q) * 0.5, ArmParts.along(dir))
		prev = q
