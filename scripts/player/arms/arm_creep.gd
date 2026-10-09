extends RefCounted
## Creepy idle layer for a monster hand: held per-joint finger poses, multi-joint spasm tics, slow stretches and a per-joint drift.
##
## Sources: Eiserloh GDC 2016 (squared energy: most tics small, a few big), myoclonic jerk
## 10-50 ms (medlink.com/articles/myoclonic-seizures), successive breaking
## (brianlemay.com/animation/successivebreaking.html), golden-ratio sines
## (piterpasma.nl/articles/wobbly).
## Layers: ArmCreepPoses (free hand only: one joint at a time into odd held shapes), tics (a
## staggered snap with overshoot, a decaying tremor, a hold, then a joint-by-joint release),
## stretches and a small per-joint drift.
## Everything is a pure function of `t`: the schedule is built once in `_init` and `sample`
## only reads it, so the debug `arms weave T` scrub is reproducible and nothing allocates.

const ArmCreepPoses := preload("res://scripts/player/arms/arm_creep_poses.gd")

const START := 7.0  ## seconds before anything moves, so the sandbox time keep today's pose
const LOOP := 240.0  ## schedule length; t wraps with fposmod, events stop early so the wrap is quiet
const SCAN := 10.0  ## seconds back from now that stretches can still be running (longest stretch)
const TIC_GAP := Vector2(3.0, 8.0)  ## seconds between tics
const TIC_AMP := Vector2(35.0, 70.0)  ## degrees on the lead joint of a finger tic
const TIC_IN := Vector2(0.07, 0.12)  ## the snap, per joint
const TIC_STAGGER := Vector2(0.03, 0.08)  ## between one joint's snap start and the next
const TIC_OVERSHOOT := 0.25
const TIC_HOLD := Vector2(0.4, 1.2)
const TIC_OUT := Vector2(0.3, 0.7)  ## the release, per joint
const TIC_OUT_GAP := Vector2(0.1, 0.3)
const TREMOR_HZ := 7.0  ## in t units, about 12 Hz real
const TREMOR_K := 0.12
const TREMOR_DECAY := 5.0
const ECHO := 0.35  ## chance a finger tic also twitches a neighbour
const ECHO_K := 0.35
const ECHO_DELAY := Vector2(0.06, 0.12)
const DOUBLE_TIC := 0.25  ## chance a tic is followed by a second one on another target
const DOUBLE_GAP := Vector2(0.10, 0.25)
const TIC_WRIST := Vector2(8.0, 14.0)  ## degrees, wrist tic
## Snap order by lead joint: the lead first, then outward.
const SNAP_ORDER: Array = [[0, 1, 2], [1, 2, 0], [2, 1, 0]]
const STRETCH_GAP := Vector2(9.0, 16.0)
const STRETCH_IN := Vector2(1.5, 3.0)
const STRETCH_HOLD := Vector2(0.6, 1.2)
const STRETCH_OUT := Vector2(2.5, 4.0)
const STRETCH_LAG := Vector2(0.12, 0.2)  ## seconds per finger, index to pinky
## Degrees added per joint .01/.02/.03: .01 goes about 15 degrees past straight from BASE.
const STRETCH_OPEN := Vector3(-34.0, -28.0, -18.0)
const STRETCH_SPLAY := 9.0  ## degrees of extra fan on .01, alternating sign
const STRETCH_WRIST := Vector3(-10.0, 0.0, 4.0)  ## degrees euler at full stretch
const STRETCH_THUMB := Vector3(-8.0, -10.0, -12.0)
const DRIFT_HZ := 0.23
const DRIFT_DEG := 2.0  ## per-joint non-periodic curl wander
const DRIFT_WRIST := 3.0
const PHI := 1.618034  ## golden ratio: drift octaves never line up
const FADE := 1.0  ## seconds fading in after START

## Degrees to ADD to the curl, index finger * 3 + joint.
var curl := PackedFloat32Array()
## Degrees to ADD to the .01 fan, per finger (4 = thumb).
var splay := PackedFloat32Array()
## Degrees euler to ADD to the wrist.
var wrist := Vector3.ZERO

