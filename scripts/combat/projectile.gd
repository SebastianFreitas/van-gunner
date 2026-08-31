class_name Projectile
extends Area3D

signal hit_target(target: Node)
signal ricocheted(position: Vector3, normal: Vector3)

## Distance the bullet is pushed off a surface after a bounce so the next sweep
## does not immediately re-hit the wall it just left.
const SURFACE_OFFSET := 0.03
## Below this a ricochet has lost so much energy it is not worth keeping alive.
const MIN_BOUNCE_SPEED := 4.0

var velocity := Vector3.ZERO
var gravity_scale := 1.0
var damage_info: DamageInfo
var owner_rid: RID
var max_distance := 80.0
var explosion_radius := 1.8
var bounce_speed_retention := 0.6
var bounce_damage_retention := 0.8

var _bounces_left := 0
var _bounce_count := 0
var _distance_travelled := 0.0
var _has_hit := false
var _collision_mask := 7
var _radius := 0.045
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var _bullet_mesh: MeshInstance3D = $BulletMesh
@onready var _trail: CPUParticles3D = $Trail
@onready var _trail_line: MeshInstance3D = $TrailLine


func setup(
	direction: Vector3,
	stats: GunStats,
	info: DamageInfo,
	shooter: CollisionObject3D
) -> void:
	velocity = direction.normalized() * stats.bullet_speed
	gravity_scale = stats.bullet_weight
	damage_info = info
	if shooter:
		owner_rid = shooter.get_rid()
	max_distance = stats.aim_range
	explosion_radius = stats.explosion_radius
	_bounces_left = stats.max_bounces
	bounce_speed_retention = stats.bounce_speed_retention
	bounce_damage_retention = stats.bounce_damage_retention
	_distance_travelled = 0.0
	_apply_size(stats.bullet_size)
	_update_trail()
	if _trail:
		_trail.emitting = true
		_trail.direction = -direction.normalized()


func has_hit() -> bool:
	return _has_hit


func _ready() -> void:
	_collision_mask = collision_mask
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	var from := global_position
	velocity.y -= _gravity * gravity_scale * delta
	var to := from + velocity * delta

	var hit := _sweep_for_hit(from, to)
	if hit.is_empty():
		_distance_travelled += from.distance_to(to)
		global_position = to
		_update_trail()
		_orient_to_velocity()
		if _distance_travelled >= max_distance:
			queue_free()
		return

	var contact := hit.position as Vector3
	_distance_travelled += from.distance_to(contact)
	var collider := hit.collider as Node
	if _can_ricochet_off(collider):
		_ricochet(contact, hit.normal as Vector3)
		return

	global_position = contact
	_update_trail()
	_resolve_hit(collider)


func _sweep_for_hit(from: Vector3, to: Vector3) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, _collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if owner_rid.is_valid():
		query.exclude = [owner_rid]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	return result


## Bullets only bounce off scenery. Anything that can take damage eats the shot.
func _can_ricochet_off(collider: Node) -> bool:
	if _bounces_left <= 0 or collider == null:
		return false
	return DamageResolver.find_damageable(collider) == null


func _ricochet(point: Vector3, normal: Vector3) -> void:
	_bounces_left -= 1
	_bounce_count += 1
	velocity = velocity.bounce(normal) * bounce_speed_retention
	global_position = point + normal * (_radius + SURFACE_OFFSET)
	if damage_info:
		damage_info.amount *= bounce_damage_retention
		var traits: BoonTraits = BoonCombat.get_player_traits(get_tree())
		if traits and traits.has_flag(BoonTraitKeys.RICOCHET_STACK_POWER):
			damage_info.amount *= 1.0 + float(_bounce_count) * 0.15
		if traits and traits.has_flag(BoonTraitKeys.COLD_SHATTERING_RICOCHET):
			BoonCombat.spawn_cold_projectiles_from_direction(
				get_tree(),
				global_position,
				velocity.normalized(),
				BoonCombat.RICOCHET_COLD_COUNT,
				damage_info.amount * 0.55
			)
		if traits and traits.has_flag(BoonTraitKeys.POISON_FOLLOW):
			var follow_target := BoonCombat.find_poison_follow_target(get_tree(), global_position, 10.0)
			if follow_target:
				var aim := follow_target.global_position + Vector3(0.0, 1.0, 0.0) - global_position
				if aim.length_squared() > 0.001:
					velocity = aim.normalized() * velocity.length()
	_update_trail()
	ricocheted.emit(global_position, normal)
	if velocity.length() < MIN_BOUNCE_SPEED or _distance_travelled >= max_distance:
		queue_free()
		return
	_orient_to_velocity()
	if _trail:
		_trail.direction = -velocity.normalized()


