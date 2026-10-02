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
## The held rifle is built (muzzle and lamp anchors still come from it) but hidden while the arms
## are reworked.
const SHOW_GUN := false
## Where the relaxed left wrist sits when shown (looking down, reloading): the lower-left of the frame.
const LEFT_SHOWN_WRIST := Vector3(-0.95, -0.62, -1.05)
const LEFT_HANG_POLE := Vector3(-1.0, -0.6, 0.2)
const LEFT_HANG_HAND_DIR := Vector3(0.1, -0.5, -1.0)
## How far the straightened left hand droops below its forearm line (a relaxed hang).
const LEFT_WRIST_DROP := 0.15
## Palm toward the body.
const LEFT_HANG_PALM := Vector3(1, 0, 0)
## Finger joint curls in degrees for joints .01/.02/.03.
const RIGHT_CURL := {
	&"f_index": Vector3(20, 25, 15), &"f_middle": Vector3(40, 45, 30),
	&"f_ring": Vector3(40, 45, 30), &"f_pinky": Vector3(40, 45, 30),
	&"thumb": Vector3(15, 20, 15),
}
const LEFT_CURL := {
	&"f_index": Vector3(25, 30, 20), &"f_middle": Vector3(25, 30, 20),
	&"f_ring": Vector3(25, 30, 20), &"f_pinky": Vector3(25, 30, 20),
	&"thumb": Vector3(10, 15, 10),
}
const ELBOW_JITTER := 0.03
## Sleeve, straps, wounds, shards, scars and tattoo stay off while the bare arms are tuned.
const DRESS := false
## Sleeve slots along the left forearm (0 elbow, 1 hem); wounds and straps share them.
const DRESS_SLOTS: Array[float] = [0.30, 0.44, 0.58, 0.72, 0.86]
## Bare forearm radii in model units before bulk; times the seeded scale and ArmBulk's gain where used.
const FOREARM_R_ELBOW := 0.075
const FOREARM_R_WRIST := 0.06
## The ragged sleeve hangs this much wider than the inflated forearm under it.
const SLEEVE_SLACK := 1.35


static func rng_for(seed_value: int, part_id: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, part_id])
	return rng


static func build(rig: Node3D, seed_value: int, van_name: String) -> Dictionary:
	var rng := rng_for(seed_value, &"arms")
	var skin := ArmMaterials.skin(rng)
	var s := rng.randf_range(1.12, 1.28)
	var tip_k := rng.randf_range(1.0, 1.35)
	var claw_len := rng.randf_range(0.04, 0.08)
	var bulk := rng.randf_range(0.85, 1.15)
	var r_elbow := _fore_r(FOREARM_R_ELBOW, ArmBulk.FOREARM_ELBOW_GAIN, s, bulk)
	var r_wrist := _fore_r(FOREARM_R_WRIST, ArmBulk.FOREARM_WRIST_GAIN, s, bulk)
	var claw := ArmMaterials.claw()
	var gun_root := HeldGun.build(rng_for(seed_value, &"arm_gun"))
	gun_root.visible = SHOW_GUN
	var gx := HeldGun.gun_xform()

	# Right arm: bare, holds the grip.
	var right := Node3D.new()
	right.name = "ArmRight"
	var rng_r := rng_for(seed_value, &"arm_right")
	var muscle_r := rng_r.randi()
	var model_r := ArmRig.spawn(&"R", s, bulk, muscle_r)
	right.add_child(model_r)
	var r := ArmRig.reach(model_r, ".R", RIGHT_SHOULDER + _jitter(rng_r),
			gx * RIGHT_WRIST_IN_GUN, RIGHT_POLE,
			(gx.basis * RIGHT_HAND_DIR_IN_GUN).normalized(),
			(gx.basis * RIGHT_PALM_IN_GUN).normalized())
	ArmRig.curl(model_r, ".R", RIGHT_CURL)
	ArmRig.stretch_tips(model_r, ".R", tip_k)
	ArmRig.add_claws(model_r, ".R", claw_len, claw)
	_skin_model(model_r, skin)
	if DRESS:
		_dress_right(right, rng_r, r.elbow, r.wrist, van_name,
				r_elbow, r_wrist)

	# s is 1.0: the lamp attaches inside the model that `s` already scales.
	var lamp_t := 0.5 + 0.5 * ArmLampKit.MOUNT_T
	var r_mount := _fore_r(lerpf(FOREARM_R_ELBOW, FOREARM_R_WRIST, lamp_t),
			lerpf(ArmBulk.FOREARM_ELBOW_GAIN, ArmBulk.FOREARM_WRIST_GAIN, lamp_t), 1.0, bulk)
	var bulb := ArmLampKit.build(model_r, r_mount, rng_for(seed_value, &"arm_lamp"))

	# Left arm: hangs relaxed at the side.
	var left := Node3D.new()
	left.name = "ArmLeft"
	var rng_l := rng_for(seed_value, &"arm_left")
	var muscle_l := rng_l.randi()
	var model_l := ArmRig.spawn(&"L", s, bulk, muscle_l)
	left.add_child(model_l)
	var shoulder_l := LEFT_SHOULDER + _jitter(rng_l)
	var l := ArmRig.reach(model_l, ".L", shoulder_l,
			LEFT_SHOWN_WRIST, LEFT_HANG_POLE,
			LEFT_HANG_HAND_DIR.normalized(), LEFT_HANG_PALM)
	# Pose again with the hand along the forearm: a sharply bent hand pokes its slim wrist out
	# under the fat forearm's open end.
	var fore_dir := (Vector3(l.wrist) - Vector3(l.elbow)).normalized()
	l = ArmRig.reach(model_l, ".L", shoulder_l, LEFT_SHOWN_WRIST, LEFT_HANG_POLE,
			(fore_dir + Vector3.DOWN * LEFT_WRIST_DROP).normalized(), LEFT_HANG_PALM)
	ArmRig.curl(model_l, ".L", LEFT_CURL)
	ArmRig.stretch_tips(model_l, ".L", tip_k)
	ArmRig.add_claws(model_l, ".L", claw_len, claw)
	_skin_model(model_l, skin)
	if DRESS:
		_dress_left(left, rng_l, l.elbow, l.wrist, r_elbow, r_wrist)

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


