extends RefCounted
## Drives the goblin's idle hands each frame: the witch-finger weave, and a grip idle on the gun hand when the gun is shown.
##
## Every value is a sum of smooth sines (no noise, no per-frame random), so the hands
## never twitch. Only bone rotations are written: scale and position stay untouched so
## the builder's tip stretch and the claw BoneAttachment3Ds keep working.
## The wrists circle the posed hand (the orientation ArmRig.reach chose), not the glb rest.

const PERIOD := 3.6  ## seconds per main finger roll
const ROLL_LAG := 0.9  ## radians of phase lag index -> middle -> ring -> pinky
const HARMONIC := 0.37  ## second, slower wave as a multiple of PERIOD's frequency
const HARMONIC_K := 0.3  ## its share of the amplitude, so the loop never reads as a loop
const BASE := Vector3(35.0, 55.0, 45.0)  ## degrees curl of joints .01/.02/.03: always hooked
const SWING := Vector3(14.0, 22.0, 18.0)  ## degrees of weave around BASE per joint
const THUMB_BASE := Vector3(4.0, 10.0, 18.0)  ## degrees flex of thumb .01/.02/.03: tip bent
const THUMB_SWING := Vector3(3.0, 6.0, 9.0)
const THUMB_SPREAD := 28.0  ## degrees the thumb .01 bone is held splayed from the index
## Axis and sign settled in round 9 by a six-shot top-view sheet (goblin-weave-research.md).
const THUMB_SPREAD_SIGN := -1.0  ## settled by the round 9 axis sheet (top view, 3 axes x 2 signs)
const THUMB_SPREAD_AXIS := Vector3.RIGHT  ## the thumb .01 axis that splays it from the index
const THUMB_ARC := 7.0  ## degrees of slow opposition swing on the spread, toward the index
const SPREAD := 6.0  ## degrees of side sway on each .01 bone, alternating sign
const WRIST_CIRCLE := 8.0  ## degrees, wrist pitch and yaw 90 deg apart
const WRIST_ROLL := 6.0  ## degrees, slow roll at half speed
const RIGHT_WRIST_BASE := Vector3(0.0, 0.0, 0.0)  ## degrees XYZ on top of the posed hand
const LEFT_WRIST_BASE := Vector3(0.0, 0.0, 0.0)
const ARM_DRIFT := Vector3(0.04, 0.035, 0.03)  ## rig-space metres of slow figure-eight per arm root
const ARM_TILT := Vector3(2.5, 2.0, 3.0)  ## degrees of root tilt riding the same figure-eight
const DRIFT_RATE := 0.4  ## drift speed as a multiple of the finger roll
const FLOURISH_PERIOD := 11.0  ## seconds between flourishes; hands alternate each cycle
const FLOURISH_AT := 4.0  ## seconds into the cycle it starts (keeps t 1.1 and 2.9 clear)
const FLOURISH_IN := 1.2  ## seconds opening
const FLOURISH_HOLD := 0.4
const FLOURISH_OUT := 1.6  ## seconds re-hooking
const OPEN_CURL := Vector3(8.0, 12.0, 10.0)  ## degrees per joint when stretched open
const OPEN_THUMB := Vector3(0.0, 4.0, 6.0)
const OPEN_SPREAD_K := 2.0  ## spread multiplier while open
const OPEN_WRIST_PITCH := 12.0  ## degrees the wrist lifts (negative X) while open
const GRIP_SQUEEZE := 3.0  ## degrees of extra curl on the gripping middle/ring/pinky, all joints
const THUMB_GRIP := 1.5  ## degrees of thumb flex on the gripping hand
const TRIGGER_PERIOD := 7.0  ## seconds between trigger-finger lifts
const TRIGGER_AT := 3.0  ## seconds into the cycle the lift starts (keeps t 1.1 at rest)
const TRIGGER_IN := 0.45  ## seconds lifting off the trigger
const TRIGGER_HOLD := 0.7
const TRIGGER_OUT := 0.55  ## seconds settling back
const TRIGGER_LIFT := Vector3(-14.0, -8.0, -4.0)  ## degrees per index joint at full lift (straighten)

## True when the gun is shown: the right hand grips it instead of weaving.
var _grip_right := false
## Right-hand grip joints {bone, base, finger, j} and their skeleton (grip mode only).
var _grip: Array[Dictionary] = []
var _grip_sk: Skeleton3D = null
## One entry per hand: {sk, suffix, phase, wrist, wrist_pose, wrist_base, joints}, where each
## joint is {bone, rest, finger, j} and finger 0..3 = index..pinky, 4 = thumb.
var _hands: Array[Dictionary] = []
## Drift phase and last drift transform per arm root: 0 right, 1 left.
var _phase: Array[float] = [0.0, PI]
var _arm_x: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]


