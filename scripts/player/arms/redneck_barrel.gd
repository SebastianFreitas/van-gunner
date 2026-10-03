class_name RedneckBarrel
extends RefCounted
## Receiver, ribbed shroud, stacked lower barrel and muzzle of the held gun, pieced together from mismatched junk plates.


## Builds receiver + barrel under `body` (the gun's "Body" node, gun space, -Z forward, +Y up).
## `p` is the palm length, `z_front` the trigger guard's front z, `y_axis` = trigger_y + 0.25 p
## (the guard's top). Returns the muzzle point in gun space.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, z_front: float,
		y_axis: float) -> Vector3:
	# Geometry never depends on rng: the aim must not depend on the seed.
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var rust := ArmMaterials.rust(rng.randf_range(0.0, 100.0))
	var alu := ArmMaterials.dull_alu(rng.randf_range(0.0, 100.0))
	var tape := ArmMaterials.tape(rng)
	var dark := ArmMaterials.grip_rubber()
	var ya := y_axis
	var zf := z_front
	var ztip := zf - 2.8 * p
	var fwd := ArmParts.along(Vector3.FORWARD)

	# Receiver over the hand, from the grip top up past the guard's top.
	var rh := ya + 0.40 * p - 0.03
	ArmParts.mesh(body, "Receiver", ArmParts.box(Vector3(0.44 * p, rh, 0.32 * p - zf)), steel,
			Vector3(0.0, 0.03 + rh * 0.5, (0.32 * p + zf) * 0.5))
	# Bolted-on patch plate, proud of both sides.
	ArmParts.mesh(body, "ReceiverPatch", ArmParts.box(Vector3(0.46 * p, 0.20 * p, 0.40 * p)), rust,
			Vector3(0.0, ya + 0.22 * p, zf + 0.35 * p))

	# Shroud: three mismatched plates, stepped so the outline is uneven.
	ArmParts.mesh(body, "PlateRear", ArmParts.box(Vector3(0.46 * p, 0.50 * p, 0.90 * p)), steel,
			Vector3(0.0, ya + 0.20 * p, zf - 0.45 * p))
	ArmParts.mesh(body, "PlateMid", ArmParts.box(Vector3(0.44 * p, 0.46 * p, 1.00 * p)), rust,
			Vector3(0.0, ya + 0.18 * p, zf - 1.40 * p))
	ArmParts.mesh(body, "PlateFront", ArmParts.box(Vector3(0.47 * p, 0.52 * p, 0.90 * p)), alu,
			Vector3(0.0, ya + 0.21 * p, zf - 2.35 * p))

	# Top rail with ribs and sights.
	ArmParts.mesh(body, "TopRail", ArmParts.box(Vector3(0.18 * p, 0.10 * p, 2.80 * p)), steel,
			Vector3(0.0, ya + 0.45 * p, zf - 1.40 * p))
	for i: int in range(13):
		ArmParts.mesh(body, "RailRib%d" % i, ArmParts.box(Vector3(0.24 * p, 0.05 * p, 0.05 * p)),
				steel, Vector3(0.0, ya + 0.525 * p, zf - (0.15 + 0.2 * i) * p))
	ArmParts.mesh(body, "RearSight", ArmParts.box(Vector3(0.10 * p, 0.10 * p, 0.04 * p)), steel,
			Vector3(0.0, ya + 0.43 * p, 0.22 * p))
	ArmParts.mesh(body, "FrontSight", ArmParts.box(Vector3(0.04 * p, 0.10 * p, 0.04 * p)), steel,
			Vector3(0.0, ya + 0.58 * p, ztip + 0.12 * p))

	# Lower barrel stacked under the shroud, taped and hose-clamped.
	var yl := ya - 0.15 * p
	ArmParts.mesh(body, "LowerBarrel", ArmParts.cyl(0.10 * p, 2.5 * p, 0.10 * p, 8), steel,
			Vector3(0.0, yl, zf - 1.40 * p), fwd)
	ArmParts.mesh(body, "LowerBore", ArmParts.cyl(0.07 * p, 0.04 * p, 0.07 * p), dark,
			Vector3(0.0, yl, zf - 2.66 * p), fwd)
	ArmParts.mesh(body, "TapeA", ArmParts.cyl(0.115 * p, 0.14 * p, 0.115 * p, 8), tape,
			Vector3(0.0, yl, zf - 0.8 * p), fwd)
	ArmParts.mesh(body, "TapeB", ArmParts.cyl(0.115 * p, 0.14 * p, 0.115 * p, 8), tape,
			Vector3(0.0, yl, zf - 1.9 * p), fwd)
	ArmParts.mesh(body, "Clamp", ArmParts.cyl(0.125 * p, 0.05 * p, 0.125 * p, 8), steel,
			Vector3(0.0, yl, zf - 2.3 * p), fwd)
	# Braces between the barrels, overlapping both.
	ArmParts.mesh(body, "Brace0", ArmParts.box(Vector3(0.10 * p, 0.20 * p, 0.10 * p)), rust,
			Vector3(0.0, ya - 0.02 * p, zf - 0.9 * p))
	ArmParts.mesh(body, "Brace1", ArmParts.box(Vector3(0.10 * p, 0.20 * p, 0.10 * p)), rust,
			Vector3(0.0, ya - 0.02 * p, zf - 2.0 * p))

	# Muzzle block and bore.
	ArmParts.mesh(body, "MuzzleBlock", ArmParts.box(Vector3(0.52 * p, 0.56 * p, 0.20 * p)), alu,
			Vector3(0.0, ya + 0.22 * p, ztip + 0.10 * p))
	ArmParts.mesh(body, "Bore", ArmParts.cyl(0.10 * p, 0.04 * p, 0.10 * p, 8), dark,
			Vector3(0.0, ya + 0.20 * p, ztip - 0.005), fwd)

	# Three recessed-looking side windows on the middle plate, proud of it by 0.005 p.
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		for i: int in range(3):
			ArmParts.mesh(body, "Window%s%d" % [tag, i],
					ArmParts.box(Vector3(0.02 * p, 0.16 * p, 0.22 * p)), dark,
					Vector3(side * 0.225 * p, ya + 0.18 * p, zf - (1.05 + 0.3 * i) * p))

	# Stitch welds: five beads per seam per side, then eight along the shroud's underside.
	var seams: Array[float] = [zf - 0.90 * p, zf - 1.90 * p, zf]
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		var n := 0
		for sz: float in seams:
			for off: float in [-0.18, -0.09, 0.0, 0.09, 0.18]:
				ArmParts.mesh(body, "Weld%s%d" % [tag, n],
						ArmParts.box(Vector3(0.07 * p, 0.03 * p, 0.05 * p)), steel,
						Vector3(side * 0.235 * p, ya + 0.20 * p + off * p, sz))
				n += 1
	for i: int in range(8):
		ArmParts.mesh(body, "WeldBottom%d" % i,
				ArmParts.box(Vector3(0.05 * p, 0.03 * p, 0.07 * p)), steel,
				Vector3(0.0, ya - 0.05 * p, zf - (0.2 + 0.3 * i) * p))

	return Vector3(0.0, ya + 0.20 * p, ztip - 0.04 * p)
