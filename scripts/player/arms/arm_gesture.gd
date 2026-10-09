extends RefCounted
## Left-hand interaction gesture on the goblin arms: keyed joint channels (reach, pole, lean, wrist, curl, spread, frame) drive a per-frame ArmRig.reach re-solve; the root only leans.
##
## Runs after ArmWeave every frame: bone writes post-multiply the weave's freshly written pose,
## so nothing accumulates.

## Kinds that strike a point on the camera ray: IK solve, lunge and slam hand frame.
const KINDS: Array[StringName] = [&"press", &"knock", &"push", &"pull", &"slide_open", &"slide_close"]
const ArmGestureKeys := preload("res://scripts/player/arms/arm_gesture_keys.gd")
const Channels := preload("res://scripts/player/arms/arm_gesture_channels.gd")
const Fingers := preload("res://scripts/player/arms/arm_gesture_fingers.gd")
const Strike := preload("res://scripts/player/arms/arm_gesture_strike.gd")
const WristRoutine := preload("res://scripts/player/arms/arm_wrist_routine.gd")

## Seconds from start to the moment the hand touches the thing.
const CONTACT := ArmGestureKeys.CONTACT
## Root lean cap (rig units) along `dir`.
const LEAN := 0.29
## Sign of the finger fan about the proximal z: index +, ring and pinky -.
const SPREAD_SIGN := 1.0
## Thumb abduction as a share of the fan: the thumb swings off the gun like the fingers fan.
const THUMB_FAN := -1.6
## The debug pin's hit in rig space: 0.9 m straight ahead of the camera (the rig sits at the
## camera's origin, scaled 0.18).
const DEFAULT_HIT_RIG := Vector3(0.0, 0.0, -5.0)
## The shoulder lunges SHOULDER_LUNGE rig units along the perpendicular to the centre ray (at least
## enough to bring the ray within reach by LUNGE_MARGIN, never past it), rising from the coil's end.
const SHOULDER_LUNGE := 0.75
const LUNGE_MARGIN := 0.05

## Slide sign of the current gesture: +1 or -1, which side of the van's axis the player faces.
var lat := 1.0

var _sk: Skeleton3D = null
var _ok := false
var _wrist := -1
var _joints: Array[int] = []
var _kind: StringName = &""
var _start := 0.0
var _now := 0.0  # the clock at the last sample, for set_hit's playing check
var _pos := Vector3.ZERO  # the root lean, the only root motion
# The six channels at the current age (Keys documents each).
var _reach := 0.0
var _slide := 0.0
var _pole := Vector3.ZERO
var _wrist_fd := Vector2.ZERO
var _fingers := Vector3.ZERO
var _spread := Vector2.ZERO
# Reach solve (bind_reach and set_hit); all positions in the left root's space.
var _model: Node3D = null
var _root: Node3D = null
var _fore := -1
var _bound := false
var _has_hit := false
var _shoulder := Vector3.ZERO
var _rest_wrist := Vector3.ZERO
var _rest_pole := Vector3.ZERO
var _hand_dir := Vector3.ZERO
var _palm := Vector3.ZERO
var _big_r := 0.0
var _base_h := Quaternion.IDENTITY
var _base_f := Quaternion.IDENTITY
var _dir := Vector3.FORWARD
## True while a slam kind is posed (solve this frame); _solved while the last solve needs a restore.
var _live := false
var _solved := false
var _age := 0.0
## The camera centre ray in the left root's space: the eye and the unit direction through the hit.
var _eye_left := Vector3.ZERO
var _ray_left := Vector3.FORWARD
@warning_ignore_start("unused_private_class_variable")
var _lunge := 0.0
var _lunge_dir := Vector3.ZERO
@warning_ignore_restore("unused_private_class_variable")
## The press coil depth (rig units) and end time, from the reach keys.
var _coil := 0.0
var _coil_t := 0.0
## Weight of the slam hand frame (the frame channel).
var _frame := 0.0
## The wrist-to-middle-claw-tip vector (rig units) the last frame solved, and what it needs.
var _tip_off := Vector3.ZERO
var _tip := -1
var _tip_len := 0.0
var _to_rig := Transform3D.IDENTITY
## The kind `_pose` last posed (a pinned kind is not `_kind`).
var _posed: StringName = &""


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
	# A re-press mid-gesture only reports the contact time: a restart would snap the arm.
	if not is_playing(now):
		_kind = kind
		_start = now
	return CONTACT[kind]


