class_name BoonCombat
extends RefCounted

## Applies boon trait modifiers to damage and status application.

const _PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")
const _HEAL_POTION := preload("res://resources/items/heal_potion.tres")
const _PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")
const _COLD_BURST_COUNT := 5
const _COLD_BURST_DAMAGE := 8.0
const RICOCHET_COLD_COUNT := 2


static func get_player_traits(tree: SceneTree) -> BoonTraits:
	if not tree:
		return null
	var player := tree.get_first_node_in_group(&"player")
	return BoonTraits.find_on(player)


static func modify_outgoing_damage(info: DamageInfo, traits: BoonTraits, target: Node) -> float:
	if not info or not traits:
		return 0.0
	var status := _get_status(target)
	var bonus_phys := 0.0
	if info.damage_type == DamageType.Type.FIRE:
		info.amount += traits.get_add(BoonTraitKeys.FIRE_DAMAGE_BONUS)
		info.amount *= traits.get_mult(BoonTraitKeys.FIRE_DAMAGE_MULT)
		if status and status.is_poisoned():
			var poison_bonus := traits.get_add(BoonTraitKeys.EXTRA_POISON_TO_FIRE)
			if poison_bonus > 0.0:
				info.amount += status.get_poison_dps() * poison_bonus
		var ratio := clampf(traits.get_add(BoonTraitKeys.FIRE_TO_PHYS_RATIO), 0.0, 1.0)
		if ratio > 0.0:
			var converted := info.amount * ratio
			info.amount -= converted
			if converted > 0.0:
				if is_zero_approx(info.amount):
					info.amount = converted
					info.damage_type = DamageType.Type.NORMAL
				else:
					bonus_phys = converted
	if info.damage_type == DamageType.Type.NORMAL:
		info.amount += traits.get_add(BoonTraitKeys.PHYS_DAMAGE_BONUS)
		if status and status.is_frozen() and traits.has_flag(BoonTraitKeys.DOUBLE_PHYS_COLD):
			info.amount *= 2.0
		if info.is_headshot and traits.has_flag(BoonTraitKeys.TRIPLE_CRIT_PHYS):
			info.amount *= 1.5
	if info.damage_type == DamageType.Type.POISON and status:
		if status.is_frozen() or status.is_chilled():
			info.amount *= 1.0 + traits.get_add(BoonTraitKeys.POISONED_COLD_BONUS)
	if info.damage_type == DamageType.Type.COLD and status:
		if status.is_frozen() or status.is_chilled():
			info.amount *= traits.get_mult(BoonTraitKeys.FROZEN_DAMAGE_MULT)
	return bonus_phys


static func apply_bonus_physical_hit(
	amount: float,
	base_info: DamageInfo,
	target: Node,
	traits: BoonTraits
) -> void:
	if amount <= 0.0 or not base_info:
		return
	var phys := DamageInfo.create(amount, DamageType.Type.NORMAL, base_info.source)
	phys.hit_position = base_info.hit_position
	phys.is_headshot = base_info.is_headshot
	if traits:
		modify_outgoing_damage(phys, traits, target)
	DamageResolver.apply_hit(phys, target)


static func modify_explosion_radius(base_radius: float, info: DamageInfo, traits: BoonTraits) -> float:
	if not traits or info.damage_type != DamageType.Type.FIRE:
		return base_radius
	return base_radius * traits.get_mult(BoonTraitKeys.FIRE_AREA_MULT)


static func apply_post_hit(info: DamageInfo, target: Node, traits: BoonTraits) -> void:
	if not traits:
		return
	var status := _get_status(target)
	if not status:
		return
	if info.damage_type == DamageType.Type.COLD:
		var freeze_chance := traits.get_add(BoonTraitKeys.FREEZE_CHANCE)
		status.try_apply_freeze(freeze_chance, traits.get_add(BoonTraitKeys.FREEZE_DURATION_BONUS))
	if info.is_headshot and traits.has_flag(BoonTraitKeys.PHYS_TO_COLD_ON_CRIT) and info.damage_type == DamageType.Type.NORMAL:
		status.apply_cold(0.55, 3.0)
		status.try_apply_freeze(traits.get_add(BoonTraitKeys.FREEZE_CHANCE) * 2.0, traits.get_add(BoonTraitKeys.FREEZE_DURATION_BONUS))


static func configure_enemy_status_effects(enemy: Node, tree: SceneTree) -> void:
	var status := _get_status(enemy)
	var traits := get_player_traits(tree)
	if status and traits:
		status.configure_from_traits(traits)


