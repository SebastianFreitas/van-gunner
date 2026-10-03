class_name ArmsBuilder
extends RefCounted
## Builds seeded skinned goblin arms (CC0 rigged model, grime skin) posed by ArmRig on the pipe rifle, dressed from the van seed.

const RIGHT_SHOULDER := Vector3(1.12, -0.72, -0.27)
const RIGHT_POLE := Vector3(1.0, -0.2, 0.3)
## Wrist, finger direction and palm normal on the grip, in gun space.
const RIGHT_WRIST_IN_GUN := Vector3(0.08, -0.13, 0.17)
const RIGHT_HAND_DIR_IN_GUN := Vector3(-0.05, 0.25, -1.0)
const RIGHT_PALM_IN_GUN := Vector3(-1.0, 0.0, 0.0)
## Low and off-frame left of the camera (camera = 0.18 * rig point), so only the forearm and hand show.
const LEFT_SHOULDER := Vector3(-1.35, -1.35, -0.3)
## The held pistol is shown while the hand pose is reworked around its holder.
const SHOW_GUN := true
## Where the relaxed left wrist sits when shown (looking down, reloading): the lower-left of the frame.
const LEFT_SHOWN_WRIST := Vector3(-1.1, -0.62, -1.25)
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
## The gripping thumb's curl in degrees for joints .01/.02/.03, split out so it can be tuned live.
const RIGHT_THUMB_CURL := Vector3(15, 45, 60)
## Finger joint curls in degrees for joints .01/.02/.03.
const RIGHT_CURL := {
	&"f_index": Vector3(20, 25, 15), &"f_middle": Vector3(40, 45, 30),
	&"f_ring": Vector3(40, 45, 30), &"f_pinky": Vector3(40, 45, 30),
	&"thumb": RIGHT_THUMB_CURL,
}
## Extra euler degrees on the right thumb's first bone after the curl: lifts the thumb out of
## the grip and lays it over the frame's left flank (the curl alone only bends it about one axis).
## Swept with `arms fit`: .01 near vertical, .02 leaning left, .03 hooked onto the flank.
const RIGHT_THUMB_AIM := Vector3(-40, 70, -55)
## Live copies of the gripping hand's tunables: the `arms thumbaim`, `arms thumbcurl` and
## `arms wrist` console commands set them and rebuild, so a thumb pose is tuned by numbers
## instead of a screenshot per try. The constants above are their defaults.
static var right_thumb_aim := RIGHT_THUMB_AIM
static var right_thumb_curl := RIGHT_THUMB_CURL
static var right_wrist_in_gun := RIGHT_WRIST_IN_GUN
const LEFT_CURL := {
	&"f_index": Vector3(25, 30, 20), &"f_middle": Vector3(25, 30, 20),
	&"f_ring": Vector3(25, 30, 20), &"f_pinky": Vector3(25, 30, 20),
	&"thumb": Vector3(10, 15, 10),
}
const ELBOW_JITTER := 0.03
## Pose scale on each thumb's .02 bone (its .03 inherits it), so the thumb outreaches the fingers.
const THUMB_STRETCH := 1.2
## Arm, hand and claw proportions are fixed, not seeded: randomized thickness made the nails
## and the gun fit inconsistent between runs. Pose scale on each arm model, and the stretch of
## the fingertip bones.
const ARM_SCALE := 1.20
const TIP_K := 1.15
## Fixed for the same reason. Fingers twice as thick as a human's and the hand half again as big
## are the monster read the owner asked for (2026-10-02); the claw share rises so the wider
## nails stay long.
const CLAW_K := 0.72
## Fixed for the same reason: the arm model's muscle bulk and the nails' curve in degrees.
const BULK := 1.0
const CLAW_CURVE := 22.0
## Fixed for the same reason. Girth is about three times the witch's gaunt shafts (0.68-0.80):
## the index shaft is over a quarter of its length. HAND_K scales the hand and the gun grip.
const GIRTH := 2.10
const HAND_K := 1.47

## Hand dressing: `&"gear"` (a wrecked T-shirt sleeve on each arm plus the skin layers),
## `&"rags"` (the old rag and glove dress) or `&"none"` (bare arms). Set by the `arms dress`
## console command, then rebuilt.
static var dress_style := &"gear"


static func rng_for(seed_value: int, part_id: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, part_id])
	return rng


