extends Node3D

## Truck-style rear double doors.
## Grip (button) retracts first, then Mount (black latch) pulls into the door
## while keeping its head visible. Visual leaves swing on hinges. Fixed half-blockers on world
## layer 1 stop the player when a leaf is closed — they never rotate, so
## close never pushes anyone. Hinge-attached leaf colliders (same layer) take
## over while open so the swung panel blocks the player. Scripted Node3D mobs
## ignore physics, so callers should use is_passage_open() / get_outside_hold_position().

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
@export var grip_retract_duration := 0.1
@export var mount_retract_duration := 0.14
@export var grip_retract_distance := 0.06
## Shallow pull — rear mount faces the camera, so deep Z travel vanishes into the panel.
@export var mount_retract_distance := 0.01

@onready var _left_hinge: Node3D = $LeftHinge
@onready var _right_hinge: Node3D = $RightHinge
@onready var _left_glass: Node = $LeftHinge/BreakableGlass
@onready var _right_glass: Node = $RightHinge/BreakableGlass
@onready var _left_grip: Node3D = $LeftHinge/Handle/Grip
@onready var _left_mount: Node3D = $LeftHinge/Handle/Mount
@onready var _right_grip: Node3D = $RightHinge/Handle/Grip
@onready var _right_mount: Node3D = $RightHinge/Handle/Mount

var _left_blocker_shapes: Array[CollisionShape3D] = []
var _right_blocker_shapes: Array[CollisionShape3D] = []
var _left_leaf_body: StaticBody3D
var _right_leaf_body: StaticBody3D
var _left_grip_closed: Vector3
var _left_mount_closed: Vector3
var _right_grip_closed: Vector3
var _right_mount_closed: Vector3
var _left_open := false
var _right_open := false
var _left_broken := false
var _right_broken := false
var _left_tween: Tween
var _right_tween: Tween


func _ready() -> void:
	preload("res://scripts/van/rear_door_leaf_build.gd").build(self, _left_hinge, _right_hinge)
	preload("res://scripts/van/rear_door_frame.gd").build(self, _left_hinge)
	preload("res://scripts/van/rear_door_lips.gd").build(self, _left_hinge, _right_hinge)
	preload("res://scripts/van/rear_door_lighting.gd").apply(_left_hinge, _right_hinge)
	_left_grip_closed = _left_grip.position
	_left_mount_closed = _left_mount.position
	_right_grip_closed = _right_grip.position
	_right_mount_closed = _right_mount.position
	_left_blocker_shapes = _collect_blocker_shapes("Left")
	_right_blocker_shapes = _collect_blocker_shapes("Right")
	_left_leaf_body = _create_leaf_collision_body(_left_hinge)
	_right_leaf_body = _create_leaf_collision_body(_right_hinge)
	_set_leaf_collision_enabled(SIDE_LEFT, _left_open)
	_set_leaf_collision_enabled(SIDE_RIGHT, _right_open)
	if _left_glass and _left_glass.has_signal("shattered"):
		_left_glass.shattered.connect(func() -> void: glass_shattered.emit(SIDE_LEFT))
	if _right_glass and _right_glass.has_signal("shattered"):
		_right_glass.shattered.connect(func() -> void: glass_shattered.emit(SIDE_RIGHT))


func is_open() -> bool:
	return _left_open and _right_open


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
		_set_leaf_collision_enabled(side, true)


func clear_door_broken(side: StringName) -> void:
	if side == SIDE_LEFT:
		_left_broken = false
	else:
		_right_broken = false


## Standpoint outside closed doors for scripted mobs (world space).
func get_outside_hold_position() -> Vector3:
	return to_global(OUTSIDE_HOLD_LOCAL)


func get_door_prompt(side: StringName) -> String:
	if is_door_broken(side):
		return "BROKEN"
	if is_door_open(side):
		if _is_stop_keeping_doors_open():
			return "%s — KEEP OPEN" % _stop_short_label()
		return "E  CLOSE DOOR"
	return "E  OPEN DOOR"


func toggle_door(side: StringName) -> void:
	if is_door_broken(side):
		return
	if is_door_open(side):
		# Player close would clear open flags while shop still needs the gap;
		# seal then no-ops and leaves the leaf uninteractable.
		if _is_stop_keeping_doors_open():
			return
		close_door(side)
	else:
		open_door(side)


func open_door(side: StringName) -> void:
	if is_door_open(side):
		return
	_set_door_open(side, true)
	_set_blocker_enabled(side, false)
	_set_leaf_collision_enabled(side, true)
	_animate_door(side, true)
	door_changed.emit(side, true)
	if is_open():
		opened.emit()


