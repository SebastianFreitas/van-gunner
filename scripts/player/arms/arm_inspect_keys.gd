extends RefCounted
## Keys of the gun inspect (plan arms-inspect-anim, phases 1 and 2): the LEFT arm (shoulder, wrist, hand_dir, palm roll, fingers, spread) and the RIGHT root offset (pos, rot), sampled by age.
##
## Times are seconds after play, values rig units and degrees. Ease `out` goes into a hold, `in`
## out of it. The palm is a base direction plus a roll about hand_dir, so the 180 degree turn
## never lerps through zero.

const Channels := preload("res://scripts/player/arms/arm_gesture_channels.gd")

const T_REST := 0.10
const T_B2_END := 0.70
const T_B2_HOLD := 1.50
const T_B3_END := 2.00
const T_SPREAD_START := 1.65
const T_SPREAD_END := 2.15
const T_B3_HOLD := 2.80
const T_B4_END := 3.40
## After the tattoo hold the gun turns: pose A (left side) by T_B5_END, pose B (right side) by
## T_B6_END, back to the dip by T_B7_END.
const T_B4_HOLD := 4.90
const T_B5_END := 5.40
const T_B5_HOLD := 5.80
const T_B6_END := 6.30
const T_B6_HOLD := 6.70
const T_B7_END := 7.20

## The gun dip about the grip (spec p1-2): down and canted out to the right.
const DIP_DOWN := 0.1
const DIP_CANT_DEG := 10.0
## Right root offset at pose A (gun's left side to the eye) and its euler (pitch, yaw, roll)
## degrees; pose B rolls it over to the right side.
const GRIP_A := Vector3(-0.25, 0.22, 0.30)
const ROT_A_DEG := Vector3(0.0, 70.0, 0.0)
const ROT_B_DEG := Vector3(0.0, 70.0, 150.0)

## Beat 2 shoulder S' (0.98 unit along u (0.675, 0.675, -0.30) from LEFT_SHOULDER).
const SHOULDER_B2 := Vector3(-0.737, -0.737, -0.569)
## Beat 4 slide 0.08 less (D45, spec p1-6), after W4 moved down: keeps the elbow at 120 or more.
const SHOULDER_B4 := Vector3(-0.791, -0.791, -0.545)
const HAND_DIR_B2 := Vector3(0.871, 0.490, 0.0)
## Beat 4 unfolds the wrist (D44, spec p1-6): the claw fold read as a puppet head.
const HAND_DIR_B4 := Vector3(0.95, 0.31, 0.0)
## Hand centre at the crosshair, wrist depth 0.97; the wrist sits half a hand back of it.
const HAND_CENTRE_B2 := Vector3(0.0, 0.0, -0.97)
## Back of the hand to the eye.
## Probe fallback 1.1 (spec p1-2): hand centre 59,62 px off the crosshair, shifted back.
const W2_SHIFT := Vector3(-0.049, -0.052, 0.0)
const PALM_B2 := Vector3(0.2, -0.3, -0.93)
const WRIST_B4 := Vector3(0.03, -0.004, -0.93)
## Beat 5 palm: from the half-dropped wrist (-0.385, -0.302, -1.09, half way from WRIST_B4 to
## LEFT_SHOWN_WRIST) toward the grip at pose A (HeldGun.GRIP + GRIP_A = (0.16, -0.23, -1.30)),
## normalised. The roll key is cancelled so the sampled palm_n is exactly this.
const PALM_B5 := Vector3(0.926, 0.122, -0.357)
## Beat 4 total roll about hand_dir from PALM_B2 (degrees); spec p1-2 tunes it so the tattoo
## face looks at the camera.
const ROLL_B4_DEG := -45.0
const ROLL_B3_DEG := 180.0
## Elbow down, not LEFT_HANG_POLE, so the upper arm stays out of the frame.
const POLE := Vector3(0.2, -1.0, 0.0)

## Finger curl (thumb, middle, pinky) on top of the baked LEFT_CURL, degrees; spread (thumb and
## index fan, ring and pinky fan).
const FINGERS_B2 := Vector3(20.0, 25.0, 25.0)
const FINGERS_B3 := Vector3(-20.0, -20.0, -5.0)
const FINGERS_B4 := Vector3(10.0, 12.0, 12.0)
const SPREAD_B3 := Vector2(24.0, 12.0)
## Beat 1 anticipation: the left wrist sinks and the fingers curl (`dress` spreads the value over
## three joints, so 30 is 10 degrees each) before the lift.
const DIP_WRIST := 0.05
const DIP_CURL := Vector3(30.0, 30.0, 30.0)
## The fingers trail the hand by this many seconds (every finger and spread key after t 0).
const FINGER_LAG := 0.15
## Hold sway: wrist deviation amplitude (degrees) and period (seconds), faded in and out by an
## envelope that is 1 in every hold and 0 in every travel.
const SWAY_DEG := 1.5
const SWAY_PERIOD := 2.2
const SWAY_FADE := 0.1

