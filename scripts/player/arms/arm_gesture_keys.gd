extends RefCounted
## Key tables for ArmGesture: per kind, six channels of keys {t, v, ease}, plus contact times and durations.

## Seconds from start to the moment the hand touches the thing.
const CONTACT := {
	&"press": 0.22, &"knock": 0.22, &"push": 0.22, &"pull": 0.22,
	&"slide_open": 0.22, &"slide_close": 0.22,
}

## Seconds a gesture runs, the time of its last key.
const DURATION := {
	&"press": 0.52, &"knock": 0.66, &"push": 0.55, &"pull": 0.65,
	&"slide_open": 0.71, &"slide_close": 0.71,
}

## Per kind, per channel, keys of t (s), v and ease (`in`, `out`, `smooth`, `snap`; default
## smooth), the ease shaping the segment that ends at the key. `snap` rings from the previous
## key's v about the key's v: damped cosine with optional `tau` and `omega`. A channel holds its
## last value after its last key; a missing channel stays 0 (pole: the rest pole).
## - reach: float along `dir` from the rest wrist; slam kinds: -coil at keys[1], 1.0 = the centre-ray
##   point at full reach (the solver clamps).
## - pole: elbow pole, rig space.
## - lean: root offset along `dir`, at most 0.29.
## - wrist: Vector2 flex, dev in degrees.
## - curl: Vector3 index, middle/ring/pinky, thumb degrees; positive curls.
## - spread: Vector2 index/pinky fan, ring fan, degrees.
## - slide: float, rig units of sideways yank along `ArmGestureStrike.side` (the slides only).
## - frame: float 0..1, weight of the slam hand frame (palm along `dir`) over the baked one.
## Slam kinds (press, knock, push) use reach 1.0 at contact and 1.0 + an offset in rig units after it,
## the recoil; the last two reach keys bound the settle back to the rest wrist.
const KEYS := {
	&"press": {
		&"reach": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": -0.25, &"ease": &"out"},
			{&"t": 0.22, &"v": 1.0, &"ease": &"in"},
			{&"t": 0.27, &"v": 1.0},
			{&"t": 0.52, &"v": 1.0},
		],
		&"pole": [
			{&"t": 0.0, &"v": Vector3(-1.0, -0.6, 0.2)},
			{&"t": 0.10, &"v": Vector3(-1.0, -1.2, 0.6), &"ease": &"out"},
			{&"t": 0.22, &"v": Vector3(-1.6, -1.0, 0.0), &"ease": &"in"},
			{&"t": 0.27, &"v": Vector3(-1.6, -1.0, 0.0)},
			{&"t": 0.52, &"v": Vector3(-1.0, -0.6, 0.2)},
		],
		&"lean": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": 0.2, &"ease": &"out"},
			{&"t": 0.15, &"v": 0.2}, {&"t": 0.17, &"v": 0.0573},
			{&"t": 0.22, &"v": 0.29, &"ease": &"in"},
			{&"t": 0.27, &"v": 0.29},
			{&"t": 0.52, &"v": 0.0},
		],
		&"wrist": [
			{&"t": 0.0, &"v": Vector2.ZERO}, {&"t": 0.10, &"v": Vector2(-60, 8), &"ease": &"out"},
			{&"t": 0.12, &"v": Vector2(-60, 8)},
			{&"t": 0.22, &"v": Vector2(10, 0), &"ease": &"snap", &"tau": 0.03, &"omega": 20.0},
			{&"t": 0.27, &"v": Vector2(10, 0)},
			{&"t": 0.30, &"v": Vector2.ZERO, &"ease": &"snap", &"tau": 0.05, &"omega": 30.0},
			{&"t": 0.52, &"v": Vector2.ZERO},
		],
		&"curl": [
			{&"t": 0.0, &"v": Vector3.ZERO}, {&"t": 0.10, &"v": Vector3(45, 45, 45), &"ease": &"out"},
			{&"t": 0.12, &"v": Vector3.ZERO, &"ease": &"out"},
			{&"t": 0.19, &"v": Vector3.ZERO},
			{&"t": 0.22, &"v": Vector3(-20, -20, -5), &"ease": &"in"},
			{&"t": 0.31, &"v": Vector3(-20, -20, -5)},
			{&"t": 0.52, &"v": Vector3.ZERO},
		],
		&"spread": [
			{&"t": 0.0, &"v": Vector2.ZERO}, {&"t": 0.10, &"v": Vector2.ZERO},
			{&"t": 0.12, &"v": Vector2(24, 12), &"ease": &"out"},
			{&"t": 0.22, &"v": Vector2(24, 12)}, {&"t": 0.25, &"v": Vector2(12, 6)},
			{&"t": 0.31, &"v": Vector2(12, 6)}, {&"t": 0.52, &"v": Vector2.ZERO},
		],
		&"frame": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": 0.0},
			{&"t": 0.22, &"v": 1.0, &"ease": &"in"},
			{&"t": 0.31, &"v": 1.0},
			{&"t": 0.52, &"v": 0.0},
		],
	},
	&"knock": {
		&"reach": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": -0.25, &"ease": &"out"},
			{&"t": 0.22, &"v": 1.0, &"ease": &"in"},
			{&"t": 0.27, &"v": 0.84, &"ease": &"snap", &"tau": 0.08, &"omega": 25.0},
			{&"t": 0.36, &"v": 1.0, &"ease": &"in"},
			{&"t": 0.41, &"v": 0.91, &"ease": &"snap", &"tau": 0.08, &"omega": 25.0},
			{&"t": 0.66, &"v": 1.0},
		],
		&"pole": [
			{&"t": 0.0, &"v": Vector3(-1.0, -0.6, 0.2)},
			{&"t": 0.10, &"v": Vector3(-1.0, -1.2, 0.6), &"ease": &"out"},
			{&"t": 0.22, &"v": Vector3(-1.6, -1.0, 0.0), &"ease": &"in"},
			{&"t": 0.41, &"v": Vector3(-1.6, -1.0, 0.0)},
			{&"t": 0.66, &"v": Vector3(-1.0, -0.6, 0.2)},
		],
		&"lean": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": 0.0},
			{&"t": 0.22, &"v": 0.29, &"ease": &"in"},
			{&"t": 0.27, &"v": 0.19, &"ease": &"snap", &"tau": 0.08, &"omega": 25.0},
			{&"t": 0.36, &"v": 0.29, &"ease": &"in"},
			{&"t": 0.41, &"v": 0.19, &"ease": &"snap", &"tau": 0.08, &"omega": 25.0},
			{&"t": 0.66, &"v": 0.0},
		],
		&"wrist": [
			{&"t": 0.0, &"v": Vector2.ZERO}, {&"t": 0.18, &"v": Vector2(26.3, -13.9), &"ease": &"out"},
			{&"t": 0.45, &"v": Vector2(26.3, -13.9)}, {&"t": 0.66, &"v": Vector2.ZERO},
		],
		&"curl": [
			{&"t": 0.0, &"v": Vector3.ZERO}, {&"t": 0.18, &"v": Vector3(135, 106, 35), &"ease": &"out"},
			{&"t": 0.45, &"v": Vector3(135, 106, 35)}, {&"t": 0.66, &"v": Vector3.ZERO},
		],
		&"frame": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": 0.0},
			{&"t": 0.22, &"v": 1.0, &"ease": &"in"},
			{&"t": 0.45, &"v": 1.0},
			{&"t": 0.66, &"v": 0.0},
		],
	},
	&"push": {
		&"reach": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": -0.25, &"ease": &"out"},
			{&"t": 0.22, &"v": 1.0, &"ease": &"in"},
			{&"t": 0.27, &"v": 0.84, &"ease": &"snap", &"tau": 0.08, &"omega": 25.0},
			{&"t": 0.30, &"v": 0.84},
			{&"t": 0.55, &"v": 1.0},
		],
		&"pole": [
			{&"t": 0.0, &"v": Vector3(-1.0, -0.6, 0.2)},
			{&"t": 0.10, &"v": Vector3(-1.0, -1.2, 0.6), &"ease": &"out"},
			{&"t": 0.22, &"v": Vector3(-1.6, -1.0, 0.0), &"ease": &"in"},
			{&"t": 0.30, &"v": Vector3(-1.6, -1.0, 0.0)},
			{&"t": 0.55, &"v": Vector3(-1.0, -0.6, 0.2)},
		],
		&"lean": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": 0.2, &"ease": &"out"},
			{&"t": 0.15, &"v": 0.2}, {&"t": 0.17, &"v": 0.0573},
			{&"t": 0.22, &"v": 0.29, &"ease": &"in"},
			{&"t": 0.27, &"v": 0.19, &"ease": &"snap", &"tau": 0.08, &"omega": 25.0},
			{&"t": 0.30, &"v": 0.19},
			{&"t": 0.55, &"v": 0.0},
		],
		&"wrist": [
			{&"t": 0.0, &"v": Vector2.ZERO}, {&"t": 0.10, &"v": Vector2(-60, 8), &"ease": &"out"},
			{&"t": 0.12, &"v": Vector2(-60, 8)},
			{&"t": 0.22, &"v": Vector2(10, 0), &"ease": &"snap", &"tau": 0.03, &"omega": 20.0},
			{&"t": 0.27, &"v": Vector2(10, 0)},
			{&"t": 0.30, &"v": Vector2.ZERO, &"ease": &"snap", &"tau": 0.05, &"omega": 30.0},
			{&"t": 0.55, &"v": Vector2.ZERO},
		],
		&"curl": [
			{&"t": 0.0, &"v": Vector3.ZERO}, {&"t": 0.10, &"v": Vector3(45, 45, 45), &"ease": &"out"},
			{&"t": 0.12, &"v": Vector3.ZERO, &"ease": &"out"},
			{&"t": 0.19, &"v": Vector3.ZERO},
			{&"t": 0.22, &"v": Vector3(-20, -20, -5), &"ease": &"in"},
			{&"t": 0.27, &"v": Vector3(-20, -20, -5)},
			{&"t": 0.34, &"v": Vector3(-20, -20, -5)},
			{&"t": 0.55, &"v": Vector3.ZERO},
		],
		&"spread": [
			{&"t": 0.0, &"v": Vector2.ZERO}, {&"t": 0.10, &"v": Vector2.ZERO},
			{&"t": 0.12, &"v": Vector2(24, 12), &"ease": &"out"},
			{&"t": 0.22, &"v": Vector2(24, 12)}, {&"t": 0.25, &"v": Vector2(12, 6)},
			{&"t": 0.34, &"v": Vector2(12, 6)}, {&"t": 0.55, &"v": Vector2.ZERO},
		],
		&"frame": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": 0.0},
			{&"t": 0.22, &"v": 1.0, &"ease": &"in"},
			{&"t": 0.27, &"v": 1.0},
			{&"t": 0.34, &"v": 1.0},
			{&"t": 0.55, &"v": 0.0},
		],
	},
	&"pull": {
		&"reach": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": -0.25, &"ease": &"out"},
			{&"t": 0.22, &"v": 1.0, &"ease": &"in"},
			{&"t": 0.26, &"v": 1.0},
			{&"t": 0.36, &"v": 0.65, &"ease": &"out"},
			{&"t": 0.40, &"v": 0.65},
			{&"t": 0.65, &"v": 1.0},
		],
		&"pole": [
			{&"t": 0.0, &"v": Vector3(-1.0, -0.6, 0.2)},
			{&"t": 0.10, &"v": Vector3(-1.0, -1.2, 0.6), &"ease": &"out"},
			{&"t": 0.22, &"v": Vector3(-1.6, -1.0, 0.0), &"ease": &"in"},
			{&"t": 0.40, &"v": Vector3(-1.6, -1.0, 0.0)},
			{&"t": 0.65, &"v": Vector3(-1.0, -0.6, 0.2)},
		],
		&"lean": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": 0.2, &"ease": &"out"},
			{&"t": 0.15, &"v": 0.2}, {&"t": 0.17, &"v": 0.0573},
			{&"t": 0.22, &"v": 0.29, &"ease": &"in"},
			{&"t": 0.26, &"v": 0.20},
			{&"t": 0.36, &"v": 0.05, &"ease": &"out"},
			{&"t": 0.40, &"v": 0.05},
			{&"t": 0.65, &"v": 0.0},
		],
		&"wrist": [
			{&"t": 0.0, &"v": Vector2.ZERO}, {&"t": 0.10, &"v": Vector2(-60, 8), &"ease": &"out"},
			{&"t": 0.12, &"v": Vector2(-60, 8)},
			{&"t": 0.22, &"v": Vector2(10, 0), &"ease": &"snap", &"tau": 0.03, &"omega": 20.0},
			{&"t": 0.27, &"v": Vector2(10, 0)},
			{&"t": 0.30, &"v": Vector2.ZERO, &"ease": &"snap", &"tau": 0.05, &"omega": 30.0},
			{&"t": 0.65, &"v": Vector2.ZERO},
		],
		&"curl": [
			{&"t": 0.0, &"v": Vector3.ZERO}, {&"t": 0.10, &"v": Vector3(45, 45, 45), &"ease": &"out"},
			{&"t": 0.12, &"v": Vector3(-20, -20, -15), &"ease": &"out"},
			{&"t": 0.19, &"v": Vector3(-20, -20, -15)},
			{&"t": 0.22, &"v": Vector3(65, 70, 40), &"ease": &"in"},
			{&"t": 0.44, &"v": Vector3(65, 70, 40)},
			{&"t": 0.65, &"v": Vector3.ZERO},
		],
		&"spread": [
			{&"t": 0.0, &"v": Vector2.ZERO}, {&"t": 0.10, &"v": Vector2.ZERO},
			{&"t": 0.12, &"v": Vector2(24, 12), &"ease": &"out"}, {&"t": 0.19, &"v": Vector2(24, 12)},
			{&"t": 0.22, &"v": Vector2.ZERO, &"ease": &"in"}, {&"t": 0.65, &"v": Vector2.ZERO},
		],
		&"frame": [
			{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": 0.0},
			{&"t": 0.22, &"v": 1.0, &"ease": &"in"},
			{&"t": 0.44, &"v": 1.0},
			{&"t": 0.65, &"v": 0.0},
		],
	},
	&"slide_open": SLIDE,
	&"slide_close": SLIDE,
}

