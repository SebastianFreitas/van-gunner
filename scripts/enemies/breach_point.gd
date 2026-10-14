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
## VanOpenings opening this point sits on; _ready derives the Outside and Entry markers from it
## (see breach_point_markers.gd for the ids).
@export var opening_id: StringName = &""

## Rear leaf vs its pane sit ~0.15m apart. XZ under this = the same hole.
const _SAME_OPENING_XZ := 0.75

const _BreachPointMarkers := preload("res://scripts/enemies/breach_point_markers.gd")
const _BreachPointBars := preload("res://scripts/enemies/breach_point_bars.gd")

@onready var outside_marker: Marker3D = $Outside
@onready var entry_marker: Marker3D = $Entry

var health := 0.0
var is_breached := false
var _occupants: Array[Node] = []
var _bars := _BreachPointBars.new(self)


func _ready() -> void:
	var placed := _BreachPointMarkers.transforms(opening_id)
	if placed.size() == 2:
		outside_marker.transform = placed[0]
		entry_marker.transform = placed[1]
	if _is_door_kind():
		max_health = GameBalance.REAR_DOOR_BREACH_HP
	else:
		max_health = GameBalance.WINDOW_BREACH_HP
	health = max_health
	if point_id == &"":
		point_id = StringName(name)
	add_to_group(&"breach_points")


## The window's IronCross (see breach_point_bars.gd); null, with an error naming the id, when
## none or two match.
func find_bars() -> Node:
	return _bars.find_bars()


func get_outside_position() -> Vector3:
	return outside_marker.global_position


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
			else:
				# Side windows: open sash swings bars out of the opening.
				var windows := _side_windows()
				var wid := _side_window_id()
				if windows and wid != &"" and windows.is_window_open(wid):
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
	return _cluster_occupant_count() < max_occupants


func claim(raider: Node) -> bool:
	_prune_occupants()
	if raider in _occupants:
		return true
	if _cluster_occupant_count() >= max_occupants:
		return false
	_occupants.append(raider)
	return true


func release(raider: Node) -> void:
	_occupants.erase(raider)


func take_damage(amount) -> void:
	if is_passable():
		return
	var dmg := 0.0
	if amount is DamageInfo:
		dmg = (amount as DamageInfo).get_final_amount()
	else:
		dmg = float(amount)
	if dmg <= 0.0:
		return
	# First smash on a barred window always pops the pane if it is still intact.
	_bars.shatter_glass_if_needed()
	health = maxf(0.0, health - dmg)
	health_changed.emit(health, max_health)
	_bars.update_stage()
	CombatFeedback.show_damage(get_outside_position() + Vector3(0, 0.6, 0), dmg, false)
	if is_zero_approx(health):
		_mark_breached()


