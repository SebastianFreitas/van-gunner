class_name HeldGun
extends RefCounted
## The scavenged pipe rifle the arms hold: receiver, pipe barrel, taped grip, lamp fixture and sling, built from one seed.

## Grip centre in rig space (camera at the origin, -Z forward, +X right).
const GRIP := Vector3(0.40, -0.42, -0.95)
## Rifle yawed inward so the muzzle points at the screen centre.
const CANT := 5.0 * PI / 180.0
## Muzzle and fore-end in gun space; fixed so the aim never depends on the seed.
const MUZZLE_IN_GUN := Vector3(0.0, 0.09, -1.13)
const FORE_END_IN_GUN := Vector3(0.0, -0.02, -0.48)


static func gun_xform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, CANT), GRIP)


static func muzzle_local() -> Vector3:
	return gun_xform() * MUZZLE_IN_GUN


static func fore_end() -> Vector3:
	return gun_xform() * FORE_END_IN_GUN


## Builds the rifle under a "Gun" root the caller animates; the lamp's rig-space spot is
## stored in the root's `lamp_local` meta.
static func build(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Gun"
	var body := Node3D.new()
	body.name = "Body"
	body.transform = gun_xform()
	root.add_child(body)

	# Draw order is part of the design: it keeps the same seed giving the same rifle.
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var pipe := ArmMaterials.pipe(rng.randf_range(0.0, 100.0))
	var tape := ArmMaterials.tape(rng)
	var wood := ArmMaterials.grip_wood()
	var lamp_mat := ArmMaterials.lamp_body()
	var lens := ArmMaterials.lens()
	var leather := ArmMaterials.leather()

	ArmParts.mesh(body, "Grip", ArmParts.box(Vector3(0.07, 0.20, 0.09)), wood,
			Vector3(0.0, -0.09, 0.02), Basis(Vector3.RIGHT, deg_to_rad(18.0)))
	ArmParts.mesh(body, "Receiver", ArmParts.box(Vector3(0.10, 0.14, 0.42)), steel,
			Vector3(0.0, 0.06, -0.10))
	ArmParts.mesh(body, "ChargingHandle", ArmParts.box(Vector3(0.06, 0.025, 0.03)), steel,
			Vector3(-0.08, 0.09, -0.02))
	ArmParts.mesh(body, "ChargingKnob", ArmParts.cyl(0.018, 0.03, 0.018), steel,
			Vector3(-0.115, 0.09, -0.02), ArmParts.along(Vector3.RIGHT))

	# Skeletal pipe stock: two rails and a butt plate, no slab.
	ArmParts.limb(body, "StockTop", Vector3(0.0, 0.08, 0.11), Vector3(0.0, 0.06, 0.45),
			0.016, 0.016, pipe)
	ArmParts.limb(body, "StockLow", Vector3(0.0, -0.02, 0.08), Vector3(0.0, -0.04, 0.45),
			0.016, 0.016, pipe)
	ArmParts.mesh(body, "Butt", ArmParts.box(Vector3(0.06, 0.18, 0.03)), steel,
			Vector3(0.0, 0.01, 0.46))

	ArmParts.limb(body, "Barrel", Vector3(0.0, 0.09, -0.31), Vector3(0.0, 0.09, -1.05),
			0.028, 0.028, pipe)
	ArmParts.mesh(body, "Brake", ArmParts.cyl(0.045, 0.08, 0.045), steel,
			Vector3(0.0, 0.09, -1.09), ArmParts.along(Vector3.FORWARD))
	for i: int in range(3):
		ArmParts.mesh(body, "BrakeSlot%d" % i, ArmParts.box(Vector3(0.095, 0.012, 0.014)),
				lamp_mat, Vector3(0.0, 0.09, -1.07 - 0.02 * i))
	ArmParts.mesh(body, "Handguard", ArmParts.box(Vector3(0.09, 0.08, 0.30)), wood,
			Vector3(0.0, 0.03, -0.47))

	if rng.randf() < 0.5:
		ArmParts.mesh(body, "Drum", ArmParts.cyl(0.11, 0.07, 0.11), steel,
				Vector3(0.0, -0.10, -0.22), ArmParts.along(Vector3.RIGHT))
	else:
		ArmParts.mesh(body, "Magazine", ArmParts.box(Vector3(0.06, 0.22, 0.10)), steel,
				Vector3(0.0, -0.12, -0.22), Basis(Vector3.RIGHT, deg_to_rad(10.0)))

	ArmParts.limb(body, "TriggerGuardA", Vector3(0.0, -0.01, -0.04), Vector3(0.0, -0.07, -0.06),
			0.008, 0.008, steel)
	ArmParts.limb(body, "TriggerGuardB", Vector3(0.0, -0.07, -0.06), Vector3(0.0, -0.07, 0.0),
			0.008, 0.008, steel)
	ArmParts.mesh(body, "Trigger", ArmParts.box(Vector3(0.012, 0.04, 0.012)), steel,
			Vector3(0.0, -0.035, -0.03))

	ArmParts.mesh(body, "RearSight", ArmParts.box(Vector3(0.05, 0.03, 0.02)), steel,
			Vector3(0.0, 0.15, -0.25))
	ArmParts.mesh(body, "FrontSight", ArmParts.box(Vector3(0.012, 0.05, 0.012)), steel,
			Vector3(0.0, 0.14, -1.0))

	# The lamp is taped to the left of the barrel, where the camera sees it.
	ArmParts.mesh(body, "LampBody", ArmParts.cyl(0.035, 0.12, 0.035), lamp_mat,
			Vector3(-0.07, 0.04, -0.62), ArmParts.along(Vector3.FORWARD))
	ArmParts.mesh(body, "Lens", ArmParts.cyl(0.03, 0.01, 0.03), lens,
			Vector3(-0.07, 0.04, -0.685), ArmParts.along(Vector3.FORWARD))
	for i: int in range(2):
		ArmParts.mesh(body, "LampTape%d" % i, ArmParts.cyl(0.04, 0.02, 0.04), tape,
				Vector3(-0.07, 0.04, -0.60 - 0.04 * i), ArmParts.along(Vector3.FORWARD))
	root.set_meta(&"lamp_local", gun_xform() * Vector3(-0.07, 0.04, -0.695))

	var bands := rng.randi_range(2, 4)
	for i: int in range(bands):
		var h := rng.randf_range(0.02, 0.04)
		ArmParts.mesh(body, "Tape%d" % i, ArmParts.cyl(0.034, h, 0.034), tape,
				Vector3(0.0, 0.09, rng.randf_range(-0.95, -0.40)),
				ArmParts.along(Vector3.FORWARD))

	var sling := MachineParts.cable_bundle(body, PackedVector3Array([
			Vector3(0.0, 0.01, 0.46), Vector3(0.03, -0.30, 0.15),
			Vector3(0.02, -0.22, -0.30), Vector3(0.0, 0.0, -0.55)]), leather, 0.015, 1)
	# The bundle's meshes are already on layer 2; only its shadows need turning off.
	for node: Node in sling.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
