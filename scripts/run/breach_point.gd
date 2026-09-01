class_name BreachPoint
extends Node3D

## Outside attack slot that must be breached (or opened) before mobs can enter.

signal breached
signal health_changed(current: float, maximum: float)

enum Kind { REAR_DOOR, SIDE_DOOR, WINDOW, SIDE_DOOR_WINDOW }

@export var point_id: StringName = &""
@export var kind: Kind = Kind.WINDOW
## Overwritten in _ready from GameBalance (door / window HP).
@export var max_health := 40.0
@export var max_occupants := 1
## Lower = preferred. Rear doors should stay ahead of windows.
@export var priority := 1
@export var door_side: StringName = &""
## Window / side-door-window: IronCross to hide when bars are breached.
@export var bars_path: NodePath = NodePath()

@onready var outside_marker: Marker3D = $Outside
@onready var entry_marker: Marker3D = $Entry

var health := 0.0
var is_breached := false
var _occupants: Array[Node] = []


func _ready() -> void:
	if _is_door_kind():
		max_health = GameBalance.REAR_DOOR_BREACH_HP
	else:
		max_health = GameBalance.WINDOW_BREACH_HP
	health = max_health
	if point_id == &"":
		point_id = StringName(name)
	add_to_group(&"breach_points")


func get_outside_position() -> Vector3:
	return outside_marker.global_position


func get_outside_basis() -> Basis:
	return outside_marker.global_basis


func get_entry_position() -> Vector3:
	return entry_marker.global_position


func is_passable() -> bool:
	if is_breached:
		return true
	match kind:
		Kind.REAR_DOOR:
			if door_side != &"":
				var doors := _rear_doors()
				if doors and doors.is_door_open(door_side):
					return true
		Kind.SIDE_DOOR:
			if door_side != &"":
				var doors := _side_doors()
				if doors and doors.is_door_passable(door_side):
					return true
		Kind.SIDE_DOOR_WINDOW:
			# Whole cargo opening clear — no need to smash bars.
			if door_side != &"":
				var doors := _side_doors()
				if doors and doors.is_door_passable(door_side):
					return true
		_:
			pass
	return false


func has_vacancy() -> bool:
	_prune_occupants()
	return _occupants.size() < max_occupants


func occupant_count() -> int:
	_prune_occupants()
	return _occupants.size()


func claim(raider: Node) -> bool:
	_prune_occupants()
	if raider in _occupants:
		return true
	if _occupants.size() >= max_occupants:
		return false
	_occupants.append(raider)
	return true


func release(raider: Node) -> void:
	_occupants.erase(raider)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or is_passable():
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	CombatFeedback.show_damage(
		get_outside_position() + Vector3(0, 0.6, 0),
		amount,
		false,
		DamageType.Type.NORMAL
	)
	if is_zero_approx(health):
		_mark_breached()


func _mark_breached() -> void:
	if is_breached:
		return
	is_breached = true
	health = 0.0
	health_changed.emit(health, max_health)
	match kind:
		Kind.REAR_DOOR:
			if door_side != &"":
				var doors := _rear_doors()
				if doors:
					doors.open_door(door_side)
		Kind.SIDE_DOOR:
			if door_side != &"":
				var doors := _side_doors()
				if doors:
					doors.open_door(door_side)
		Kind.WINDOW, Kind.SIDE_DOOR_WINDOW:
			_break_bars()
		_:
			pass
	breached.emit()


func _break_bars() -> void:
	if bars_path.is_empty():
		return
	var bars := get_node_or_null(bars_path)
	if bars == null:
		return
	if bars.has_method("break_bars"):
		bars.break_bars()
	elif bars is Node3D:
		(bars as Node3D).visible = false


func _is_door_kind() -> bool:
	return kind == Kind.REAR_DOOR or kind == Kind.SIDE_DOOR


func _prune_occupants() -> void:
	for i in range(_occupants.size() - 1, -1, -1):
		if not is_instance_valid(_occupants[i]):
			_occupants.remove_at(i)


func _rear_doors() -> Node:
	return get_tree().get_first_node_in_group(&"rear_doors")


func _side_doors() -> Node:
	return get_tree().get_first_node_in_group(&"side_doors")
