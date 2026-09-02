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

## Door leaf extents (slightly inset from the wall opening).
const DOOR_HALF_Z := 1.265
const DOOR_THICKNESS := 0.14
const OUTER_SKIN := 0.035
const FRAME_THICKNESS := 0.05
## Window center on the leaf (matches CSG WindowCut / rear-style pane).
const DOOR_WIN_CENTER_Y := 1.775

## Exact CSG outlines from van.tscn (Vector2 = local Z, local Y from window center).
var DOOR_CUT_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-0.85, -0.55), Vector2(-0.97, -0.49), Vector2(-1.05, -0.38),
	Vector2(-1.05, 0.38), Vector2(-0.97, 0.49), Vector2(-0.85, 0.55),
	Vector2(0.85, 0.55), Vector2(0.97, 0.49), Vector2(1.05, 0.38),
	Vector2(1.05, -0.38), Vector2(0.97, -0.49), Vector2(0.85, -0.55),
])
var DOOR_FRAME_OUTER_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-0.9, -0.6), Vector2(-1.03, -0.535), Vector2(-1.12, -0.42),
	Vector2(-1.12, 0.42), Vector2(-1.03, 0.535), Vector2(-0.9, 0.6),
	Vector2(0.9, 0.6), Vector2(1.03, 0.535), Vector2(1.12, 0.42),
	Vector2(1.12, -0.42), Vector2(1.03, -0.535), Vector2(0.9, -0.6),
])
var DOOR_GLASS_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-0.76, -0.48), Vector2(-0.88, -0.43), Vector2(-0.96, -0.33),
	Vector2(-0.96, 0.33), Vector2(-0.88, 0.43), Vector2(-0.76, 0.48),
	Vector2(0.76, 0.48), Vector2(0.88, 0.43), Vector2(0.96, 0.33),
	Vector2(0.96, -0.33), Vector2(0.88, -0.43), Vector2(0.76, -0.48),
])

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
var _left_broken := false
var _right_broken := false
var _left_passable := false
var _right_passable := false
var _left_tween: Tween
var _right_tween: Tween


func _ready() -> void:
	_fit_to_side_walls()
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


func _fit_to_side_walls() -> void:
	var walls := get_parent().get_node_or_null("SideWalls") as VanSideWall
	if walls == null:
		return
	_fit_door_leaf(_left, -1.0, walls)
	_fit_door_leaf(_right, 1.0, walls)