func clear() -> void:
	_kind = &""
	_zero()


## The weave's beat_scale. A pinned gesture shows the duck a played gesture has at `pin_t`
## (busy from 0, ramping), not the full snap; `pin_t` < 0 is no pin.
static func wrist_scale(weave: RefCounted, delta: float, hold: bool, busy: bool, snap: bool,
		walk: float, pin_t: float) -> float:
	if pin_t < 0.0:
		return weave.wrist_scale(delta, hold, busy, snap, walk)
	weave.wrist_scale(delta, hold, false, true, walk)
	return weave.wrist_scale(pin_t, hold, true, false, walk)


func is_playing(now: float) -> bool:
	return _kind != &"" and now >= _start and now - _start < duration(_kind)


func sample(now: float) -> void:
	_now = now
	# A wrapped clock puts now before the start; drop the gesture rather than replay it.
	if _kind == &"" or now < _start or now - _start >= duration(_kind):
		clear()
		return
	_pose(_kind, now - _start)


func pin(kind: StringName, t: float, eye_rig := Vector3.ZERO) -> void:
	clear()
	if not ArmGestureKeys.KEYS.has(kind):
		return
	set_hit(DEFAULT_HIT_RIG, 1.0, eye_rig)
	_pose(kind, t)


func settle() -> void:
	clear()


func left_offset() -> Transform3D:
	return Transform3D(Basis.IDENTITY, _pos)


## Caches what the press solve needs from the builder's `left_reach` dict.
func bind_reach(model_l: Node3D, inputs: Dictionary) -> void:
	if not _ok or model_l == null:
		return
	_model = model_l
	_root = model_l.get_parent() as Node3D
	_fore = _sk.find_bone("DEF-forearm.L.001")
	if _fore == -1:
		return
	_shoulder = inputs.get("shoulder", Vector3.ZERO) as Vector3
	_rest_wrist = inputs.get("wrist", Vector3.ZERO) as Vector3
	_rest_pole = inputs.get("pole", Vector3.ZERO) as Vector3
	_palm = inputs.get("palm", Vector3.RIGHT) as Vector3
	var elbow := inputs.get("elbow", Vector3.ZERO) as Vector3
	_hand_dir = ((_rest_wrist - elbow).normalized()
			+ Vector3.DOWN * float(inputs.get("drop", 0.0))).normalized()
	_base_h = _sk.get_bone_pose_rotation(_wrist)
	_base_f = _sk.get_bone_pose_rotation(_fore)
	# Full reach R = 0.98 (a + b) in rig units: bone lengths times the model's scale to the rig.
	var to_rig := Transform3D.IDENTITY
	var node: Node = _sk
	while node != _root and node is Node3D:
		to_rig = (node as Node3D).transform * to_rig
		node = node.get_parent()
	var p_u := ArmRig._global_rest(_sk, _sk.find_bone("DEF-upper_arm.L")).origin
	var p_f := ArmRig._global_rest(_sk, _sk.find_bone("DEF-forearm.L")).origin
	var p_h := ArmRig._global_rest(_sk, _wrist).origin
	_big_r = 0.98 * to_rig.basis.x.length() * (p_u.distance_to(p_f) + p_f.distance_to(p_h))
	_to_rig = to_rig
	_tip = _sk.find_bone("DEF-f_middle.03.L")
	var middle: Dictionary = (model_l.get_meta(&"fingers", {}) as Dictionary).get(&"f_middle", {})
	_tip_len = float(middle.get(&"tip_len", 0.0))
	_bound = true


## The interact hit, the camera eye (rig space) and the slide sign: fixes `dir` and the strike ray.
func set_hit(hit_rig: Vector3, lat_sign := 1.0, eye_rig := Vector3.ZERO) -> void:
	if is_playing(_now):
		return
	lat = lat_sign
	if not _bound:
		return
	# The root carries last frame's lean (`_pos`): undo it so a pinned frame depends on t alone.
	var to_left := _root.transform.translated_local(-_pos).affine_inverse()
	var hit_left := to_left * hit_rig
	_eye_left = to_left * eye_rig
	_ray_left = (hit_left - _eye_left).normalized()
	_dir = (hit_left - _shoulder).normalized()
	Strike.set_lunge(self)


