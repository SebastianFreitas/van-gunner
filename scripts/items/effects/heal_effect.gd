class_name HealEffect
extends ItemEffect

## Heals the player by a percentage of their maximum health.

@export_range(0.0, 1.0, 0.01) var heal_percent := 0.2


func apply(_player: Node3D) -> void:
	GameSession.heal_player(GameSession.get_max_player_health() * heal_percent)
