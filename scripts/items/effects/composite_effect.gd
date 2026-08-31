class_name CompositeEffect
extends ItemEffect

## Runs multiple child effects when a boon is collected.

@export var child_effects: Array[ItemEffect] = []


func apply(player: Node3D) -> void:
	for effect in child_effects:
		if effect:
			effect.apply(player)
