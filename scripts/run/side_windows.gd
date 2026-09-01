extends Node3D

## Side cargo windows — top-hinged sashes that tip vertically outward.
## Tiny interior latch (grip/mount) retracts first, then the sash swings open.
## Iron bars ride with the sash, so an open window clears the breach slot.

signal opened
signal closed
signal window_changed(window_id: StringName, is_open: bool)

const WIN_LEFT_REAR := &"left_rear"
const WIN_LEFT_FRONT := &"left_front"
const WIN_RIGHT_REAR := &"right_rear"
const WIN_RIGHT_FRONT := &"right_front"

const ALL_WINDOWS: Array[StringName] = [
	WIN_LEFT_REAR,
	WIN_LEFT_FRONT,
	WIN_RIGHT_REAR,
	WIN_RIGHT_FRONT,
]

@export var open_angle_deg := 85.0
@export var open_duration := 0.75
@export var grip_retract_duration := 0.08
@export var mount_retract_duration := 0.1
@export var grip_retract_distance := 0.035
@export var mount_retract_distance := 0.018

var _hinges: Dictionary = {}
var _grips: Dictionary = {}
var _mounts: Dictionary = {}
var _grip_closed: Dictionary = {}
var _mount_closed: Dictionary = {}
var _open: Dictionary = {}
var _tweens: Dictionary = {}


func _ready() -> void:
	_bind_window(WIN_LEFT_REAR, "LeftRear")
	_bind_window(WIN_LEFT_FRONT, "LeftFront")
	_bind_window(WIN_RIGHT_REAR, "RightRear")
	_bind_window(WIN_RIGHT_FRONT, "RightFront")


func is_window_open(window_id: StringName) -> bool:
	return bool(_open.get(window_id, false))


func get_window_prompt(window_id: StringName) -> String:
	if is_window_open(window_id):
		return "E  CLOSE WINDOW"
	return "E  OPEN WINDOW"


func toggle_window(window_id: StringName) -> void:
	if is_window_open(window_id):
		close_window(window_id)
	else:
		open_window(window_id)


func open_window(window_id: StringName) -> void:
	if not _hinges.has(window_id) or is_window_open(window_id):
		return
	var was_any_open := _any_open()
	_open[window_id] = true
	_animate_window(window_id, true)
	window_changed.emit(window_id, true)
	if not was_any_open:
		opened.emit()


func close_window(window_id: StringName) -> void:
	if not _hinges.has(window_id) or not is_window_open(window_id):
		return
	_open[window_id] = false
	_animate_window(window_id, false)
	var tween: Tween = _tweens.get(window_id)
	if tween:
		await tween.finished
	if not is_window_open(window_id):
		window_changed.emit(window_id, false)
		if not _any_open():
			closed.emit()


func open() -> void:
	for id in ALL_WINDOWS:
		open_window(id)


func close() -> void:
	for id in ALL_WINDOWS:
		close_window(id)


func _bind_window(window_id: StringName, node_name: String) -> void:
	var root := get_node_or_null(node_name)
	if root == null:
		return
	var hinge := root.get_node_or_null("Hinge") as Node3D
	var grip := root.get_node_or_null("Hinge/Handle/Grip") as Node3D
	var mount := root.get_node_or_null("Hinge/Handle/Mount") as Node3D
	if hinge == null or grip == null or mount == null:
		push_warning("SideWindows: missing hinge/handle under %s" % node_name)
		return
	_hinges[window_id] = hinge
	_grips[window_id] = grip
	_mounts[window_id] = mount
	_grip_closed[window_id] = grip.position
	_mount_closed[window_id] = mount.position
	_open[window_id] = false


func _any_open() -> bool:
	for id in ALL_WINDOWS:
		if is_window_open(id):
			return true
	return false


func _is_left(window_id: StringName) -> bool:
	return window_id == WIN_LEFT_REAR or window_id == WIN_LEFT_FRONT


func _into_sash_axis(window_id: StringName) -> Vector3:
	# Interior handle pulls into the sash thickness (toward the glass / outside).
	return Vector3.LEFT if _is_left(window_id) else Vector3.RIGHT


func _open_rotation_z(window_id: StringName) -> float:
	var angle := deg_to_rad(open_angle_deg)
	# Top hinge: tip bottom of sash outward (±X).
	return -angle if _is_left(window_id) else angle


func _animate_window(window_id: StringName, opening: bool) -> void:
	var hinge: Node3D = _hinges[window_id]
	var grip: Node3D = _grips[window_id]
	var mount: Node3D = _mounts[window_id]
	var grip_closed: Vector3 = _grip_closed[window_id]
	var mount_closed: Vector3 = _mount_closed[window_id]
	var into_sash := _into_sash_axis(window_id)
	var grip_retracted := grip_closed + into_sash * grip_retract_distance
	var mount_retracted := mount_closed + into_sash * mount_retract_distance
	var target_z := _open_rotation_z(window_id) if opening else 0.0

	var existing: Tween = _tweens.get(window_id)
	if existing:
		existing.kill()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	_tweens[window_id] = tween

	if opening:
		tween.tween_property(grip, "position", grip_retracted, grip_retract_duration)
		tween.tween_property(mount, "position", mount_retracted, mount_retract_duration)
		tween.tween_property(hinge, "rotation:z", target_z, open_duration)
	else:
		tween.tween_property(hinge, "rotation:z", target_z, open_duration)
		tween.tween_property(mount, "position", mount_closed, mount_retract_duration)
		tween.tween_property(grip, "position", grip_closed, grip_retract_duration)