## Restore HP on this opening. Un-breaches and un-breaks a door if HP returns.
## Does not close leaves or restore shattered glass.
func repair(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before := health
	var was_breached := is_breached
	health = minf(max_health, health + amount)
	var gained := health - before
	if gained <= 0.001 and not was_breached:
		return 0.0
	if health > 0.001:
		is_breached = false
		if was_breached:
			_restore_after_repair()
	health_changed.emit(health, max_health)
	_bars.update_stage()
	return gained


func is_at_full_health() -> bool:
	return not is_breached and health >= max_health - 0.001


## Instantly restore window-bar HP. If breached, swap BrokenIronCross back to intact bars.
## Does not restore shattered glass or close door leaves.
func repair_bars() -> void:
	if kind != Kind.WINDOW and kind != Kind.SIDE_DOOR_WINDOW:
		return
	repair(max_health)


func _restore_after_repair() -> void:
	match kind:
		Kind.REAR_DOOR:
			if door_side != &"":
				var doors := _rear_doors()
				if doors and doors.has_method("clear_door_broken"):
					doors.clear_door_broken(door_side)
		Kind.SIDE_DOOR:
			if door_side != &"":
				var doors := _side_doors()
				if doors and doors.has_method("clear_door_broken"):
					doors.clear_door_broken(door_side)
		Kind.WINDOW, Kind.SIDE_DOOR_WINDOW:
			_bars.repair_visual()
		_:
			pass


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
				if doors and doors.has_method("mark_door_broken"):
					doors.mark_door_broken(door_side)
				elif doors and doors.has_method("open_door"):
					doors.open_door(door_side)
				# Open front sash sits in the slide path — smash glass + bars with the door.
				_breach_adjacent_open_window()
		Kind.WINDOW, Kind.SIDE_DOOR_WINDOW:
			# Bars only — sash stays put (player can tip it open separately).
			_bars.break_bars()
		_:
			pass
	breached.emit()


## Complete this window breach immediately (glass + bars). Used when a cargo door
## slides into an already-open adjacent sash.
func force_breach() -> void:
	if kind != Kind.WINDOW and kind != Kind.SIDE_DOOR_WINDOW:
		return
	if is_breached:
		_bars.shatter_glass_if_needed()
		return
	_bars.shatter_glass_if_needed()
	_mark_breached()


func _breach_adjacent_open_window() -> void:
	if door_side == &"":
		return
	var wid: StringName = &"left_front" if door_side == &"left" else &"right_front"
	var windows := _side_windows()
	if windows == null or not windows.is_window_open(wid):
		return
	var target_id := StringName("%s_window" % String(wid))
	for node in get_tree().get_nodes_in_group(&"breach_points"):
		if node is BreachPoint and (node as BreachPoint).point_id == target_id:
			(node as BreachPoint).force_breach()
			return


func _is_door_kind() -> bool:
	return kind == Kind.REAR_DOOR or kind == Kind.SIDE_DOOR


func is_door_kind() -> bool:
	return _is_door_kind()


func _prune_occupants() -> void:
	for i in range(_occupants.size() - 1, -1, -1):
		if not is_instance_valid(_occupants[i]):
			_occupants.remove_at(i)


## Door leaf + its own window are separate BreachPoints (door goon vs climber
## pools) but they share one stand slot. CabinNav never occupies outside holes,
## so without this a mixed pack stacks on the same marker.
func _cluster_occupant_count() -> int:
	var seen := {}
	var n := 0
	for point in _opening_cluster():
		point._prune_occupants()
		for occ in point._occupants:
			if seen.has(occ):
				continue
			seen[occ] = true
			n += 1
	return n


func _opening_cluster() -> Array[BreachPoint]:
	var cluster: Array[BreachPoint] = [self]
	if get_tree() == null:
		return cluster
	for node in get_tree().get_nodes_in_group(&"breach_points"):
		if node == self or not (node is BreachPoint):
			continue
		var other := node as BreachPoint
		if _shares_opening(other):
			cluster.append(other)
	return cluster


func _shares_opening(other: BreachPoint) -> bool:
	if other == null:
		return false
	if door_side != &"" and door_side == other.door_side:
		var rear_pair := (
			(kind == Kind.REAR_DOOR and other.kind == Kind.WINDOW)
			or (kind == Kind.WINDOW and other.kind == Kind.REAR_DOOR)
		)
		var side_pair := (
			(kind == Kind.SIDE_DOOR and other.kind == Kind.SIDE_DOOR_WINDOW)
			or (kind == Kind.SIDE_DOOR_WINDOW and other.kind == Kind.SIDE_DOOR)
		)
		if rear_pair or side_pair:
			return true
	if outside_marker == null or other.outside_marker == null:
		return false
	var a := outside_marker.global_position
	var b := other.outside_marker.global_position
	return Vector2(a.x - b.x, a.z - b.z).length() < _SAME_OPENING_XZ


func _rear_doors() -> Node:
	return get_tree().get_first_node_in_group(&"rear_doors")


func _side_doors() -> Node:
	var doors := get_tree().get_first_node_in_group(&"side_doors")
	if doors == null:
		push_error("BreachPoint: no node in group 'side_doors'")
	return doors


func _side_windows() -> Node:
	return get_tree().get_first_node_in_group(&"side_windows")


## Maps breach point_id (e.g. left_rear_window) → side_windows id (left_rear).
func _side_window_id() -> StringName:
	var raw := String(point_id)
	if raw.begins_with("side_door") or not raw.ends_with("_window"):
		return &""
	return StringName(raw.trim_suffix("_window"))
