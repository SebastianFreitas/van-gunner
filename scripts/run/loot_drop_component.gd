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

## Extra weapon drop chance when the owning enemy is elite.
@export var treat_as_elite := false

## Random horizontal offset so simultaneous drops don't perfectly overlap.
@export var scatter_radius := 0.55


func spawn_bonus_drop(world_position: Vector3, container: Node) -> void:
	if not loot_pool or not is_instance_valid(container):
		return
	var rolled_item := loot_pool.pick_item()
	if rolled_item:
		LootCollector.deliver_item(rolled_item, world_position, container, get_parent())


func spawn_drops(world_position: Vector3, container: Node) -> void:
	if not is_instance_valid(container):
		return
	var catches: Array[LootCatch] = []
	var drop_chance := ActCardCombat.modify_item_drop_chance(item_drop_chance)
	if loot_pool and randf() <= drop_chance:
		var rolled_item := loot_pool.pick_item()
		if rolled_item:
			catches.append(LootCatch.from_item(rolled_item))
	if coin_item and randf() <= coin_drop_chance:
		var coin := _rolled_coin_item()
		if coin:
			catches.append(LootCatch.from_item(coin))
	var weapon := _rolled_weapon()
	if weapon:
		catches.append(LootCatch.from_weapon(weapon))
	LootCollector.deliver_catches(catches, world_position, container, get_parent())


func _rolled_weapon() -> WeaponInstance:
	var chance := GameBalance.WEAPON_DROP_CHANCE_BASE
	var elite := treat_as_elite
	var host := get_parent()
	if host != null and "is_elite" in host:
		elite = bool(host.is_elite)
	if elite:
		chance += GameBalance.WEAPON_DROP_CHANCE_ELITE_BONUS
	## Roll 1..100 as in the design doc.
	if randi_range(1, 100) > chance:
		return null
	var level := maxi(GameSession.route_step, 1)
	return WeaponGenerator.create_weapon(level)


func _rolled_coin_item() -> ItemDefinition:
	if coin_item == null:
		return null
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
	return instanced_coin

