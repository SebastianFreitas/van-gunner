class_name DamageResolver
extends RefCounted

const ENEMY_MASK := 4
const WORLD_MASK := 8


static func find_damageable(node: Node) -> Node:
	var current := node
	while current:
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return null


static func is_headshot(collider: Node) -> bool:
	if collider.is_in_group(&"head_hitbox"):
		return true
	return collider.has_meta(&"headshot") and collider.get_meta(&"headshot")


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
	exclude: Array[RID] = []
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
		splash.hit_position = center
		damageable.take_damage(splash)


static func apply_status_from_hit(info: DamageInfo, target: Node) -> void:
	var damageable := find_damageable(target)
	if not damageable:
		return
	var controller := damageable.get_node_or_null("StatusEffects") as StatusEffectController
	if not controller:
		return
	match info.damage_type:
		DamageType.Type.POISON:
			controller.apply_poison(info.amount * 0.35, info.source)
		DamageType.Type.FIRE:
			controller.apply_fire(info.amount * 0.25, info.source)
		DamageType.Type.COLD:
			controller.apply_cold(0.45, 2.5)
