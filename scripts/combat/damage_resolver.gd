class_name DamageResolver
extends RefCounted

const ENEMY_MASK := 4
const WORLD_MASK := 1
const EXPLOSION_PUSH_FORCE := 2.2
const DELAYED_FIRE_SECONDS := 0.55
const COLD_SLOW_STRENGTH := 0.45
const COLD_SLOW_DURATION := 2.5


static func find_damageable(node: Node) -> Node:
	var current := node
	while current:
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return null


static func find_status(node: Node) -> StatusEffectController:
	var damageable := find_damageable(node)
	if not damageable:
		return null
	return damageable.get_node_or_null("StatusEffects") as StatusEffectController


static func is_headshot(collider: Node, hit_position: Vector3 = Vector3.ZERO) -> bool:
	if collider.is_in_group(&"head_hitbox"):
		return true
	if collider.has_meta(&"headshot") and collider.get_meta(&"headshot"):
		return true
	if hit_position == Vector3.ZERO:
		return false
	var damageable := find_damageable(collider)
	if damageable is Node3D:
		var local_y := (damageable as Node3D).to_local(hit_position).y
		return local_y >= 1.05
	return false


static func apply_hit(info: DamageInfo, target: Node) -> void:
	var damageable := find_damageable(target)
	if not damageable:
		return
	damageable.take_damage(info)


static func apply_direct_channels(info: DamageInfo, target: Node, traits: BoonTraits = null) -> void:
	var damageable := find_damageable(target)
	if not damageable or not info:
		return
	_deliver_channel(info, DamageType.Type.NORMAL, damageable)
	_deliver_channel(info, DamageType.Type.LIGHTNING, damageable)
	_deliver_channel(info, DamageType.Type.COLD, damageable)
	_apply_poison_channel(info, damageable, traits)
	apply_cold_status(info, damageable)


static func apply_cold_status(info: DamageInfo, target: Node) -> void:
	if not info or info.get_final_channel(DamageType.Type.COLD) <= 0.0:
		return
	var controller := find_status(target)
	if controller:
		controller.apply_cold(COLD_SLOW_STRENGTH, COLD_SLOW_DURATION)


static func apply_explosion(
	center: Vector3,
	radius: float,
	info: DamageInfo,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array[RID] = [],
	traits: BoonTraits = null
) -> void:
	ExplosionFx.spawn(center, radius)
	if not space_state or radius <= 0.0 or not info:
		return
	var blast_base := info.get_final_blast_amount()
	if blast_base <= 0.0:
		blast_base = info.get_final_amount()
	if blast_base <= 0.0:
		return
	var blast_type := DamageType.Type.FIRE
	if info.get_channel(DamageType.Type.EXPLOSIVE) >= info.get_channel(DamageType.Type.FIRE):
		if info.has_channel(DamageType.Type.EXPLOSIVE):
			blast_type = DamageType.Type.EXPLOSIVE
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), center)
	params.collision_mask = ENEMY_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.exclude = exclude
	var seen: Dictionary = {}
	for result in space_state.intersect_shape(params, 32):
		var collider := result.collider as Node
		if not collider:
			continue
		var damageable := find_damageable(collider)
		if not damageable:
			continue
		var id := damageable.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		var target_pos := center
		if damageable is Node3D:
			target_pos = (damageable as Node3D).global_position + Vector3(0, 1.2, 0)
		var distance := center.distance_to(target_pos)
		var falloff := 1.0 - clampf(distance / radius, 0.0, 1.0)
		if falloff <= 0.0:
			continue
		var splash := DamageInfo.create(blast_base * falloff, blast_type, info.source)
		splash.hit_position = center
		splash.explosion_radius = radius
		splash.is_headshot = false
		if traits:
			var splash_ctx := BoonBehaviorContext.new()
			splash_ctx.traits = traits
			splash_ctx.damage_info = splash
			splash_ctx.target = damageable
			BoonBehaviorRegistry.dispatch_explosion_splash(splash_ctx)
		ActCardCombat.modify_outgoing_damage(splash, damageable)
		if damageable is Node3D:
			splash.hit_position = (damageable as Node3D).global_position + Vector3(0, 1.2, 0)
		damageable.take_damage(splash)
		if traits and info.has_explosive():
			var displacement_ctx := BoonBehaviorContext.new()
			displacement_ctx.traits = traits
			displacement_ctx.target = damageable
			displacement_ctx.explosion_center = center
			BoonBehaviorRegistry.dispatch_explosion_displacement(displacement_ctx)


static func schedule_delayed_explosion(
	tree: SceneTree,
	center: Vector3,
	radius: float,
	info: DamageInfo,
	exclude: Array[RID],
	traits: BoonTraits,
	delay_seconds: float = DELAYED_FIRE_SECONDS
) -> void:
	if not tree:
		return
	var captured_info := info.duplicate_info()
	tree.create_timer(delay_seconds).timeout.connect(func() -> void:
		if not tree.root:
			return
		var space_state := tree.root.get_world_3d().direct_space_state if tree.root.is_inside_tree() else null
		if space_state:
			apply_explosion(center, radius, captured_info, space_state, exclude, traits)
	)


static func apply_status_from_hit(info: DamageInfo, target: Node, traits: BoonTraits = null) -> void:
	_apply_poison_channel(info, find_damageable(target), traits)
	apply_cold_status(info, target)


static func _apply_poison_channel(info: DamageInfo, damageable: Node, traits: BoonTraits) -> void:
	if not info or not damageable or info.is_dot_tick:
		return
	var poison := info.get_final_channel(DamageType.Type.POISON)
	if poison <= 0.0:
		return
	var controller := damageable.get_node_or_null("StatusEffects") as StatusEffectController
	if not controller:
		_deliver_channel(info, DamageType.Type.POISON, damageable)
		return
	if traits:
		var status_ctx := BoonBehaviorContext.new()
		status_ctx.traits = traits
		status_ctx.damage_info = info
		status_ctx.target = damageable
		status_ctx.status = controller
		if BoonBehaviorRegistry.dispatch_status_apply(status_ctx):
			return
	controller.apply_poison_stack(poison, info.source)


static func _deliver_channel(info: DamageInfo, type: DamageType.Type, damageable: Node) -> void:
	var value := info.get_final_channel(type)
	if value <= 0.0:
		return
	var channel := info.for_channel(type)
	channel.is_headshot = info.is_headshot
	channel.headshot_bonus_mult = info.headshot_bonus_mult
	channel.hit_position = info.hit_position
	channel.source = info.source
	channel.is_dot_tick = info.is_dot_tick
	damageable.take_damage(channel)
