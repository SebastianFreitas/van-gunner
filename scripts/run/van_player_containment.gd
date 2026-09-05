class_name VanPlayerContainment
extends StaticBody3D

## Invisible shell that keeps the player inside the van. Uses a dedicated physics
## layer so bullets and enemy rays still pass through door/window openings.

const LAYER := 16  # physics layer 5

@export var half_width := 2.24 + 0.8
@export var half_length := 4.68 + 0.8
@export var wall_height := 3.1
@export var wall_thickness := 0.12

var _rear_exit_allowed := false


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	_build()


func _build() -> void:
	var center_y := wall_height * 0.5
	var depth_z := half_length * 2.0
	_add_panel(
		&"Left",
		Vector3(-half_width, center_y, 0.0),
		Vector3(wall_thickness, wall_height, depth_z)
	)
	_add_panel(
		&"Right",
		Vector3(half_width, center_y, 0.0),
		Vector3(wall_thickness, wall_height, depth_z)
	)
	_add_panel(
		&"Rear",
		Vector3(0.0, center_y, half_length),
		Vector3(half_width * 2.0, wall_height, wall_thickness)
	)
	_add_panel(
		&"Front",
		Vector3(0.0, center_y, -half_length),
		Vector3(half_width * 2.0, wall_height, wall_thickness)
	)


func _add_panel(panel_name: StringName, pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = String(panel_name)
	col.shape = shape
	col.position = pos
	add_child(col)


func is_rear_exit_allowed() -> bool:
	return _rear_exit_allowed


## Horizontal distance past the van hull AABB. Zero while standing inside.
func horizontal_clearance(world_pos: Vector3) -> float:
	var local := to_local(world_pos)
	var dx := maxf(absf(local.x) - half_width, 0.0)
	var dz := maxf(absf(local.z) - half_length, 0.0)
	return Vector2(dx, dz).length()


func set_rear_exit_allowed(allowed: bool) -> void:
	if _rear_exit_allowed == allowed:
		return
	_rear_exit_allowed = allowed
	var rear := get_node_or_null("Rear") as CollisionShape3D
	if rear:
		rear.disabled = allowed
