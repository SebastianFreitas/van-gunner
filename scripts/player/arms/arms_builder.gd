class_name ArmsBuilder
extends RefCounted
## Builds seeded skinned goblin arms (CC0 rigged model, grime skin) posed by ArmRig on the pipe rifle, dressed from the van seed.

const RIGHT_SHOULDER := Vector3(1.15, -1.05, 0.0)
const RIGHT_POLE := Vector3(1.0, -0.2, 0.3)
## Wrist, finger direction and palm normal on the grip, in gun space.
const RIGHT_WRIST_IN_GUN := Vector3(0.08, -0.13, 0.17)
const RIGHT_HAND_DIR_IN_GUN := Vector3(-0.05, 0.25, -1.0)
const RIGHT_PALM_IN_GUN := Vector3(-1.0, 0.0, 0.0)
## Low and off-frame left of the camera (camera = 0.18 * rig point), so only the forearm and hand show.
const LEFT_SHOULDER := Vector3(-1.2, -1.3, -0.45)
## The held pistol is shown while the hand pose is reworked around its holder.
const SHOW_GUN := true
## Where the relaxed left wrist sits when shown (looking down, reloading): the lower-left of the frame.
const LEFT_SHOWN_WRIST := Vector3(-0.95, -0.62, -1.05)
const LEFT_HANG_POLE := Vector3(-1.0, -0.6, 0.2)
const LEFT_HANG_HAND_DIR := Vector3(0.1, -0.5, -1.0)
## How far the straightened left hand droops below its forearm line (a relaxed hang).
const LEFT_WRIST_DROP := 0.15
## Weave pose (gun hidden): wrists raised in front, forearms angled in, palms down and inward.
const RIGHT_WEAVE_WRIST := Vector3(0.62, -0.50, -1.00)
const LEFT_WEAVE_WRIST := Vector3(-0.62, -0.52, -1.00)
const RIGHT_WEAVE_PALM := Vector3(-0.6, -0.8, 0.1)  ## palm normal: down, toward the body centre
const LEFT_WEAVE_PALM := Vector3(0.6, -0.8, 0.1)
const WEAVE_WRIST_LIFT := 0.18  ## UP added to the forearm line: about 10 deg of wrist extension
## Palm toward the body.
const LEFT_HANG_PALM := Vector3(1, 0, 0)
## Finger joint curls in degrees for joints .01/.02/.03.
const RIGHT_CURL := {
	&"f_index": Vector3(20, 25, 15), &"f_middle": Vector3(40, 45, 30),
	&"f_ring": Vector3(40, 45, 30), &"f_pinky": Vector3(40, 45, 30),
	&"thumb": Vector3(15, 10, 15),
}
## Extra euler degrees on the right thumb's first bone after the curl: lifts the thumb out of
## the grip and lays it over the frame's left flank (the curl alone only bends it about one axis).
const RIGHT_THUMB_AIM := Vector3(-20, 40, -40)
const LEFT_CURL := {
	&"f_index": Vector3(25, 30, 20), &"f_middle": Vector3(25, 30, 20),
	&"f_ring": Vector3(25, 30, 20), &"f_pinky": Vector3(25, 30, 20),
	&"thumb": Vector3(10, 15, 10),
}
const ELBOW_JITTER := 0.03
## Bare forearm radii in model units before bulk; times the seeded scale and ArmBulk's gain where used.
const FOREARM_R_ELBOW := 0.075
const FOREARM_R_WRIST := 0.06


static func rng_for(seed_value: int, part_id: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, part_id])
	return rng


