extends RefCounted
## Gates the idle hand layers: a seeded active/rest cycle while standing, half strength while walking, muted while shooting or busy.

## Live idle clock speed (the weave slows to this share of real time).
const TEMPO := 0.6
## Still seconds before idle starts.
const SETTLE := 1.6
## Seconds after a shot that count as shooting.
const SHOT_HOLD := 2.0
## Walk amount above which the player counts as moving.
const WALK_GATE := 0.05
## Seeded range of seconds the idle stays active.
const ACTIVE := Vector2(7.0, 12.0)
## Seeded range of seconds the hands rest between active spans.
const REST := Vector2(4.0, 8.0)
## Seconds for a full 0 -> 1 move when idle starts.
const FADE_IN := 1.8
## Seconds for a full 1 -> 0 move when the hands settle to rest.
const FADE_REST := 1.2
## Seconds for a full 1 -> 0 move when interrupted.
const FADE_CUT := 0.2
## Raw weight held while walking, so the hands keep curling and a stop never starts from nothing.
const WALK_FLOOR := 0.5
## Seconds for a full 1 -> 0 move while walking pulls the weight down to WALK_FLOOR.
const FADE_WALK := 0.6
## Still seconds before idle resumes after a walk; short so the hands come back fast on a stop.
const SETTLE_WALK := 0.25
## Seconds for a full 0 -> 1 move when idle resumes after a walk (quicker than FADE_IN).
const FADE_STOP := 0.9

var _rng: RandomNumberGenerator
var _still := 0.0
var _since_shot := 999.0
var _phase_left := 0.0
var _active := false
var _raw := 0.0
## True once the player has stood still for SETTLE seconds.
var _settled := false
## True when the last interruption was a walk: settle with SETTLE_WALK and rise with FADE_STOP.
var _from_walk := false


func _init(seed_value: int) -> void:
	_rng = ArmsBuilder.rng_for(seed_value, &"arm_idle_gate")
	_active = true
	_phase_left = _rng.randf_range(ACTIVE.x, ACTIVE.y)


## Marks a shot: the idle layers mute for SHOT_HOLD seconds.
func note_shot() -> void:
	_since_shot = 0.0


## Advances the gate and returns the eased idle weight (0 rest .. 1 full idle).
func step(delta: float, walk: float, busy: bool, snap: bool) -> float:
	if snap:
		_raw = 1.0
		return weight()
	_since_shot = minf(_since_shot + delta, 999.0)
	var interrupted := busy or _since_shot < SHOT_HOLD
	if interrupted:
		_still = 0.0
		_settled = false
		_from_walk = false
		_raw = move_toward(_raw, 0.0, delta / FADE_CUT)
		return weight()
	if walk > WALK_GATE:
		_still = 0.0
		_settled = false
		_from_walk = true
		var fade := FADE_WALK if _raw > WALK_FLOOR else FADE_IN
		_raw = move_toward(_raw, WALK_FLOOR, delta / fade)
		return weight()
	_still += delta
	if _still < (SETTLE_WALK if _from_walk else SETTLE):
		# After a walk the weight holds at its floor instead of sinking toward 0.
		if not _from_walk:
			_raw = move_toward(_raw, 0.0, delta / FADE_REST)
		return weight()
	if not _settled:
		_settled = true
		_active = true
		_phase_left = _rng.randf_range(ACTIVE.x, ACTIVE.y)
	_phase_left -= delta
	if _phase_left <= 0.0:
		_active = not _active
		_from_walk = false
		var span := ACTIVE if _active else REST
		_phase_left = _rng.randf_range(span.x, span.y)
	if _active:
		_raw = move_toward(_raw, 1.0, delta / (FADE_STOP if _from_walk else FADE_IN))
	else:
		_raw = move_toward(_raw, 0.0, delta / FADE_REST)
	return weight()


## The eased weight of the last step.
func weight() -> float:
	return smoothstep(0.0, 1.0, _raw)
