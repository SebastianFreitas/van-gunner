class_name Interactable
extends StaticBody3D
## Base class for world objects the player can interact with.

@export var prompt := "Interact"


## Left-hand gesture the first-person arms play on interact; empty plays none.
@export var gesture: StringName = &"press"


func get_interaction_prompt() -> String:
	return prompt


func get_gesture() -> StringName:
	return gesture


func interact(_actor: Node3D) -> void:
	pass
