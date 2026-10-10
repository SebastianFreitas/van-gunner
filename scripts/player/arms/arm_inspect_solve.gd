extends RefCounted
## Left-arm solver for the gun inspect: re-solves the arm with ArmRig.reach each frame, keeping the weave's wrist and forearm offsets, then dresses the fingers.
##
## Same save and re-add of the weave delta as ArmGesture._solve; `dress` is ArmGesture._dress
## without the live Fingers.straighten call. Nothing calls it until the viewmodel wires it in.

const Gesture := preload("res://scripts/player/arms/arm_gesture.gd")
const WristRoutine := preload("res://scripts/player/arms/arm_wrist_routine.gd")

## Rest inputs from the builder's reach dict, as the gesture binds them.
var rest_shoulder := Vector3.ZERO
var rest_wrist := Vector3.ZERO
var rest_pole := Vector3.ZERO
var rest_hand_dir := Vector3.DOWN
var rest_palm := Vector3.RIGHT
## False when the skeleton or a bone is missing; every method then does nothing.
var ok := false
## True for an arm whose forearm twist nothing rewrites each frame (the right one): `solve` puts it
## back to its build value first, so the weave offset it reads is zero and nothing builds up.
var reset_fore := false

var _model: Node3D = null
var _suffix := ""
var _sk: Skeleton3D = null
var _wrist := -1
var _fore := -1
var _base_f := Quaternion.IDENTITY
var _base_h := Quaternion.IDENTITY
var _joints: Array[int] = []


func _init(model: Node3D, suffix: String, inputs: Dictionary) -> void:
	if model == null:
		return
	_model = model
	_suffix = suffix
	_sk = ArmRig.skeleton(model)
	if _sk == null:
		return
	_wrist = _sk.find_bone("DEF-hand" + suffix)
	_fore = _sk.find_bone("DEF-forearm" + suffix + ".001")
	if _wrist == -1 or _fore == -1:
		return
	for f in 5:
		for j in 3:
			_joints.append(_sk.find_bone("DEF-%s.0%d%s" % [ArmRig.FINGERS[f], j + 1, suffix]))
	rest_shoulder = inputs.get("shoulder", Vector3.ZERO) as Vector3
	rest_wrist = inputs.get("wrist", Vector3.ZERO) as Vector3
	rest_pole = inputs.get("pole", Vector3.ZERO) as Vector3
	rest_palm = inputs.get("palm", Vector3.RIGHT) as Vector3
	var elbow := inputs.get("elbow", Vector3.ZERO) as Vector3
	if inputs.has("hand_dir"):
		rest_hand_dir = inputs["hand_dir"] as Vector3
	else:
		rest_hand_dir = ((rest_wrist - elbow).normalized()
				+ Vector3.DOWN * float(inputs.get("drop", 0.0))).normalized()
	_base_h = _sk.get_bone_pose_rotation(_wrist)
	_base_f = _sk.get_bone_pose_rotation(_fore)
	ok = true


## Re-solves the arm to `wrist`, then puts this frame's weave offsets back on the forearm twist
## and the hand.
func solve(shoulder: Vector3, wrist: Vector3, pole: Vector3, hand_dir: Vector3,
		palm_n: Vector3) -> void:
	if not ok:
		return
	if reset_fore:
		_sk.set_bone_pose_rotation(_fore, _base_f)
	var df := _base_f.inverse() * _sk.get_bone_pose_rotation(_fore)
	var dh := _base_h.inverse() * _sk.get_bone_pose_rotation(_wrist)
	ArmRig.reach(_model, _suffix, shoulder, wrist, pole, hand_dir, palm_n)
	_sk.set_bone_pose_rotation(_fore, _sk.get_bone_pose_rotation(_fore) * df)
	_sk.set_bone_pose_rotation(_wrist, _sk.get_bone_pose_rotation(_wrist) * dh)


## The wrist bend (x flex, y deviation, degrees), finger curl (thumb, middle, pinky) and fan on top
## of the solved pose.
func dress(wrist_fd: Vector2, fingers: Vector3, spread: Vector2) -> void:
	if not ok:
		return
	if wrist_fd == Vector2.ZERO and fingers == Vector3.ZERO and spread == Vector2.ZERO:
		return
	var hand := WristRoutine.FLEX_AXIS * wrist_fd.x + WristRoutine.DEV_AXIS * wrist_fd.y
	_sk.set_bone_pose_rotation(_wrist, _sk.get_bone_pose_rotation(_wrist)
			* Quaternion.from_euler(hand * (PI / 180.0)))
	for f in 5:
		var deg := fingers.x if f == 0 else (fingers.z if f == 4 else fingers.y)
		var fan := spread.x if f == 0 else (-spread.y if f == 2 else (-spread.x if f == 3 else 0.0))
		for j in 3:
			var i := _joints[f * 3 + j]
			if i == -1:
				continue
			if j == 0 and fan != 0.0:
				_sk.set_bone_pose_rotation(i, _sk.get_bone_pose_rotation(i)
						* Quaternion(Vector3.BACK, deg_to_rad(fan * Gesture.SPREAD_SIGN)))
			_sk.set_bone_pose_rotation(i, _sk.get_bone_pose_rotation(i)
					* Quaternion(Vector3.RIGHT, deg_to_rad(deg / 3.0) * ArmRig.CURL_SIGN))
	var thumb := _joints[12]
	if thumb != -1 and spread.x != 0.0:
		_sk.set_bone_pose_rotation(thumb, _sk.get_bone_pose_rotation(thumb)
				* Quaternion(Vector3.BACK, deg_to_rad(spread.x * Gesture.THUMB_FAN
				* Gesture.SPREAD_SIGN)))


## One solve with the rest inputs, so the arm returns to the weave's own pose.
func restore() -> void:
	solve(rest_shoulder, rest_wrist, rest_pole, rest_hand_dir, rest_palm)