func apply_bones() -> void:
	if not _ok:
		return
	if _live:
		var shoulder: Vector3 = Strike.shoulder(self)
		var fr: Array[Vector3] = Strike.frame(self, _frame)
		_solve(shoulder, Strike.aimed(self, shoulder), _pole, fr[0], fr[1])
		_solved = true
	elif _solved:
		_solve(_shoulder, _rest_wrist, _rest_pole, _hand_dir, _palm)
		_solved = false
	_dress()
	if _live:
		_tip_off = Strike.tip_vector(self)


## Puts the wrist bend, finger curl and fan on top of the solved or weave pose.
func _dress() -> void:
	if _wrist_fd == Vector2.ZERO and _fingers == Vector3.ZERO and _spread == Vector2.ZERO:
		return
	var hand := WristRoutine.FLEX_AXIS * _wrist_fd.x + WristRoutine.DEV_AXIS * _wrist_fd.y
	_sk.set_bone_pose_rotation(_wrist, _sk.get_bone_pose_rotation(_wrist)
			* Quaternion.from_euler(hand * (PI / 180.0)))
	for f in 5:
		var deg := _fingers.x if f == 0 else (_fingers.z if f == 4 else _fingers.y)
		var fan := _spread.x if f == 0 else (-_spread.y if f == 2 else (-_spread.x if f == 3 else 0.0))
		for j in 3:
			var i := _joints[f * 3 + j]
			if i == -1:
				continue
			if j == 0 and fan != 0.0:
				_sk.set_bone_pose_rotation(i, _sk.get_bone_pose_rotation(i)
						* Quaternion(Vector3.BACK, deg_to_rad(fan * SPREAD_SIGN)))
			_sk.set_bone_pose_rotation(i, _sk.get_bone_pose_rotation(i)
					* Quaternion(Vector3.RIGHT, deg_to_rad(deg / 3.0) * ArmRig.CURL_SIGN))
	if _live:
		Fingers.straighten(_sk, _joints, Fingers.weight(_posed, _age, _fingers.y), _spread)
	var thumb := _joints[12]
	if thumb != -1 and _spread.x != 0.0:
		_sk.set_bone_pose_rotation(thumb, _sk.get_bone_pose_rotation(thumb)
				* Quaternion(Vector3.BACK, deg_to_rad(_spread.x * THUMB_FAN * SPREAD_SIGN)))


func duration(kind: StringName) -> float:
	return ArmGestureKeys.DURATION.get(kind, 0.0)


## Re-solves the left arm to `target`, then puts this frame's weave and routine offsets back on
## the forearm twist and the hand.
func _solve(shoulder: Vector3, target: Vector3, pole: Vector3, hand_dir: Vector3,
		palm: Vector3) -> void:
	var df := _base_f.inverse() * _sk.get_bone_pose_rotation(_fore)
	var dh := _base_h.inverse() * _sk.get_bone_pose_rotation(_wrist)
	ArmRig.reach(_model, ".L", shoulder, target, pole, hand_dir, palm)
	_sk.set_bone_pose_rotation(_fore, _sk.get_bone_pose_rotation(_fore) * df)
	_sk.set_bone_pose_rotation(_wrist, _sk.get_bone_pose_rotation(_wrist) * dh)


func _zero() -> void:
	_live = false
	_pos = Vector3.ZERO
	_wrist_fd = Vector2.ZERO
	_fingers = Vector3.ZERO
	_spread = Vector2.ZERO


## Samples each channel of the kind at age a, independently.
func _pose(kind: StringName, a: float) -> void:
	if a < 0.0 or a >= duration(kind):
		_zero()
		return
	var ch: Dictionary = ArmGestureKeys.KEYS[kind]
	var lean: float = Channels.sample(ch.get(&"lean", []), a, 0.0)
	_pos = _dir * clampf(lean, 0.0, LEAN) + Strike.side(kind, lat) * lean * 0.5
	_wrist_fd = Channels.sample(ch.get(&"wrist", []), a, Vector2.ZERO)
	_fingers = Channels.sample(ch.get(&"curl", []), a, Vector3.ZERO)
	_spread = Channels.sample(ch.get(&"spread", []), a, Vector2.ZERO)
	_live = _bound and _has_hit
	if _live:
		var reach: Array = ch[&"reach"]
		_age = a
		_posed = kind
		_coil = -float(reach[1][&"v"])
		_coil_t = reach[1][&"t"]
		_reach = Channels.sample(reach, a, 0.0)
		_slide = Channels.sample(ch.get(&"slide", []), a, 0.0)
		_pole = Channels.sample(ch.get(&"pole", []), a, _rest_pole)
		_frame = Channels.sample(ch.get(&"frame", []), a, 0.0)
