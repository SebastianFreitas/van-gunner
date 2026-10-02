extends RefCounted
## Shot impact on the goblin arms: a time-sampled kick (root slide, forearm lift about the elbow, hand and gun flex about the wrist, trigger pull and grip squeeze, left-hand jolt) summed over recent shots.
##
## Each shot is an analytic impulse response per channel, so overlapping shots just add and a
## soft cap keeps held fire bounded; nothing restarts or snaps. The pivots are the right arm's
## real joints, so the forearm lifts about the elbow and the hand (and gun) flex about the wrist.
## It runs after ArmWeave every frame: finger writes post-multiply the weave's pose and the hand
## bone is written absolute from its rest-pose rotation, so nothing accumulates.

const MAX_SHOTS := 8
const LIFE := 0.6  ## seconds a shot counts
const SOFT_CAP := 1.5
const BACK := 0.14  ## rig-space metres the root slides back along the barrel
const LIFT := 0.03  ## and up
const ARM_PITCH := 6.0  ## degrees, root about the right elbow
const WRIST_PITCH := 14.0  ## degrees, hand and gun about the wrist, muzzle up
const ROLL := 4.0  ## degrees about the wrist, per-shot signed
const YAW := 2.0
const SQUEEZE := 8.0  ## degrees of extra curl on the right middle/ring/pinky/thumb
const TRIGGER_PULL := 16.0  ## degrees of extra curl on the right index, all three joints
const LEFT_BACK := 0.05
const LEFT_PITCH := 2.5
const LEFT_DELAY := 0.04
## Envelopes as (delay, attack, tau, omega): sine attack, then a damped cosine.
const ENV_BACK := Vector4(0.0, 0.03, 0.065, 16.0)
const ENV_ARM := Vector4(0.0, 0.045, 0.07, 14.0)
const ENV_WRIST := Vector4(0.0, 0.025, 0.06, 22.0)
const ENV_JITTER := Vector4(0.0, 0.035, 0.065, 15.0)
const ENV_GRIP := Vector4(0.0, 0.02, 0.06, 0.0)
const ENV_TRIGGER := Vector4(0.0, 0.015, 0.06, 0.0)
const ENV_LEFT := Vector4(LEFT_DELAY, 0.05, 0.06, 12.0)

## Channel slots in `_ch`.
const C_BACK := 0
const C_ARM := 1
const C_WRIST := 2
const C_ROLL := 3
const C_YAW := 4
const C_GRIP := 5
const C_TRIG := 6
const C_LEFT := 7

var _sk: Skeleton3D = null
var _ok := false
var _hand := -1
var _hand_base := Quaternion.IDENTITY
## Right finger joint bone indices, three per finger in ArmRig.FINGERS order (index first).
var _joints: Array[int] = []
var _elbow_pt := Vector3.ZERO
var _wrist_pt := Vector3.ZERO
var _parent_q := Quaternion.IDENTITY
var _axis_x := Vector3.RIGHT
var _back := Vector3.BACK
var _shots: Array[Dictionary] = []
var _ch := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var _right := Transform3D.IDENTITY
var _left := Transform3D.IDENTITY
var _wrist := Transform3D.IDENTITY


func _init(arm_right: Node3D, gun_root: Node3D) -> void:
	if arm_right == null or gun_root == null:
		push_warning("ArmKick: no right arm or gun root")
		return
	_sk = ArmRig.skeleton(arm_right)
	if _sk == null:
		push_warning("ArmKick: right arm has no skeleton")
		return
	var elbow := _sk.find_bone("DEF-forearm.R")
	_hand = _sk.find_bone("DEF-hand.R")
	if elbow == -1 or _hand == -1:
		push_warning("ArmKick: elbow or wrist bone not found")
		return
	_hand_base = _sk.get_bone_pose_rotation(_hand)
	for f in ArmRig.FINGERS:
		for j in 3:
			var i := _sk.find_bone("DEF-%s.0%d.R" % [f, j + 1])
			if i == -1:
				push_warning("ArmKick: finger bone not found: %s %d" % [f, j + 1])
				return
			_joints.append(i)
	# Root space is the space of arm_right.transform's parent; get_bone_global_pose is stale
	# right after the build, so compose the local poses by hand.
	var to_root := arm_right.transform
	var node: Node = _sk
	var rel := Transform3D.IDENTITY
	while node != arm_right and node is Node3D:
		rel = (node as Node3D).transform * rel
		node = node.get_parent()
	to_root = to_root * rel
	_elbow_pt = (to_root * _bone_chain(elbow)).origin
	_wrist_pt = (to_root * _bone_chain(_hand)).origin
	var parent := _sk.get_bone_parent(_hand)
	var parent_basis := (to_root * _bone_chain(parent)).basis if parent != -1 else to_root.basis
	_parent_q = parent_basis.orthonormalized().get_rotation_quaternion()
	var gx := HeldGun.gun_xform()
	_axis_x = gx.basis.x.normalized()
	_back = gx.basis.z.normalized()
	_ok = true


