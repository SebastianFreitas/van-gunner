class_name ArmLampKit
extends RefCounted
## Builds the goblin's scavenged trouble lamp on the right forearm and returns its bulb position.

const BONE := "DEF-forearm.R.001"  ## lower half of the right forearm; +Y runs toward the wrist
const MOUNT_T := 0.55  ## fraction along the bone from its head to the mount
const MOUNT_ANGLE := 0.0  ## degrees around the bone's Y choosing which face the lamp sits on
const LIGHT_LIFT := 0.22  ## omni sits above the bulb so the fixture never lights itself white
const STRAP_H := 0.02  ## strap ring height; two rings 0.14 apart
const BODY_R := 0.035
const BODY_LEN := 0.12
const CAGE_BARS := 4
const CAGE_LEN := 0.1
const BAR_W := 0.012
const BULB_R := 0.032  ## visible inside the cage
const CABLE_R := 0.007  ## half the old width, so it stops reading as a pipe
const CABLE_RUN := 0.12  ## short run back from the body before the cable drops off the arm
const CABLE_DROP := 70.0  ## degrees below the arm axis
const CABLE_SIDE := 0.6  ## sideways share so the drop leaves over the outer side of the arm
const PITCH := 32.0  ## degrees the fixture tilts bulb-end up, aiming the caged bulb at the hands


## Fixture frame (in the forearm bone's space): z along the arm toward the hand, y radially out
## of the forearm. `r_mount` is the arm's real radius at the mount. Returns the light position
## in the space of `model.get_parent()`, or Vector3.ZERO if the bone is missing.
static func build(model: Node3D, r_mount: float, rng: RandomNumberGenerator) -> Vector3:
	var sk := ArmRig.skeleton(model)
	var bi := -1 if sk == null else sk.find_bone(BONE)
	if bi == -1:
		push_warning("ArmLampKit: bone %s not found" % BONE)
		return Vector3.ZERO
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 0
	var bone_len := 0.25
	var hi := sk.find_bone("DEF-hand.R")
	if hi != -1:
		bone_len = sk.get_bone_rest(hi).origin.length()
	var att := BoneAttachment3D.new()
	att.name = "LampMount"
	att.bone_name = BONE
	sk.add_child(att)
	var ax := Vector3.UP
	var roll := deg_to_rad(rng.randf_range(-10.0, 10.0))
	var shift := rng.randf_range(-0.04, 0.04)
	var ang := deg_to_rad(MOUNT_ANGLE) + roll
	var up := Vector3(cos(ang), 0.0, sin(ang))
	# up x ax keeps the basis right-handed, so meshes keep their winding.
	var side := up.cross(ax)
	var flat := Basis(side, up, ax)
	var origin := Vector3(0.0, bone_len * MOUNT_T + shift, 0.0)
	var ring_r := r_mount + 0.01
	# The straps wrap the arm and stay flat; only the lamp tilts toward the hands.
	var strap_frame := Node3D.new()
	strap_frame.name = "LampStrap"
	strap_frame.transform = Transform3D(flat, origin)
	att.add_child(strap_frame)
	var fixture := Node3D.new()
	fixture.name = "ForearmLamp"
	fixture.transform = Transform3D(flat * Basis(Vector3.RIGHT, -deg_to_rad(PITCH)), origin)
	att.add_child(fixture)

	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var pipe := ArmMaterials.pipe(rng.randf_range(0.0, 100.0))
	var tape := ArmMaterials.tape(rng)
	var lamp_mat := ArmMaterials.lamp_body()
	var along_z := ArmParts.along(Vector3.BACK)

	for i: int in range(2):
		var z := -0.07 if i == 0 else 0.07
		ArmParts.mesh(strap_frame, "StrapRing%d" % i,
				ArmParts.cyl(ring_r, STRAP_H, ring_r), tape, Vector3(0.0, 0.0, z), along_z)
		var a := rng.randf_range(0.0, TAU)
		var tail := Vector3(cos(a), sin(a), 0.0) * (ring_r + 0.015) + Vector3(0.0, 0.0, z)
		ArmParts.mesh(strap_frame, "ZipTail%d" % i, ArmParts.box(Vector3(0.01, 0.03, 0.012)), tape,
				tail, Basis(Vector3.BACK, a - PI / 2.0))

	ArmParts.mesh(fixture, "LampBody", ArmParts.cyl(BODY_R, BODY_LEN, BODY_R), lamp_mat,
			Vector3(0.0, r_mount, 0.0), along_z)
	var bulb_local := Vector3(0.0, r_mount, BODY_LEN * 0.5 + BULB_R * 0.6)
	var bulb := SphereMesh.new()
	bulb.radius = BULB_R
	bulb.height = BULB_R * 2.0
	bulb.radial_segments = 8
	bulb.rings = 4
	ArmParts.mesh(fixture, "Bulb", bulb, ArmMaterials.bulb(), bulb_local)

	var cage_z := BODY_LEN * 0.5 + CAGE_LEN * 0.5
	for i: int in range(CAGE_BARS):
		var a := TAU * i / CAGE_BARS + PI / 4.0
		var at := Vector3(cos(a), sin(a), 0.0) * (BULB_R + 0.015)
		ArmParts.mesh(fixture, "CageBar%d" % i,
				ArmParts.box(Vector3(BAR_W, BAR_W, CAGE_LEN)), steel,
				Vector3(0.0, r_mount, cage_z) + at)
	ArmParts.mesh(fixture, "CageRing",
			ArmParts.cyl(BULB_R + 0.02, BAR_W, BULB_R + 0.02), steel,
			Vector3(0.0, r_mount, BODY_LEN * 0.5 + CAGE_LEN), along_z)

	var back_z := -BODY_LEN * 0.5
	ArmParts.mesh(fixture, "Cable0", ArmParts.cyl(CABLE_R, CABLE_RUN, CABLE_R), pipe,
			Vector3(0.0, r_mount, back_z - CABLE_RUN * 0.5), along_z)
	var d2 := Vector3(CABLE_SIDE, -sin(deg_to_rad(CABLE_DROP)),
			-cos(deg_to_rad(CABLE_DROP))).normalized()
	var end := Vector3(0.0, r_mount, back_z - CABLE_RUN)
	ArmParts.mesh(fixture, "Cable1", ArmParts.cyl(CABLE_R, 0.45, CABLE_R), pipe,
			end + d2 * 0.225, ArmParts.along(d2))
	# Same chain `ArmRig.reach` uses for `to_rig`; the forearm bone is static after the IK.
	var to_root := Transform3D.IDENTITY
	var node: Node = sk
	while node != model.get_parent() and node is Node3D:
		to_root = (node as Node3D).transform * to_root
		node = node.get_parent()
	var light_local := bulb_local + Vector3(0.0, LIGHT_LIFT, 0.0)
	return to_root * (sk.get_bone_global_pose(bi) * fixture.transform * light_local)
