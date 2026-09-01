class_name EnemySpawnPool
extends Resource

## A weighted collection of enemies to roll spawns from.
##
## Pools are plain data (Resources), so new pools are authored entirely in
## the inspector/as .tres files — no code changes needed to add an enemy,
## retune its weight, or spin up a brand-new pool for other acts later.

@export var entries: Array[EnemySpawnPoolEntry] = []


func total_weight() -> float:
	var total := 0.0
	for entry in entries:
		if entry and entry.enemy and entry.weight > 0.0:
			total += entry.weight
	return total


## Picks a single enemy using weighted random selection.
## Returns null if the pool is empty or every weight is zero.
func pick_enemy(exclude_ids: Array = []) -> EnemyDefinition:
	return _pick_one(exclude_ids)


func _pick_one(exclude_ids: Array) -> EnemyDefinition:
	var total := 0.0
	for entry in entries:
		if not entry or not entry.enemy or entry.weight <= 0.0:
			continue
		if entry.enemy.id in exclude_ids:
			continue
		total += entry.weight
	if total <= 0.0:
		return null
	var roll := randf() * total
	var cumulative := 0.0
	for entry in entries:
		if not entry or not entry.enemy or entry.weight <= 0.0:
			continue
		if entry.enemy.id in exclude_ids:
			continue
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.enemy
	return null
