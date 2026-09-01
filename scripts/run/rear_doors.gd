extends Node3D

## Truck-style rear double doors.
## Visual leaves swing on hinges (no physics). Fixed half-blockers on world
## layer 1 stop the player when a leaf is closed — they never rotate, so
## open/close never pushes anyone. Scripted Node3D mobs ignore physics, so
## callers should use is_passage_open() / get_outside_hold_position().

signal opened
signal closed
signal door_changed(side: StringName, is_open: bool)
signal glass_shattered(side: StringName)

const SIDE_LEFT := &"left"
const SIDE_RIGHT := &"right"

## Local Z just outside the closed door plane (rear is +Z).
const OUTSIDE_HOLD_LOCAL := Vector3(0.0, 1.62, 5.2)

@export var open_angle_deg := 110.0
@export var open_duration := 0.9

@onready var _left_hinge: Node3D = $LeftHinge
@onready var _right_hinge: Node3D = $RightHinge
@onready var _left_glass: Node = $LeftHinge/BreakableGlass
@onready var _right_glass: Node = $RightHinge/BreakableGlass

var _left_blocker_shapes: Array[CollisionShape3D] = []
var _right_blocker_shapes: Array[CollisionShape3D] = []
var _left_open := false
var _right_open := false
var _left_broken := false
var _right_broken := false
var _left_tween: Tween
var _right_tween: Tween


func _ready() -> void:
	_left_blocker_shapes = _collect_blocker_shapes("Left")
	_right_blocker_shapes = _collect_blocker_shapes("Right")
	if _left_glass and _left_glass.has_signal("shattered"):
		_left_glass.shattered.connect(func() -> void: glass_shattered.emit(SIDE_LEFT))
	if _right_glass and _right_glass.has_signal("shattered"):
		_right_glass.shattered.connect(func() -> void: glass_shattered.emit(SIDE_RIGHT))


func is_open() -> bool:
	return _left_open and _right_open


func is_glass_intact(side: StringName) -> bool:
	var glass := _left_glass if side == SIDE_LEFT else _right_glass
	if glass == null:
		return false
	if glass.has_method("is_intact"):
		return glass.is_intact()
	return false


## True only when both leaves are open — full rear passage into the van.
func is_passage_open() -> bool:
	return is_open()


func is_door_open(side: StringName) -> bool:
	return _left_open if side == SIDE_LEFT else _right_open


func is_door_broken(side: StringName) -> bool:
	return _left_broken if side == SIDE_LEFT else _right_broken


func mark_door_broken(side: StringName) -> void:
	if is_door_broken(side):
		return
	if side == SIDE_LEFT:
		_left_broken = true
	else:
		_right_broken = true
	if not is_door_open(side):
		open_door(side)
	else:
		_set_blocker_enabled(side, false)


## Standpoint outside closed doors for scripted mobs (world space).
func get_outside_hold_position() -> Vector3:
	return to_global(OUTSIDE_HOLD_LOCAL)


func get_door_prompt(side: StringName) -> String:
	if is_door_broken(side):
		return "BROKEN"
	if is_door_open(side):
		return "E  CLOSE DOOR"
	return "E  OPEN DOOR"


func toggle_door(side: StringName) -> void:
	if is_door_broken(side):
		return
	if is_door_open(side):
		close_door(side)
	else:
		open_door(side)


func open_door(side: StringName) -> void:
	if is_door_open(side):
		return
	_set_door_open(side, true)
	_set_blocker_enabled(side, false)
	_animate_door(side, true)
	door_changed.emit(side, true)
	if is_open():
		opened.emit()


func close_door(side: StringName) -> void:
	if is_door_broken(side) or not is_door_open(side):
		return
	_set_door_open(side, false)
	_animate_door(side, false)
	var tween := _left_tween if side == SIDE_LEFT else _right_tween
	await tween.finished
	if not is_door_open(side):
		_set_blocker_enabled(side, true)
		door_changed.emit(side, false)
		if not _left_open and not _right_open:
			closed.emit()


func open() -> void:
	open_door(SIDE_LEFT)
	open_door(SIDE_RIGHT)


func close() -> void:
	close_door(SIDE_LEFT)
	close_door(SIDE_RIGHT)


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func _set_door_open(side: StringName, value: bool) -> void:
	if side == SIDE_LEFT:
		_left_open = value
	else:
		_right_open = value


func _set_blocker_enabled(side: StringName, enabled: bool) -> void:
	var shapes := _left_blocker_shapes if side == SIDE_LEFT else _right_blocker_shapes
	for shape in shapes:
		shape.disabled = not enabled


func _collect_blocker_shapes(side_prefix: String) -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	var blocker := get_node_or_null("Blocker")
	if blocker == null:
		return shapes
	for child in blocker.get_children():
		if child is CollisionShape3D and String(child.name).begins_with(side_prefix):
			shapes.append(child)
	return shapes


func _animate_door(side: StringName, opening: bool) -> void:
	var hinge := _left_hinge if side == SIDE_LEFT else _right_hinge
	var angle := deg_to_rad(open_angle_deg)
	var target_y := 0.0
	if opening:
		target_y = -angle if side == SIDE_LEFT else angle
	var tween := _left_tween if side == SIDE_LEFT else _right_tween
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(hinge, "rotation:y", target_y, open_duration)
	if side == SIDE_LEFT:
		_left_tween = tween
	else:
		_right_tween = tween
