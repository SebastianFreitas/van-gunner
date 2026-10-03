extends RefCounted
## Debug console `arms wristang`: the left wrist's flex, twist and deviation in degrees against the posed wrist, the forearm.001 twist, an axis-sign experiment and a range and speed scan.

const USAGE := "arms wristang [t|axes|scan [t0 t1]]"
const NO_WRIST := "arms wristang: no left wrist"
## Scan step, one frame at 60 fps.
const DT := 1.0 / 60.0
const RAD_TO_DEG := 180.0 / PI
## Test turn per axis in `axes`, and the finger curl the weave's +20 stands in for.
const AXIS_DEG := 10.0
const CURL_DEG := 20.0

var _weave: RefCounted = null
var _sk: Skeleton3D = null
var _wrist := -1
## The posed wrist the weave turns from (`wrist_pose`), so zero euler means the rest of the weave.
var _pose := Quaternion.IDENTITY


## Prints the left wrist's angles for `arms wristang [t|axes|scan [t0 t1]]`; `args[0]` is
## "wristang". Read-only apart from posing the bones, which the viewmodel overwrites next frame.
func run(vm: Node, args: Array) -> String:
	_weave = vm.get("_weave")
	if _weave == null:
		return NO_WRIST
	var hands: Array = _weave.get("_hands")
	for h in hands:
		if h is Dictionary and h[&"suffix"] == ".L":
			_sk = h[&"sk"] as Skeleton3D
			_wrist = h[&"wrist"]
			_pose = h[&"wrist_pose"]
	if _sk == null or not is_instance_valid(_sk) or _wrist == -1:
		return NO_WRIST
	if args.size() < 2:
		return _reading(-1.0)
	var word := str(args[1])
	if word == "axes":
		return _axes()
	if word == "scan":
		if args.size() == 2:
			return _scan(0.0, 10.8)
		if args.size() == 4 and str(args[2]).is_valid_float() and str(args[3]).is_valid_float():
			return _scan(maxf(0.0, str(args[2]).to_float()), str(args[3]).to_float())
		return USAGE
	if word.is_valid_float():
		return _reading(maxf(0.0, word.to_float()))
	return USAGE


## Wrist rotation relative to the posed wrist, read from the skeleton as the weave left it.
func _rel() -> Quaternion:
	_sk.force_update_all_bone_transforms()
	return _pose.inverse() * _sk.get_bone_pose_rotation(_wrist)


## Euler degrees (x flex, y twist, z sideways) of a relative rotation: the same YXZ order the
## weave builds it with, so this returns the euler it wrote.
func _angles(q_rel: Quaternion) -> Vector3:
	return Basis(q_rel).get_euler() * RAD_TO_DEG


## One reading line; `t` below 0 means the live pose.
func _reading(t: float) -> String:
	var label := "live"
	if t >= 0.0:
		_weave.call(&"update", t)
		label = "%.3f" % t
	var ang := _angles(_rel())
	return ("wristang t=%s  left wrist: flex(x)=%+.1f  twist(y)=%+.1f  dev(z)=%+.1f deg"
			+ "   %s") % [label, ang.x, ang.y, ang.z, _forearm_twist()]


## The forearm.001 twist about its own Y as swing-twist, signed degrees, wrapped to -180..180.
func _forearm_twist() -> String:
	var tag := "forearm.001 twist (about its Y)"
	var i := _sk.find_bone("DEF-forearm.L.001")
	if i == -1:
		return tag + "=n/a (bone not found)"
	var rest := _sk.get_bone_rest(i).basis.get_rotation_quaternion()
	var q := rest.inverse() * _sk.get_bone_pose_rotation(i)
	var raw := rad_to_deg(2.0 * atan2(Vector3(q.x, q.y, q.z).dot(Vector3.UP), q.w))
	var twist := wrapf(raw, -180.0, 180.0)
	return "%s=%+.1f deg" % [tag, twist]


func _pos(bone: int) -> Vector3:
	return _sk.get_bone_global_pose(bone).origin


## Turns the wrist alone by `euler_deg` (no weave update, no creep) and returns nothing; the
## fingers keep the pose they have.
func _turn(euler_deg: Vector3) -> void:
	_sk.set_bone_pose_rotation(_wrist, _pose * Quaternion.from_euler(euler_deg * (PI / 180.0)))
	_sk.force_update_all_bone_transforms()