var _shoulder: Array = []
var _wrist: Array = []
var _hand_dir: Array = []
var _palm: Array = []
var _roll: Array = []
var _fingers: Array = []
var _spread: Array = []
var _sway: Array = []
var _r_pos: Array = []
var _r_rot: Array = []


## `palm_len` is ArmRig.palm_len(model_l) * ArmsBuilder.HAND_K; the rest values come from the
## solver (ArmInspectSolve.rest_*).
func _init(rest_shoulder: Vector3, rest_wrist: Vector3, rest_hand_dir: Vector3, rest_palm: Vector3,
		palm_len: float) -> void:
	var dir_b2 := HAND_DIR_B2.normalized()
	var wrist_b2 := HAND_CENTRE_B2 - 0.5 * palm_len * dir_b2 + W2_SHIFT
	# Beats 5 and 6 half-drop the left hand: half way from beat 4 back to the rest pose.
	var dir_b4 := HAND_DIR_B4.normalized()
	var dir_b5 := dir_b4.lerp(rest_hand_dir, 0.5).normalized()
	var roll_b5 := ROLL_B4_DEG * 0.5
	var palm_b5 := Quaternion(dir_b5, -deg_to_rad(roll_b5)) * PALM_B5
	var shoulder_b5 := SHOULDER_B4.lerp(rest_shoulder, 0.5)
	var wrist_b5 := WRIST_B4.lerp(rest_wrist, 0.5)
	var dip_pos := Vector3(0.0, -DIP_DOWN, 0.0)
	var dip_rot := Vector3(0.0, 0.0, -DIP_CANT_DEG)
	_shoulder = [
		_k(0.0, rest_shoulder), _k(T_REST, rest_shoulder),
		_k(T_B2_END, SHOULDER_B2, &"out"), _k(T_B3_HOLD, SHOULDER_B2),
		_k(T_B4_END, SHOULDER_B4, &"out"), _k(T_B4_HOLD, SHOULDER_B4),
		_k(T_B5_END, shoulder_b5, &"out"), _k(T_B6_HOLD, shoulder_b5),
		_k(T_B7_END, SHOULDER_B4),
	]
	_wrist = [
		_k(0.0, rest_wrist), _k(T_REST, rest_wrist + Vector3(0.0, -DIP_WRIST, 0.0), &"out"),
		_k(T_B2_END, wrist_b2, &"out"),
		_k(T_B2_HOLD, wrist_b2), _k(T_B3_HOLD, wrist_b2), _k(T_B4_END, WRIST_B4, &"out"),
		_k(T_B4_HOLD, WRIST_B4), _k(T_B5_END, wrist_b5, &"out"), _k(T_B6_HOLD, wrist_b5),
		_k(T_B7_END, WRIST_B4),
	]
	_hand_dir = [
		_k(0.0, rest_hand_dir), _k(T_REST, rest_hand_dir), _k(T_B2_END, dir_b2, &"out"),
		_k(T_B3_HOLD, dir_b2), _k(T_B4_END, dir_b4, &"out"), _k(T_B4_HOLD, dir_b4),
		_k(T_B5_END, dir_b5, &"out"), _k(T_B6_HOLD, dir_b5), _k(T_B7_END, dir_b4),
	]
	_palm = [
		_k(0.0, rest_palm), _k(T_REST, rest_palm), _k(T_B2_END, PALM_B2.normalized(), &"out"),
		_k(T_B4_HOLD, PALM_B2.normalized()), _k(T_B5_END, palm_b5, &"out"),
		_k(T_B6_HOLD, palm_b5), _k(T_B7_END, PALM_B2.normalized()),
	]
	_roll = [
		_k(0.0, 0.0), _k(T_B2_HOLD, 0.0), _k(T_B3_END, ROLL_B3_DEG, &"out"),
		_k(T_B3_HOLD, ROLL_B3_DEG), _k(T_B4_END, ROLL_B4_DEG, &"out"), _k(T_B4_HOLD, ROLL_B4_DEG),
		_k(T_B5_END, roll_b5, &"out"), _k(T_B6_HOLD, roll_b5), _k(T_B7_END, ROLL_B4_DEG),
	]
	_fingers = [
		_k(0.0, Vector3.ZERO), _k(T_REST + FINGER_LAG, DIP_CURL, &"out"),
		_k(T_B2_END + FINGER_LAG, FINGERS_B2, &"out"),
		_k(T_B2_HOLD + FINGER_LAG, FINGERS_B2), _k(T_B3_END + FINGER_LAG, FINGERS_B3, &"out"),
		_k(T_B3_HOLD + FINGER_LAG, FINGERS_B3), _k(T_B4_END + FINGER_LAG, FINGERS_B4, &"out"),
		_k(T_B4_HOLD + FINGER_LAG, FINGERS_B4), _k(T_B5_END + FINGER_LAG, FINGERS_B4 * 0.5, &"out"),
		_k(T_B6_HOLD + FINGER_LAG, FINGERS_B4 * 0.5), _k(T_B7_END + FINGER_LAG, FINGERS_B4),
	]
	_spread = [
		_k(0.0, Vector2.ZERO), _k(T_SPREAD_START + FINGER_LAG, Vector2.ZERO),
		_k(T_SPREAD_END + FINGER_LAG, SPREAD_B3, &"out"), _k(T_B3_HOLD + FINGER_LAG, SPREAD_B3),
		_k(T_B4_END + FINGER_LAG, Vector2.ZERO, &"out"),
	]
	_sway = [_k(0.0, 0.0)]
	var holds := [[T_B2_END, T_B2_HOLD], [T_B3_END, T_B3_HOLD], [T_B4_END, T_B4_HOLD],
			[T_B5_END, T_B5_HOLD], [T_B6_END, T_B6_HOLD]]
	for h: Array in holds:
		var s: float = h[0]
		var e: float = h[1]
		_sway.append_array([_k(s - SWAY_FADE, 0.0), _k(s, 1.0, &"out"), _k(e, 1.0),
				_k(e + SWAY_FADE, 0.0, &"in")])
	_sway.append_array([_k(T_B7_END - SWAY_FADE, 0.0), _k(T_B7_END, 1.0, &"out")])
	_r_pos = [
		_k(0.0, Vector3.ZERO), _k(T_REST, Vector3.ZERO), _k(T_B2_END, dip_pos, &"out"),
		_k(T_B4_HOLD, dip_pos), _k(T_B5_END, GRIP_A), _k(T_B5_HOLD, GRIP_A),
		_k(T_B6_END, GRIP_A), _k(T_B6_HOLD, GRIP_A), _k(T_B7_END, dip_pos),
	]
	_r_rot = [
		_k(0.0, Vector3.ZERO), _k(T_REST, Vector3.ZERO), _k(T_B2_END, dip_rot, &"out"),
		_k(T_B4_HOLD, dip_rot), _k(T_B5_END, ROT_A_DEG), _k(T_B5_HOLD, ROT_A_DEG),
		_k(T_B6_END, ROT_B_DEG), _k(T_B6_HOLD, ROT_B_DEG), _k(T_B7_END, dip_rot),
	]


