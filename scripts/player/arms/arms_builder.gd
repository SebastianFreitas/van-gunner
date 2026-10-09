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
const LEFT_SHOWN_WRIST := Vector3(-0.8, -0.6, -1.25)
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
const RIGHT_THUMB_CURL := Vector3(10, 0, 18)
## Finger joint curls in degrees for joints .01/.02/.03.
const RIGHT_CURL := {
	&"f_index": Vector3(20, 25, 15), &"f_middle": Vector3(40, 45, 30),
	&"f_ring": Vector3(40, 45, 30), &"f_pinky": Vector3(40, 45, 30),
	&"thumb": RIGHT_THUMB_CURL,
}
## Extra euler degrees on the right thumb's first bone after the curl: wraps the thumb around the
## grip's far (left) side so it points forward under the slide, a C with the trigger finger (the
## curl alone only bends it about one axis). Swept with `arms fit` and `arms thumbs`: .01 rolled
## down around the back of the grip, .02 straight along the flank, .03 hooked slightly inward.
const RIGHT_THUMB_AIM := Vector3(-36, -18, -82)
## Pose of the monster grip piece (`gun_style == &"grip"`), a separate set so tuning it leaves the
## pistol pose alone. Same shape as the pistol constants above.
const GRIP_WRIST_IN_GUN := Vector3(0.072, -0.13, 0.17)
const GRIP_HAND_DIR_IN_GUN := Vector3(-0.05, 0.25, -1.0)
const GRIP_PALM_IN_GUN := Vector3(-1.0, 0.0, 0.0)
## The thumb's .03 value tips its nail slightly down from the player's POV (owner, 2026-10-04).
const GRIP_CURL := {
	&"f_index": Vector3(20, 25, 15), &"f_middle": Vector3(46, 57, 38),
	&"f_ring": Vector3(55, 70, 50), &"f_pinky": Vector3(55, 70, 62),
	&"thumb": Vector3(-5, -8, 78),
}
## Tuned with `arms touch` on the grip: the fingers wrap the front strap, the thumb lies high on the
## left panel (the side facing the camera), crossing the back strap so it stays out of the core.
const GRIP_THUMB_AIM := Vector3(-65, -70, -20)
## Screen-space turn of the right thumb at its palm joint, degrees about the rig axes:
## x rolls it about its own length, y swings the nail toward you (+) or away (-),
## z turns the nail down (+) or up (-) on screen; the thumb lies along screen -X in the grip.
## Swept live with `arms thumbturn` and approved by the owner on 2026-10-04.
const GRIP_THUMB_TURN := Vector3(-50, -10, -5)
const RIGHT_THUMB_TURN := Vector3.ZERO
## Degrees, spins the thumb's tip bone about its own length (twists the nail sideways); the rest
## of the thumb stays put (`arms thumbroll`).
const RIGHT_THUMB_ROLL := 50.0
## Default knuckle swing that lowers the four gun-hand fingers onto the grip; owner-tuned with
## `arms rall 1 0 0 35`.
const RIGHT_FINGER_KNUCKLE_AIM := Vector3(0.0, 0.0, 35.0)
## Live copy of RIGHT_THUMB_ROLL; one value for both grip and pistol.
static var right_thumb_roll := RIGHT_THUMB_ROLL
## Live copies of the gripping hand's tunables: the `arms thumbaim`, `arms thumbcurl`, `arms wrist`
## and `arms curl` console commands set them and rebuild, so a pose is tuned by numbers instead of
## a screenshot per try. The constants above are their defaults. The `right_*` names read and write
## the grip set while `gun_style` is grip and the pistol set otherwise.
static var _pistol_thumb_aim := RIGHT_THUMB_AIM
static var _pistol_thumb_curl := RIGHT_THUMB_CURL
static var _pistol_wrist := RIGHT_WRIST_IN_GUN
static var _pistol_curl: Dictionary = RIGHT_CURL.duplicate()
static var _grip_thumb_aim := GRIP_THUMB_AIM
static var _pistol_thumb_turn := RIGHT_THUMB_TURN
static var _grip_thumb_turn := GRIP_THUMB_TURN
static var _grip_wrist := GRIP_WRIST_IN_GUN
static var _grip_curl: Dictionary = GRIP_CURL.duplicate()
static var right_thumb_aim: Vector3:
	get:
		return _grip_thumb_aim if gun_style == &"grip" else _pistol_thumb_aim
	set(v):
		if gun_style == &"grip":
			_grip_thumb_aim = v
		else:
			_pistol_thumb_aim = v
