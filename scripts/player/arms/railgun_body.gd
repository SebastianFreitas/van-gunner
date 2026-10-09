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
	var rail_mat := ArmMaterials.rail_steel(rng.randf_range(0.0, 100.0))
	var ember := ArmMaterials.ember(rng.randf_range(0.0, 100.0))
	var ya := y_axis
	var zf := z_front
	var ztip := zf - 2.8 * p

	# Receiver over the hand, from the grip top up past the guard's top.
	var rh := ya + 0.40 * p - 0.03
	ArmParts.mesh(body, "Receiver", ArmParts.box(Vector3(0.44 * p, rh, 0.32 * p - zf)), paint,
			Vector3(0.0, 0.03 + rh * 0.5, (0.32 * p + zf) * 0.5))
	_build_caps(body, p, rng, alu, ya)

	# Spine under the rails, 0.002 p below their underside so the faces never coincide.
	var spine_z0 := zf - 0.05 * p
	var spine_z1 := ztip + 0.30 * p
	ArmParts.mesh(body, "Spine", ArmParts.box(Vector3(0.40 * p, 0.418 * p, spine_z0 - spine_z1)),
			paint, Vector3(0.0, ya + 0.009 * p, (spine_z0 + spine_z1) * 0.5))

	# Two rails, their tops level with the receiver's, and the glowing channel between them.
	var rail_z0 := zf - 0.25 * p
	var rail_z1 := ztip + 0.01 * p
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		ArmParts.mesh(body, "Rail" + tag,
				ArmParts.box(Vector3(0.15 * p, 0.18 * p, rail_z0 - rail_z1)), rail_mat,
				Vector3(side * 0.16 * p, ya + 0.31 * p, (rail_z0 + rail_z1) * 0.5))
	var strip_z0 := zf - 0.5 * p
	var strip_z1 := ztip + 0.25 * p
	# Fills the channel (0.17 p between the rails, down to the spine top) up to 0.015 p under the
	# rail tops so it reads as one orange line from above and behind.
	ArmParts.mesh(body, "ChargeStrip", ArmParts.box(Vector3(0.17 * p, 0.167 * p, strip_z0 - strip_z1)),
			ember, Vector3(0.0, ya + 0.3015 * p, (strip_z0 + strip_z1) * 0.5))

	for i: int in range(3):
		_build_clamp(body, p, paint, steel, i, zf - (0.7 + 0.8 * i) * p, ya)

	# Muzzle block with a crude, slightly canted cut face and the two flared rail ends.
	ArmParts.mesh(body, "MuzzleBlock", ArmParts.box(Vector3(0.40 * p, 0.56 * p, 0.30 * p)), paint,
			Vector3(0.0, ya + 0.20 * p, ztip + 0.17 * p), Basis(Vector3.RIGHT, deg_to_rad(5.0)))
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		ArmParts.mesh(body, "RailEnd" + tag, ArmParts.box(Vector3(0.18 * p, 0.24 * p, 0.12 * p)),
				steel, Vector3(side * 0.17 * p, ya + 0.31 * p, ztip + 0.06 * p))

	RailgunJunk.build(body, p, rng, zf, ya)
	body.add_child(RailGlow.new())
	return Vector3(0.0, ya + 0.20 * p, ztip - 0.04 * p)


## One U-bracket under and around the spine and rails, with hex bolt heads on both sides.
static func _build_clamp(body: Node3D, p: float, rust: Material, steel: Material, i: int,
		z: float, ya: float) -> void:
	ArmParts.mesh(body, "ClampBase%d" % i, ArmParts.box(Vector3(0.52 * p, 0.05 * p, 0.14 * p)),
			rust, Vector3(0.0, ya - 0.225 * p, z))
	var side_h := 0.55 * p
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		ArmParts.mesh(body, "ClampArm%s%d" % [tag, i],
				ArmParts.box(Vector3(0.04 * p, side_h, 0.14 * p)), rust,
				Vector3(side * 0.26 * p, ya - 0.2 * p + side_h * 0.5, z))
		for k: int in range(2):
			ArmParts.mesh(body, "ClampBolt%s%d_%d" % [tag, i, k],
					ArmParts.cyl(0.035 * p, 0.03 * p, 0.035 * p, 6), steel,
					Vector3(side * 0.285 * p, ya + (0.25 - 0.3 * k) * p, z),
					ArmParts.along(Vector3(side, 0.0, 0.0)))


## Four capacitor ends on the receiver's rear face, each with a brass post and an amber lamp.
static func _build_caps(body: Node3D, p: float, rng: RandomNumberGenerator, alu: Material,
		ya: float) -> void:
	var brass := ArmMaterials.brass()
	var rear := 0.32 * p
	var n := 0
	for row: int in range(2):
		for col: int in range(2):
			var at := Vector3((-0.11 + 0.22 * col) * p, ya + (0.27 - 0.24 * row) * p, 0.0)
			ArmParts.mesh(body, "Cap%d" % n, ArmParts.cyl(0.11 * p, 0.12 * p, 0.11 * p, 12), alu,
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