func _fit_door_leaf(leaf: Node3D, wall_sign: float, walls: VanSideWall) -> void:
	var y_min := walls.door_y_min
	var y_max := walls.door_y_max
	var mid_y := (y_min + y_max) * 0.5
	var x_ref := walls.wall_x_at(mid_y)
	var z_ref := walls.door_center_z
	var z0 := z_ref - DOOR_HALF_Z
	var z1 := z_ref + DOOR_HALF_Z

	leaf.rotation = Vector3.ZERO
	leaf.position = Vector3(wall_sign * x_ref, mid_y, z_ref)

	var body_mat := _steal_material(leaf, "Panel/Body")
	var trim_mat := _steal_material(leaf, "Panel/OuterSkin")
	var frame_mat := _steal_material(leaf, "WindowFrame/Outer")
	var glass_mat := _steal_material(leaf, "WindowGlass")

	_hide_node(leaf, "Panel")
	_hide_node(leaf, "WindowFrame")
	_free_node(leaf, "WindowGlass")
	_free_node(leaf, "CurvedBody")
	_free_node(leaf, "CurvedOuter")
	_free_node(leaf, "CurvedFrame")
	_free_node(leaf, "CurvedGlass")

	# Door leaf = wall-material panel with rounded WindowCut (same idea as rear doors).
	var body := MeshInstance3D.new()
	body.name = "CurvedBody"
	body.mesh = walls.build_curved_shell_mesh(
		wall_sign, y_min, y_max, z0, z1, x_ref, mid_y, z_ref, DOOR_THICKNESS,
		0.0, 28, 16,
		INF, -INF, INF, -INF,
		PackedVector2Array(),
		DOOR_CUT_POLY,
		DOOR_WIN_CENTER_Y
	)
	body.material_override = body_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	leaf.add_child(body)

	var outer := MeshInstance3D.new()
	outer.name = "CurvedOuter"
	outer.mesh = walls.build_curved_shell_mesh(
		wall_sign, y_min + 0.02, y_max - 0.02, z0 + 0.02, z1 - 0.02,
		x_ref, mid_y, z_ref, OUTER_SKIN,
		wall_sign * DOOR_THICKNESS, 24, 14,
		INF, -INF, INF, -INF,
		PackedVector2Array(),
		DOOR_CUT_POLY,
		DOOR_WIN_CENTER_Y
	)
	outer.material_override = trim_mat
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(outer)

	var frame := MeshInstance3D.new()
	frame.name = "CurvedFrame"
	frame.mesh = walls.build_curved_frame_ring_mesh(
		wall_sign, DOOR_FRAME_OUTER_POLY, DOOR_GLASS_POLY,
		x_ref, mid_y, z_ref, DOOR_WIN_CENTER_Y, FRAME_THICKNESS, wall_sign * 0.02, 10
	)
	frame.material_override = frame_mat
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	leaf.add_child(frame)

	var glass := MeshInstance3D.new()
	glass.name = "WindowGlass"
	glass.mesh = walls.build_curved_pane_from_poly(
		wall_sign, DOOR_GLASS_POLY, x_ref, mid_y, z_ref, DOOR_WIN_CENTER_Y, wall_sign * 0.055, 8
	)
	glass.material_override = glass_mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(glass)

	var breakable := leaf.get_node_or_null("BreakableGlass")
	if breakable and breakable.has_method("bind_glass_visual"):
		breakable.bind_glass_visual(glass)

	_place_on_curve(leaf.get_node_or_null("Handle") as Node3D, walls, wall_sign, x_ref, mid_y, 1.375, 0.85, 0.12)
	var iron_cross := leaf.get_node_or_null("IronCross") as IronCross
	_place_on_curve(iron_cross, walls, wall_sign, x_ref, mid_y, DOOR_WIN_CENTER_Y, 0.0, 0.03)
	if iron_cross:
		iron_cross.follow_side_wall_curve(walls, DOOR_WIN_CENTER_Y)
	_place_on_curve(breakable as Node3D, walls, wall_sign, x_ref, mid_y, DOOR_WIN_CENTER_Y, 0.0, 0.055)


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
	# Keep any facing rotation; only rewrite translation onto the curve.
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


func is_open() -> bool:
	return _left_open or _right_open


func is_passage_open() -> bool:
	return _left_passable or _right_passable


func is_door_open(side: StringName) -> bool:
	return _left_open if side == SIDE_LEFT else _right_open


func is_door_passable(side: StringName) -> bool:
	return _left_passable if side == SIDE_LEFT else _right_passable


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
		_set_passable(side, true)


func is_glass_intact(side: StringName) -> bool:
	var glass := _left_glass if side == SIDE_LEFT else _right_glass
	if glass == null:
		return false
	if glass.has_method("is_intact"):
		return glass.is_intact()
	return false


## Standpoint just outside a closed leaf for scripted mobs (world space).
func get_outside_hold_position(side: StringName = SIDE_LEFT) -> Vector3:
	var closed_pos := _left_closed_pos if side == SIDE_LEFT else _right_closed_pos
	var local := closed_pos + (
		Vector3(-0.85, 0.0, 0.0) if side == SIDE_LEFT else Vector3(0.85, 0.0, 0.0)
	)
	return to_global(local)


func get_door_prompt(side: StringName) -> String:
	if is_door_broken(side):
		return "BROKEN"
	if is_blocked_by_adjacent_window(side):
		return "CLOSE WINDOW FIRST"
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
	if is_blocked_by_adjacent_window(side):
		return
	var was_any_open := _left_open or _right_open
	_set_door_open(side, true)
	_animate_door(side, true)
	door_changed.emit(side, true)
	if not was_any_open:
		opened.emit()


func close_door(side: StringName) -> void:
	if is_door_broken(side) or not is_door_open(side):
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


func _adjacent_window_id(side: StringName) -> StringName:
	return &"left_front" if side == SIDE_LEFT else &"right_front"


func is_blocked_by_adjacent_window(side: StringName) -> bool:
	var windows := get_tree().get_first_node_in_group(&"side_windows")
	if windows == null:
		return false
	return windows.is_window_open(_adjacent_window_id(side))


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
