class_name Interactable
extends StaticBody3D

@export var prompt := "Interact"


func get_interaction_prompt() -> String:
	return prompt


func interact(_actor: Node3D) -> void:
	pass
