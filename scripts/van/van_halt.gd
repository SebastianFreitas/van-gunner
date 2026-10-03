extends RefCounted
## Halted-van exit: who counts as inside the van, and what the rear exit does while the van is fully stopped.

var _van: Node3D  # untyped owner; van.gd has no class_name (cycle rule), so fields are read dynamically


func _init(van: Node3D) -> void:
	_van = van
	_connect_travel.call_deferred()  # the van is still in _ready


func _connect_travel() -> void:
	var travel := _van.get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_signal(&"halted_changed"):
		travel.connect(&"halted_changed", _on_halted_changed)


## Margin-free test: standing outside against the hull is not inside.
func is_player_inside() -> bool:
	return _van.player_containment.is_inside_interior(_van.player.global_position)


func _on_halted_changed(halted: bool) -> void:
	_van.player_containment.set_halt_exit(halted)
	if halted:
		return  # the player opens the rear doors with E
	var doors := _van.get_tree().get_first_node_in_group(&"rear_doors")
	if doors and doors.has_method(&"close"):
		doors.close()
