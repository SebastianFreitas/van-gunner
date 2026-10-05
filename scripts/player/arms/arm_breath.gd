class_name ArmBreath
extends RefCounted
## Breathing for the first-person rig: a slow rise and fall that gets deeper and faster with exertion.

const RATE_CALM := 0.22  ## breaths per second at rest
const RATE_HARD := 0.55  ## breaths per second fully winded
const EXERT_RISE := 3.0  ## seconds (time constant) of moving to get winded
const EXERT_FALL := 5.0  ## seconds (time constant) to calm down after a stop
const HARD_GAIN := 2.6  ## amplitude multiplier when fully winded
const WALK_KEEP := 0.4  ## share of the breath that shows under the full run bob
const RISE := 0.008  ## rig units up on the inhale, calm
const PULL := 0.004  ## rig units toward the body (+z) on the inhale, calm
const PITCH := 0.5  ## degrees the muzzle lifts on the inhale, calm
const ROLL := 0.25  ## degrees of roll, trailing the lift
const SKEW := 0.35  ## inhale quicker than exhale

var _phase := 0.0
var _exert := 0.0
var _gain := 0.0


func reset() -> void:
	_phase = 0.0
	_exert = 0.0
	_gain = 0.0


func seed_exert(value: float) -> void:
	_exert = clampf(value, 0.0, 1.0)
	_phase = 0.0


func step(delta: float, walk_amount: float) -> void:
	if delta <= 0.0:
		return
	var target := clampf(walk_amount, 0.0, 1.0)
	var tau := EXERT_RISE if target > _exert else EXERT_FALL
	_exert = lerpf(_exert, target, 1.0 - exp(-delta / tau))
	_phase = fmod(_phase + TAU * lerpf(RATE_CALM, RATE_HARD, _exert) * delta, TAU)
	_gain = lerpf(1.0, HARD_GAIN, _exert) * lerpf(1.0, WALK_KEEP, target)


func pos() -> Vector3:
	var s := _wave(0.0)
	return Vector3(0.0, RISE * s, PULL * s) * _gain


## x = pitch up, y = yaw, z = roll, in degrees; the caller converts and applies the signs.
func rot_deg() -> Vector3:
	return Vector3(PITCH * _wave(0.0), 0.0, ROLL * _wave(0.9)) * _gain


func _wave(lead: float) -> float:
	return sin(_phase - lead + SKEW * sin(_phase - lead))
