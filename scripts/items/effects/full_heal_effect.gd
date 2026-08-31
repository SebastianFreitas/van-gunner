class_name FullHealEffect
extends ItemEffect

## Heals the van to full hull health.


func apply(_player: Node3D) -> void:
	GameSession.heal_van(GameSession.get_max_van_health())
