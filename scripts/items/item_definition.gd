class_name ItemDefinition
extends Resource

## Data-only description of a single item.
##
## Every pickup is an item with one of four kinds:
## - MONEY: currency — effects run immediately.
## - CONSUMABLE: heals and other one-shot pickups — effects run immediately.
## - BOON: permanent run buff — effects run once and show in the boons HUD.
## - TOOL: hotbar item activated with keys 1–4.

enum ItemKind {
	MONEY = 0,
	BOON = 1,
	TOOL = 2,
	CONSUMABLE = 3,
}

enum BoonPool {
	GENERAL,
	FIRE,
	POISON,
	COLD,
	PHYSICAL,
}

@export var id: StringName = &""
@export var display_name := "Unknown Item"
@export_multiline var description := ""
@export var icon: Texture2D
@export var kind: ItemKind = ItemKind.MONEY
## Which boon reward pool this belongs to (only used when kind = BOON).
@export var boon_pool: BoonPool = BoonPool.GENERAL
## Charge, cooldown, and recharge rules for TOOL items.
@export var usable: ItemUsableConfig
## Overrides the pickup's default auto-grab radius when > 0.
@export var pickup_radius := 0.0
## Overrides the pickup's shot-only hit radius when > 0.
@export var shot_hit_radius := 0.0
## Gold cost when sold in a shop. 0 means not priced for sale.
@export var shop_price := 0
@export var effects: Array[ItemEffect] = []


func is_usable() -> bool:
	return kind == ItemKind.TOOL


func is_instant() -> bool:
	return kind == ItemKind.MONEY or kind == ItemKind.CONSUMABLE


func is_heal_consumable() -> bool:
	if kind != ItemKind.CONSUMABLE or effects.is_empty():
		return false
	for effect in effects:
		if not effect:
			return false
		if not (effect is HealEffect or effect is FullHealEffect):
			return false
	return true


func can_collect(player: Node3D) -> bool:
	if not player:
		return false
	match kind:
		ItemKind.MONEY:
			return true
		ItemKind.CONSUMABLE:
			if is_heal_consumable() and GameSession.is_van_at_full_health():
				return false
			return true
		ItemKind.BOON:
			var controller := player.get_node_or_null("Usables") as UsablesController
			return controller == null or not controller.has_boon(self)
		ItemKind.TOOL:
			return true
	return false


func apply_effects(player: Node3D) -> void:
	for effect in effects:
		if effect:
			effect.apply(player)


func collect(player: Node3D) -> void:
	if not player or not can_collect(player):
		return
	match kind:
		ItemKind.MONEY, ItemKind.CONSUMABLE:
			apply_effects(player)
		ItemKind.BOON:
			apply_effects(player)
			var controller := player.get_node_or_null("Usables") as UsablesController
			if controller:
				controller.register_boon(self)
		ItemKind.TOOL:
			var controller := player.get_node_or_null("Usables") as UsablesController
			if controller:
				controller.add_usable(self)
			else:
				apply_effects(player)