var _scale := 1.0
var _fingers_only := false
var _poses: ArmCreepPoses = null
var _drift_ph := PackedFloat32Array()
# Tics, in creation order: start, end of the whole spasm, target (0..4 finger, 5 wrist), wrist
# direction. Per-joint data is flat, tic * 3 + joint: amplitude (signed degrees), snap start,
# snap length, release start, release length, tremor phase. A wrist tic only uses joint 0.
var _t_start := PackedFloat32Array()
var _t_end := PackedFloat32Array()
var _t_target := PackedInt32Array()
var _t_dir := PackedVector3Array()
var _t_amp := PackedFloat32Array()
var _t_snap := PackedFloat32Array()
var _t_dur := PackedFloat32Array()
var _t_rel := PackedFloat32Array()
var _t_rdur := PackedFloat32Array()
var _t_ph := PackedFloat32Array()
# Stretches, sorted by start.
var _s_start := PackedFloat32Array()
var _s_in := PackedFloat32Array()
var _s_hold := PackedFloat32Array()
var _s_out := PackedFloat32Array()
var _s_lag := PackedFloat32Array()


func _init(rng: RandomNumberGenerator, scale: float, fingers_only: bool) -> void:
	_scale = scale
	_fingers_only = fingers_only
	curl.resize(15)
	splay.resize(5)
	_drift_ph.resize(18 * 3)
	for i in _drift_ph.size():
		_drift_ph[i] = rng.randf() * TAU
	var t := START + _range(rng, TIC_GAP)
	while t < LOOP - 6.0:
		_add_tic(rng, t, -1)
		var first_target := _t_target[_t_target.size() - 1]
		if rng.randf() < DOUBLE_TIC:
			_add_tic(rng, t + _range(rng, DOUBLE_GAP), first_target)
		t += _range(rng, TIC_GAP)
	if not fingers_only:
		_poses = ArmCreepPoses.new(rng, START, LOOP)
		t = START + 4.0
		while t < LOOP - 10.0:
			_s_start.append(t)
			_s_in.append(_range(rng, STRETCH_IN))
			_s_hold.append(_range(rng, STRETCH_HOLD))
			_s_out.append(_range(rng, STRETCH_OUT))
			_s_lag.append(_range(rng, STRETCH_LAG))
			t += _range(rng, STRETCH_GAP)


## Fills `curl`, `splay` and `wrist` for time `t`. Allocation-free.
func sample(t: float) -> void:
	curl.fill(0.0)
	splay.fill(0.0)
	wrist = Vector3.ZERO
	var u := fposmod(t, LOOP)
	if u < START:
		return
	if _poses != null:
		_poses.add_to(curl, u, _scale)
	for i in _t_start.size():
		if u < _t_start[i] or u > _t_end[i]:
			continue
		var target := _t_target[i]
		if target == 5:
			wrist += _t_dir[i] * (_t_amp[i * 3] * _tic_env(u, i * 3, 0.0, 0.0))
		else:
			for j in 3:
				curl[target * 3 + j] += _t_amp[i * 3 + j] * _tic_env(u, i * 3 + j, TIC_OVERSHOOT, 1.0)
	for i in _s_start.size():
		var du := u - _s_start[i]
		if du < 0.0:
			break
		if du > SCAN:
			continue
		for k in 5:
			var env := _soft_env(du - k * _s_lag[i], _s_in[i], _s_hold[i], _s_out[i])
			if env <= 0.0:
				continue
			var open := STRETCH_THUMB if k == 4 else STRETCH_OPEN
			for j in 3:
				curl[k * 3 + j] += open[j] * _scale * env
			if k < 4:
				splay[k] += STRETCH_SPLAY * _scale * env * (1.0 if k % 2 == 0 else -1.0)
		wrist += STRETCH_WRIST * (_scale * _soft_env(du, _s_in[i], _s_hold[i], _s_out[i]))
	for c in 15:
		curl[c] += DRIFT_DEG * _scale * _drift(u, c)
	if not _fingers_only:
		wrist += Vector3(_drift(u, 15), _drift(u, 16), _drift(u, 17)) * (DRIFT_WRIST * _scale)
	var fade := smoothstep(START, START + FADE, u) * (1.0 - smoothstep(LOOP - FADE, LOOP, u))
	for i in 15:
		curl[i] *= fade
	for i in 5:
		splay[i] *= fade
	wrist *= fade


