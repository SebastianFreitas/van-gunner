class_name DamageResolver
extends RefCounted

const ENEMY_MASK := 4
const WORLD_MASK := 1
const EXPLOSION_PUSH_FORCE := 2.2
const DELAYED_FIRE_SECONDS := 0.55


static func find_damageable(node: Node) -> Node:
	var current := node
	while current:
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return null


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


static func apply_explosion(
	center: Vector3,
	radius: float,
	info: DamageInfo,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array[RID] = [],
	traits: BoonTraits = null
) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), center)
	params.collision_mask = ENEMY_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.exclude = exclude
	for result in space_state.intersect_shape(params, 32):
		var collider := result.collider as Node
		if not collider:
			continue
		var damageable := find_damageable(collider)
		if not damageable:
			continue
		var splash := info.duplicate_info()
		splash.amount *= 0.55
		var bonus_phys := 0.0
		if traits:
			bonus_phys = BoonCombat.modify_outgoing_damage(splash, traits, damageable)
		if traits and traits.has_flag(BoonTraitKeys.POISON_EXPLOSIONS) and splash.damage_type == DamageType.Type.FIRE:
			var poison_info := splash.duplicate_info()
			poison_info.damage_type = DamageType.Type.POISON
			poison_info.amount *= 0.35
			apply_status_from_hit(poison_info, damageable)
		if damageable is Node3D:
			splash.hit_position = (damageable as Node3D).global_position + Vector3(0, 1.2, 0)
		else:
			splash.hit_position = center
		damageable.take_damage(splash)
		if bonus_phys > 0.0:
			BoonCombat.apply_bonus_physical_hit(bonus_phys, splash, damageable, traits)
		if splash.damage_type == DamageType.Type.FIRE:
			_apply_explosion_displacement(center, damageable, traits)


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


static func _apply_explosion_displacement(center: Vector3, damageable: Node, traits: BoonTraits) -> void:
	if not damageable is Node3D:
		return
	var push_mult := traits.get_mult(BoonTraitKeys.FIRE_PUSH_MULT) if traits else 1.0
	var pull := traits != null and traits.has_flag(BoonTraitKeys.FIRE_PULL)
	var offset := (damageable as Node3D).global_position - center
	offset.y = 0.0
	if offset.length_squared() < 0.001:
		return
	var direction := offset.normalized()
	if pull:
		direction = -direction
	(damageable as Node3D).global_position += direction * EXPLOSION_PUSH_FORCE * push_mult


static func apply_status_from_hit(info: DamageInfo, target: Node) -> void:
	var damageable := find_damageable(target)
	if not damageable:
		return
	var controller := damageable.get_node_or_null("StatusEffects") as StatusEffectController
	if not controller:
		return
	var tree := damageable.get_tree() if damageable else null
	var traits := BoonCombat.get_player_traits(tree)
	match info.damage_type:
		DamageType.Type.POISON:
			if traits and traits.has_flag(BoonTraitKeys.INSTANT_POISON):
				var instant := controller.get_poison_total_damage_for_dps(info.amount * 0.35) * 0.5
				if instant > 0.0:
					var poison_hit := info.duplicate_info()
					poison_hit.amount = instant
					poison_hit.damage_type = DamageType.Type.POISON
					damageable.take_damage(poison_hit)
				return
			controller.apply_poison(info.amount * 0.35, info.source)
		DamageType.Type.FIRE:
			controller.apply_fire(info.amount * 0.25, info.source)
		DamageType.Type.COLD:
			controller.apply_cold(0.45, 2.5)
