extends RefCounted
## Per-joint held finger poses for the free hand: one joint bends at a time into odd shapes, then holds.
##
## The whole schedule is built once in `_init` from a private RNG; `add_to` only reads it, so it
## is a pure function of the looped time and allocation-free.

## Offsets in degrees for joints .01/.02/.03.
const POSES: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),  ## NEUTRAL
	Vector3(55.0, -10.0, -5.0),  ## KNUCKLE: base bent, finger straight
	Vector3(0.0, 60.0, 10.0),  ## MID_CLAW
	Vector3(-5.0, -5.0, 55.0),  ## TIP_HOOK
	Vector3(10.0, -35.0, 50.0),  ## SWAN: swan neck
	Vector3(-10.0, 60.0, -30.0),  ## BUTTONHOLE
	Vector3(45.0, 55.0, 45.0),  ## FIST
	Vector3(-25.0, -30.0, -20.0),  ## RIGID: hyperextended
]
const POSE_WEIGHT: Array[float] = [3.0, 2.0, 2.0, 2.0, 1.5, 1.5, 1.0, 1.0]
const POSE_HOLD := Vector2(0.8, 3.5)  ## seconds holding a finished pose
const JOINT_MOVE := Vector2(0.25, 0.9)  ## seconds one joint takes to move
const JOINT_GAP := Vector2(0.05, 0.7)  ## seconds between one joint ending and the next starting
const POSE_JITTER := 6.0  ## degrees per joint
const POSE_SCALE := Vector2(0.7, 1.0)
const THUMB_K := 0.6  ## thumb poses are scaled down
const EASE_WEIGHT: Array[float] = [0.55, 0.25, 0.2]  ## kinds 1 (smooth), 2 (slow-then-snap), 3 (ratchet)
const MIN_DELTA := 4.0  ## a joint closer than this to its target does not move
const TAIL := 15.0  ## last pose starts this long before the loop end, so the return fits

# Per channel (finger * 3 + joint): key times, values, and the ease kind of the segment that
# starts at the key (0 hold, 1 smoothstep, 2 u^3, 3 ratchet).
var _kt: Array[PackedFloat32Array] = []
var _kv: Array[PackedFloat32Array] = []
var _ke: Array[PackedFloat32Array] = []
var _rng := RandomNumberGenerator.new()
var _cur := Vector3.ZERO  ## value each joint of the finger being built holds right now


func _init(rng: RandomNumberGenerator, start: float, loop: float) -> void:
	_rng.seed = rng.randi()
	for c in 15:
		_kt.append(PackedFloat32Array())
		_kv.append(PackedFloat32Array())
		_ke.append(PackedFloat32Array())
	for f in 5:
		_build_finger(f, start, loop)


## Adds the pose offsets at looped time `u`, times `gain`, onto `curl`.
func add_to(curl: PackedFloat32Array, u: float, gain: float) -> void:
	for c in 15:
		var kt := _kt[c]
		var n := kt.size()
		var i := clampi(kt.bsearch(u, false) - 1, 0, n - 2)
		var kv := _kv[c]
		var t0 := kt[i]
		var t1 := kt[i + 1]
		var v0 := kv[i]
		var v1 := kv[i + 1]
		var value := v0
		if u >= t1:
			value = v1
		elif u > t0:
			var x := (u - t0) / (t1 - t0)
			match int(_ke[c][i]):
				1:
					value = lerpf(v0, v1, smoothstep(0.0, 1.0, x))
				2:
					value = lerpf(v0, v1, x * x * x)
				3:
					var s := x * 3.0
					var step := minf(floorf(s), 2.0)
					var q := smoothstep(0.0, 1.0, minf((s - step) / 0.6, 1.0))
					value = lerpf(v0, v1, (step + q) / 3.0)
		curl[c] += value * gain


## Builds the keys of finger `f`: out-of-phase poses until the tail, then back to zero.
func _build_finger(f: int, start: float, loop: float) -> void:
	_cur = Vector3.ZERO
	for j in 3:
		_key(f * 3 + j, start, 0.0, 0.0)
	var t := start + f * _rng.randf_range(0.3, 1.2)
	var last := -1
	while t < loop - TAIL:
		last = _pick_pose(last)
		var target := POSES[last] * _rng.randf_range(POSE_SCALE.x, POSE_SCALE.y)
		target += Vector3(_rng.randf_range(-POSE_JITTER, POSE_JITTER),
				_rng.randf_range(-POSE_JITTER, POSE_JITTER), _rng.randf_range(-POSE_JITTER, POSE_JITTER))
		if f == 4:
			target *= THUMB_K
		t = _move_joints(f, t, target, MIN_DELTA) + _rng.randf_range(POSE_HOLD.x, POSE_HOLD.y)
	_move_joints(f, t, Vector3.ZERO, 0.001)
	for j in 3:
		_key(f * 3 + j, loop, 0.0, 0.0)


## Moves the joints of finger `f` to `target` one at a time from `t`; returns the time after the last.
func _move_joints(f: int, t: float, target: Vector3, min_delta: float) -> float:
	var order: Array[int] = [2, 1, 0]
	var r := _rng.randf()
	if r < 0.4:
		order = [2, 1, 0]
	elif r < 0.8:
		order = [0, 1, 2]
	else:
		for a in [2, 1]:
			var b := _rng.randi_range(0, a)
			var tmp := order[a]
			order[a] = order[b]
			order[b] = tmp
	for j in order:
		if absf(target[j] - _cur[j]) < min_delta:
			continue
		var dur := _rng.randf_range(JOINT_MOVE.x, JOINT_MOVE.y)
		_key(f * 3 + j, t, _cur[j], _pick_ease())
		_key(f * 3 + j, t + dur, target[j], 0.0)
		_cur[j] = target[j]
		t += dur + _rng.randf_range(JOINT_GAP.x, JOINT_GAP.y)
	return t


## Appends one key to channel `c`. Reassigns the arrays so it never depends on aliasing.
func _key(c: int, t: float, v: float, e: float) -> void:
	var kt := _kt[c]
	var kv := _kv[c]
	var ke := _ke[c]
	kt.append(t)
	kv.append(v)
	ke.append(e)
	_kt[c] = kt
	_kv[c] = kv
	_ke[c] = ke


## Weighted pose index, never `last` twice in a row.
func _pick_pose(last: int) -> int:
	var total := 0.0
	for w in POSE_WEIGHT:
		total += w
	var p := last
	while p == last:
		var r := _rng.randf() * total
		p = POSES.size() - 1
		for i in POSE_WEIGHT.size():
			r -= POSE_WEIGHT[i]
			if r < 0.0:
				p = i
				break
	return p


## Ease kind 1..3 by EASE_WEIGHT.
func _pick_ease() -> float:
	var r := _rng.randf()
	if r < EASE_WEIGHT[0]:
		return 1.0
	if r < EASE_WEIGHT[0] + EASE_WEIGHT[1]:
		return 2.0
	return 3.0