## Shot `index` fired at clock time `now`.
func fire(now: float, index: int) -> void:
	_shots.append({&"t": now, &"i": index})
	if _shots.size() > MAX_SHOTS:
		_shots.remove_at(0)


func clear() -> void:
	_shots.clear()


## Sums every live shot at clock time `now`, then poses the offsets and bones.
func sample(now: float) -> void:
	if not _ok:
		return
	_ch.fill(0.0)
	var keep: Array[Dictionary] = []
	for s in _shots:
		if now - (s[&"t"] as float) <= LIFE:
			keep.append(s)
			_add_shot(now - (s[&"t"] as float), s[&"i"] as int)
	_shots = keep
	_finish()


## Like `sample`, as if exactly one shot (index 0) fired at time 0 and now = `t`.
func pin(t: float) -> void:
	if not _ok:
		return
	_ch.fill(0.0)
	_add_shot(t, 0)
	_finish()


func right_offset() -> Transform3D:
	return _right


func left_offset() -> Transform3D:
	return _left


func wrist_offset() -> Transform3D:
	return _wrist


## One shot's impulse response at age `t` seconds.
static func response(env: Vector4, t: float) -> float:
	var u := t - env.x
	if u < 0.0:
		return 0.0
	if u < env.y:
		return sin(PI * 0.5 * u / env.y)
	var v := u - env.y
	if v > LIFE:
		return 0.0
	return exp(-v / env.z) * cos(env.w * v)


func _add_shot(age: float, index: int) -> void:
	var s := 1.0 if index % 2 == 0 else -1.0
	var h := fposmod(sin(float(index) * 12.9898) * 43758.5453, 1.0)
	var j := 0.6 + 0.4 * h
	var jitter := response(ENV_JITTER, age)
	_ch[C_BACK] += response(ENV_BACK, age)
	_ch[C_ARM] += response(ENV_ARM, age)
	_ch[C_WRIST] += response(ENV_WRIST, age)
	_ch[C_ROLL] += s * j * jitter
	_ch[C_YAW] += -s * (1.4 - j) * jitter
	_ch[C_GRIP] += response(ENV_GRIP, age)
	_ch[C_TRIG] += response(ENV_TRIGGER, age)
	_ch[C_LEFT] += response(ENV_LEFT, age)


## Soft-caps the sums, builds the three offsets and writes the hand and finger bones.
func _finish() -> void:
	for c in _ch.size():
		_ch[c] = SOFT_CAP * tanh(_ch[c] / SOFT_CAP)
	var back := _ch[C_BACK]
	var wrist_b := Basis(_axis_x, deg_to_rad(WRIST_PITCH) * _ch[C_WRIST])
	_right = Transform3D(Basis.IDENTITY, _back * BACK * back + Vector3.UP * LIFT * back) \
			* _about(_elbow_pt, Basis(_axis_x, deg_to_rad(ARM_PITCH) * _ch[C_ARM])) \
			* _about(_wrist_pt, Basis(Vector3.BACK, deg_to_rad(ROLL) * _ch[C_ROLL])
					* Basis(Vector3.UP, deg_to_rad(YAW) * _ch[C_YAW]))
	_wrist = _about(_wrist_pt, wrist_b)
	_left = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(LEFT_PITCH) * _ch[C_LEFT]),
			Vector3(0.0, 0.0, LEFT_BACK * _ch[C_LEFT]))
	var q_w := wrist_b.get_rotation_quaternion()
	_sk.set_bone_pose_rotation(_hand, (_parent_q.inverse() * q_w * _parent_q) * _hand_base)
	for k in _joints.size():
		var deg := TRIGGER_PULL * _ch[C_TRIG] if k < 3 else SQUEEZE * _ch[C_GRIP]
		if absf(deg) < 0.01:
			continue
		var i := _joints[k]
		_sk.set_bone_pose_rotation(i, _sk.get_bone_pose_rotation(i)
				* Quaternion(Vector3.RIGHT, deg_to_rad(deg) * ArmRig.CURL_SIGN))


func _about(pivot: Vector3, b: Basis) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pivot) * Transform3D(b, Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -pivot)


## Bone `i` in the skeleton's space, from the local poses, root bone first.
func _bone_chain(i: int) -> Transform3D:
	var t := Transform3D.IDENTITY
	var b := i
	while b != -1:
		t = _sk.get_bone_pose(b) * t
		b = _sk.get_bone_parent(b)
	return t
