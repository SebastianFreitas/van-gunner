class_name GunViewmodel
extends Node3D

## Viewmodel motion: quarter-roll per shot, tip-up accelerating spin on reload
## with a coast / settle finish so the mag change doesn't hard-cut.

const SHOT_SPIN := TAU * 0.25
const SHOT_SPIN_DURATION := 0.32
const RELOAD_TIP_RAD := deg_to_rad(42.0)
const RELOAD_TIP_UP := 0.28
const RELOAD_TIP_DOWN := 0.42
const RELOAD_SPIN_START := 2.0
const RELOAD_SPIN_END := 18.0
## Tip-down split: coast spin + pitch drop, brief overshoot, spring settle.
const RELOAD_COAST_FRAC := 0.50
const RELOAD_LOCK_FRAC := 0.15
const RELOAD_SETTLE_FRAC := 0.35
const RELOAD_OVERSHOOT_RAD := deg_to_rad(-6.5)

@onready var _rig: Node3D = $Rig

var _rest_rotation := Vector3.ZERO
var _family: int = -1
var _muzzle_z := -0.38
var _pitch := 0.0
var _roll := 0.0
var _shot_tween: Tween
var _reload_tween: Tween
var _spinning := false
var _spin_speed := 0.0
var _spin_accel := 0.0
var _coasting := false
var _coast_target_roll := 0.0
var _coast_start_roll := 0.0
var _coast_start_speed := 0.0
var _coast_elapsed := 0.0
var _coast_duration := 0.0


func _ready() -> void:
	_rest_rotation = _rig.rotation
	if _family < 0:
		apply_family(WeaponDefinition.Family.BASIC)
	_apply()


func apply_family(family: WeaponDefinition.Family) -> float:
	if family == _family and _rig.get_child_count() > 0:
		return _muzzle_z
	_family = family
	_muzzle_z = ArmCannonMesh.build(_rig, family)
	return _muzzle_z


func _process(delta: float) -> void:
	if _coasting:
		_update_coast(delta)
		return
	if not _spinning:
		return
	_spin_speed += _spin_accel * delta
	_roll -= _spin_speed * delta
	_apply()


func play_shot() -> void:
	if _spinning or _coasting or (_reload_tween and _reload_tween.is_valid()):
		return
	if _shot_tween and _shot_tween.is_valid():
		_shot_tween.kill()
	var start := _roll
	var target := start - SHOT_SPIN
	_shot_tween = create_tween()
	_shot_tween.tween_method(_set_roll, start, target, SHOT_SPIN_DURATION).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)


func play_reload(duration: float) -> void:
	if duration <= 0.0:
		return
	_kill_shot()
	_stop_spin()
	_stop_coast()
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()

	var tip_up := minf(RELOAD_TIP_UP, duration * 0.22)
	var tip_down := minf(RELOAD_TIP_DOWN, duration * 0.38)
	var spin_time := maxf(duration - tip_up - tip_down, 0.05)
	var coast_time := tip_down * RELOAD_COAST_FRAC
	var lock_time := tip_down * RELOAD_LOCK_FRAC
	var settle_time := tip_down * RELOAD_SETTLE_FRAC

	_spin_speed = RELOAD_SPIN_START
	_spin_accel = (RELOAD_SPIN_END - RELOAD_SPIN_START) / spin_time

	_reload_tween = create_tween()
	## Tip muzzle up into the spin.
	_reload_tween.tween_method(_set_pitch, _pitch, RELOAD_TIP_RAD, tip_up).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_reload_tween.tween_callback(_start_spin)
	_reload_tween.tween_interval(spin_time)
	## Coast: decelerate spin into a quarter-turn while pitching most of the way down.
	_reload_tween.tween_callback(_begin_coast.bind(coast_time))
	_reload_tween.parallel().tween_method(
		_set_pitch, RELOAD_TIP_RAD, RELOAD_OVERSHOOT_RAD * 0.35, coast_time
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_reload_tween.tween_callback(_finish_coast)
	## Soft lock: overshoot past rest, then spring settle.
	if lock_time > 0.001:
		_reload_tween.tween_method(
			_set_pitch, RELOAD_OVERSHOOT_RAD * 0.35, RELOAD_OVERSHOOT_RAD, lock_time
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reload_tween.tween_method(_set_pitch, RELOAD_OVERSHOOT_RAD, 0.0, settle_time).set_trans(
		Tween.TRANS_ELASTIC
	).set_ease(Tween.EASE_OUT)
	_reload_tween.tween_callback(_finalize_reload)


func snap_rest() -> void:
	_kill_shot()
	_stop_spin()
	_stop_coast()
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()
	_pitch = 0.0
	_roll = _quantize_roll(_roll)
	_apply()


func _set_roll(value: float) -> void:
	_roll = value
	_apply()


func _set_pitch(value: float) -> void:
	_pitch = value
	_apply()


func _apply() -> void:
	_rig.rotation = _rest_rotation + Vector3(_pitch, 0.0, _roll)


func _start_spin() -> void:
	_spinning = true


func _stop_spin() -> void:
	_spinning = false
	_spin_speed = 0.0
	_spin_accel = 0.0


func _begin_coast(duration: float) -> void:
	## Capture peak speed before clearing the accel spin state.
	var peak_speed := maxf(_spin_speed, RELOAD_SPIN_END * 0.85)
	_stop_spin()
	_coasting = true
	_coast_elapsed = 0.0
	_coast_duration = maxf(duration, 0.05)
	_coast_start_roll = _roll
	_coast_start_speed = peak_speed
	## Aim for the next quarter-turn ahead (spin is negative roll).
	## Estimate how far we'd travel under ease-out so the target feels intentional.
	var expected_travel := _coast_start_speed * _coast_duration * 0.45
	var provisional := _roll - expected_travel
	_coast_target_roll = _quantize_roll_down(provisional)


func _update_coast(delta: float) -> void:
	_coast_elapsed += delta
	var t := clampf(_coast_elapsed / _coast_duration, 0.0, 1.0)
	## Smoothstep ease-out: fast residual spin that dies into the lock.
	var eased := 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
	_roll = lerpf(_coast_start_roll, _coast_target_roll, eased)
	## Keep a decaying visual spin speed for anything that reads it later.
	_spin_speed = _coast_start_speed * (1.0 - eased)
	_apply()
	if t >= 1.0:
		_finish_coast()


func _finish_coast() -> void:
	if not _coasting:
		return
	_coasting = false
	_roll = _coast_target_roll
	_spin_speed = 0.0
	_apply()


func _stop_coast() -> void:
	_coasting = false
	_coast_elapsed = 0.0
	_coast_duration = 0.0
	_coast_start_speed = 0.0


func _finalize_reload() -> void:
	_stop_spin()
	_stop_coast()
	_pitch = 0.0
	_roll = _quantize_roll(_roll)
	_apply()


func _quantize_roll(value: float) -> float:
	return roundf(value / SHOT_SPIN) * SHOT_SPIN


## Nearest quarter-turn at or below value (spin decreases roll).
func _quantize_roll_down(value: float) -> float:
	return floorf(value / SHOT_SPIN) * SHOT_SPIN


func _kill_shot() -> void:
	if _shot_tween and _shot_tween.is_valid():
		_shot_tween.kill()
