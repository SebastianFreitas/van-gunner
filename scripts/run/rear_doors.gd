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

const DOOR_THICKNESS := 0.16
const CENTER_GAP := 0.012
const Y_MIN := 0.02
## Window cut polygon (XY offsets from window center) — matches CSG WindowCut.
var WINDOW_HOLE: PackedVector2Array = PackedVector2Array([
	Vector2(-0.79, -0.775), Vector2(-0.92, -0.7), Vector2(-0.99, -0.575),
	Vector2(-0.99, 0.575), Vector2(-0.92, 0.7), Vector2(-0.79, 0.775),
	Vector2(0.79, 0.775), Vector2(0.92, 0.7), Vector2(0.99, 0.575),
	Vector2(0.99, -0.575), Vector2(0.92, -0.7), Vector2(0.79, -0.775),
])

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
	_fit_to_hull()
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


func _fit_to_hull() -> void:
	var walls := get_parent().get_node_or_null("SideWalls") as VanSideWall
	var ceiling := get_parent().get_node_or_null("Ceiling") as VanCeiling
	# One canonical left leaf — mirror for the right so bow/normals match.
	var mesh := _build_left_leaf_mesh(walls, ceiling)
	var mat := _door_body_material(walls, ceiling)
	_apply_leaf(_left_hinge, mesh, mat, false)
	_apply_leaf(_right_hinge, mesh, mat, true)


func _build_left_leaf_mesh(walls: VanSideWall, ceiling: VanCeiling) -> ArrayMesh:
	var hinge_x := absf(_left_hinge.position.x) if _left_hinge else 2.39
	var hinge_y := _left_hinge.position.y if _left_hinge else 1.55
	var wall_sign := -1.0
	var x_inner := wall_sign * CENTER_GAP
	var origin := Vector3(wall_sign * hinge_x, hinge_y, 0.0)
	# World-space window center from the original CSG layout (left leaf).
	var hole_center := Vector2(wall_sign * 1.075, 1.775)
	return VanHullMesh.build_vaulted_xy_slab(
		walls, ceiling,
		x_inner, wall_sign, Y_MIN, DOOR_THICKNESS, origin,
		0.03, 0.025, 16, 32,
		WINDOW_HOLE, hole_center,
		3.05, 0.38, 2.42,
		true
	)


func _apply_leaf(hinge: Node3D, mesh: ArrayMesh, mat: Material, mirror_x: bool) -> void:
	if hinge == null or mesh == null:
		return
	# Hinge / window frame / glass / handle locals stay put — body only.
	var panel := hinge.get_node_or_null("Panel") as Node3D
	if panel:
		panel.visible = false

	var existing := hinge.get_node_or_null("CurvedBody")
	if existing:
		existing.free()

	var body := MeshInstance3D.new()
	body.name = "CurvedBody"
	body.mesh = mesh
	body.material_override = mat
	if mirror_x:
		# Flips geometry + normals together (avoids the right-leaf winding bug).
		body.scale = Vector3(-1.0, 1.0, 1.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hinge.add_child(body)
	hinge.move_child(body, 0)


func _door_body_material(walls: VanSideWall, ceiling: VanCeiling) -> Material:
	# Same cargo-liner shader the side doors / walls use.
	var source: Material = null
	if walls != null and walls.wall_material != null:
		source = walls.wall_material
	else:
		var side_doors := get_parent().get_node_or_null("SideDoors")
		if side_doors:
			var side_body := side_doors.get_node_or_null("Left/Panel/Body")
			if side_body and side_body.get("material") != null:
				source = side_body.get("material") as Material
	if source == null and _left_hinge:
		var body := _left_hinge.get_node_or_null("Panel/Body")
		if body and body.get("material") != null:
			source = body.get("material") as Material

	var hinge_x := absf(_left_hinge.position.x) if _left_hinge else 2.39
	var door_width := hinge_x - CENTER_GAP
	var y_peak := VanHullMesh.vault_y(ceiling, 0.0, 3.05, 0.38)
	var door_height := y_peak - Y_MIN

	if source is ShaderMaterial:
		var mat := (source as ShaderMaterial).duplicate()
		mat.set_shader_parameter("wall_size_m", Vector2(door_width, door_height))
		mat.set_shader_parameter("panel_spacing_m", 0.85)
		mat.set_shader_parameter("rib_spacing_m", 0.28)
		mat.set_shader_parameter("kick_height_m", 0.32)
		mat.set_shader_parameter("belt_y_m", 1.42)
		mat.set_shader_parameter("waist_y_m", 2.05)
		return mat
	return source


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
		_set_leaf_collision_enabled(side, true)


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
	_set_leaf_collision_enabled(side, true)
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
