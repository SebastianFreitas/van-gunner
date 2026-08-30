class_name LootDropComponent
extends Node

## Drop-in component that gives any enemy a chance to drop loot on death.
##
## Attach as a child node of an enemy and call `spawn_drops()` (e.g. from
## the enemy's death handler) with the position to drop at and a container
## to spawn into. Everything about *what* can drop lives in the assigned
## LootPool resource and the pickup scenes, so adding a new enemy type that
## drops loot never requires new code — just add this node and wire it up
## in the inspector.

## Weighted pool of items this component can drop. May be shared across
## many enemies, or swapped per-enemy for rarer loot tables later.
@export var loot_pool: LootPool
## Chance [0, 1] that an item drop is attempted at all when spawn_drops() runs.
@export_range(0.0, 1.0, 0.01) var item_drop_chance := 1.0
@export var item_pickup_scene: PackedScene

## Independent roll for a coin drop; items and coins can both land on the
## same kill.
@export_range(0.0, 1.0, 0.01) var coin_drop_chance := 0.0
@export var coin_pickup_scene: PackedScene
@export var coin_amount_min := 1
@export var coin_amount_max := 3

## Random horizontal offset so simultaneous drops don't perfectly overlap.
@export var scatter_radius := 0.35


func spawn_drops(world_position: Vector3, container: Node) -> void:
	if not is_instance_valid(container):
		return
	if loot_pool and item_pickup_scene and randf() <= item_drop_chance:
		var item := loot_pool.pick_item()
		if item:
			_spawn_item(item, world_position, container)
	if coin_pickup_scene and randf() <= coin_drop_chance:
		_spawn_coins(world_position, container)


func _spawn_item(item: ItemDefinition, world_position: Vector3, container: Node) -> void:
	var pickup := item_pickup_scene.instantiate() as ItemPickup
	if not pickup:
		return
	pickup.item = item
	container.add_child(pickup)
	pickup.global_position = world_position + _scatter_offset()


func _spawn_coins(world_position: Vector3, container: Node) -> void:
	var pickup := coin_pickup_scene.instantiate() as CoinPickup
	if not pickup:
		return
	pickup.amount = randi_range(coin_amount_min, coin_amount_max)
	container.add_child(pickup)
	pickup.global_position = world_position + _scatter_offset()


func _scatter_offset() -> Vector3:
	var angle := randf() * TAU
	var radius := randf() * scatter_radius
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