func _init(arm_right: Node3D, arm_left: Node3D, seed_value: int, grip_right := false) -> void:
	_grip_right = grip_right
	var rng := ArmsBuilder.rng_for(seed_value, &"arm_weave")
	var right_phase := rng.randf() * TAU
	_phase[0] = right_phase
	_phase[1] = right_phase + PI
	if _grip_right:
		_add_grip(arm_right)
	else:
		_add_hand(arm_right, ".R", RIGHT_WRIST_BASE, right_phase)
	# The hands weave out of step.
	_add_hand(arm_left, ".L", LEFT_WRIST_BASE, right_phase + PI)


## Records the right hand's finger joints with the grip curl the builder already posed.
func _add_grip(model: Node3D) -> void:
	if model == null:
		return
	var sk := ArmRig.skeleton(model)
	if sk == null:
		return
	_grip_sk = sk
	for f in ArmRig.FINGERS.size():
		for j in 3:
			var bone_name := "DEF-%s.0%d.R" % [ArmRig.FINGERS[f], j + 1]
			var i := sk.find_bone(bone_name)
			if i == -1:
				push_warning("ArmWeave: bone not found: %s" % bone_name)
				continue
			_grip.append({&"bone": i, &"base": sk.get_bone_pose_rotation(i),
					&"finger": f, &"j": j})


func _add_hand(model: Node3D, suffix: String, wrist_base: Vector3, phase: float) -> void:
	if model == null:
		return
	var sk := ArmRig.skeleton(model)
	if sk == null:
		return
	var joints: Array = []
	for f in ArmRig.FINGERS.size():
		for j in 3:
			var bone_name := "DEF-%s.0%d%s" % [ArmRig.FINGERS[f], j + 1, suffix]
			var i := sk.find_bone(bone_name)
			if i == -1:
				push_warning("ArmWeave: bone not found: %s" % bone_name)
				continue
			joints.append({&"bone": i, &"rest": sk.get_bone_rest(i).basis.get_rotation_quaternion(),
					&"finger": f, &"j": j})
	var wrist_name := "DEF-hand" + suffix
	var wrist := sk.find_bone(wrist_name)
	var wrist_pose := Quaternion.IDENTITY
	if wrist == -1:
		push_warning("ArmWeave: bone not found: %s" % wrist_name)
	else:
		wrist_pose = sk.get_bone_pose_rotation(wrist)
	_hands.append({&"sk": sk, &"suffix": suffix, &"phase": phase, &"wrist": wrist,
			&"wrist_pose": wrist_pose, &"wrist_base": wrist_base, &"joints": joints})


## Poses every finger and wrist for time `t` (seconds). Allocation-free per frame.
func update(t: float) -> void:
	var w := TAU * t / PERIOD
	if _grip_right:
		_update_grip(t, w)
	for hand in _hands:
		var sk: Skeleton3D = hand[&"sk"]
		if not is_instance_valid(sk):
			continue
		var phase: float = hand[&"phase"]
		var hand_side := 0 if hand[&"suffix"] == ".R" else 1
		var f := _flourish(t, hand_side)
		for joint in hand[&"joints"]:
			var finger: int = joint[&"finger"]
			var j: int = joint[&"j"]
			var a := 0.0
			var deg := 0.0
			if finger < 4:
				a = w + phase - finger * ROLL_LAG
				var wave := _wave(a)
				deg = lerpf(BASE[j] + SWING[j] * wave, OPEN_CURL[j] + SWING[j] * wave * 0.3, f)
			else:
				a = w * 0.5 + phase + PI
				var wave := _wave(a)
				deg = lerpf(THUMB_BASE[j] + THUMB_SWING[j] * wave,
						OPEN_THUMB[j] + THUMB_SWING[j] * wave * 0.3, f)
			var rot: Quaternion = joint[&"rest"] * Quaternion(Vector3.RIGHT,
					deg_to_rad(deg) * ArmRig.CURL_SIGN)
			if j == 0 and finger == 4:
				# Hold the thumb abducted from the palm and swing it slowly toward the index.
				rot = rot * Quaternion(THUMB_SPREAD_AXIS, deg_to_rad((THUMB_SPREAD
						+ THUMB_ARC * sin(a * 0.5 + 0.9)) * THUMB_SPREAD_SIGN * lerpf(1.0, 1.25, f)))
			if j == 0 and finger < 4:
				var side := 1.0 if finger % 2 == 0 else -1.0
				rot = rot * Quaternion(Vector3.BACK,
						deg_to_rad(SPREAD * sin(a + 0.7) * side * lerpf(1.0, OPEN_SPREAD_K, f)))
			sk.set_bone_pose_rotation(joint[&"bone"], rot)
		var wrist: int = hand[&"wrist"]
		if wrist == -1:
			continue
		var b := w * 0.8 + phase
		var wrist_base: Vector3 = hand[&"wrist_base"]
		var e := wrist_base + Vector3(WRIST_CIRCLE * sin(b), WRIST_ROLL * sin(b * 0.5),
				WRIST_CIRCLE * cos(b))
		e.x -= OPEN_WRIST_PITCH * f
		var wrist_pose: Quaternion = hand[&"wrist_pose"]
		sk.set_bone_pose_rotation(wrist, wrist_pose * Quaternion.from_euler(e * (PI / 180.0)))
	for side in 2:
		var p := w * DRIFT_RATE + _phase[side]
		var pos := Vector3(ARM_DRIFT.x * sin(p), ARM_DRIFT.y * sin(2.0 * p + 0.4),
				ARM_DRIFT.z * cos(p))
		var tilt := ARM_TILT * Vector3(sin(p + 1.0), sin(0.5 * p), cos(p))
		_arm_x[side] = Transform3D(Basis.from_euler(tilt * (PI / 180.0)), pos)


