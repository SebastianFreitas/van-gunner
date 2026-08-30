class_name LootPoolEntry
extends Resource

## A single weighted slot inside a LootPool.

@export var item: ItemDefinition
@export_range(0.0, 1000.0, 0.1) var weight := 1.0