static func build(rig: Node3D, seed_value: int, _van_name: String) -> Dictionary:
	var rng := rng_for(seed_value, &"arms")
	var skin := ArmMaterials.skin(rng)
	var s := rng.randf_range(1.12, 1.28)
	var tip_k := rng.randf_range(1.0, 1.35)
	var claw_len := rng.randf_range(0.04, 0.08)
	var bulk := rng.randf_range(0.85, 1.15)
	var claw := ArmMaterials.claw()
	var gx := HeldGun.gun_xform()

	# Right arm: bare, holds the grip.
	var right := Node3D.new()
	right.name = "ArmRight"
	var rng_r := rng_for(seed_value, &"arm_right")
	var muscle_r := rng_r.randi()
	var model_r := ArmRig.spawn(&"R", s, bulk, muscle_r)
	right.add_child(model_r)
	var gun_root := HeldGun.build(rng_for(seed_value, &"arm_gun"), ArmRig.palm_len(model_r))
	gun_root.visible = SHOW_GUN
	var shoulder_r := RIGHT_SHOULDER + _jitter(rng_r)
	var r: Dictionary
	if SHOW_GUN:
		r = ArmRig.reach(model_r, ".R", shoulder_r,
				gx * RIGHT_WRIST_IN_GUN, RIGHT_POLE,
				(gx.basis * RIGHT_HAND_DIR_IN_GUN).normalized(),
				(gx.basis * RIGHT_PALM_IN_GUN).normalized())
	else:
		r = ArmRig.reach(model_r, ".R", shoulder_r, RIGHT_WEAVE_WRIST, RIGHT_POLE,
				(RIGHT_WEAVE_WRIST - shoulder_r).normalized(),
				RIGHT_WEAVE_PALM.normalized())
		var fore_r := (Vector3(r.wrist) - Vector3(r.elbow)).normalized()
		r = ArmRig.reach(model_r, ".R", shoulder_r, RIGHT_WEAVE_WRIST, RIGHT_POLE,
				(fore_r + Vector3.UP * WEAVE_WRIST_LIFT).normalized(),
				RIGHT_WEAVE_PALM.normalized())
	ArmRig.curl(model_r, ".R", RIGHT_CURL)
	var sk_r := ArmRig.skeleton(model_r)
	var thumb_i := sk_r.find_bone("DEF-thumb.01.R")
	if SHOW_GUN and thumb_i != -1:
		sk_r.set_bone_pose_rotation(thumb_i, sk_r.get_bone_pose_rotation(thumb_i)
				* Quaternion.from_euler(RIGHT_THUMB_AIM * (PI / 180.0)))
	ArmRig.stretch_tips(model_r, ".R", tip_k)
	ArmRig.add_claws(model_r, ".R", claw_len, claw)
	_skin_model(model_r, skin)

	# s is 1.0: the lamp attaches inside the model that `s` already scales.
	var lamp_t := 0.5 + 0.5 * ArmLampKit.MOUNT_T
	var r_mount := _fore_r(lerpf(FOREARM_R_ELBOW, FOREARM_R_WRIST, lamp_t),
			lerpf(ArmBulk.FOREARM_ELBOW_GAIN, ArmBulk.FOREARM_WRIST_GAIN, lamp_t), 1.0, bulk)
	var bulb := ArmLampKit.build(model_r, r_mount, rng_for(seed_value, &"arm_lamp"))
	# After the lamp so the dress stream never shifts the lamp's.
	ArmDress.right(model_r, rng_for(seed_value, &"arm_dress_r"))

	# Left arm: hangs relaxed at the side.
	var left := Node3D.new()
	left.name = "ArmLeft"
	var rng_l := rng_for(seed_value, &"arm_left")
	var muscle_l := rng_l.randi()
	var model_l := ArmRig.spawn(&"L", s, bulk, muscle_l)
	left.add_child(model_l)
	var shoulder_l := LEFT_SHOULDER + _jitter(rng_l)
	var l: Dictionary
	if SHOW_GUN:
		l = ArmRig.reach(model_l, ".L", shoulder_l,
				LEFT_SHOWN_WRIST, LEFT_HANG_POLE,
				LEFT_HANG_HAND_DIR.normalized(), LEFT_HANG_PALM)
		# Pose again with the hand along the forearm: a sharply bent hand pokes its slim wrist
		# out under the fat forearm's open end.
		var fore_dir := (Vector3(l.wrist) - Vector3(l.elbow)).normalized()
		l = ArmRig.reach(model_l, ".L", shoulder_l, LEFT_SHOWN_WRIST, LEFT_HANG_POLE,
				(fore_dir + Vector3.DOWN * LEFT_WRIST_DROP).normalized(), LEFT_HANG_PALM)
	else:
		l = ArmRig.reach(model_l, ".L", shoulder_l, LEFT_WEAVE_WRIST, LEFT_HANG_POLE,
				(LEFT_WEAVE_WRIST - shoulder_l).normalized(),
				LEFT_WEAVE_PALM.normalized())
		var fore_l := (Vector3(l.wrist) - Vector3(l.elbow)).normalized()
		l = ArmRig.reach(model_l, ".L", shoulder_l, LEFT_WEAVE_WRIST, LEFT_HANG_POLE,
				(fore_l + Vector3.UP * WEAVE_WRIST_LIFT).normalized(),
				LEFT_WEAVE_PALM.normalized())
	ArmRig.curl(model_l, ".L", LEFT_CURL)
	ArmRig.stretch_tips(model_l, ".L", tip_k)
	ArmRig.add_claws(model_l, ".L", claw_len, claw)
	_skin_model(model_l, skin)
	ArmDress.left(model_l, rng_for(seed_value, &"arm_dress_l"))

	rig.add_child(left)
	rig.add_child(right)
	rig.add_child(gun_root)
	return {
		"left_root": left,
		"right_root": right,
		"gun_root": gun_root,
		"left_wrist": l["wrist"],
		"lamp_local": bulb,
	}


## Skins the arm mesh: the skeleton's direct meshes, not the claw cones under its attachments.
static func _skin_model(model: Node3D, skin: Material) -> void:
	for c in ArmRig.skeleton(model).get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = skin


static func _fore_r(base: float, gain: float, s: float, bulk: float) -> float:
	return base * s * (1.0 + (gain - 1.0) * bulk)


static func _jitter(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(
		rng.randf_range(-ELBOW_JITTER, ELBOW_JITTER),
		rng.randf_range(-ELBOW_JITTER, ELBOW_JITTER),
		rng.randf_range(-ELBOW_JITTER, ELBOW_JITTER))
