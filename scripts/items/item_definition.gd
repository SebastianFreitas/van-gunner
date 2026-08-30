class_name ItemDefinition
extends Resource

## Data-only description of a single item/boon/tool/ability.
##
## `kind` decides what happens when the player walks over a pickup:
## - INSTANT: heal, coins, etc. — effects run immediately.
## - BOON: permanent run buff — effects run once and show in the boons HUD.
## - TOOL / ABILITY: go to the hotbar and activate with `use_usable`.

enum ItemKind {
	INSTANT,
	BOON,
	TOOL,
	ABILITY,
}

@export var id: StringName = &""
@export var display_name := "Unknown Item"
@export_multiline var description := ""
@export var icon: Texture2D
@export var kind: ItemKind = ItemKind.INSTANT
## Charge, cooldown, and recharge rules for TOOL and ABILITY items.
@export var usable: ItemUsableConfig
## Overrides the pickup's default auto-grab radius when > 0.
@export var pickup_radius := 0.0
@export var effects: Array[ItemEffect] = []


func is_usable() -> bool:
	return kind == ItemKind.TOOL or kind == ItemKind.ABILITY


func apply_effects(player: Node3D) -> void:
	for effect in effects:
		if effect:
			effect.apply(player)


func collect(player: Node3D) -> void:
	if not player:
		return
	match kind:
		ItemKind.INSTANT:
			apply_effects(player)
		ItemKind.BOON:
			var controller := player.get_node_or_null("Usables") as UsablesController
			if controller and controller.has_boon(self):
				return
			apply_effects(player)
			if controller:
				controller.register_boon(self)
		ItemKind.TOOL, ItemKind.ABILITY:
			var controller := player.get_node_or_null("Usables") as UsablesController
			if controller:
				controller.add_usable(self)
			else:
				apply_effects(player)
