class_name ItemPoolRegistry
extends RefCounted

## Loads loot pools by name. Pools are plain LootPool .tres files.

const _POOL_PATHS := {
	"goon": "res://resources/items/pools/goon_pool.tres",
	## Alias of general_boon — mechanic / van-identity rolls use this key.
	"van": "res://resources/items/pools/general_boon_pool.tres",
	"general_boon": "res://resources/items/pools/general_boon_pool.tres",
	"rest_tools": "res://resources/items/pools/rest_tools_pool.tres",
	"shop": "res://resources/items/pools/shop_pool.tres",
}

## REST offers draw boons from the one boon pool, with tools as occasional spice.
const _REST_BOON_WEIGHT := 1.0
const _REST_TOOLS_WEIGHT := 0.35


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


## REST rewards: boons the player does not own yet, plus the occasional tool.
static func pick_rest_choices(count: int, exclude_boon_ids: Array = []) -> Array[ItemDefinition]:
	var weighted_pools: Array[Dictionary] = [
		{"key": "general_boon", "weight": _REST_BOON_WEIGHT},
		{"key": "rest_tools", "weight": _REST_TOOLS_WEIGHT},
	]
	return _pick_unique_from_weighted_pools(weighted_pools, count, exclude_boon_ids)


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