## Grip idle on the gun hand: a slow squeeze on middle/ring/pinky, a faint thumb flex and an
## occasional trigger-finger lift, all on top of the grip curl the builder posed. The wrist is
## never touched: the gun is not attached to the hand, so a wrist turn would slide it off.
func _update_grip(t: float, w: float) -> void:
	if not is_instance_valid(_grip_sk):
		return
	var lift := _trigger(t)
	for joint in _grip:
		var finger: int = joint[&"finger"]
		var j: int = joint[&"j"]
		var deg := 0.0
		if finger == 0:
			deg = TRIGGER_LIFT[j] * lift
		elif finger < 4:
			deg = GRIP_SQUEEZE * _wave(w * 0.6 + finger * 0.4)
		else:
			deg = THUMB_GRIP * _wave(w * 0.45 + 2.0)
		var base: Quaternion = joint[&"base"]
		_grip_sk.set_bone_pose_rotation(joint[&"bone"],
				base * Quaternion(Vector3.RIGHT, deg_to_rad(deg) * ArmRig.CURL_SIGN))


## Slow whole-arm figure-eight drift of the last update (0 right, 1 left), in rig space.
func arm_offset(side: int) -> Transform3D:
	if side < 0 or side > 1:
		return Transform3D.IDENTITY
	return _arm_x[side]


## 0..1 flourish envelope for one hand (0 right, 1 left) at time `t`: smoothstep open, hold,
## smoothstep re-hook, once per FLOURISH_PERIOD, alternating hands. With the gun shown the left
## hand is the only weave hand, so it flourishes every cycle.
func _flourish(t: float, side: int) -> float:
	var cycle := floori(t / FLOURISH_PERIOD)
	if _grip_right:
		if side != 1:
			return 0.0
	elif cycle % 2 != side:
		return 0.0
	var u := t - cycle * FLOURISH_PERIOD - FLOURISH_AT
	return _envelope(u, FLOURISH_IN, FLOURISH_HOLD, FLOURISH_OUT)


## 0..1 trigger-finger lift at time `t`: the same envelope shape as the flourish, every cycle.
func _trigger(t: float) -> float:
	var cycle := floori(t / TRIGGER_PERIOD)
	return _envelope(t - cycle * TRIGGER_PERIOD - TRIGGER_AT, TRIGGER_IN, TRIGGER_HOLD, TRIGGER_OUT)


## Smoothstep up over `t_in`, hold, smoothstep down over `t_out`, measured from `u` = 0.
func _envelope(u: float, t_in: float, hold: float, t_out: float) -> float:
	if u < 0.0 or u > t_in + hold + t_out:
		return 0.0
	if u < t_in:
		return smoothstep(0.0, 1.0, u / t_in)
	if u < t_in + hold:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (u - t_in - hold) / t_out)


## Main sine plus a slower harmonic, normalised to -1..1.
func _wave(a: float) -> float:
	return (sin(a) + HARMONIC_K * sin(a * HARMONIC + 1.3)) / (1.0 + HARMONIC_K)
