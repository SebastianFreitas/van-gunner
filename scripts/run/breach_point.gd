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
## Window / side-door-window: IronCross swapped to BrokenIronCross when breached.
@export var bars_path: NodePath = NodePath()

@onready var outside_marker: Marker3D = $Outside
@onready var entry_marker: Marker3D = $Entry

var health := 0.0
var is_breached := false
var _occupants: Array[Node] = []
var _glass_cleared := false


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
		Kind.WINDOW:
			# Rear door panes: leaf already open → climb through, skip bars.
			if door_side != &"":
				var doors := _rear_doors()
				if doors and doors.is_door_open(door_side):
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
	# First smash on a barred window always pops the pane if it is still intact.
	_shatter_window_glass_if_needed()
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


## Instantly restore window-bar HP. If breached, swap BrokenIronCross back to intact bars.
## Does not restore shattered glass or close door leaves.
func repair_bars() -> void:
	if kind != Kind.WINDOW and kind != Kind.SIDE_DOOR_WINDOW:
		return
	var was_breached := is_breached
	health = max_health
	is_breached = false
	health_changed.emit(health, max_health)
	if was_breached:
		_repair_bars_visual()


func _repair_bars_visual() -> void:
	if bars_path.is_empty():
		return
	var bars := get_node_or_null(bars_path)
	if bars == null:
		return
	if bars.has_method("repair_bars"):
		bars.repair_bars()
	elif bars is Node3D:
		(bars as Node3D).visible = true


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
					if doors.has_method("mark_door_broken"):
						doors.mark_door_broken(door_side)
		Kind.SIDE_DOOR:
			if door_side != &"":
				var doors := _side_doors()
				if doors:
					doors.open_door(door_side)
					if doors.has_method("mark_door_broken"):
						doors.mark_door_broken(door_side)
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


func _shatter_window_glass_if_needed() -> void:
	if _glass_cleared:
		return
	if kind != Kind.WINDOW and kind != Kind.SIDE_DOOR_WINDOW:
		return
	_glass_cleared = true
	if bars_path.is_empty():
		return
	var bars := get_node_or_null(bars_path)
	if bars == null:
		return
	var host := bars.get_parent()
	if host == null:
		return
	var glass := host.get_node_or_null("BreakableGlass")
	if glass == null:
		return
	if glass.has_method("is_intact") and not glass.is_intact():
		return
	if glass.has_method("take_damage"):
		var dmg := 1.0
		if "max_health" in glass:
			dmg = maxf(float(glass.max_health), 1.0)
		glass.take_damage(dmg)


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