static func build(rig: Node3D, seed_value: int, van_name: String) -> Dictionary:
	var rng := rng_for(seed_value, &"arms")
	var skin := ArmMaterials.skin(rng)
	# One copy per arm so the skin layers' uniforms (tattoo, scars) differ between the arms.
	var skin_r := skin.duplicate() as ShaderMaterial
	var skin_l := skin.duplicate() as ShaderMaterial
	# One shirt for both arms: the two sleeves are the same cloth.
	var cloth := ArmMaterials.gear_cloth(rng_for(seed_value, &"arm_cloth"))
	var claw := ArmMaterials.claw()
	var gx := HeldGun.gun_xform()

	# Right arm: bare, holds the grip.
	var right := Node3D.new()
	right.name = "ArmRight"
	var rng_r := rng_for(seed_value, &"arm_right")
	var muscle_r := rng_r.randi()
	var model_r := ArmRig.spawn(&"R", ARM_SCALE, BULK, muscle_r)
	right.add_child(model_r)
	# Parented at once: gear and skin layers aim at the camera, found through the ancestors.
	rig.add_child(right)
	var gun_root := HeldGun.build(rng_for(seed_value, &"arm_gun"),
			ArmRig.palm_len(model_r) * HAND_K)
	gun_root.visible = SHOW_GUN
	var shoulder_r := RIGHT_SHOULDER + _jitter(rng_r)
	var r: Dictionary
	if SHOW_GUN:
		r = ArmRig.reach(model_r, ".R", shoulder_r,
				gx * (right_wrist_in_gun * HAND_K), RIGHT_POLE,
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
	var curl_r := RIGHT_CURL.duplicate()
	curl_r[&"thumb"] = right_thumb_curl
	ArmRig.curl(model_r, ".R", curl_r)
	var sk_r := ArmRig.skeleton(model_r)
	var thumb_i := sk_r.find_bone("DEF-thumb.01.R")
	if SHOW_GUN and thumb_i != -1:
		sk_r.set_bone_pose_rotation(thumb_i, sk_r.get_bone_pose_rotation(thumb_i)
				* Quaternion.from_euler(right_thumb_aim * (PI / 180.0)))
	ArmRig.stretch_tips(model_r, ".R", TIP_K)
	ArmRig.stretch_thumb(model_r, ".R", THUMB_STRETCH)
	ArmRig.scale_hand(model_r, ".R", HAND_K)
	var fingers_r := ArmFingers.build(model_r, ".R", GIRTH, rng_r, skin_r)
	model_r.set_meta(&"fingers", fingers_r)
	ArmRig.add_claws(model_r, ".R", fingers_r, CLAW_K, CLAW_CURVE, claw)
	_skin_model(model_r, skin_r)

	match dress_style:
		&"rags":
			ArmDress.right(model_r, rng_for(seed_value, &"arm_dress_r"))
		&"gear":
			ArmSleeve.build(model_r, ".R", rng_for(seed_value, &"arm_gear_r"), cloth)
	if dress_style != &"none":
		ArmSkinLayers.apply(skin_r, model_r, ".R", rng_for(seed_value, &"arm_skin_r"),
				van_name, false)

	# Left arm: hangs relaxed at the side.
	var left := Node3D.new()
	left.name = "ArmLeft"
	var rng_l := rng_for(seed_value, &"arm_left")
	var muscle_l := rng_l.randi()
	var model_l := ArmRig.spawn(&"L", ARM_SCALE, BULK, muscle_l)
	left.add_child(model_l)
	rig.add_child(left)
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
	ArmRig.stretch_tips(model_l, ".L", TIP_K)
	ArmRig.stretch_thumb(model_l, ".L", THUMB_STRETCH)
	ArmRig.scale_hand(model_l, ".L", HAND_K)
	var fingers_l := ArmFingers.build(model_l, ".L", GIRTH, rng_l, skin_l)
	model_l.set_meta(&"fingers", fingers_l)
	ArmRig.add_claws(model_l, ".L", fingers_l, CLAW_K, CLAW_CURVE, claw)
	_skin_model(model_l, skin_l)
	match dress_style:
		&"rags":
			ArmDress.left(model_l, rng_for(seed_value, &"arm_dress_l"))
		&"gear":
			ArmSleeve.build(model_l, ".L", rng_for(seed_value, &"arm_gear_l"), cloth)
	if dress_style != &"none":
		ArmSkinLayers.apply(skin_l, model_l, ".L", rng_for(seed_value, &"arm_skin_l"),
				van_name, true)

	rig.add_child(gun_root)
	return {
		"left_root": left,
		"right_root": right,
		"gun_root": gun_root,
		"left_wrist": l["wrist"],
	}


## Skins the arm mesh: the skeleton's direct meshes, not the claw nails under its attachments.
static func _skin_model(model: Node3D, skin: Material) -> void:
	for c in ArmRig.skeleton(model).get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = skin


static func _jitter(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(
		rng.randf_range(-ELBOW_JITTER, ELBOW_JITTER),
		rng.randf_range(-ELBOW_JITTER, ELBOW_JITTER),
		rng.randf_range(-ELBOW_JITTER, ELBOW_JITTER))
