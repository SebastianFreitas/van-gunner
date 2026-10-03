class_name VanPlayerContainment
extends StaticBody3D

## Invisible shell that keeps the player inside the van. Uses a dedicated physics
## layer so bullets and enemy rays still pass through door/window openings.

const LAYER := 16  # physics layer 5

@export var half_width := INTERIOR_HALF_WIDTH + 0.8
@export var half_length := INTERIOR_HALF_LENGTH + 0.8
@export var wall_height := 3.1
@export var wall_thickness := 0.12

## Side door bay length (leaf blocker 2.53 m) plus 0.1 m margin each way.
const BAY_HALF_LENGTH := 2.53 * 0.5 + 0.1
## Cabin half width; the export half_width is this plus the 0.8 m margin.
const INTERIOR_HALF_WIDTH := 2.24
## Cabin half length; the export half_length is this plus the 0.8 m margin.
const INTERIOR_HALF_LENGTH := 4.68
## Below this local y the feet are on the road (deck 0.05, road -0.9).
const DECK_MIN_LOCAL_Y := -0.35

var _rear_exit_allowed := false
var _side_exit_allowed := false


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	_build()


func _build() -> void:
	var center_y := wall_height * 0.5
	_build_side_panels.call_deferred()
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


## Side panels are split around each door bay so the bay can open while halted.
## Deferred: the side doors set up their closed positions in their own _ready.
func _build_side_panels() -> void:
	var doors := get_tree().get_first_node_in_group(&"side_doors") as Node3D
	var left_z := NAN
	var right_z := NAN
	if doors != null and doors.get(&"_left_closed_pos") != null:
		left_z = to_local(doors.to_global(doors.get(&"_left_closed_pos") as Vector3)).z
		right_z = to_local(doors.to_global(doors.get(&"_right_closed_pos") as Vector3)).z
	_add_side(&"Left", -half_width, left_z)
	_add_side(&"Right", half_width, right_z)
	set_side_exit_allowed(_side_exit_allowed)


func _add_side(side: StringName, x: float, bay_z: float) -> void:
	var center_y := wall_height * 0.5
	if is_nan(bay_z):
		_add_panel(
			side,
			Vector3(x, center_y, 0.0),
			Vector3(wall_thickness, wall_height, half_length * 2.0)
		)
		return
	var z0 := clampf(bay_z - BAY_HALF_LENGTH, -half_length, half_length)
	var z1 := clampf(bay_z + BAY_HALF_LENGTH, -half_length, half_length)
	var spans := [
		[String(side) + "Front", -half_length, z0],
		[String(side) + "Door", z0, z1],
		[String(side) + "Rear", z1, half_length],
	]
	for span: Array in spans:
		var a := span[1] as float
		var b := span[2] as float
		_add_panel(
			StringName(span[0] as String),
			Vector3(x, center_y, (a + b) * 0.5),
			Vector3(wall_thickness, wall_height, b - a)
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


## True while the feet are on the van's deck inside the cabin walls: no margin, so standing
## outside against the hull or on the rear ramp is outside.
func is_inside_interior(world_pos: Vector3) -> bool:
	var local := to_local(world_pos)
	return local.y > DECK_MIN_LOCAL_Y \
			and absf(local.x) <= INTERIOR_HALF_WIDTH and absf(local.z) <= INTERIOR_HALF_LENGTH


func set_rear_exit_allowed(allowed: bool) -> void:
	if _rear_exit_allowed == allowed:
		return
	_rear_exit_allowed = allowed
	var rear := get_node_or_null("Rear") as CollisionShape3D
	if rear:
		rear.disabled = allowed


func is_side_exit_allowed() -> bool:
	return _side_exit_allowed


## Opens or closes the side door bays; the closed door leaves still block on their own.
func set_side_exit_allowed(allowed: bool) -> void:
	_side_exit_allowed = allowed
	for panel_name in [&"LeftDoor", &"RightDoor"]:
		var panel := get_node_or_null(NodePath(panel_name)) as CollisionShape3D
		if panel:
			panel.disabled = allowed


## The exit used while the van is halted mid-street: the rear and both side door
## bays are open. The closed door leaves still block (their Blocker bodies are on
## layer 1), so the player leaves only through a door they opened. Side stops keep
## calling set_rear_exit_allowed alone: rear-only, level floor. The player gets back in by jumping onto the deck (a mantle).
func set_halt_exit(allowed: bool) -> void:
	set_rear_exit_allowed(allowed)
	set_side_exit_allowed(allowed)
