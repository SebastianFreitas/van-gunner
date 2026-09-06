class_name RepairWindowBarsEffect
extends ItemEffect

## Look-at weld: restore `repair_amount` on a machine, door, or window.

const _REAR_DOOR_INTERACT := preload("res://scripts/run/rear_door_interact.gd")
const _SIDE_DOOR_INTERACT := preload("res://scripts/run/side_door_interact.gd")
const _SIDE_WINDOW_INTERACT := preload("res://scripts/run/side_window_interact.gd")

@export var repair_amount := 50.0


func apply(player: Node3D) -> void:
	try_apply(player)


func try_apply(player: Node3D) -> bool:
	if not player:
		return false
	var interact := _look_interactable(player)
	if interact == null:
		return false
	var vital := VanVital.find_on(interact)
	if vital:
		if vital.is_at_full_health():
			return false
		return vital.heal(repair_amount) > 0.001
	var point := _breach_for_interact(player, interact)
	if point == null:
		return false
	if point.is_at_full_health():
		return false
	return point.repair(repair_amount) > 0.001


func _look_interactable(player: Node3D) -> Interactable:
	if player.has_method("get_look_interactable"):
		return player.get_look_interactable() as Interactable
	return null


func _breach_for_interact(player: Node3D, interact: Node) -> BreachPoint:
	var script: Script = interact.get_script()
	if script == _REAR_DOOR_INTERACT:
		return _find_door_breach(player, BreachPoint.Kind.REAR_DOOR, StringName(str(interact.side)))
	if script == _SIDE_DOOR_INTERACT:
		return _find_door_breach(player, BreachPoint.Kind.SIDE_DOOR, StringName(str(interact.side)))
	if script == _SIDE_WINDOW_INTERACT:
		var wid := String(interact.window_id)
		return _find_breach_by_id(player, StringName("%s_window" % wid))
	return null


func _find_door_breach(player: Node3D, kind: BreachPoint.Kind, side: StringName) -> BreachPoint:
	for node: Node in player.get_tree().get_nodes_in_group(&"breach_points"):
		var point := node as BreachPoint
		if point == null:
			continue
		if point.kind == kind and point.door_side == side:
			return point
	return null


func _find_breach_by_id(player: Node3D, point_id: StringName) -> BreachPoint:
	for node: Node in player.get_tree().get_nodes_in_group(&"breach_points"):
		var point := node as BreachPoint
		if point != null and point.point_id == point_id:
			return point
	return null