static func _k(t: float, v: Variant, ease_name := &"") -> Dictionary:
	var key := {&"t": t, &"v": v}
	if ease_name != &"":
		key[&"ease"] = ease_name
	return key


## Every channel at age `a`: LEFT shoulder, wrist, hand_dir, palm_n (Vector3), fingers (Vector3),
## spread (Vector2); RIGHT r_pos and r_rot (Vector3). The last keys hold forever.
func sample(a: float) -> Dictionary:
	var dir: Vector3 = (Channels.sample(_hand_dir, a, Vector3.RIGHT) as Vector3).normalized()
	var palm: Vector3 = (Channels.sample(_palm, a, Vector3.RIGHT) as Vector3).normalized()
	var roll: float = Channels.sample(_roll, a, 0.0)
	var env: float = Channels.sample(_sway, a, 0.0)
	return {
		&"wrist_fd": Vector2(0.0, SWAY_DEG * sin(TAU * a / SWAY_PERIOD) * env),
		&"shoulder": Channels.sample(_shoulder, a, Vector3.ZERO),
		&"wrist": Channels.sample(_wrist, a, Vector3.ZERO),
		&"hand_dir": dir,
		&"palm_n": Quaternion(dir, deg_to_rad(roll)) * palm,
		&"fingers": Channels.sample(_fingers, a, Vector3.ZERO),
		&"spread": Channels.sample(_spread, a, Vector2.ZERO),
		&"r_pos": Channels.sample(_r_pos, a, Vector3.ZERO),
		&"r_rot": Channels.sample(_r_rot, a, Vector3.ZERO),
	}
