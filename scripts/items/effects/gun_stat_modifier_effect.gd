class_name GunStatModifierEffect
extends ItemEffect

## Permanently changes gun stats for the rest of the run via BoonTraits.
## GunStatsController reads these trait keys when building effective stats.

@export var modifier: StatModifier


func apply(player: Node3D) -> void:
	var traits := BoonTraits.find_on(player)
	if not traits:
		push_warning("GunStatModifierEffect: player has no BoonTraits node")
		return
	if not modifier:
		return
	var key := BoonTraitKeys.gun_stat_key(modifier.stat_name)
	if modifier.mode == StatModifier.Mode.MULTIPLY:
		traits.multiply_value(key, modifier.value)
	else:
		traits.add_value(key, modifier.value)
