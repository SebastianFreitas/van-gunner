class_name LootPool
extends Resource

## A weighted collection of items to roll drops from.
##
## Pools are plain data (Resources), so new pools are authored entirely in
## the inspector/as .tres files — no code changes needed to add an item to
## a pool, retune its weight, or spin up a brand-new pool (e.g. "goon_pool",
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
func pick_item(exclude_ids: Array = []) -> ItemDefinition:
	return _pick_one(exclude_ids)


## Picks up to [param count] unique items, skipping ids in [param exclude_ids].
func pick_items(count: int, exclude_ids: Array = []) -> Array[ItemDefinition]:
	var picked: Array[ItemDefinition] = []
	var excluded := exclude_ids.duplicate()
	for _attempt in range(count):
		var item := _pick_one(excluded)
		if not item:
			break
		picked.append(item)
		excluded.append(item.id)
	return picked


func _pick_one(exclude_ids: Array) -> ItemDefinition:
	var total := 0.0
	for entry in entries:
		if not entry or not entry.item or entry.weight <= 0.0:
			continue
		if entry.item.id in exclude_ids:
			continue
		total += entry.weight
	if total <= 0.0:
		return null
	var roll := randf() * total
	var cumulative := 0.0
	for entry in entries:
		if not entry or not entry.item or entry.weight <= 0.0:
			continue
		if entry.item.id in exclude_ids:
			continue
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.item
	return null
