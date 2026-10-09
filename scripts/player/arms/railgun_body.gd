class_name RailgunBody
extends RefCounted
## Held gun body: two steel rails over an orange charge channel, rust clamps, a spine, a muzzle block and a receiver whose rear face shows a 2x2 capacitor bank.


## Builds receiver + rails under `body` (the gun's "Body" node, gun space, -Z forward, +Y up).
## `p` is the palm length, `z_front` the trigger guard's front z, `y_axis` = trigger_y + 0.25 p
## (the guard's top). Returns the muzzle point in gun space.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, z_front: float,
		y_axis: float) -> Vector3:
	# Geometry never depends on rng: the aim must not depend on the seed.
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var alu := ArmMaterials.dull_alu(rng.randf_range(0.0, 100.0))
	var paint := ArmMaterials.gun_paint(rng.randf_range(0.0, 100.0))
	# Darker blued steel so the bars separate from the olive body at the player's distance.
	var rail_mat := ArmMaterials.surface(Color(0.20, 0.25, 0.34), Color(0.11, 0.14, 0.20),
			Color(0.08, 0.08, 0.07), 60.0, 6.0, 0.0, 0.5, 0.6, 0.4, rng.randf_range(0.0, 100.0))
	var ember := ArmMaterials.ember(rng.randf_range(0.0, 100.0))
	var ya := y_axis
	var zf := z_front
	var ztip := zf - 2.8 * p

	# Receiver over the hand, from the grip top up past the guard's top.
	var rh := ya + 0.40 * p - 0.03
	# Octagon with flats up and to the sides (22.5 degrees), stretched in y to the box's height.
	var oct_r := 0.22 * p / cos(deg_to_rad(22.5))
	var flats_up := Basis(Vector3.UP, deg_to_rad(22.5))
	ArmParts.mesh(body, "Receiver", ArmParts.cyl(oct_r, 0.32 * p - zf, oct_r, 8), paint,
			Vector3(0.0, 0.03 + rh * 0.5, (0.32 * p + zf) * 0.5),
			Basis.from_scale(Vector3(1.0, rh / (0.44 * p), 1.0)) * ArmParts.along(Vector3.BACK)
			* flats_up)
	_build_caps(body, p, rng, alu, ya)

	# Round spine tube, as wide as the box it replaced; the rails sit on its upper flanks.
	var spine_z0 := zf - 0.05 * p
	var spine_z1 := ztip + 0.30 * p
	ArmParts.mesh(body, "Spine", ArmParts.cyl(0.20 * p, spine_z0 - spine_z1, 0.20 * p, 12),
			paint, Vector3(0.0, ya + 0.009 * p, (spine_z0 + spine_z1) * 0.5),
			ArmParts.along(Vector3.BACK))

	# Two rails standing 0.40 p above the receiver's apex (0.80 p over the axis against 0.40 p):
	# each is a 0.15 x 0.18 p cap on a 0.09 p web sunk into the tube, so from the eye and
	# from behind they read as two bars with a deep channel (0.17 p wide, 0.38 p deep) between
	# them. The orange line lies at the channel's floor.
	var rail_z0 := 0.32 * p + 0.02 * p
	var rail_z1 := ztip + 0.01 * p
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		ArmParts.mesh(body, "Rail" + tag,
				ArmParts.box(Vector3(0.15 * p, 0.18 * p, rail_z0 - rail_z1)), rail_mat,
				Vector3(side * 0.16 * p, ya + 0.71 * p, (rail_z0 + rail_z1) * 0.5))
		ArmParts.mesh(body, "RailWeb" + tag,
				ArmParts.box(Vector3(0.09 * p, 0.46 * p, rail_z0 - rail_z1)), rail_mat,
				Vector3(side * 0.16 * p, ya + 0.39 * p, (rail_z0 + rail_z1) * 0.5))
	var strip_z0 := zf - 0.5 * p
	var strip_z1 := ztip + 0.25 * p
	# Fills the channel floor (0.17 p between the rails), from the tube's top to 0.42 p.
	ArmParts.mesh(body, "ChargeStrip", ArmParts.box(Vector3(0.17 * p, 0.22 * p, strip_z0 - strip_z1)),
			ember, Vector3(0.0, ya + 0.31 * p, (strip_z0 + strip_z1) * 0.5))
	# The same line over the receiver, a hair above its top flat, so it shows from behind.
	ArmParts.mesh(body, "ChargeStripRear", ArmParts.box(Vector3(0.17 * p, 0.03 * p, 0.32 * p - zf)),
			ember, Vector3(0.0, ya + 0.405 * p, (0.32 * p + zf) * 0.5))

	for i: int in range(3):
		_build_clamp(body, p, paint, steel, i, zf - (0.7 + 0.8 * i) * p, ya)

	# Muzzle nose tapering to 70% at the tip, slightly canted, and the two flared rail ends.
	ArmParts.mesh(body, "MuzzleBlock", ArmParts.cyl(0.7 * oct_r, 0.30 * p, oct_r, 8), paint,
			Vector3(0.0, ya + 0.20 * p, ztip + 0.17 * p),
			Basis(Vector3.RIGHT, deg_to_rad(5.0)) * ArmParts.along(Vector3.FORWARD) * flats_up)
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		ArmParts.mesh(body, "RailEnd" + tag, ArmParts.box(Vector3(0.18 * p, 0.24 * p, 0.12 * p)),
				steel, Vector3(side * 0.17 * p, ya + 0.68 * p, ztip + 0.06 * p))

	RailgunJunk.build(body, p, rng, zf, ya)
	body.add_child(RailGlow.new())
	GunSockets.place(body, p, zf, ya)
	body.add_child(GunAttachments.new())
	return Vector3(0.0, ya + 0.20 * p, ztip - 0.04 * p)


