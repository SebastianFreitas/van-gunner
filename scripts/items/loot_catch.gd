class_name LootCatch
extends RefCounted

## One hopper / popup entry wrapping a dropped ItemDefinition.

var item: ItemDefinition


static func from_item(dropped: ItemDefinition) -> LootCatch:
	var catch := LootCatch.new()
	catch.item = dropped
	return catch


func get_icon() -> Texture2D:
	if item and item.icon:
		return item.icon
	return null


func get_modulate() -> Color:
	return Color.WHITE


func coin_amount() -> int:
	if item == null:
		return 0
	var total := 0
	for effect in item.effects:
		if effect is GrantCoinEffect:
			total += (effect as GrantCoinEffect).amount
	return total
