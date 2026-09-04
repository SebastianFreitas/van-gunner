class_name GunViewmodel
extends Node3D

## Simple viewmodel motion: quarter-roll per shot, tip-up accelerating spin on reload.

const SHOT_SPIN := TAU * 0.25
const SHOT_SPIN_DURATION := 0.1
const RELOAD_TIP_RAD := deg_to_rad(42.0)
const RELOAD_TIP_UP := 0.16
const RELOAD_TIP_DOWN := 0.2
const RELOAD_SPIN_START := 4.0
const RELOAD_SPIN_END := 38.0

@onready var _rig: Node3D = $Rig

var _rest_rotation := Vector3.ZERO
var _pitch := 0.0
var _roll := 0.0
var _shot_tween: Tween
var _reload_tween: Tween
var _spinning := false
var _spin_speed := 0.0
var _spin_accel := 0.0


func _ready() -> void:
	_rest_rotation = _rig.rotation
	_apply()


func _process(delta: float) -> void:
	if not _spinning:
		return
	_spin_speed += _spin_accel * delta
	_roll -= _spin_speed * delta
	_apply()


func play_shot() -> void:
	if _spinning or (_reload_tween and _reload_tween.is_valid()):
		return
	if _shot_tween and _shot_tween.is_valid():
		_shot_tween.kill()
	var start := _roll
	var target := start - SHOT_SPIN
	_shot_tween = create_tween()
	_shot_tween.tween_method(_set_roll, start, target, SHOT_SPIN_DURATION).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)


func play_reload(duration: float) -> void:
	if duration <= 0.0:
		return
	_kill_shot()
	_stop_spin()
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()

	var tip_up := minf(RELOAD_TIP_UP, duration * 0.25)
	var tip_down := minf(RELOAD_TIP_DOWN, duration * 0.3)
	var spin_time := maxf(duration - tip_up - tip_down, 0.05)
	_spin_speed = RELOAD_SPIN_START
	_spin_accel = (RELOAD_SPIN_END - RELOAD_SPIN_START) / spin_time

	_reload_tween = create_tween()
	_reload_tween.tween_method(_set_pitch, _pitch, RELOAD_TIP_RAD, tip_up).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_reload_tween.tween_callback(_start_spin)
	_reload_tween.tween_interval(spin_time)
	_reload_tween.tween_callback(_stop_spin)
	_reload_tween.tween_method(_set_pitch, RELOAD_TIP_RAD, 0.0, tip_down).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN_OUT)
	_reload_tween.tween_callback(snap_rest)


func snap_rest() -> void:
	_kill_shot()
	_stop_spin()
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()
	_pitch = 0.0
	_roll = roundf(_roll / SHOT_SPIN) * SHOT_SPIN
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


func _kill_shot() -> void:
	if _shot_tween and _shot_tween.is_valid():
		_shot_tween.kill()
