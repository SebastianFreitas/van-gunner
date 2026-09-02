extends Node3D

## Side cargo windows — top-hinged sashes that tip vertically outward.
## Built like rear doors: wall-material bezel with a rounded cut, then dark
## frame + glass. All three pieces follow the bowed side-wall profile.

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

## Front sashes sit next to the sliding side doors and swing into the door path.
const DOOR_ADJACENT_WINDOWS: Array[StringName] = [
	WIN_LEFT_FRONT,
	WIN_RIGHT_FRONT,
]

@export var open_angle_deg := 85.0
@export var open_duration := 0.75
@export var grip_retract_duration := 0.08
@export var mount_retract_duration := 0.1
@export var grip_retract_distance := 0.035
@export var mount_retract_distance := 0.018

## Matches original CSG sash (half extents).
const SASH_HALF_H := 0.74
const FRAME_THICKNESS := 0.05

## Exact CSG outlines from van.tscn (Vector2 = local Z, local Y from window center).
var FRAME_OUTER_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-1.029, -0.74), Vector2(-1.196, -0.666), Vector2(-1.28, -0.543),
	Vector2(-1.28, 0.543), Vector2(-1.196, 0.666), Vector2(-1.029, 0.74),
	Vector2(1.029, 0.74), Vector2(1.196, 0.666), Vector2(1.28, 0.543),
	Vector2(1.28, -0.543), Vector2(1.196, -0.666), Vector2(1.029, -0.74),
])
var GLASS_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-0.861, -0.617), Vector2(-1.017, -0.56), Vector2(-1.1, -0.455),
	Vector2(-1.1, 0.455), Vector2(-1.017, 0.56), Vector2(-0.861, 0.617),
	Vector2(0.861, 0.617), Vector2(1.017, 0.56), Vector2(1.1, 0.455),
	Vector2(1.1, -0.455), Vector2(1.017, -0.56), Vector2(0.861, -0.617),
])

var _hinges: Dictionary = {}
var _grips: Dictionary = {}
var _mounts: Dictionary = {}
var _grip_closed: Dictionary = {}
var _mount_closed: Dictionary = {}
var _open: Dictionary = {}
var _tweens: Dictionary = {}


func _ready() -> void:
	_fit_to_side_walls()
	_bind_window(WIN_LEFT_REAR, "LeftRear")
	_bind_window(WIN_LEFT_FRONT, "LeftFront")
	_bind_window(WIN_RIGHT_REAR, "RightRear")
	_bind_window(WIN_RIGHT_FRONT, "RightFront")


func _fit_to_side_walls() -> void:
	var walls := get_parent().get_node_or_null("SideWalls") as VanSideWall
	if walls == null:
		return
	_fit_window_root($LeftRear, -1.0, walls.window_centers_z[0], walls)
	_fit_window_root($LeftFront, -1.0, walls.window_centers_z[1], walls)
	_fit_window_root($RightRear, 1.0, walls.window_centers_z[0], walls)
	_fit_window_root($RightFront, 1.0, walls.window_centers_z[1], walls)


