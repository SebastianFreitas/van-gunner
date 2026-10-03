extends RefCounted
## Creepy idle layer for a monster hand: irregular finger tics, slow finger-by-finger stretches and a non-periodic drift.
##
## Sources: Eiserloh GDC 2016 (squared energy: most tics small, a few big), myoclonic jerk
## 10-50 ms (medlink.com/articles/myoclonic-seizures), successive breaking
## (brianlemay.com/animation/successivebreaking.html), golden-ratio sines
## (piterpasma.nl/articles/wobbly).
## Everything is a pure function of `t`: the schedule is built once in `_init` and `sample`
## only reads it, so the debug `arms weave T` scrub is reproducible and nothing allocates.

const START := 7.0  ## seconds before anything moves, so the sandbox time and the gear-fit sweep keep today's pose
const LOOP := 240.0  ## schedule length; t wraps with fposmod, events stop early so the wrap is quiet
const SCAN := 10.0  ## seconds back from now that events can still be running (longest stretch)
const TIC_GAP := Vector2(2.0, 9.0)  ## seconds between tics
const TIC_IN := Vector2(0.04, 0.08)  ## the snap
const TIC_HOLD := Vector2(0.15, 0.6)
const TIC_OUT := Vector2(0.6, 1.5)  ## the slow release
const DOUBLE_TIC := 0.25  ## chance a tic is followed by a second one on another target
const DOUBLE_GAP := Vector2(0.10, 0.25)
const TIC_CURL := Vector2(14.0, 28.0)  ## degrees, curling tic
const TIC_STRAIGHTEN := Vector2(10.0, 20.0)  ## degrees, straightening tic
const TIC_WRIST := Vector2(5.0, 9.0)  ## degrees, wrist tic
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
const DRIFT_DEG := 5.0  ## per-finger non-periodic curl wander
const DRIFT_JOINT := Vector3(1.0, 0.7, 0.5)  ## drift share per joint
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
var _drift_ph := PackedFloat32Array()
# Tics, sorted by start: start, in, hold, out, target (0..4 finger, 5 wrist), signed degrees,
# whether joint .03 follows, wrist direction.
var _t_start := PackedFloat32Array()
var _t_in := PackedFloat32Array()
var _t_hold := PackedFloat32Array()
var _t_out := PackedFloat32Array()
var _t_target := PackedInt32Array()
var _t_amp := PackedFloat32Array()
var _t_j3 := PackedByteArray()
var _t_dir := PackedVector3Array()
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
	_drift_ph.resize(8 * 3)
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
	for i in _t_start.size():
		var du := u - _t_start[i]
		if du < 0.0:
			break
		if du > SCAN:
			continue
		var env := _tic_env(du, _t_in[i], _t_hold[i], _t_out[i])
		if env <= 0.0:
			continue
		var target := _t_target[i]
		if target == 5:
			wrist += _t_dir[i] * (_t_amp[i] * env)
		else:
			curl[target * 3] += _t_amp[i] * env
			curl[target * 3 + 1] += _t_amp[i] * env
			if _t_j3[i] != 0:
				curl[target * 3 + 2] += _t_amp[i] * env
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
	for f in 5:
		var d := DRIFT_DEG * _scale * _drift(u, f)
		for j in 3:
			curl[f * 3 + j] += d * DRIFT_JOINT[j]
	if not _fingers_only:
		wrist += Vector3(_drift(u, 5), _drift(u, 6), _drift(u, 7)) * (DRIFT_WRIST * _scale)
	var fade := smoothstep(START, START + FADE, u)
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
	_t_start.append(at)
	_t_in.append(_range(rng, TIC_IN))
	_t_hold.append(_range(rng, TIC_HOLD))
	_t_out.append(_range(rng, TIC_OUT))
	_t_target.append(target)
	var amp := 0.0
	var dir := Vector3.ZERO
	if target == 5:
		amp = _range(rng, TIC_WRIST) * k
		dir = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0)).normalized()
	elif rng.randf() < 0.65:
		amp = _range(rng, TIC_CURL) * k
	else:
		amp = -_range(rng, TIC_STRAIGHTEN) * k
	_t_amp.append(amp)
	_t_j3.append(1 if rng.randf() < 0.5 else 0)
	_t_dir.append(dir)


## Random value in a (min, max) range.
func _range(rng: RandomNumberGenerator, r: Vector2) -> float:
	return rng.randf_range(r.x, r.y)


## Tic envelope from the tic start: ease-out cubic up, hold, smoothstep down.
func _tic_env(u: float, t_in: float, hold: float, t_out: float) -> float:
	if u < t_in:
		return 1.0 - pow(1.0 - u / t_in, 3.0)
	if u < t_in + hold:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (u - t_in - hold) / t_out)


## Stretch envelope: smoothstep up, hold, smoothstep down; 0 outside.
func _soft_env(u: float, t_in: float, hold: float, t_out: float) -> float:
	if u < 0.0 or u > t_in + hold + t_out:
		return 0.0
	if u < t_in:
		return smoothstep(0.0, 1.0, u / t_in)
	if u < t_in + hold:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (u - t_in - hold) / t_out)


## Non-periodic wander of channel `ch` (5 fingers, then 3 wrist axes): three golden-ratio sines, about -1..1.
func _drift(t: float, ch: int) -> float:
	var sum := 0.0
	for k in 3:
		sum += sin(TAU * DRIFT_HZ * pow(PHI, k) * t + _drift_ph[ch * 3 + k]) / pow(2.0, k)
	return sum / 1.75
