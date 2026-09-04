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
@export var pickup_scene: PackedScene

## Independent roll for a coin drop; items and coins can both land on the
## same kill.
@export_range(0.0, 1.0, 0.01) var coin_drop_chance := 0.0
@export var coin_item: ItemDefinition
@export var coin_amount_min := 1
@export var coin_amount_max := 3

## Extra weapon drop chance when the owning enemy is elite (or flagged).
@export var treat_as_elite := false

## Random horizontal offset so simultaneous drops don't perfectly overlap.
@export var scatter_radius := 0.55

const _WEAPON_PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")


func spawn_bonus_drop(world_position: Vector3, container: Node) -> void:
	if not loot_pool or not pickup_scene or not is_instance_valid(container):
		return
	var rolled_item := loot_pool.pick_item()
	if rolled_item:
		_spawn_item(rolled_item, world_position, container)


func spawn_drops(world_position: Vector3, container: Node) -> void:
	if not is_instance_valid(container):
		return
	var item_spawned := false
	if loot_pool and pickup_scene and randf() <= item_drop_chance:
		var rolled_item := loot_pool.pick_item()
		if rolled_item:
			_spawn_item(rolled_item, world_position, container)
			item_spawned = true
	if coin_item and pickup_scene and randf() <= coin_drop_chance:
		_spawn_coins(world_position, container, item_spawned)
	_try_weapon_drop(world_position, container)


func _try_weapon_drop(world_position: Vector3, container: Node) -> void:
	var chance := GameBalance.WEAPON_DROP_CHANCE_BASE
	var elite := treat_as_elite
	var owner := get_parent()
	if owner != null and "is_elite" in owner:
		elite = bool(owner.is_elite)
	elif owner != null and "is_agile" in owner and bool(owner.is_agile):
		elite = true
	if elite:
		chance += GameBalance.WEAPON_DROP_CHANCE_ELITE_BONUS
	## Roll 1..100 as in the design doc.
	if randi_range(1, 100) > chance:
		return
	var level := maxi(GameSession.route_step, 1)
	var inst := WeaponGenerator.create_weapon(level)
	var pickup = _WEAPON_PICKUP_SCENE.instantiate()
	if pickup == null:
		return
	if pickup.has_method("setup"):
		pickup.call("setup", inst)
	container.add_child(pickup)
	pickup.global_position = world_position + _scatter_offset() + Vector3(0.0, 0.15, 0.0)


func _spawn_item(item: ItemDefinition, world_position: Vector3, container: Node) -> void:
	var pickup := pickup_scene.instantiate() as Pickup
	if not pickup:
		return
	pickup.item = item
	container.add_child(pickup)
	pickup.global_position = world_position + _scatter_offset()


func _spawn_coins(world_position: Vector3, container: Node, offset_from_item: bool) -> void:
	var pickup := pickup_scene.instantiate() as Pickup
	if not pickup:
		return
	var instanced_coin := coin_item.duplicate() as ItemDefinition
	var new_effects: Array[ItemEffect] = []
	for effect in instanced_coin.effects:
		if effect is GrantCoinEffect:
			var duplicated_effect = effect.duplicate() as GrantCoinEffect
			duplicated_effect.amount = randi_range(coin_amount_min, coin_amount_max)
			new_effects.append(duplicated_effect)
		else:
			new_effects.append(effect)
	instanced_coin.effects = new_effects
	pickup.item = instanced_coin
	container.add_child(pickup)
	var extra := Vector3(0.45, 0.0, 0.0) if offset_from_item else Vector3.ZERO
	pickup.global_position = world_position + _scatter_offset() + extra


func _scatter_offset() -> Vector3:
	var angle := randf() * TAU
	var radius := randf() * scatter_radius
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