func _fit_window_root(root: Node3D, wall_sign: float, z_center: float, walls: VanSideWall) -> void:
	if root == null:
		return

	var mid_y := walls.window_center_y
	var y_hinge := mid_y + SASH_HALF_H
	var x_ref := walls.wall_x_at(y_hinge)
	root.rotation = Vector3.ZERO
	root.position = Vector3(wall_sign * x_ref, y_hinge, z_center)

	var hinge := root.get_node_or_null("Hinge") as Node3D
	if hinge == null:
		return
	hinge.position = Vector3.ZERO
	hinge.rotation = Vector3.ZERO

	var frame_mat := _steal_material(hinge, "WindowFrame/Outer")
	var glass_mat := _steal_material(hinge, "WindowGlass")

	_hide_node(root, "WallPanel")
	_hide_node(hinge, "WindowFrame")
	_free_node(hinge, "WindowGlass")
	_free_node(root, "CurvedBezel")
	_free_node(hinge, "CurvedFrame")

	# No separate bezel — VanSideWall punches the rounded WindowCut so the liner
	# itself is the surround (same as the rear door leaf around its pane).

	var frame := MeshInstance3D.new()
	frame.name = "CurvedFrame"
	frame.mesh = walls.build_curved_frame_ring_mesh(
		wall_sign, FRAME_OUTER_POLY, GLASS_POLY,
		x_ref, y_hinge, z_center, mid_y, FRAME_THICKNESS, 0.0, 10
	)
	frame.material_override = frame_mat
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hinge.add_child(frame)

	var glass := MeshInstance3D.new()
	glass.name = "WindowGlass"
	glass.mesh = walls.build_curved_pane_from_poly(
		wall_sign, GLASS_POLY, x_ref, y_hinge, z_center, mid_y, -wall_sign * 0.06, 8
	)
	glass.material_override = glass_mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hinge.add_child(glass)

	var breakable := hinge.get_node_or_null("BreakableGlass")
	if breakable and breakable.has_method("bind_glass_visual"):
		breakable.bind_glass_visual(glass)

	var iron_cross := hinge.get_node_or_null("IronCross") as IronCross
	_place_on_curve(iron_cross, walls, wall_sign, x_ref, y_hinge, mid_y, 0.0, 0.035)
	if iron_cross:
		iron_cross.follow_side_wall_curve(walls, mid_y)
	_place_on_curve(breakable as Node3D, walls, wall_sign, x_ref, y_hinge, mid_y, 0.0, 0.04)
	_place_on_curve(hinge.get_node_or_null("Interact") as Node3D, walls, wall_sign, x_ref, y_hinge, mid_y, 0.0, 0.0)

	var handle := hinge.get_node_or_null("Handle") as Node3D
	if handle:
		_place_on_curve(handle, walls, wall_sign, x_ref, y_hinge, mid_y - 0.52, -0.95, 0.08)


func _place_on_curve(
	node: Node3D,
	walls: VanSideWall,
	wall_sign: float,
	x_ref: float,
	y_ref: float,
	world_y: float,
	local_z: float,
	into_cabin: float
) -> void:
	if node == null:
		return
	var node_basis := node.transform.basis
	var local_x := walls.local_x_on_wall(wall_sign, world_y, x_ref) - wall_sign * into_cabin
	node.transform = Transform3D(node_basis, Vector3(local_x, world_y - y_ref, local_z))


func _hide_node(parent: Node, path: String) -> void:
	var node := parent.get_node_or_null(path) as Node3D
	if node:
		node.visible = false


func _free_node(parent: Node, path: String) -> void:
	var node := parent.get_node_or_null(path)
	if node:
		node.free()


func _steal_material(parent: Node, path: String) -> Material:
	var node := parent.get_node_or_null(path)
	if node == null:
		return null
	if node is GeometryInstance3D and (node as GeometryInstance3D).material_override:
		return (node as GeometryInstance3D).material_override
	if node.get("material") != null:
		return node.get("material") as Material
	return null


func is_window_open(window_id: StringName) -> bool:
	return bool(_open.get(window_id, false))


func get_window_prompt(window_id: StringName) -> String:
	if is_blocked_by_door(window_id):
		return "CLOSE DOOR FIRST"
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
	if is_blocked_by_door(window_id):
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


func is_door_adjacent_window(window_id: StringName) -> bool:
	return window_id in DOOR_ADJACENT_WINDOWS


func is_blocked_by_door(window_id: StringName) -> bool:
	if not is_door_adjacent_window(window_id):
		return false
	var doors := get_tree().get_first_node_in_group(&"side_doors")
	if doors == null:
		return false
	var side := &"left" if _is_left(window_id) else &"right"
	return doors.is_door_open(side)


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