## The snatch shared by both slides: pull's coil, strike, splay and clamp, then the hand yanks
## sideways (the slide channel, rig units; ArmGestureStrike.side gives the direction) instead of back.
const SLIDE := {
	&"reach": [
		{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": -0.25, &"ease": &"out"},
		{&"t": 0.22, &"v": 1.0, &"ease": &"in"},
		{&"t": 0.46, &"v": 1.0},
		{&"t": 0.71, &"v": 1.0},
	],
	&"slide": [
		{&"t": 0.0, &"v": 0.0}, {&"t": 0.26, &"v": 0.0},
		{&"t": 0.42, &"v": 0.55, &"ease": &"out"},
		{&"t": 0.46, &"v": 0.55},
		{&"t": 0.71, &"v": 0.0},
	],
	&"pole": [
		{&"t": 0.0, &"v": Vector3(-1.0, -0.6, 0.2)},
		{&"t": 0.10, &"v": Vector3(-1.0, -1.2, 0.6), &"ease": &"out"},
		{&"t": 0.22, &"v": Vector3(-1.6, -1.0, 0.0), &"ease": &"in"},
		{&"t": 0.46, &"v": Vector3(-1.6, -1.0, 0.0)},
		{&"t": 0.71, &"v": Vector3(-1.0, -0.6, 0.2)},
	],
	&"lean": [
		{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": 0.2, &"ease": &"out"},
		{&"t": 0.15, &"v": 0.2}, {&"t": 0.17, &"v": 0.0573},
		{&"t": 0.22, &"v": 0.29, &"ease": &"in"},
		{&"t": 0.26, &"v": 0.20},
		{&"t": 0.42, &"v": 0.10, &"ease": &"out"},
		{&"t": 0.46, &"v": 0.10},
		{&"t": 0.71, &"v": 0.0},
	],
	&"wrist": [
		{&"t": 0.0, &"v": Vector2.ZERO}, {&"t": 0.10, &"v": Vector2(-60, 8), &"ease": &"out"},
		{&"t": 0.12, &"v": Vector2(-60, 8)},
		{&"t": 0.22, &"v": Vector2(10, 0), &"ease": &"snap", &"tau": 0.03, &"omega": 20.0},
		{&"t": 0.27, &"v": Vector2(10, 0)},
		{&"t": 0.30, &"v": Vector2.ZERO, &"ease": &"snap", &"tau": 0.05, &"omega": 30.0},
		{&"t": 0.71, &"v": Vector2.ZERO},
	],
	&"curl": [
		{&"t": 0.0, &"v": Vector3.ZERO}, {&"t": 0.10, &"v": Vector3(45, 45, 45), &"ease": &"out"},
		{&"t": 0.12, &"v": Vector3(-20, -20, -15), &"ease": &"out"},
		{&"t": 0.19, &"v": Vector3(-20, -20, -15)},
		{&"t": 0.22, &"v": Vector3(60, 65, 35), &"ease": &"in"},
		{&"t": 0.46, &"v": Vector3(60, 65, 35)},
		{&"t": 0.50, &"v": Vector3(60, 65, 35)},
		{&"t": 0.71, &"v": Vector3.ZERO},
	],
	&"spread": [
		{&"t": 0.0, &"v": Vector2.ZERO}, {&"t": 0.10, &"v": Vector2.ZERO},
		{&"t": 0.12, &"v": Vector2(24, 12), &"ease": &"out"}, {&"t": 0.19, &"v": Vector2(24, 12)},
		{&"t": 0.22, &"v": Vector2.ZERO, &"ease": &"in"}, {&"t": 0.71, &"v": Vector2.ZERO},
	],
	&"frame": [
		{&"t": 0.0, &"v": 0.0}, {&"t": 0.10, &"v": 0.0},
		{&"t": 0.22, &"v": 1.0, &"ease": &"in"},
		{&"t": 0.50, &"v": 1.0},
		{&"t": 0.71, &"v": 0.0},
	],
}
