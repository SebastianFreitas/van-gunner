class_name EnemyLootBonusEffect
extends ActCardEffect

## Adds to the item drop chance roll on enemy death (0.1 = +10%).

@export_range(-1.0, 1.0, 0.01) var chance_bonus := 0.0


func modify_item_drop_chance(chance: float, _ctx: ActCardEffectContext) -> float:
	return chance + chance_bonus