static func apply_on_enemy_death(enemy: Node, last_damage_type: DamageType.Type) -> void:
	if not enemy or not enemy.is_inside_tree():
		return
	var tree := enemy.get_tree()
	var traits := get_player_traits(tree)
	if not traits:
		return
	var status := _get_status(enemy)
	var pos := enemy.global_position if enemy is Node3D else Vector3.ZERO
	var container := enemy.get_parent()
	if traits.has_flag(BoonTraitKeys.COLD_SHATTER) and last_damage_type == DamageType.Type.COLD:
		spawn_radial_cold_projectiles(tree, pos, _COLD_BURST_COUNT, _COLD_BURST_DAMAGE)
	if status and status.is_poisoned():
		var heal_chance := traits.get_add(BoonTraitKeys.VAMPIRIC_POISON_CHANCE)
		if heal_chance > 0.0 and randf() <= heal_chance:
			_spawn_heal_pickup(pos, container)
	if status and (status.is_frozen() or status.is_chilled()):
		var extra_drops := int(traits.get_add(BoonTraitKeys.FROZEN_LOOT_BONUS))
		if extra_drops > 0:
			var loot_drop := enemy.get_node_or_null("LootDrop") as LootDropComponent
			if loot_drop:
				for _i in extra_drops:
					loot_drop.spawn_bonus_drop(pos, container)


static func spawn_radial_cold_projectiles(
	tree: SceneTree,
	origin: Vector3,
	count: int,
	damage: float
) -> void:
	if not tree or count <= 0:
		return
	var player := tree.get_first_node_in_group(&"player")
	var shooter := player as CollisionObject3D
	var spawn_parent := tree.current_scene if tree.current_scene else tree.root
	for i in count:
		var angle := TAU * float(i) / float(count)
		var direction := Vector3(cos(angle), 0.15, sin(angle)).normalized()
		_spawn_cold_projectile(spawn_parent, origin, direction, damage, shooter)


static func spawn_cold_projectiles_from_direction(
	tree: SceneTree,
	origin: Vector3,
	base_direction: Vector3,
	count: int,
	damage: float,
	spread_deg: float = 18.0
) -> void:
	if not tree or count <= 0:
		return
	var player := tree.get_first_node_in_group(&"player")
	var shooter := player as CollisionObject3D
	var spawn_parent := tree.current_scene if tree.current_scene else tree.root
	for i in count:
		var spread := deg_to_rad(spread_deg * (float(i) - float(count - 1) * 0.5))
		var direction := base_direction.rotated(Vector3.UP, spread).normalized()
		_spawn_cold_projectile(spawn_parent, origin, direction, damage, shooter)


static func find_poison_follow_target(tree: SceneTree, from: Vector3, max_range: float) -> Node3D:
	if not tree:
		return null
	var best: Node3D = null
	var best_dist := max_range
	for enemy in tree.get_nodes_in_group(&"enemy"):
		if not enemy is Node3D:
			continue
		var status := _get_status(enemy)
		if not status or not status.is_poisoned():
			continue
		var dist := from.distance_to((enemy as Node3D).global_position)
		if dist < best_dist:
			best = enemy as Node3D
			best_dist = dist
	return best


static func _spawn_cold_projectile(
	spawn_parent: Node,
	origin: Vector3,
	direction: Vector3,
	damage: float,
	shooter: CollisionObject3D
) -> void:
	var stats := GunStats.new()
	stats.damage_type = DamageType.Type.COLD
	stats.damage_per_shot = damage
	stats.bullet_speed = 32.0
	stats.aim_range = 40.0
	stats.max_bounces = 0
	var projectile := _PROJECTILE_SCENE.instantiate() as Projectile
	var info := DamageInfo.create(damage, DamageType.Type.COLD, shooter)
	spawn_parent.add_child(projectile)
	projectile.global_position = origin + Vector3(0.0, 1.0, 0.0)
	projectile.setup(direction, stats, info, shooter)


static func _spawn_heal_pickup(world_position: Vector3, container: Node) -> void:
	if not is_instance_valid(container):
		return
	var pickup := _PICKUP_SCENE.instantiate() as Pickup
	if not pickup:
		return
	pickup.item = _HEAL_POTION
	container.add_child(pickup)
	pickup.global_position = world_position + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))


static func _get_status(target: Node) -> StatusEffectController:
	var damageable := DamageResolver.find_damageable(target) if target else null
	if not damageable:
		return null
	return damageable.get_node_or_null("StatusEffects") as StatusEffectController
