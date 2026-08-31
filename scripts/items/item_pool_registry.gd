class_name ItemPoolRegistry
extends RefCounted

## Loads loot pools by name. Pools are plain LootPool .tres files.

const _POOL_PATHS := {
	"goon": "res://resources/items/pools/goon_pool.tres",
	"general_boon": "res://resources/items/pools/general_boon_pool.tres",
	"fire_boon": "res://resources/items/pools/fire_boon_pool.tres",
	"poison_boon": "res://resources/items/pools/poison_boon_pool.tres",
	"cold_boon": "res://resources/items/pools/cold_boon_pool.tres",
	"physical_boon": "res://resources/items/pools/physical_boon_pool.tres",
	"rest_tools": "res://resources/items/pools/rest_tools_pool.tres",
}

const _ELEMENTAL_POOLS: Array[ItemDefinition.BoonPool] = [
	ItemDefinition.BoonPool.FIRE,
	ItemDefinition.BoonPool.POISON,
	ItemDefinition.BoonPool.COLD,
	ItemDefinition.BoonPool.PHYSICAL,
]

const _REST_PRIMARY_WEIGHT := 1.0
const _REST_CROSS_POOL_WEIGHT := 0.14
const _REST_GENERAL_WEIGHT := 0.18
const _REST_TOOLS_WEIGHT := 0.22
const _REST_START_TOOLS_WEIGHT := 0.35

const _BOON_POOL_KEYS := {
	ItemDefinition.BoonPool.GENERAL: "general_boon",
	ItemDefinition.BoonPool.FIRE: "fire_boon",
	ItemDefinition.BoonPool.POISON: "poison_boon",
	ItemDefinition.BoonPool.COLD: "cold_boon",
	ItemDefinition.BoonPool.PHYSICAL: "physical_boon",
}


static func get_pool(pool_key: String) -> LootPool:
	var path: String = _POOL_PATHS.get(pool_key, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("ItemPoolRegistry: missing pool '%s'" % pool_key)
		return null
	return load(path) as LootPool


static func pick_from(pool_key: String) -> ItemDefinition:
	var loot_pool := get_pool(pool_key)
	if not loot_pool:
		return null
	return loot_pool.pick_item() as ItemDefinition


static func pick_items_from(
	pool_key: String,
	count: int,
	exclude_ids: Array = []
) -> Array[ItemDefinition]:
	var loot_pool := get_pool(pool_key)
	if not loot_pool:
		return []
	return loot_pool.pick_items(count, exclude_ids)


static func get_boon_pool(pool: ItemDefinition.BoonPool) -> LootPool:
	var key: String = _BOON_POOL_KEYS.get(pool, "general_boon")
	return get_pool(key)


static func pick_from_boon_pool(pool: ItemDefinition.BoonPool) -> ItemDefinition:
	var key: String = _BOON_POOL_KEYS.get(pool, "general_boon")
	return pick_from(key)


## Binding-of-Isaac-style REST rewards: area-themed boons with cross-pool spice + tools.
static func pick_rest_choices(
	area: ItemDefinition.BoonPool,
	count: int,
	exclude_boon_ids: Array = []
) -> Array[ItemDefinition]:
	var weighted_pools: Array[Dictionary] = _rest_pool_weights(area)
	return _pick_unique_from_weighted_pools(weighted_pools, count, exclude_boon_ids)


static func _rest_pool_weights(area: ItemDefinition.BoonPool) -> Array[Dictionary]:
	var weighted: Array[Dictionary] = []
	if area == ItemDefinition.BoonPool.GENERAL:
		for pool in _ELEMENTAL_POOLS:
			weighted.append({"key": _BOON_POOL_KEYS[pool], "weight": _REST_PRIMARY_WEIGHT})
		weighted.append({"key": _BOON_POOL_KEYS[ItemDefinition.BoonPool.GENERAL], "weight": _REST_PRIMARY_WEIGHT})
		weighted.append({"key": "rest_tools", "weight": _REST_START_TOOLS_WEIGHT})
		return weighted
	weighted.append({"key": _BOON_POOL_KEYS[area], "weight": _REST_PRIMARY_WEIGHT})
	weighted.append({"key": _BOON_POOL_KEYS[ItemDefinition.BoonPool.GENERAL], "weight": _REST_GENERAL_WEIGHT})
	for pool in _ELEMENTAL_POOLS:
		if pool == area:
			continue
		weighted.append({"key": _BOON_POOL_KEYS[pool], "weight": _REST_CROSS_POOL_WEIGHT})
	weighted.append({"key": "rest_tools", "weight": _REST_TOOLS_WEIGHT})
	return weighted


static func _pick_unique_from_weighted_pools(
	weighted_pools: Array[Dictionary],
	count: int,
	exclude_boon_ids: Array
) -> Array[ItemDefinition]:
	var picked: Array[ItemDefinition] = []
	var excluded_boons := exclude_boon_ids.duplicate()
	var attempts := 0
	var max_attempts := maxi(count * 12, 12)
	while picked.size() < count and attempts < max_attempts:
		attempts += 1
		var pool_key: String = _pick_weighted_pool_key(weighted_pools)
		if pool_key.is_empty():
			break
		var loot_pool := get_pool(pool_key)
		if not loot_pool:
			continue
		var exclude: Array = excluded_boons if pool_key != "rest_tools" else []
		var item := loot_pool.pick_item(exclude)
		if not item:
			continue
		if item.kind == ItemDefinition.ItemKind.BOON:
			if item.id in excluded_boons:
				continue
			excluded_boons.append(item.id)
		elif _contains_item_id(picked, item.id):
			continue
		picked.append(item)
	return picked


static func _pick_weighted_pool_key(weighted_pools: Array[Dictionary]) -> String:
	var total := 0.0
	for entry in weighted_pools:
		total += float(entry.get("weight", 0.0))
	if total <= 0.0:
		return ""
	var roll := randf() * total
	var cumulative := 0.0
	for entry in weighted_pools:
		cumulative += float(entry.get("weight", 0.0))
		if roll <= cumulative:
			return String(entry.get("key", ""))
	return ""


static func _contains_item_id(items: Array[ItemDefinition], item_id: StringName) -> bool:
	for item in items:
		if item and item.id == item_id:
			return true
	return false
