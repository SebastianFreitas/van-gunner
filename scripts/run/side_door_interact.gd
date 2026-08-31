extends Interactable

## Layer-2-only hit target on a side door leaf. Toggles that leaf only.

@export_enum("left", "right") var side: String = "left"


func get_interaction_prompt() -> String:
	var doors := _doors()
	if doors == null:
		return ""
	return doors.get_door_prompt(StringName(side))


func interact(_actor: Node3D) -> void:
	var doors := _doors()
	if doors:
		doors.toggle_door(StringName(side))


func _doors() -> Node:
	return get_parent().get_parent()
