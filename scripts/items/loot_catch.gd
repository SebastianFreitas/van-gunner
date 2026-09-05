class_name LootCatch
extends RefCounted

## One hopper / popup entry: either an ItemDefinition or a rolled weapon.

var item: ItemDefinition
var weapon: WeaponInstance


static func from_item(dropped: ItemDefinition) -> LootCatch:
	var catch := LootCatch.new()
	catch.item = dropped
	return catch


static func from_weapon(instance: WeaponInstance) -> LootCatch:
	var catch := LootCatch.new()
	catch.weapon = instance
	return catch


func get_icon() -> Texture2D:
	if item and item.icon:
		return item.icon
	if weapon:
		return WeaponPickup.placeholder_texture()
	return null


func get_modulate() -> Color:
	if weapon:
		return WeaponPickup._color_for_family(weapon)
	return Color.WHITE


func coin_amount() -> int:
	if item == null:
		return 0
	var total := 0
	for effect in item.effects:
		if effect is GrantCoinEffect:
			total += (effect as GrantCoinEffect).amount
	return total
