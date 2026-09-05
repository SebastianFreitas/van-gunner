class_name FullHealEffect
extends ItemEffect

## Heals the player to full health.


func apply(_player: Node3D) -> void:
	GameSession.heal_player(GameSession.get_max_player_health())
