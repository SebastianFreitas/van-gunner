class_name BoonCombat
extends RefCounted

## Thin dispatcher for boon combat logic. All behavior lives in BoonBehaviorRegistry handlers.

const _HEAL_POTION := preload("res://resources/items/heal_potion.tres")
const _PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")
const RICOCHET_COLD_COUNT := 2


static func get_player_traits(tree: SceneTree) -> BoonTraits:
	if not tree:
		return null
	var player := tree.get_first_node_in_group(&"player")
	return BoonTraits.find_on(player)


static func _make_damage_ctx(info: DamageInfo, traits: BoonTraits, target: Node) -> BoonBehaviorContext:
	var ctx := BoonBehaviorContext.new()
	ctx.traits = traits
	ctx.damage_info = info
	ctx.target = target
	ctx.status = _get_status(target)
	return ctx


static func modify_outgoing_damage(info: DamageInfo, traits: BoonTraits, target: Node) -> float:
	if not info or not traits:
		return 0.0
	var ctx := _make_damage_ctx(info, traits, target)
	BoonBehaviorRegistry.dispatch_modify_damage(ctx)
	return ctx.bonus_phys


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
	if not traits or not info:
		return base_radius
	var ctx := BoonBehaviorContext.new()
	ctx.traits = traits
	ctx.damage_info = info
	ctx.explosion_radius = base_radius
	BoonBehaviorRegistry.dispatch_modify_explosion_radius(ctx)
	return ctx.explosion_radius


static func apply_post_hit(info: DamageInfo, target: Node, traits: BoonTraits) -> void:
	if not traits:
		return
	var ctx := _make_damage_ctx(info, traits, target)
	BoonBehaviorRegistry.dispatch_post_hit(ctx)


static func configure_enemy_status_effects(enemy: Node, tree: SceneTree) -> void:
	var status := _get_status(enemy)
	var traits := get_player_traits(tree)
	if status and traits:
		status.configure_from_traits(traits)


static func refresh_all_enemy_status_effects(tree: SceneTree) -> void:
	if not tree:
		return
	for enemy in tree.get_nodes_in_group(&"enemy"):
		configure_enemy_status_effects(enemy, tree)


static func apply_on_enemy_death(enemy: Node, last_damage_type: DamageType.Type) -> void:
	if not enemy or not enemy.is_inside_tree():
		return
	var tree := enemy.get_tree()
	var traits := get_player_traits(tree)
	if not traits:
		return
	var ctx := BoonBehaviorContext.new()
	ctx.traits = traits
	ctx.tree = tree
	ctx.enemy = enemy
	ctx.status = _get_status(enemy)
	ctx.explosion_center = enemy.global_position if enemy is Node3D else Vector3.ZERO
	ctx.loot_container = enemy.get_parent()
	ctx.last_damage_type = last_damage_type
	ctx.space_state = enemy.get_world_3d().direct_space_state if enemy is Node3D else null
	BoonBehaviorRegistry.dispatch_enemy_death(ctx)


static func dispatch_ricochet(
	projectile: Projectile,
	traits: BoonTraits,
	bounce_count: int,
	velocity: Vector3
) -> Vector3:
	if not traits or not projectile:
		return velocity
	var ctx := BoonBehaviorContext.new()
	ctx.traits = traits
	ctx.projectile = projectile
	ctx.damage_info = projectile.damage_info
	ctx.bounce_count = bounce_count
	ctx.velocity = velocity
	ctx.tree = projectile.get_tree()
	BoonBehaviorRegistry.dispatch_ricochet(ctx)
	return ctx.velocity


static func should_delay_fire(traits: BoonTraits, info: DamageInfo) -> bool:
	if not traits or not info:
		return false
	var ctx := BoonBehaviorContext.new()
	ctx.traits = traits
	ctx.damage_info = info
	return BoonBehaviorRegistry.dispatch_should_delay_fire(ctx)


static func should_keep_alive_after_hit(traits: BoonTraits, info: DamageInfo, projectile: Projectile) -> bool:
	if not traits or not info or not projectile:
		return false
	var ctx := BoonBehaviorContext.new()
	ctx.traits = traits
	ctx.damage_info = info
	ctx.projectile = projectile
	return BoonBehaviorRegistry.dispatch_should_keep_alive_after_hit(ctx)


static func dispatch_bonus_projectiles(
	tree: SceneTree,
	origin: Vector3,
	direction: Vector3,
	stats: GunStats,
	shooter: CollisionObject3D,
	traits: BoonTraits
) -> void:
	if not traits or not tree:
		return
	var ctx := BoonBehaviorContext.new()
	ctx.traits = traits
	ctx.tree = tree
	ctx.fire_origin = origin
	ctx.fire_direction = direction
	ctx.gun_stats = stats
	ctx.projectile_shooter = shooter
	BoonBehaviorRegistry.dispatch_bonus_projectiles(ctx)


static func get_poisoned_damage_multiplier(traits: BoonTraits) -> float:
	if not traits:
		return 1.0
	var ctx := BoonBehaviorContext.new()
	ctx.traits = traits
	return BoonBehaviorRegistry.dispatch_poisoned_damage_multiplier(ctx)


static func spawn_projectile(
	tree: SceneTree,
	origin: Vector3,
	direction: Vector3,
	stats: GunStats,
	shooter: CollisionObject3D
) -> Projectile:
	var info := DamageInfo.create(stats.damage_per_shot, stats.damage_type, shooter)
	var spawn_parent := tree.current_scene if tree.current_scene else tree.root
	return ProjectilePool.acquire(spawn_parent, origin, direction, stats, info, shooter)


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
	var stats := GunStats.new()
	stats.damage_type = DamageType.Type.COLD
	stats.damage_per_shot = damage
	stats.bullet_speed = 32.0
	stats.aim_range = 40.0
	stats.max_bounces = 0
	for i in count:
		var angle := TAU * float(i) / float(count)
		var direction := Vector3(cos(angle), 0.15, sin(angle)).normalized()
		spawn_projectile(tree, origin + Vector3(0.0, 1.0, 0.0), direction, stats, shooter)


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
	var stats := GunStats.new()
	stats.damage_type = DamageType.Type.COLD
	stats.damage_per_shot = damage
	stats.bullet_speed = 32.0
	stats.aim_range = 40.0
	stats.max_bounces = 0
	for i in count:
		var spread := deg_to_rad(spread_deg * (float(i) - float(count - 1) * 0.5))
		var direction := base_direction.rotated(Vector3.UP, spread).normalized()
		spawn_projectile(tree, origin + Vector3(0.0, 1.0, 0.0), direction, stats, shooter)


static func spawn_heal_pickup(world_position: Vector3, container: Node) -> void:
	if not is_instance_valid(container):
		return
	var pickup := _PICKUP_SCENE.instantiate() as Pickup
	if not pickup:
		return
	pickup.item = _HEAL_POTION
	container.add_child(pickup)
	pickup.global_position = world_position + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))


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


static func _get_status(target: Node) -> StatusEffectController:
	var damageable := DamageResolver.find_damageable(target) if target else null
	if not damageable:
		return null
	return damageable.get_node_or_null("StatusEffects") as StatusEffectController
