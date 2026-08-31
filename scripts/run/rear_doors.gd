extends Node3D

## Truck-style rear double doors. Visual hinges swing; collision stays on a fixed
## blocker so opening never pushes the player.

signal opened
signal closed

@export var open_angle_deg := 110.0
@export var open_duration := 0.9

@onready var _left_hinge: Node3D = $LeftHinge
@onready var _right_hinge: Node3D = $RightHinge
@onready var _blocker: CollisionShape3D = $Blocker/Collision

var _is_open := false
var _tween: Tween


func is_open() -> bool:
	return _is_open


func get_interaction_prompt() -> String:
	if _is_open:
		return "E  CLOSE REAR DOORS"
	return "E  OPEN REAR DOORS"


func interact(_actor: Node3D) -> void:
	toggle()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	# Drop the wall immediately so the swing never scrapes the player.
	_set_blocker_enabled(false)
	_animate_doors(true)
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_animate_doors(false)
	# Restore the wall only after panels are shut.
	await _tween.finished
	if not _is_open:
		_set_blocker_enabled(true)
		closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _set_blocker_enabled(enabled: bool) -> void:
	_blocker.disabled = not enabled


func _animate_doors(opening: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	var angle := deg_to_rad(open_angle_deg)
	var left_y := -angle if opening else 0.0
	var right_y := angle if opening else 0.0
	_tween.tween_property(_left_hinge, "rotation:y", left_y, open_duration)
	_tween.tween_property(_right_hinge, "rotation:y", right_y, open_duration)
