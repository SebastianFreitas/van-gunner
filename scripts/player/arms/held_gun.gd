class_name HeldGun
extends RefCounted
## The Desert-Eagle-style pistol the arms hold: a shared holder (grip, guard, trigger, frame) plus a per-gun barrel block.

## Grip centre in rig space (camera at the origin, -Z forward, +X right).
const GRIP := Vector3(0.40, -0.42, -0.82)
## Gun yawed inward so the muzzle points at the screen centre.
const CANT := 5.0 * PI / 180.0
## Rake of the grip: its bottom sits further back than its top.
const RAKE := 18.0 * PI / 180.0
## Muzzle tip in gun space; written by `build` from the barrel, so the aim never depends on
## the seed (the barrel block is a fixed size).
static var muzzle_in_gun := Vector3(0.0, 0.14, -0.6)
## Fore-end (where the left hand supports the barrel) in gun space; written by `build`.
static var fore_end_in_gun := Vector3(0.0, 0.08, -0.45)
## Bottom of the grip in gun space, where the left hand slaps the magazine; written by `build`.
static var mag_slap_in_gun := Vector3(0.0, -0.3, 0.1)

## Top of the grip axis in body space.
const _TOP := Vector3(0.0, 0.03, -0.01)


static func gun_xform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, CANT), GRIP)


static func muzzle_local() -> Vector3:
	return gun_xform() * muzzle_in_gun


static func fore_end_local() -> Vector3:
	return gun_xform() * fore_end_in_gun


## Builds the pistol under a "Gun" root the caller animates; `palm_len` is the right hand's
## palm length, which every dimension scales from. The lamp's rig-space spot is stored in
## the root's `lamp_local` meta.
static func build(rng: RandomNumberGenerator, palm_len: float = 0.22) -> Node3D:
	var p := palm_len if palm_len > 0.0 else 0.22
	var root := Node3D.new()
	root.name = "Gun"
	root.set_meta(&"palm_len", p)
	var body := Node3D.new()
	body.name = "Body"
	body.transform = gun_xform()
	root.add_child(body)

	_build_grip(body, p, rng)
	_build_guard_and_trigger(body, p, rng)
	_build_frame(body, p, rng)
	_build_barrel(body, p, rng)

	var y0 := _TOP.y + 0.36 * p
	var down := Vector3(0.0, -cos(RAKE), sin(RAKE))
	muzzle_in_gun = Vector3(0.0, y0 + 0.25 * p, 0.20 * p - 2.80 * p - 0.02)
	fore_end_in_gun = Vector3(0.0, y0 - 0.06 * p, 0.20 * p - 2.30 * p)
	mag_slap_in_gun = _TOP + (1.35 * p + 0.10 * p) * down
	# Under the barrel's left flank.
	root.set_meta(&"lamp_local",
			gun_xform() * Vector3(-0.19 * p, y0 - 0.10 * p, 0.20 * p - 2.0 * p))
	return root


## The palm length the gun was built with, scaled by the hand scale, so every gun point
## (muzzle, fore-end, mag slap, lamp) is computed from the same number as the geometry.
static func palm_len_of(gun_root: Node3D) -> float:
	return float(gun_root.get_meta(&"palm_len", 0.22))


