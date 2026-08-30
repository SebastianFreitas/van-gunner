class_name HealEffect
extends ItemEffect

## Heals the van by a percentage of its maximum health.

@export_range(0.0, 1.0, 0.01) var heal_percent := 0.2


func apply(_player: Node3D) -> void:
	GameSession.heal_van(GameSession.MAX_VAN_HEALTH * heal_percent)
