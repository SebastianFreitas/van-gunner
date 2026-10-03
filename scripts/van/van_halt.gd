extends RefCounted
## Halted-van exit: who counts as inside the van, and what the rear exit does while the van is fully stopped.

## Below this VanRig-local y the player is standing on the road (deck 0.05, road about -0.85).
const _DECK_MIN_LOCAL_Y := -0.35

var _van: Node3D  # untyped owner; van.gd has no class_name (cycle rule), so fields are read dynamically


func _init(van: Node3D) -> void:
	_van = van
	_connect_travel.call_deferred()  # the van is still in _ready


func _connect_travel() -> void:
	var travel := _van.get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_signal(&"halted_changed"):
		travel.connect(&"halted_changed", _on_halted_changed)


## horizontal_clearance ignores height, so the y test keeps someone standing on the road under
## the rear sill from counting as inside.
func is_player_inside() -> bool:
	return _van.player.position.y > _DECK_MIN_LOCAL_Y \
			and _van.player_containment.horizontal_clearance(_van.player.global_position) <= 0.0


func _on_halted_changed(halted: bool) -> void:
	_van.player_containment.set_halt_exit(halted)
	if halted:
		return  # the player opens the rear doors with E
	var doors := _van.get_tree().get_first_node_in_group(&"rear_doors")
	if doors and doors.has_method(&"close"):
		doors.close()