func _update_trail() -> void:
	if _trail_line and _trail_line.has_method("add_point"):
		_trail_line.call("add_point", global_position)


func _orient_to_velocity() -> void:
	if velocity.length_squared() < 0.001:
		return
	var forward := velocity.normalized()
	# A ricochet can send the bullet straight up or down, which would make
	# look_at() fail against the default up vector.
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	look_at(global_position + forward, up)


func _apply_size(size: float) -> void:
	_radius = size
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node:
		var sphere := SphereShape3D.new()
		sphere.radius = size
		shape_node.shape = sphere
	if _bullet_mesh and _bullet_mesh.mesh is SphereMesh:
		(_bullet_mesh.mesh as SphereMesh).radius = size * 1.6
		(_bullet_mesh.mesh as SphereMesh).height = size * 3.2
		_bullet_mesh.scale = Vector3.ONE * maxf(size * 22.0, 1.0)


func _on_body_entered(body: Node3D) -> void:
	if _can_ricochet_off(body):
		return
	_resolve_hit(body)


func _on_area_entered(area: Area3D) -> void:
	if _can_ricochet_off(area):
		return
	_resolve_hit(area)


func _resolve_hit(collider: Node) -> void:
	if _has_hit:
		return
	if collider is CollisionObject3D and (collider as CollisionObject3D).get_rid() == owner_rid:
		return
	var traits: BoonTraits = BoonCombat.get_player_traits(get_tree())
	var bonus_phys := 0.0
	if damage_info:
		damage_info.hit_position = global_position
		damage_info.is_headshot = DamageResolver.is_headshot(collider, damage_info.hit_position)
		if traits:
			bonus_phys = BoonCombat.modify_outgoing_damage(damage_info, traits, collider)
			explosion_radius = BoonCombat.modify_explosion_radius(explosion_radius, damage_info, traits)
	_has_hit = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if _trail:
		_trail.emitting = false
	if damage_info:
		damage_info.explosion_radius = explosion_radius
		DamageResolver.apply_hit(damage_info, collider)
		if bonus_phys > 0.0:
			BoonCombat.apply_bonus_physical_hit(bonus_phys, damage_info, collider, traits)
		DamageResolver.apply_status_from_hit(damage_info, collider)
		if traits:
			BoonCombat.apply_post_hit(damage_info, collider, traits)
		var should_explode := damage_info.damage_type in [DamageType.Type.EXPLOSIVE, DamageType.Type.FIRE]
		if should_explode:
			var space_state := get_world_3d().direct_space_state
			var exclude: Array[RID] = []
			if owner_rid.is_valid():
				exclude.append(owner_rid)
			if traits and traits.has_flag(BoonTraitKeys.DELAYED_FIRE) and damage_info.damage_type == DamageType.Type.FIRE:
				DamageResolver.schedule_delayed_explosion(
					get_tree(),
					global_position,
					explosion_radius,
					damage_info,
					exclude,
					traits
				)
			else:
				DamageResolver.apply_explosion(
					global_position,
					explosion_radius,
					damage_info,
					space_state,
					exclude,
					traits
				)
		hit_target.emit(collider)
	var keep_alive := false
	if traits and traits.has_flag(BoonTraitKeys.RICOCHET_EXPLOSIVE) and damage_info and damage_info.damage_type == DamageType.Type.FIRE and _bounces_left > 0:
		keep_alive = true
	if keep_alive:
		_has_hit = false
		set_deferred("monitoring", true)
		set_deferred("monitorable", true)
		return
	queue_free()
