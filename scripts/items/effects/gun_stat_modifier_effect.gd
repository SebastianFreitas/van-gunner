class_name GunStatModifierEffect
extends ItemEffect

## Permanently changes gun stats for the rest of the run (Binding of Isaac style).

@export var modifier: StatModifier


func apply(player: Node3D) -> void:
	var controller := player.get_node_or_null("GunStats") as GunStatsController
	if not controller:
		push_warning("GunStatModifierEffect: player has no GunStatsController")
		return
	if modifier:
		controller.add_modifier(modifier)