func close_door(side: StringName) -> void:
	if is_door_broken(side):
		return
	# Already logically closed — still repair mesh/collision (stop desync / killed tween).
	if not is_door_open(side):
		_snap_door_closed(side)
		return
	_set_door_open(side, false)
	_animate_door(side, false)
	var tween := _left_tween if side == SIDE_LEFT else _right_tween
	await tween.finished
	if not is_door_open(side):
		_set_blocker_enabled(side, true)
		_set_leaf_collision_enabled(side, false)
		door_changed.emit(side, false)
		if not _left_open and not _right_open:
			closed.emit()


func open() -> void:
	open_door(SIDE_LEFT)
	open_door(SIDE_RIGHT)


func close() -> void:
	close_door(SIDE_LEFT)
	close_door(SIDE_RIGHT)


func _is_stop_keeping_doors_open() -> bool:
	return GameSession.phase == GameSession.RunPhase.STOP


func _stop_short_label() -> String:
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_method(&"get_active_stop"):
		var stop: SideStopDefinition = travel.get_active_stop()
		if stop:
			return stop.short_label
	return "STOP"


func _snap_door_closed(side: StringName) -> void:
	var existing := _left_tween if side == SIDE_LEFT else _right_tween
	if existing:
		existing.kill()
	var hinge := _left_hinge if side == SIDE_LEFT else _right_hinge
	var grip := _left_grip if side == SIDE_LEFT else _right_grip
	var mount := _left_mount if side == SIDE_LEFT else _right_mount
	var grip_closed := _left_grip_closed if side == SIDE_LEFT else _right_grip_closed
	var mount_closed := _left_mount_closed if side == SIDE_LEFT else _right_mount_closed
	if hinge:
		hinge.rotation.y = 0.0
	if grip:
		grip.position = grip_closed
	if mount:
		mount.position = mount_closed
	_set_blocker_enabled(side, true)
	_set_leaf_collision_enabled(side, false)


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


func _set_leaf_collision_enabled(side: StringName, enabled: bool) -> void:
	var body := _left_leaf_body if side == SIDE_LEFT else _right_leaf_body
	if body:
		body.collision_layer = 1 if enabled else 0


func _create_leaf_collision_body(hinge: Node3D) -> StaticBody3D:
	var interact := hinge.get_node_or_null("Interact") as StaticBody3D
	if interact == null:
		return null
	var body := StaticBody3D.new()
	body.name = "LeafCollision"
	body.collision_layer = 0
	body.collision_mask = 0
	body.transform = interact.transform
	hinge.add_child(body)
	for child in interact.get_children():
		if child is CollisionShape3D:
			body.add_child((child as CollisionShape3D).duplicate())
	return body


func _collect_blocker_shapes(side_prefix: String) -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	var blocker := get_node_or_null("Blocker")
	if blocker == null:
		return shapes
	for child in blocker.get_children():
		if child is CollisionShape3D and String(child.name).begins_with(side_prefix):
			shapes.append(child)
	return shapes


func _into_door_axis() -> Vector3:
	# Interior handle pulls into the panel thickness (toward the exterior / +Z).
	return Vector3.BACK


func _animate_door(side: StringName, opening: bool) -> void:
	var hinge := _left_hinge if side == SIDE_LEFT else _right_hinge
	var grip := _left_grip if side == SIDE_LEFT else _right_grip
	var mount := _left_mount if side == SIDE_LEFT else _right_mount
	var grip_closed := _left_grip_closed if side == SIDE_LEFT else _right_grip_closed
	var mount_closed := _left_mount_closed if side == SIDE_LEFT else _right_mount_closed
	var into_door := _into_door_axis()
	var grip_retracted := grip_closed + into_door * grip_retract_distance
	var mount_retracted := mount_closed + into_door * mount_retract_distance
	var angle := deg_to_rad(open_angle_deg)
	var target_y := 0.0
	if opening:
		target_y = -angle if side == SIDE_LEFT else angle

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
		tween.tween_property(hinge, "rotation:y", target_y, open_duration)
	else:
		tween.tween_property(hinge, "rotation:y", target_y, open_duration)
		tween.tween_property(mount, "position", mount_closed, mount_retract_duration)
		tween.tween_property(grip, "position", grip_closed, grip_retract_duration)


## Kit refit: `holes` maps &"left"/&"right" to {hole_grow, glazing}; both are always rolled.
func refit_windows(holes: Dictionary) -> void:
	RearWindowFit.fit(self, holes)
