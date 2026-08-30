class_name UsableState
extends RefCounted

var definition: ItemDefinition
var charges: int = 0
var cooldown_remaining: float = 0.0


func _init(item: ItemDefinition) -> void:
	definition = item
	var config := item.usable
	if config:
		charges = config.max_charges
	else:
		charges = 1


func is_ready() -> bool:
	if charges <= 0:
		return false
	return cooldown_remaining <= 0.0


func get_config() -> ItemUsableConfig:
	return definition.usable if definition else null
