extends RefCounted
## Left-hand interaction gesture on the goblin arms: a keyed one-shot (press, knock, push, pull, slide) that moves the left arm root and bends the left wrist and fingers on top of the weave.
##
## Runs after ArmWeave every frame: bone writes post-multiply the weave's freshly written pose,
## so nothing accumulates. Keys are first guesses, tuned later with pinned stills.

const KINDS: Array[StringName] = [
	&"press", &"knock", &"push", &"pull", &"slide_open", &"slide_close"
]

## Seconds from start to the moment the hand touches the thing.
const CONTACT := {
	&"press": 0.12, &"knock": 0.14, &"push": 0.16, &"pull": 0.16,
	&"slide_open": 0.16, &"slide_close": 0.16,
}

## Per kind: keys of t (s), pos (rig-space root offset), hand (wrist euler deg) and fingers
## (index, middle/ring/pinky, thumb deg; positive curls).
const KEYS := {
	&"press": [
		{&"t": 0.0, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
		{&"t": 0.12, &"pos": Vector3(0.75, 0.47, -0.75), &"hand": Vector3(-10, 0, 0),
			&"fingers": Vector3(-25, 45, 20)},
		{&"t": 0.20, &"pos": Vector3(0.72, 0.45, -0.62), &"hand": Vector3(-10, 0, 0),
			&"fingers": Vector3(-25, 45, 20)},
		{&"t": 0.40, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
	],
	&"knock": [
		{&"t": 0.0, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
		{&"t": 0.10, &"pos": Vector3(0.6, 0.6, -0.45), &"hand": Vector3(0, 0, -30),
			&"fingers": Vector3(135, 106, 35)},
		{&"t": 0.14, &"pos": Vector3(0.6, 0.6, -0.65), &"hand": Vector3(0, 0, -30),
			&"fingers": Vector3(135, 106, 35)},
		{&"t": 0.22, &"pos": Vector3(0.6, 0.6, -0.45), &"hand": Vector3(0, 0, -30),
			&"fingers": Vector3(135, 106, 35)},
		{&"t": 0.30, &"pos": Vector3(0.6, 0.6, -0.65), &"hand": Vector3(0, 0, -30),
			&"fingers": Vector3(135, 106, 35)},
		{&"t": 0.40, &"pos": Vector3(0.6, 0.6, -0.45), &"hand": Vector3(0, 0, -30),
			&"fingers": Vector3(135, 106, 35)},
		{&"t": 0.62, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
	],
	&"push": [
		{&"t": 0.0, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
		{&"t": 0.10, &"pos": Vector3(0.6, 0.45, -0.45), &"hand": Vector3(-35, 0, 0),
			&"fingers": Vector3(-15, -15, -10)},
		{&"t": 0.16, &"pos": Vector3(0.6, 0.45, -0.85), &"hand": Vector3(-35, 0, 0),
			&"fingers": Vector3(-15, -15, -10)},
		{&"t": 0.24, &"pos": Vector3(0.6, 0.45, -0.85), &"hand": Vector3(-35, 0, 0),
			&"fingers": Vector3(-15, -15, -10)},
		{&"t": 0.48, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
	],
	&"pull": [
		{&"t": 0.0, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
		{&"t": 0.12, &"pos": Vector3(0.6, 0.4, -0.75), &"hand": Vector3.ZERO,
			&"fingers": Vector3(-10, -10, -5)},
		{&"t": 0.16, &"pos": Vector3(0.6, 0.4, -0.75), &"hand": Vector3.ZERO,
			&"fingers": Vector3(65, 70, 40)},
		{&"t": 0.32, &"pos": Vector3(0.55, 0.3, -0.2), &"hand": Vector3.ZERO,
			&"fingers": Vector3(65, 70, 40)},
		{&"t": 0.52, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
	],
	&"slide_open": [
		{&"t": 0.0, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
		{&"t": 0.12, &"pos": Vector3(0.6, 0.4, -0.7), &"hand": Vector3.ZERO,
			&"fingers": Vector3(-10, -10, -5)},
		{&"t": 0.16, &"pos": Vector3(0.6, 0.4, -0.7), &"hand": Vector3.ZERO,
			&"fingers": Vector3(60, 65, 35)},
		{&"t": 0.34, &"pos": Vector3(1.15, 0.4, -0.7), &"hand": Vector3.ZERO,
			&"fingers": Vector3(60, 65, 35)},
		{&"t": 0.52, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
	],
	&"slide_close": [
		{&"t": 0.0, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
		{&"t": 0.12, &"pos": Vector3(0.6, 0.4, -0.7), &"hand": Vector3.ZERO,
			&"fingers": Vector3(-10, -10, -5)},
		{&"t": 0.16, &"pos": Vector3(0.6, 0.4, -0.7), &"hand": Vector3.ZERO,
			&"fingers": Vector3(60, 65, 35)},
		{&"t": 0.34, &"pos": Vector3(0.05, 0.4, -0.7), &"hand": Vector3.ZERO,
			&"fingers": Vector3(60, 65, 35)},
		{&"t": 0.52, &"pos": Vector3.ZERO, &"hand": Vector3.ZERO, &"fingers": Vector3.ZERO},
	],
}

var _sk: Skeleton3D = null
var _ok := false
var _wrist := -1
var _joints: Array[int] = []
var _kind: StringName = &""
var _start := 0.0
var _pos := Vector3.ZERO
var _hand := Vector3.ZERO
var _fingers := Vector3.ZERO


func _init(arm_left: Node3D) -> void:
	if arm_left == null:
		push_warning("ArmGesture: no left arm")
		return
	_sk = ArmRig.skeleton(arm_left)
	if _sk == null:
		push_warning("ArmGesture: left arm has no skeleton")
		return
	_wrist = _sk.find_bone("DEF-hand.L")
	if _wrist == -1:
		push_warning("ArmGesture: wrist bone not found")
		return
	for f in 5:
		for j in 3:
			_joints.append(_sk.find_bone("DEF-%s.0%d.L" % [ArmRig.FINGERS[f], j + 1]))
	_ok = true


func play(kind: StringName, now: float) -> float:
	if not CONTACT.has(kind):
		return 0.0
	_kind = kind
	_start = now
	return CONTACT[kind]


func clear() -> void:
	_kind = &""
	_zero()


func is_playing(now: float) -> bool:
	return _kind != &"" and now >= _start and now - _start < duration(_kind)


func sample(now: float) -> void:
	# A wrapped clock puts now before the start; drop the gesture rather than replay it.
	if _kind == &"" or now < _start or now - _start >= duration(_kind):
		clear()
		return
	_pose(_kind, now - _start)


func pin(kind: StringName, t: float) -> void:
	if not KEYS.has(kind):
		_zero()
		return
	_pose(kind, t)


func settle() -> void:
	clear()


func left_offset() -> Transform3D:
	return Transform3D(Basis.IDENTITY, _pos)


func apply_bones() -> void:
	if not _ok or (_hand == Vector3.ZERO and _fingers == Vector3.ZERO):
		return
	_sk.set_bone_pose_rotation(_wrist, _sk.get_bone_pose_rotation(_wrist)
			* Quaternion.from_euler(_hand * (PI / 180.0)))
	for f in 5:
		var deg := _fingers.x if f == 0 else (_fingers.z if f == 4 else _fingers.y)
		for j in 3:
			var i := _joints[f * 3 + j]
			if i == -1:
				continue
			_sk.set_bone_pose_rotation(i, _sk.get_bone_pose_rotation(i)
					* Quaternion(Vector3.RIGHT, deg_to_rad(deg / 3.0) * ArmRig.CURL_SIGN))


func duration(kind: StringName) -> float:
	if not KEYS.has(kind):
		return 0.0
	var keys: Array = KEYS[kind]
	return keys[keys.size() - 1][&"t"]


func _zero() -> void:
	_pos = Vector3.ZERO
	_hand = Vector3.ZERO
	_fingers = Vector3.ZERO


## Interpolates the kind's keys at age a (smoothstep between neighbours).
func _pose(kind: StringName, a: float) -> void:
	var keys: Array = KEYS[kind]
	if a < 0.0 or a >= duration(kind):
		_zero()
		return
	for n in keys.size() - 1:
		var k0: Dictionary = keys[n]
		var k1: Dictionary = keys[n + 1]
		if a >= k0[&"t"] and a < k1[&"t"]:
			var f := smoothstep(0.0, 1.0, (a - k0[&"t"]) / (k1[&"t"] - k0[&"t"]))
			_pos = (k0[&"pos"] as Vector3).lerp(k1[&"pos"], f)
			_hand = (k0[&"hand"] as Vector3).lerp(k1[&"hand"], f)
			_fingers = (k0[&"fingers"] as Vector3).lerp(k1[&"fingers"], f)
			return
	_zero()