## For +10 degrees on each euler axis, how the middle fingertip and thumb base move against
## the palm-ward (finger curl) direction and the thumb-to-pinky side, so the signs get named.
func _axes() -> String:
	var names := {&"mid": "DEF-f_middle.01.L", &"tip": "DEF-f_middle.03.L",
			&"thumb": "DEF-thumb.01.L", &"pinky": "DEF-f_pinky.01.L"}
	var bones := {}
	var lines: Array[String] = []
	for key: StringName in names:
		bones[key] = _sk.find_bone(names[key])
		if bones[key] == -1:
			lines.append("axes: bone %s not found" % names[key])
	if not lines.is_empty():
		for axis_name in ["x", "y", "z"]:
			lines.append("axes +%ddeg %s: skipped" % [int(AXIS_DEG), axis_name])
		return "\n".join(lines)
	var mid: int = bones[&"mid"]
	var tip: int = bones[&"tip"]
	var thumb: int = bones[&"thumb"]
	var pinky: int = bones[&"pinky"]
	_turn(Vector3.ZERO)
	var tip0 := _pos(tip)
	var thumb0 := _pos(thumb)
	var hand_axis := _pos(mid) - _sk.get_bone_global_pose(_wrist).origin
	var hand_len := hand_axis.length()
	var hand_dir := hand_axis.normalized()
	var side := _pos(thumb) - _pos(pinky)
	side = (side - hand_dir * side.dot(hand_dir)).normalized()
	# A palm-ward move is the one a positive finger curl makes, written the way the weave does.
	var joint_rot := _sk.get_bone_pose_rotation(mid)
	_sk.set_bone_pose_rotation(mid, joint_rot * Quaternion(Vector3.RIGHT,
			deg_to_rad(CURL_DEG) * ArmRig.CURL_SIGN))
	_sk.force_update_all_bone_transforms()
	var d_curl := _pos(tip) - tip0
	_sk.set_bone_pose_rotation(mid, joint_rot)
	# The curl is not square to the thumb side, so the palm-ward axis is what is left of it once
	# the hand axis and the thumb side are taken out (Gram-Schmidt).
	var palm := d_curl - hand_dir * d_curl.dot(hand_dir) - side * d_curl.dot(side)
	if palm.length() < hand_len * 1e-4:
		_weave.call(&"update", 0.0)
		return "axes: curl displacement has no palm-ward part"
	palm = palm.normalized()
	lines.append("palm frame: |a.s|=%.2f |a.p|=%.2f |s.p|=%.2f" % [absf(hand_dir.dot(side)),
			absf(hand_dir.dot(palm)), absf(side.dot(palm))])
	# A hand is 8 to 10 cm: only a metre scale skeleton is printed in centimetres.
	var metres := hand_len > 0.04 and hand_len < 0.2
	var unit := "cm" if metres else "units"
	var dec := 1 if metres else 3
	var k := 100.0 if metres else 1.0
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var axis_names := ["x", "y", "z"]
	for n in 3:
		_turn((axes[n] as Vector3) * AXIS_DEG)
		var d_tip := _pos(tip) - tip0
		var d_thumb := _pos(thumb) - thumb0
		# Fractions of the displacement along the hand (x), thumb side (y) and palm-ward (z).
		var moved := d_thumb if n == 1 else d_tip
		var dir := moved.normalized()
		var frac := Vector3(dir.dot(hand_dir), dir.dot(side), dir.dot(palm))
		var big := 0
		for i in 3:
			if absf(frac[i]) > absf(frac[big]):
				big = i
		var clear := absf(frac[big]) > 0.7
		var fracs := "a=%+.2f s=%+.2f p=%+.2f" % [frac.x, frac.y, frac.z]
		var verdict := "UNCLEAR"
		if n == 1:
			var head := "axes +%ddeg y: tip moves %s %s" % [int(AXIS_DEG),
					String.num(d_tip.length() * k, dec), unit]
			if clear and big == 2:
				verdict = "+y = thumb palm-ward" if frac.z > 0.0 else "+y = thumb back-of-hand-ward"
			elif clear and big == 1:
				verdict = "+y = thumb sideways"
			lines.append("%s; thumb base along %s -> %s" % [head, fracs, verdict])
			continue
		if clear and big == 2:
			verdict = "+%s = FLEXION" % axis_names[n] if frac.z > 0.0 \
					else "+%s = EXTENSION" % axis_names[n]
		elif clear and big == 1:
			verdict = "+%s = DEVIATION toward THUMB" % axis_names[n] if frac.y > 0.0 \
					else "+%s = DEVIATION toward PINKY" % axis_names[n]
		elif clear:
			verdict = "UNCLEAR (along the hand)"
		lines.append("axes +%ddeg %s: tip %s %s; %s -> %s" % [int(AXIS_DEG), axis_names[n],
				String.num(d_tip.length() * k, dec), unit, fracs, verdict])
	_weave.call(&"update", 0.0)
	return "\n".join(lines)


## Range, peak angular speed and largest per-frame jump of the wrist over t0..t1. `t` only
## steps upward, as in play, so the creep sampler sees time the way it does there.
func _scan(t0: float, t1: float) -> String:
	if t1 <= t0:
		return USAGE
	var steps := int(roundf((t1 - t0) / DT))
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var peak_jump := 0.0
	var peak_t := t0
	var prev := Quaternion.IDENTITY
	for i in steps + 1:
		var t := t0 + i * DT
		_weave.call(&"update", t)
		var q_rel := _rel()
		var ang := _angles(q_rel)
		lo = lo.min(ang)
		hi = hi.max(ang)
		if i > 0:
			var jump := rad_to_deg(2.0 * acos(clampf(absf((prev.inverse() * q_rel).w), 0.0, 1.0)))
			if jump > peak_jump:
				peak_jump = jump
				peak_t = t
		prev = q_rel
	_weave.call(&"update", 0.0)
	return ("wristang scan %.2f..%.2f (%d steps, dt 1/60):\n" % [t0, t1, steps]
			+ "  flex(x) min %+.1f max %+.1f | twist(y) min %+.1f max %+.1f"
			% [lo.x, hi.x, lo.y, hi.y]
			+ " | dev(z) min %+.1f max %+.1f deg\n" % [lo.z, hi.z]
			+ "  peak speed %.1f deg/s at t=%.2f | max jump %.2f deg/frame at t=%.2f"
			% [peak_jump / DT, peak_t, peak_jump, peak_t])