## One U-bracket under and around the round spine, with hex bolt heads on both sides.
static func _build_clamp(body: Node3D, p: float, rust: Material, steel: Material, i: int,
		z: float, ya: float) -> void:
	ArmParts.mesh(body, "ClampBase%d" % i, ArmParts.box(Vector3(0.48 * p, 0.05 * p, 0.14 * p)),
			rust, Vector3(0.0, ya - 0.213 * p, z))
	var side_h := 0.21 * p
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		ArmParts.mesh(body, "ClampArm%s%d" % [tag, i],
				ArmParts.box(Vector3(0.04 * p, side_h, 0.14 * p)), rust,
				Vector3(side * 0.22 * p, ya - 0.2 * p + side_h * 0.5, z))
		for k: int in range(2):
			ArmParts.mesh(body, "ClampBolt%s%d_%d" % [tag, i, k],
					ArmParts.cyl(0.035 * p, 0.03 * p, 0.035 * p, 6), steel,
					Vector3(side * 0.245 * p, ya + (-0.04 - 0.1 * k) * p, z),
					ArmParts.along(Vector3(side, 0.0, 0.0)))


## Four capacitor ends on the receiver's rear face, each with a brass post and an amber lamp.
static func _build_caps(body: Node3D, p: float, rng: RandomNumberGenerator, alu: Material,
		ya: float) -> void:
	var brass := ArmMaterials.brass()
	var rear := 0.32 * p
	var n := 0
	for row: int in range(2):
		for col: int in range(2):
			var at := Vector3((-0.10 + 0.20 * col) * p, ya + (0.29 - 0.20 * row) * p, 0.0)
			ArmParts.mesh(body, "Cap%d" % n, ArmParts.cyl(0.09 * p, 0.12 * p, 0.09 * p, 12), alu,
					at + Vector3(0.0, 0.0, rear - 0.01 * p), ArmParts.along(Vector3.BACK))
			ArmParts.mesh(body, "Post%d" % n, ArmParts.cyl(0.03 * p, 0.044 * p, 0.03 * p, 6),
					brass, at + Vector3(0.0, 0.0, rear + 0.072 * p), ArmParts.along(Vector3.BACK))
			var lamp := SphereMesh.new()
			lamp.radius = 0.025 * p
			lamp.height = 0.05 * p
			lamp.radial_segments = 8
			lamp.rings = 4
			var lamp_mat: Material = ArmMaterials.ember(rng.randf_range(0.0, 100.0))
			ArmParts.mesh(body, "Lamp%d" % n, lamp, lamp_mat,
					at + Vector3(0.0, 0.07 * p, rear + 0.05 * p))
			n += 1
