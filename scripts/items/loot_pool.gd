class_name LootPool
extends Resource

## A weighted collection of items to roll drops from.
##
## Pools are plain data (Resources), so new pools are authored entirely in
## the inspector/as .tres files — no code changes needed to add an item to
## a pool, retune its weight, or spin up a brand-new pool (e.g. "rare_pool",
## "boss_pool") for other enemies to pull from later.

@export var entries: Array[LootPoolEntry] = []


func total_weight() -> float:
	var total := 0.0
	for entry in entries:
		if entry and entry.item and entry.weight > 0.0:
			total += entry.weight
	return total


## Picks a single item using weighted random selection.
## Returns null if the pool is empty or every weight is zero.
func pick_item() -> ItemDefinition:
	var total := total_weight()
	if total <= 0.0:
		return null
	var roll := randf() * total
	var cumulative := 0.0
	for entry in entries:
		if not entry or not entry.item or entry.weight <= 0.0:
			continue
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.item
	return null
