extends Node3D

## Sliding cargo-style side doors.
## Grip (button) retracts first, then Mount (black latch) pulls into the door
## while keeping its head visible. Door recesses inward, then slides rearward.
## Passage for player/enemies unlocks later in the slide than rear hinge doors.

signal opened
signal closed
signal door_changed(side: StringName, is_open: bool)
signal passage_changed(side: StringName, is_passable: bool)

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

## Recessed panel + trim (from original CSG Panel, local y/z from door center).
const PANEL_CENTER_Y := -0.15
const PANEL_HALF_Z := 1.10
const PANEL_HALF_Y := 1.275
const PANEL_FRAME_INSET := 0.08
const PANEL_RECESS_DEPTH := 0.05
const BELT_Y := -0.05
const BELT_HALF_H := 0.025
const LOWER_CREASE_Y := -0.85
const LOWER_CREASE_HALF_H := 0.02
const PERIMETER_FRAME_INSET := 0.06
const FRAME_THICKNESS := 0.045

@onready var _left: Node3D = $Left
@onready var _right: Node3D = $Right
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

	var door_height := y_max - y_min
	var body_mat := _door_body_material(_steal_material(leaf, "Panel/Body"), door_height)
	var trim_mat := _steal_material(leaf, "Panel/OuterSkin")
	var frame_mat := _find_frame_material(trim_mat)

	_hide_node(leaf, "Panel")
	_free_node(leaf, "CurvedBody")
	_free_node(leaf, "CurvedOuter")
	_free_node(leaf, "PerimeterFrame")
	_free_node(leaf, "PanelFrame")
	_free_node(leaf, "RecessedPanel")
	_free_node(leaf, "BeltStrip")
	_free_node(leaf, "LowerCrease")
	_free_node(leaf, "LatchPlate")

	var body := MeshInstance3D.new()
	body.name = "CurvedBody"
	body.mesh = walls.build_curved_shell_mesh(
		wall_sign, y_min, y_max, z0, z1, x_ref, mid_y, z_ref, DOOR_THICKNESS,
		0.0, 28, 16,
		INF, -INF, INF, -INF,
		PackedVector2Array(),
		PackedVector2Array()
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
		PackedVector2Array()
	)
	outer.material_override = trim_mat
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(outer)

	var door_half_y := (y_max - y_min) * 0.5
	var perimeter_outer := _rect_poly(DOOR_HALF_Z - 0.02, door_half_y - 0.02)
	var perimeter_inner := _rect_poly(
		DOOR_HALF_Z - 0.02 - PERIMETER_FRAME_INSET,
		door_half_y - 0.02 - PERIMETER_FRAME_INSET
	)
	_add_frame_ring(
		leaf, walls, wall_sign, x_ref, mid_y, z_ref, mid_y,
		perimeter_outer, perimeter_inner, frame_mat, "PerimeterFrame", 0.0, 10
	)

	var panel_outer := _rect_poly(PANEL_HALF_Z, PANEL_HALF_Y)
	var panel_inner := _rect_poly(
		PANEL_HALF_Z - PANEL_FRAME_INSET, PANEL_HALF_Y - PANEL_FRAME_INSET
	)
	_add_frame_ring(
		leaf, walls, wall_sign, x_ref, mid_y, z_ref, mid_y + PANEL_CENTER_Y,
		panel_outer, panel_inner, frame_mat, "PanelFrame",
		-wall_sign * PANEL_RECESS_DEPTH * 0.35, 8
	)

	var recessed := MeshInstance3D.new()
	recessed.name = "RecessedPanel"
	recessed.mesh = walls.build_curved_pane_from_poly(
		wall_sign, panel_inner, x_ref, mid_y, z_ref, mid_y + PANEL_CENTER_Y,
		-wall_sign * PANEL_RECESS_DEPTH, 6
	)
	recessed.material_override = body_mat
	recessed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	leaf.add_child(recessed)

	_add_trim_strip(
		leaf, walls, wall_sign, x_ref, mid_y, z_ref,
		mid_y + BELT_Y - BELT_HALF_H, mid_y + BELT_Y + BELT_HALF_H,
		z_ref - PANEL_HALF_Z, z_ref + PANEL_HALF_Z,
		-wall_sign * PANEL_RECESS_DEPTH * 0.5, trim_mat, "BeltStrip"
	)
	_add_trim_strip(
		leaf, walls, wall_sign, x_ref, mid_y, z_ref,
		mid_y + LOWER_CREASE_Y - LOWER_CREASE_HALF_H, mid_y + LOWER_CREASE_Y + LOWER_CREASE_HALF_H,
		z_ref - PANEL_HALF_Z, z_ref + PANEL_HALF_Z,
		-wall_sign * PANEL_RECESS_DEPTH * 0.5, trim_mat, "LowerCrease"
	)

	_add_latch_plate(leaf, walls, wall_sign, x_ref, mid_y, z_ref, trim_mat)

	_place_on_curve(leaf.get_node_or_null("Handle") as Node3D, walls, wall_sign, x_ref, mid_y, 1.375, 0.85, 0.12)


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