static var right_thumb_turn: Vector3:
	get:
		return _grip_thumb_turn if gun_style == &"grip" else _pistol_thumb_turn
	set(v):
		if gun_style == &"grip":
			_grip_thumb_turn = v
		else:
			_pistol_thumb_turn = v
static var right_thumb_curl: Vector3:
	get:
		return _grip_curl[&"thumb"] if gun_style == &"grip" else _pistol_thumb_curl
	set(v):
		if gun_style == &"grip":
			_grip_curl[&"thumb"] = v
		else:
			_pistol_thumb_curl = v
static var right_wrist_in_gun: Vector3:
	get:
		return _grip_wrist if gun_style == &"grip" else _pistol_wrist
	set(v):
		if gun_style == &"grip":
			_grip_wrist = v
		else:
			_pistol_wrist = v
## Finger curls of the active piece's pose, a copy; the thumb entry is `right_thumb_curl`.
static var right_curl: Dictionary:
	get:
		var c: Dictionary = _grip_curl if gun_style == &"grip" else _pistol_curl
		return c.duplicate()
	set(v):
		if gun_style == &"grip":
			_grip_curl = v
		else:
			_pistol_curl = v
## Right finger aim per gun style, finger id -> degrees per joint .01/.02/.03: x extra curl, y twist
## along the finger, z side swing, all bone-local, on top of the curl (`arms ridx` etc.).
static var _pistol_fingers := _zero_fingers()
static var _grip_fingers := _zero_fingers()
## Right finger knuckle shift per gun style, finger id -> centimetres, bone-local (`arms ridx shift`).
static var _pistol_shifts := _zero_shifts()
static var _grip_shifts := _zero_shifts()


static func _zero_fingers() -> Dictionary:
	var d := {}
	for f: StringName in [&"f_index", &"f_middle", &"f_ring", &"f_pinky"]:
		d[f] = [RIGHT_FINGER_KNUCKLE_AIM, Vector3.ZERO, Vector3.ZERO]
	return d


static func _zero_shifts() -> Dictionary:
	var d := {}
	for f: StringName in [&"f_index", &"f_middle", &"f_ring", &"f_pinky"]:
		d[f] = Vector3.ZERO
	return d


## The current gun style's curl/twist/side aim triple for one right finger bone.
static func finger_aim(f: StringName) -> Array:
	var d: Dictionary = _grip_fingers if gun_style == &"grip" else _pistol_fingers
	return (d[f] as Array).duplicate()


## Stores the aim triple for one right finger bone under the current gun style.
static func set_finger_aim(f: StringName, a: Array) -> void:
	var d: Dictionary = _grip_fingers if gun_style == &"grip" else _pistol_fingers
	d[f] = a


## The current gun style's knuckle shift for one right finger bone.
static func finger_shift(f: StringName) -> Vector3:
	var d: Dictionary = _grip_shifts if gun_style == &"grip" else _pistol_shifts
	return d[f]


## Stores the knuckle shift for one right finger bone under the current gun style.
static func set_finger_shift(f: StringName, v: Vector3) -> void:
	var d: Dictionary = _grip_shifts if gun_style == &"grip" else _pistol_shifts
	d[f] = v
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
const HAND_K := ArmBulk.HAND_SCALE
## The hands are one fixed design (owner, 2026-10-05): skin tone, scars, wounds and dirt
## hash from this, never from the van seed.
const HAND_LOOK_SEED := 7
## Part ids whose streams use HAND_LOOK_SEED instead of the van seed.
const FIXED_LOOK_PARTS: Array[StringName] = [&"arms", &"arm_skin_r", &"arm_skin_l"]
## The shape and pose streams (muscle lumps, the shoulder offset, each finger's sideways
## crook) are fixed too, at the seed the posture and the claws were tuned under. Any other
## value turns the hand and swings the fingertips, a posture change the owner forbids.
const HAND_SHAPE_SEED := 1337
## Part ids whose streams use HAND_SHAPE_SEED instead of the van seed.
const FIXED_SHAPE_PARTS: Array[StringName] = [&"arm_right", &"arm_left"]
## The skin's `seed_offset`, seed 1337's draw: it places the wart domes the shader lifts out of
## the skin, so it is shape. Seed 7's 2.32 put domes on three fingertips and buried the claws.
const HAND_SKIN_OFFSET := 91.1654968261719

