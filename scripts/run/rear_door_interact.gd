extends Interactable

## Layer-2-only hit target on a rear door leaf. Forwards to RearWall.


func get_interaction_prompt() -> String:
	var doors := _doors()
	if doors == null:
		return ""
	return doors.get_interaction_prompt()


func interact(actor: Node3D) -> void:
	var doors := _doors()
	if doors:
		doors.interact(actor)


func _doors() -> Node:
	return get_parent().get_parent()