## Appends one tic at `at` on a random target other than `avoid` (-1: any).
func _add_tic(rng: RandomNumberGenerator, at: float, avoid: int) -> void:
	var r := rng.randf()
	var target := 5
	if r < 0.6:
		target = rng.randi_range(0, 3)
	elif r < 0.8 or _fingers_only:
		target = 4
	if target == avoid:
		target = (target + 1) % 5 if avoid < 4 else 0
	# Squared so most tics are small and a few are big (Eiserloh).
	var k := 0.6 + 0.4 * rng.randf()
	k = k * k * _scale
	if target == 5:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0)).normalized()
		_push_tic(rng, at, 5, 0, Vector3(_range(rng, TIC_WRIST) * k, 0.0, 0.0), dir)
		return
	var amp := _range(rng, TIC_AMP) * k * (1.0 if rng.randf() < 0.65 else -1.0)
	var lead := rng.randi_range(0, 2)
	# The other joints go partly the other way, so the finger kinks instead of dragging.
	var amps := Vector3.ZERO
	for j in 3:
		amps[j] = amp if j == lead else amp * rng.randf_range(-0.6, 1.0)
	_push_tic(rng, at, target, lead, amps, Vector3.ZERO)
	if target < 4 and rng.randf() < ECHO:
		var near := target + (1 if rng.randf() < 0.5 else -1)
		near = 1 if near < 0 else (2 if near > 3 else near)
		_push_tic(rng, at + _range(rng, ECHO_DELAY), near, lead, amps * ECHO_K, Vector3.ZERO)


## Schedules one spasm: joints snap in order from `lead` (staggered), hold, then release in reverse.
func _push_tic(rng: RandomNumberGenerator, at: float, target: int, lead: int, amps: Vector3,
		dir: Vector3) -> void:
	var base := _t_amp.size()
	for arr in [_t_amp, _t_snap, _t_dur, _t_rel, _t_rdur, _t_ph]:
		arr.resize(base + 3)
	var order: Array = SNAP_ORDER[lead]
	var count := 1 if target == 5 else 3
	var s := at
	for n in count:
		var j: int = order[n]
		_t_amp[base + j] = amps[j]
		_t_snap[base + j] = s
		_t_dur[base + j] = _range(rng, TIC_IN)
		_t_ph[base + j] = rng.randf() * TAU
		if n < count - 1:
			s += _range(rng, TIC_STAGGER)
	var r: float = s + _t_dur[base + order[count - 1] as int] + _range(rng, TIC_HOLD)
	var end := r
	for n in range(count - 1, -1, -1):
		var j: int = order[n]
		_t_rel[base + j] = r
		_t_rdur[base + j] = _range(rng, TIC_OUT)
		end = r + _t_rdur[base + j]
		r = end + _range(rng, TIC_OUT_GAP)
	_t_start.append(at)
	_t_end.append(end)
	_t_target.append(target)
	_t_dir.append(dir)


## Random value in a (min, max) range.
func _range(rng: RandomNumberGenerator, r: Vector2) -> float:
	return rng.randf_range(r.x, r.y)


## Envelope of the tic joint at flat index `k`: ease-out cubic up to 1 + `over` over the first
## 70% of the snap, back to 1; a decaying tremor (x `trem`) while held; smoothstep down; 0 before.
func _tic_env(u: float, k: int, over: float, trem: float) -> float:
	var x := u - _t_snap[k]
	if x < 0.0:
		return 0.0
	var d := _t_dur[k]
	if x < d:
		var q := x / d
		if q < 0.7:
			return (1.0 + over) * (1.0 - pow(1.0 - q / 0.7, 3.0))
		return lerpf(1.0 + over, 1.0, (q - 0.7) / 0.3)
	if u < _t_rel[k]:
		var dt := x - d
		return 1.0 + trem * TREMOR_K * sin(TAU * TREMOR_HZ * dt + _t_ph[k]) * exp(-TREMOR_DECAY * dt) * minf(dt / 0.04, 1.0) * minf((_t_rel[k] - u) / 0.08, 1.0)
	return 1.0 - smoothstep(0.0, 1.0, (u - _t_rel[k]) / _t_rdur[k])


## Stretch envelope: smoothstep up, hold, smoothstep down; 0 outside.
func _soft_env(u: float, t_in: float, hold: float, t_out: float) -> float:
	if u < 0.0 or u > t_in + hold + t_out:
		return 0.0
	if u < t_in:
		return smoothstep(0.0, 1.0, u / t_in)
	if u < t_in + hold:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (u - t_in - hold) / t_out)


## Non-periodic wander of channel `ch` (15 finger joints, then 3 wrist axes): three golden-ratio sines, about -1..1.
func _drift(t: float, ch: int) -> float:
	var sum := 0.0
	for k in 3:
		sum += sin(TAU * DRIFT_HZ * pow(PHI, k) * t + _drift_ph[ch * 3 + k]) / pow(2.0, k)
	return sum / 1.75