## Hand dressing: `&"bare"` (monster skin plus `ArmSkinLayers`, the default), `&"none"` (plain
## skin, no layers, debug) or `&"rags"` (the old rag and glove dress, plus layers). Set by the
## `arms dress` console command, then rebuilt.
static var dress_style := &"bare"
## Held piece: &"grip" (MonsterGrip, the default) or &"pistol" (HeldGun).
static var gun_style: StringName = &"grip"


static func rng_for(seed_value: int, part_id: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var look_seed := seed_value
	if part_id in FIXED_LOOK_PARTS:
		look_seed = HAND_LOOK_SEED
	elif part_id in FIXED_SHAPE_PARTS:
		look_seed = HAND_SHAPE_SEED
	rng.seed = hash([look_seed, part_id])
	return rng


static func build(rig: Node3D, seed_value: int, van_name: String) -> Dictionary:
	var perf_t := PerfStats.begin()
	var rng := rng_for(seed_value, &"arms")
	var skin := ArmMaterials.skin(rng)
	skin.set_shader_parameter(&"seed_offset", HAND_SKIN_OFFSET)
	# One copy per arm so the skin layers' uniforms (tattoo, scars) differ between the arms.
	var skin_r := skin.duplicate() as ShaderMaterial
	var skin_l := skin.duplicate() as ShaderMaterial
	var claw := ArmMaterials.claw()
	var gx := HeldGun.gun_xform()

	# Right arm: bare, holds the grip.
	var right := Node3D.new()
	right.name = "ArmRight"
	var rng_r := rng_for(seed_value, &"arm_right")
	var muscle_r := rng_r.randi()
	var model_r := ArmRig.spawn(&"R", ARM_SCALE, BULK, muscle_r)
	right.add_child(model_r)
	# Parented at once: dress and skin layers aim at the camera, found through the ancestors.
	rig.add_child(right)
	var gun_root: Node3D
	if gun_style == &"grip":
		gun_root = MonsterGrip.build(rng_for(seed_value, &"arm_gun"),
				ArmRig.palm_len(model_r) * HAND_K)
	else:
		gun_root = HeldGun.build(rng_for(seed_value, &"arm_gun"),
				ArmRig.palm_len(model_r) * HAND_K)
	gun_root.visible = SHOW_GUN
	var shoulder_r := RIGHT_SHOULDER + _jitter(rng_r)
	var r: Dictionary
	if SHOW_GUN:
		r = ArmRig.reach(model_r, ".R", shoulder_r,
				gx * (right_wrist_in_gun * HAND_K), RIGHT_POLE,
				(gx.basis * (GRIP_HAND_DIR_IN_GUN if gun_style == &"grip" else RIGHT_HAND_DIR_IN_GUN)).normalized(),
				(gx.basis * (GRIP_PALM_IN_GUN if gun_style == &"grip" else RIGHT_PALM_IN_GUN)).normalized())
	else:
		r = ArmRig.reach(model_r, ".R", shoulder_r, RIGHT_WEAVE_WRIST, RIGHT_POLE,
				(RIGHT_WEAVE_WRIST - shoulder_r).normalized(),
				RIGHT_WEAVE_PALM.normalized())
		var fore_r := (Vector3(r.wrist) - Vector3(r.elbow)).normalized()
		r = ArmRig.reach(model_r, ".R", shoulder_r, RIGHT_WEAVE_WRIST, RIGHT_POLE,
				(fore_r + Vector3.UP * WEAVE_WRIST_LIFT).normalized(),
				RIGHT_WEAVE_PALM.normalized())
	var curl_r := right_curl
	curl_r[&"thumb"] = right_thumb_curl
	ArmRig.curl(model_r, ".R", curl_r)
	for f: StringName in [&"f_index", &"f_middle", &"f_ring", &"f_pinky"]:
		ArmRig.aim_joints(model_r, "DEF-%s.0%%d.R" % f, finger_aim(f), finger_shift(f))
	var sk_r := ArmRig.skeleton(model_r)
	var thumb_i := sk_r.find_bone("DEF-thumb.01.R")
	if SHOW_GUN and thumb_i != -1:
		sk_r.set_bone_pose_rotation(thumb_i, sk_r.get_bone_pose_rotation(thumb_i)
				* Quaternion.from_euler(right_thumb_aim * (PI / 180.0)))
		var tip_i := sk_r.find_bone("DEF-thumb.03.R")
		if right_thumb_roll != 0.0 and tip_i != -1:
			sk_r.set_bone_pose_rotation(tip_i, sk_r.get_bone_pose_rotation(tip_i)
					* Quaternion(Vector3.UP, deg_to_rad(right_thumb_roll)))
	ArmRig.stretch_tips(model_r, ".R", TIP_K)
	ArmRig.stretch_thumb(model_r, ".R", THUMB_STRETCH)
	ArmRig.scale_hand(model_r, ".R", HAND_K)
	if SHOW_GUN:
		_turn_thumb(rig, sk_r, right_thumb_turn)
	var fingers_r := ArmFingers.build(model_r, ".R", GIRTH, rng_r, skin_r)
	model_r.set_meta(&"fingers", fingers_r)
	ArmRig.add_claws(model_r, ".R", fingers_r, CLAW_K, CLAW_CURVE, claw)
	_skin_model(model_r, skin_r)
	ArmLimbTail.build(model_r, ".R", rng_for(seed_value, &"arm_tail_r"), skin_r)

	match dress_style:
		&"rags":
			ArmDress.right(model_r, rng_for(seed_value, &"arm_dress_r"))
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
	ArmLimbTail.build(model_l, ".L", rng_for(seed_value, &"arm_tail_l"), skin_l)
	match dress_style:
		&"rags":
			ArmDress.left(model_l, rng_for(seed_value, &"arm_dress_l"))
	if dress_style != &"none":
		ArmSkinLayers.apply(skin_l, model_l, ".L", rng_for(seed_value, &"arm_skin_l"),
				van_name, true)

	rig.add_child(gun_root)
	PerfStats.end(&"arms_build", perf_t)
	return {
		"left_root": left, "right_root": right, "gun_root": gun_root,
		"left_reach": {"shoulder": shoulder_l, "elbow": l.elbow, "wrist": l.wrist,
			"pole": LEFT_HANG_POLE, "palm": LEFT_HANG_PALM, "drop": LEFT_WRIST_DROP},
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


## Rotates DEF-thumb.01.R about its own head by screen-space degrees (rig axes). It
## rotates about the screen axes (right-hand rule), so each number moves it the way the player
## sees it instead of along the bone's local axes.
static func _turn_thumb(rig: Node3D, sk: Skeleton3D, turn_deg: Vector3) -> void:
	if turn_deg == Vector3.ZERO:
		return
	var bone := sk.find_bone("DEF-thumb.01.R")
	if bone == -1:
		return
	# Skeleton basis expressed in rig space, from the local transforms (the rig may be
	# outside the tree while a probe builds it, so no global_transform).
	var sk_to_rig := Basis.IDENTITY
	var n: Node3D = sk
	while n != null and n != rig:
		sk_to_rig = n.transform.basis * sk_to_rig
		n = n.get_parent() as Node3D
	var q_b := sk_to_rig.get_rotation_quaternion()
	var r_rig := (Quaternion(Vector3.BACK, deg_to_rad(turn_deg.z))
			* Quaternion(Vector3.UP, deg_to_rad(turn_deg.y))
			* Quaternion(Vector3.RIGHT, deg_to_rad(turn_deg.x)))
	var r_sk := q_b.inverse() * r_rig * q_b
	sk.force_update_all_bone_transforms()
	var parent := sk.get_bone_parent(bone)
	var q_p := Quaternion.IDENTITY
	if parent != -1:
		q_p = sk.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	sk.set_bone_pose_rotation(bone, q_p.inverse() * r_sk * q_p * sk.get_bone_pose_rotation(bone))