func _door_body_material(source: Material, door_height: float) -> Material:
	if source is ShaderMaterial:
		var mat := (source as ShaderMaterial).duplicate()
		mat.set_shader_parameter("wall_size_m", Vector2(DOOR_HALF_Z * 2.0, door_height))
		mat.set_shader_parameter("panel_spacing_m", 0.85)
		mat.set_shader_parameter("rib_spacing_m", 0.28)
		mat.set_shader_parameter("kick_height_m", 0.32)
		mat.set_shader_parameter("belt_y_m", 1.42)
		mat.set_shader_parameter("waist_y_m", 2.05)
		return mat
	return source


func _find_frame_material(fallback: Material) -> Material:
	var windows := get_parent().get_node_or_null("SideWindows")
	if windows:
		var stolen := _steal_material(windows, "LeftRear/Hinge/WindowFrame/Outer")
		if stolen:
			return stolen
	return fallback


func _rect_poly(half_z: float, half_y: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_z, -half_y), Vector2(half_z, -half_y),
		Vector2(half_z, half_y), Vector2(-half_z, half_y),
	])


func _add_frame_ring(
	parent: Node3D,
	walls: VanSideWall,
	wall_sign: float,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	poly_center_y: float,
	outer_poly: PackedVector2Array,
	inner_poly: PackedVector2Array,
	mat: Material,
	node_name: String,
	x_shift: float,
	edge_subdiv: int
) -> void:
	var frame := MeshInstance3D.new()
	frame.name = node_name
	frame.mesh = walls.build_curved_frame_ring_mesh(
		wall_sign, outer_poly, inner_poly,
		x_ref, y_ref, z_ref, poly_center_y, FRAME_THICKNESS, x_shift, edge_subdiv
	)
	frame.material_override = mat
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(frame)


func _add_trim_strip(
	parent: Node3D,
	walls: VanSideWall,
	wall_sign: float,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	y0: float,
	y1: float,
	z0: float,
	z1: float,
	x_shift: float,
	mat: Material,
	node_name: String
) -> void:
	var strip := MeshInstance3D.new()
	strip.name = node_name
	strip.mesh = walls.build_curved_shell_mesh(
		wall_sign, y0, y1, z0, z1, x_ref, y_ref, z_ref, FRAME_THICKNESS,
		x_shift, 4, 16,
		INF, -INF, INF, -INF,
		PackedVector2Array(),
		PackedVector2Array()
	)
	strip.material_override = mat
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(strip)


func _add_latch_plate(
	leaf: Node3D,
	walls: VanSideWall,
	wall_sign: float,
	x_ref: float,
	mid_y: float,
	z_ref: float,
	trim_mat: Material
) -> void:
	# Exterior latch backing plate beside the handle (cargo sliding-door look).
	var plate_y0 := mid_y + 0.95
	var plate_y1 := mid_y + 1.55
	var plate_z0 := z_ref + 0.55
	var plate_z1 := z_ref + 1.15
	var plate := MeshInstance3D.new()
	plate.name = "LatchPlate"
	plate.mesh = walls.build_curved_shell_mesh(
		wall_sign, plate_y0, plate_y1, plate_z0, plate_z1,
		x_ref, mid_y, z_ref, 0.012,
		wall_sign * (DOOR_THICKNESS + OUTER_SKIN * 0.5), 6, 8,
		INF, -INF, INF, -INF,
		PackedVector2Array(),
		PackedVector2Array()
	)
	plate.material_override = trim_mat
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(plate)


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