## Scars on one flank of the right forearm, then the van tattoo on top.
static func _dress_right(right: Node3D, rng: RandomNumberGenerator, elbow: Vector3,
		wrist: Vector3, van_name: String, r_elbow: float, r_wrist: float) -> void:
	var dn := (wrist - elbow).normalized()
	var facing := -((elbow + wrist) * 0.5).normalized()
	var scar_mat := ArmMaterials.scar()
	var side := 1.0 if rng.randi_range(0, 1) == 0 else -1.0
	var flank := facing.rotated(dn, side * rng.randf_range(0.8, 1.3))
	for i in rng.randi_range(2, 4):
		var t := rng.randf_range(0.45, 0.95)
		ArmParts.scar(right, "Scar%d" % i, elbow.lerp(wrist, t), dn,
				lerpf(r_elbow, r_wrist, t), flank, scar_mat, rng)
	ArmTattoo.apply(right, rng, van_name, elbow, wrist, r_elbow,
			r_wrist, facing)


## Cloth sleeve on the left forearm with wounds, straps knotted over them, and shards.
static func _dress_left(left: Node3D, rng: RandomNumberGenerator, elbow: Vector3,
		wrist: Vector3, r_elbow: float, r_wrist: float) -> void:
	var sleeve_elbow := r_elbow * SLEEVE_SLACK
	var sleeve_hem := r_wrist * SLEEVE_SLACK
	var cloth := ArmMaterials.cloth(rng)
	var leather := ArmMaterials.leather()
	var blood := ArmMaterials.wound()
	var steel := ArmMaterials.shrapnel()
	var dn := (wrist - elbow).normalized()
	var a := elbow - dn * 0.10
	var b := wrist - dn * 0.05
	ArmParts.sleeve(left, "Sleeve", a, b, sleeve_elbow, sleeve_hem, cloth, rng,
			rng.randi_range(6, 10))
	var facing := -((a + b) * 0.5).normalized()
	var slots: Array[float] = DRESS_SLOTS.duplicate()
	# Fisher-Yates on the arm's own stream; Array.shuffle() would use the global RNG.
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: float = slots[i]
		slots[i] = slots[j]
		slots[j] = tmp
	var n_wounds := rng.randi_range(2, 3)
	var n_straps := rng.randi_range(2, 4)
	for i in n_wounds:
		var t := slots[i]
		ArmParts.wound(left, "Wound%d" % i, a.lerp(b, t), dn,
				lerpf(sleeve_elbow, sleeve_hem, t), facing, blood, rng)
	for i in n_straps:
		var t := slots[i]
		ArmParts.strap(left, "Strap%d" % i, a.lerp(b, t), dn,
				lerpf(sleeve_elbow, sleeve_hem, t), facing, leather, rng)
	for i in rng.randi_range(3, 6):
		var t := rng.randf_range(0.25, 0.90)
		ArmParts.shard(left, "Shard%d" % i, a.lerp(b, t), dn,
				lerpf(sleeve_elbow, sleeve_hem, t), facing, steel, blood, rng)
