extends Node3D

## Sliding cargo-style side doors.
## Grip (button) retracts first, then Mount (black latch) pulls into the door
## while keeping its head visible. Door recesses inward, then slides rearward.
## Passage for player/enemies unlocks later in the slide than rear hinge doors.

signal opened
signal closed
signal door_changed(side: StringName, is_open: bool)
signal passage_changed(side: StringName, is_passable: bool)
signal glass_shattered(side: StringName)

const SIDE_LEFT := &"left"
const SIDE_RIGHT := &"right"

@export var grip_retract_duration := 0.1
@export var mount_retract_duration := 0.14
@export var recess_duration := 0.22
@export var slide_duration := 1.15
## Fraction of the slide before the opening counts as passable.
@export_range(0.05, 1.0) var passage_slide_ratio := 0.72
@export var recess_distance := -0.17
@export var slide_distance := 2.45
## Mount pull into the door — leave a visible head proud of the panel.
@export var mount_retract_distance := 0.028
## Grip pull into the door (flush / pocketed).
@export var grip_retract_distance := 0.06

@onready var _left: Node3D = $Left
@onready var _right: Node3D = $Right
@onready var _left_glass: Node = $Left/BreakableGlass
@onready var _right_glass: Node = $Right/BreakableGlass
@onready var _left_grip: Node3D = $Left/Handle/Grip
@onready var _left_mount: Node3D = $Left/Handle/Mount
@onready var _right_grip: Node3D = $Right/Handle/Grip
@onready var _right_mount: Node3D = $Right/Handle/Mount

var _left_closed_pos: Vector3
var _right_closed_pos: Vector3
var _left_grip_closed: Vector3
var _left_mount_closed: Vector3
var _right_grip_closed: Vector3
var _right_mount_closed: Vector3

var _left_open := false
var _right_open := false
var _left_passable := false
var _right_passable := false
var _left_tween: Tween
var _right_tween: Tween


func _ready() -> void:
	_left_closed_pos = _left.position
	_right_closed_pos = _right.position
	_left_grip_closed = _left_grip.position
	_left_mount_closed = _left_mount.position
	_right_grip_closed = _right_grip.position
	_right_mount_closed = _right_mount.position
	if _left_glass and _left_glass.has_signal("shattered"):
		_left_glass.shattered.connect(func() -> void: glass_shattered.emit(SIDE_LEFT))
	if _right_glass and _right_glass.has_signal("shattered"):
		_right_glass.shattered.connect(func() -> void: glass_shattered.emit(SIDE_RIGHT))


func is_open() -> bool:
	return _left_open or _right_open


func is_passage_open() -> bool:
	return _left_passable or _right_passable


func is_door_open(side: StringName) -> bool:
	return _left_open if side == SIDE_LEFT else _right_open


func is_door_passable(side: StringName) -> bool:
	return _left_passable if side == SIDE_LEFT else _right_passable


func is_glass_intact(side: StringName) -> bool:
	var glass := _left_glass if side == SIDE_LEFT else _right_glass
	if glass == null:
		return false
	if glass.has_method("is_intact"):
		return glass.is_intact()
	return false


## Standpoint just outside a closed leaf for scripted mobs (world space).
func get_outside_hold_position(side: StringName = SIDE_LEFT) -> Vector3:
	var closed := _left_closed_pos if side == SIDE_LEFT else _right_closed_pos
	var local := closed + (
		Vector3(-0.85, 0.0, 0.0) if side == SIDE_LEFT else Vector3(0.85, 0.0, 0.0)
	)
	return to_global(local)


func get_door_prompt(side: StringName) -> String:
	if is_door_open(side):
		return "E  CLOSE DOOR"
	return "E  OPEN DOOR"


func toggle_door(side: StringName) -> void:
	if is_door_open(side):
		close_door(side)
	else:
		open_door(side)


func open_door(side: StringName) -> void:
	if is_door_open(side):
		return
	var was_any_open := _left_open or _right_open
	_set_door_open(side, true)
	_animate_door(side, true)
	door_changed.emit(side, true)
	if not was_any_open:
		opened.emit()


func close_door(side: StringName) -> void:
	if not is_door_open(side):
		return
	_set_door_open(side, false)
	_set_passable(side, false)
	_animate_door(side, false)
	var tween := _left_tween if side == SIDE_LEFT else _right_tween
	await tween.finished
	if not is_door_open(side):
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
	if _left_open or _right_open:
		close()
	else:
		open()


func _set_door_open(side: StringName, value: bool) -> void:
	if side == SIDE_LEFT:
		_left_open = value
	else:
		_right_open = value


func _set_passable(side: StringName, value: bool) -> void:
	var current := _left_passable if side == SIDE_LEFT else _right_passable
	if current == value:
		return
	if side == SIDE_LEFT:
		_left_passable = value
	else:
		_right_passable = value
	passage_changed.emit(side, value)


func _inward_axis(side: StringName) -> Vector3:
	return Vector3.RIGHT if side == SIDE_LEFT else Vector3.LEFT


func _into_door_axis(side: StringName) -> Vector3:
	# From interior handle into the panel thickness.
	return Vector3.LEFT if side == SIDE_LEFT else Vector3.RIGHT


func _animate_door(side: StringName, opening: bool) -> void:
	var leaf := _left if side == SIDE_LEFT else _right
	var grip := _left_grip if side == SIDE_LEFT else _right_grip
	var mount := _left_mount if side == SIDE_LEFT else _right_mount
	var closed_pos := _left_closed_pos if side == SIDE_LEFT else _right_closed_pos
	var grip_closed := _left_grip_closed if side == SIDE_LEFT else _right_grip_closed
	var mount_closed := _left_mount_closed if side == SIDE_LEFT else _right_mount_closed

	var inward := _inward_axis(side)
	var into_door := _into_door_axis(side)
	var recessed_pos := closed_pos + inward * recess_distance
	var open_pos := recessed_pos + Vector3(0.0, 0.0, slide_distance)
	var grip_retracted := grip_closed + into_door * grip_retract_distance
	var mount_retracted := mount_closed + into_door * mount_retract_distance

	var existing := _left_tween if side == SIDE_LEFT else _right_tween
	if existing:
		existing.kill()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	if side == SIDE_LEFT:
		_left_tween = tween
	else:
		_right_tween = tween

	if opening:
		tween.tween_property(grip, "position", grip_retracted, grip_retract_duration)
		tween.tween_property(mount, "position", mount_retracted, mount_retract_duration)
		tween.tween_property(leaf, "position", recessed_pos, recess_duration)
		tween.tween_property(leaf, "position", open_pos, slide_duration)
		# Fires alongside the slide step — passage opens mid-slide, later than rear doors.
		tween.parallel().tween_callback(_set_passable.bind(side, true)).set_delay(
			slide_duration * passage_slide_ratio
		)
	else:
		_set_passable(side, false)
		tween.tween_property(leaf, "position", recessed_pos, slide_duration)
		tween.tween_property(leaf, "position", closed_pos, recess_duration)
		tween.tween_property(mount, "position", mount_closed, mount_retract_duration)
		tween.tween_property(grip, "position", grip_closed, grip_retract_duration)
