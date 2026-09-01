extends Interactable

## Layer-2 hit target on a side window sash. Toggles that sash only.

@export_enum("left_rear", "left_front", "right_rear", "right_front") var window_id: String = "left_rear"


func get_interaction_prompt() -> String:
	var windows := _windows()
	if windows == null:
		return ""
	return windows.get_window_prompt(StringName(window_id))


func interact(_actor: Node3D) -> void:
	var windows := _windows()
	if windows:
		windows.toggle_window(StringName(window_id))


func _windows() -> Node:
	return get_tree().get_first_node_in_group(&"side_windows")