## The grip the right hand closes on: steel core, rubber panels with screws, a floor plate
## and three finger grooves on the front strap.
static func _build_grip(body: Node3D, p: float, rng: RandomNumberGenerator) -> void:
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var rubber := ArmMaterials.grip_rubber()
	var length := 1.35 * p
	var down := Vector3(0.0, -cos(RAKE), sin(RAKE))
	var centre := _TOP + 0.5 * length * down
	var gb := Basis(Vector3.RIGHT, -RAKE)

	ArmParts.mesh(body, "GripCore", ArmParts.box(Vector3(0.34 * p, length, 0.62 * p)), steel,
			centre, gb)
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		ArmParts.mesh(body, "GripPanel" + tag,
				ArmParts.box(Vector3(0.07 * p, 0.78 * length, 0.50 * p)), rubber,
				centre + gb * Vector3(side * 0.17 * p, -0.04 * length, 0.02 * p), gb)
		for k: float in [-1.0, 1.0]:
			ArmParts.mesh(body, "GripScrew%s%d" % [tag, int(k)],
					ArmParts.cyl(0.03 * p, 0.02 * p, 0.03 * p), steel,
					centre + gb * Vector3(side * 0.205 * p,
							-0.04 * length + k * 0.28 * length, 0.02 * p),
					gb * ArmParts.along(Vector3.RIGHT))
	ArmParts.mesh(body, "FloorPlate", ArmParts.box(Vector3(0.40 * p, 0.07 * length, 0.72 * p)),
			steel, _TOP + length * down, gb)
	for i: int in range(3):
		var f := 0.30 + 0.20 * i
		ArmParts.mesh(body, "GripRidge%d" % i,
				ArmParts.box(Vector3(0.34 * p, 0.045 * length, 0.05 * p)), steel,
				centre + gb * Vector3(0.0, length * (0.5 - f), -0.31 * p), gb)


## Squared trigger guard of four limbs, and the trigger inside it.
static func _build_guard_and_trigger(body: Node3D, p: float, rng: RandomNumberGenerator) -> void:
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var a := Vector3(0.0, 0.03, -0.30 * p)
	var b := Vector3(0.0, -0.42 * p, -0.30 * p)
	var c := Vector3(0.0, -0.42 * p, -1.05 * p)
	var d := Vector3(0.0, 0.03, -1.05 * p)
	var r := 0.035 * p
	ArmParts.limb(body, "GuardRear", a, b, r, r, steel)
	ArmParts.limb(body, "GuardBottom", b, c, r, r, steel)
	ArmParts.limb(body, "GuardFront", c, d, r, r, steel)
	ArmParts.limb(body, "GuardJoin", d, d + Vector3(0.0, 0.08 * p, 0.0), r, r, steel)
	ArmParts.mesh(body, "Trigger", ArmParts.box(Vector3(0.09 * p, 0.34 * p, 0.09 * p)), steel,
			Vector3(0.0, 0.03 - 0.20 * p, -0.62 * p), Basis(Vector3.RIGHT, deg_to_rad(-12.0)))


## The frame stub above the grip: frame box, beavertail over the web of the hand, hammer.
static func _build_frame(body: Node3D, p: float, rng: RandomNumberGenerator) -> void:
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	ArmParts.mesh(body, "Frame", ArmParts.box(Vector3(0.38 * p, 0.36 * p, 1.55 * p)), steel,
			Vector3(0.0, 0.03 + 0.18 * p, 0.32 * p - 0.775 * p))
	ArmParts.mesh(body, "Beavertail", ArmParts.box(Vector3(0.30 * p, 0.05 * p, 0.30 * p)),
			steel, Vector3(0.0, 0.03, 0.40 * p), Basis(Vector3.RIGHT, deg_to_rad(25.0)))
	ArmParts.mesh(body, "Hammer", ArmParts.box(Vector3(0.10 * p, 0.22 * p, 0.08 * p)), steel,
			Vector3(0.0, 0.03 + 0.36 * p + 0.09 * p, 0.26 * p),
			Basis(Vector3.RIGHT, deg_to_rad(20.0)))


## The per-gun part: a placeholder barrel block that later guns swap for their own.
static func _build_barrel(body: Node3D, p: float, rng: RandomNumberGenerator) -> void:
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var rubber := ArmMaterials.grip_rubber()
	var y0 := 0.03 + 0.36 * p
	ArmParts.mesh(body, "Barrel", ArmParts.box(Vector3(0.38 * p, 0.50 * p, 2.80 * p)), steel,
			Vector3(0.0, y0 + 0.25 * p, 0.20 * p - 1.40 * p))
	ArmParts.mesh(body, "Bore", ArmParts.cyl(0.10 * p, 0.04 * p, 0.10 * p), rubber,
			Vector3(0.0, y0 + 0.25 * p, 0.20 * p - 2.80 * p - 0.01),
			ArmParts.along(Vector3.FORWARD))
