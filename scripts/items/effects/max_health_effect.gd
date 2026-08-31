class_name MaxHealthEffect
extends ItemEffect

## Permanently increases the van's maximum hull health for the run.

@export var bonus_health := 10.0


func apply(_player: Node3D) -> void:
	GameSession.add_max_van_health(bonus_health)
