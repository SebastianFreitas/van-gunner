class_name Projectile
extends Area3D

signal hit_target(target: Node)
signal ricocheted(position: Vector3, normal: Vector3)
signal despawned(was_hit: bool)

## Distance the bullet is pushed off a surface after a bounce so the next sweep
## does not immediately re-hit the wall it just left.
const SURFACE_OFFSET := 0.03
## Below this a ricochet has lost so much energy it is not worth keeping alive.
const MIN_BOUNCE_SPEED := 4.0
const TRAIL_FADE_SECONDS := 0.45
const BULLET_VISUAL_SCALE := 0.22

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
var _despawning := false
var _pooled := false
var _collision_mask := 7
var _radius := 0.045
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _bullet_mesh: MeshInstance3D
var _trail_line: MeshInstance3D
var _visual: BulletVisual
var _visual_origin := Vector3.ZERO


func setup(
	direction: Vector3,
	stats: GunStats,
	info: DamageInfo,
	shooter: CollisionObject3D,
	visual_origin = null,
	inherited_velocity: Vector3 = Vector3.ZERO,
	aim_point = null
) -> void:
	_pooled = false
	_despawning = false
	set_physics_process(true)
	_has_hit = false
	_bounce_count = 0
	_distance_travelled = 0.0
	var aim_dir := direction.normalized()
	# Van-parented shots ride the van transform — only bake extra inherited motion
	# (e.g. player strafe) here, never continuous van travel velocity.
	velocity = aim_dir * stats.bullet_speed + inherited_velocity
	gravity_scale = stats.bullet_weight
	damage_info = info
	owner_rid = RID()
	if shooter:
		owner_rid = shooter.get_rid()
	max_distance = stats.aim_range
	explosion_radius = stats.explosion_radius
	_bounces_left = stats.max_bounces
	bounce_speed_retention = stats.bounce_speed_retention
	bounce_damage_retention = stats.bounce_damage_retention
	_collision_mask = collision_mask
	_clear_visual()
	# Prefer a detached cosmetic visual so the trail can fade after despawn.
	var cosmetic_origin := global_position
	if visual_origin is Vector3:
		cosmetic_origin = visual_origin as Vector3
	_visual_origin = cosmetic_origin
	_spawn_visual(_visual_origin, info, stats, aim_point, inherited_velocity, aim_dir)
	_hide_self_visuals()
	show()


func is_pooled() -> bool:
	return _pooled


func reset_for_pool() -> void:
	_pooled = true
	_despawning = true
	set_physics_process(false)
	_has_hit = false
	_bounce_count = 0
	_distance_travelled = 0.0
	velocity = Vector3.ZERO
	damage_info = null
	owner_rid = RID()
	_clear_visual()
	if _trail_line and _trail_line.has_method("clear_points"):
		_trail_line.call("clear_points")
	if _bullet_mesh:
		_bullet_mesh.hide()
	hide()


func has_hit() -> bool:
	return _has_hit


func get_bounces_left() -> int:
	return _bounces_left


func _ready() -> void:
	_bullet_mesh = get_node_or_null("BulletMesh") as MeshInstance3D
	_collision_mask = collision_mask
	monitoring = false
	monitorable = false


func _physics_process(delta: float) -> void:
	if _has_hit or _despawning:
		return

	var from := global_position
	velocity.y -= _gravity * gravity_scale * delta
	var to := from + velocity * delta

	var hit := _sweep_for_hit(from, to)
	if hit.is_empty():
		_distance_travelled += from.distance_to(to)
		global_position = to
		_update_trail()
		_sync_visual()
		_orient_to_velocity()
		if _distance_travelled >= max_distance:
			_despawn()
		return

	var contact := hit.position as Vector3
	_distance_travelled += from.distance_to(contact)
	var collider := hit.collider as Node
	if _can_ricochet_off(collider):
		_ricochet(contact, hit.normal as Vector3)
		return

	global_position = contact
	_update_trail()
	if _visual:
		_visual.snap_to(global_position, velocity)
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
	var safe_normal := normal.normalized()
	if safe_normal.dot(velocity) > 0.0:
		safe_normal = -safe_normal
	velocity = velocity.bounce(safe_normal) * bounce_speed_retention
	var exit := point + safe_normal * (_radius + SURFACE_OFFSET)
	global_position = exit
	if damage_info:
		damage_info.amount *= bounce_damage_retention
		var traits: BoonTraits = BoonCombat.get_player_traits(get_tree())
		if traits:
			velocity = BoonCombat.dispatch_ricochet(self, traits, _bounce_count, velocity)
	if _visual:
		_visual.on_bounce(point, exit, velocity)
	elif _trail_line and _trail_line.has_method("set_bounce_vertex"):
		_trail_line.call("set_bounce_vertex", point, exit)
	else:
		_update_trail()
	ricocheted.emit(global_position, safe_normal)
	if velocity.length() < MIN_BOUNCE_SPEED or _distance_travelled >= max_distance:
		_despawn()
		return
	_orient_to_velocity()


func _update_trail() -> void:
	if _visual:
		return
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
		var visual_radius := size * BULLET_VISUAL_SCALE
		(_bullet_mesh.mesh as SphereMesh).radius = visual_radius
		(_bullet_mesh.mesh as SphereMesh).height = visual_radius * 2.0
		_bullet_mesh.scale = Vector3.ONE


func _apply_trail_color(info: DamageInfo) -> void:
	if not _trail_line:
		return
	var dmg_type := DamageType.Type.NORMAL
	if info:
		dmg_type = info.damage_type
	if _trail_line.has_method("set_trail_color"):
		_trail_line.call("set_trail_color", BulletTrail.color_for_damage_type(dmg_type))


func _ensure_trail_line() -> void:
	if _trail_line and is_instance_valid(_trail_line):
		if _trail_line.has_method("clear_points"):
			_trail_line.call("clear_points")
		return
	_trail_line = get_node_or_null("TrailLine") as MeshInstance3D
	if not _trail_line:
		_trail_line = MeshInstance3D.new()
		_trail_line.name = &"TrailLine"
		_trail_line.set_script(preload("res://scripts/combat/bullet_trail.gd"))
		add_child(_trail_line)
	if _trail_line.has_method("clear_points"):
		_trail_line.call("clear_points")


func _detach_trail_line() -> void:
	if _visual:
		return
	if _trail_line and is_instance_valid(_trail_line) and _trail_line.has_method("detach_and_fade"):
		_trail_line.call("detach_and_fade", TRAIL_FADE_SECONDS)
		_trail_line = null


func _hide_self_visuals() -> void:
	if _bullet_mesh:
		_bullet_mesh.hide()
	if _trail_line:
		_trail_line.hide()


func _sync_visual() -> void:
	if not _visual:
		return
	_visual.sync_to(global_position, velocity)


func _spawn_visual(
	origin: Vector3,
	info: DamageInfo,
	stats: GunStats,
	aim_point = null,
	inherited_velocity: Vector3 = Vector3.ZERO,
	aim_dir: Vector3 = Vector3.FORWARD
) -> void:
	var parent := get_parent()
	if not parent:
		return
	# Tracer flies muzzle → aim on its own frozen velocity (no mid-flight course correction).
	var visual_velocity := velocity
	if aim_point is Vector3:
		var to_aim := (aim_point as Vector3) - origin
		if to_aim.length_squared() > 0.0001:
			visual_velocity = to_aim.normalized() * stats.bullet_speed + inherited_velocity
		elif aim_dir.length_squared() > 0.0001:
			visual_velocity = aim_dir.normalized() * stats.bullet_speed + inherited_velocity
	_visual = BulletVisual.new()
	parent.add_child(_visual)
	var motion_frame := parent as Node3D
	_visual.setup(origin, visual_velocity, gravity_scale, info, stats, global_position, motion_frame)


func _clear_visual() -> void:
	if _visual and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null


func _fade_visual() -> void:
	if _visual and is_instance_valid(_visual):
		_visual.snap_to(global_position, velocity)
		_visual.fade_out()
	_visual = null


func _resolve_hit(collider: Node) -> void:
	if _has_hit or _despawning:
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
			if BoonCombat.should_delay_fire(traits, damage_info):
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
	var keep_alive := BoonCombat.should_keep_alive_after_hit(traits, damage_info, self)
	if keep_alive:
		_has_hit = false
		return
	_despawn()


func _despawn() -> void:
	if _despawning:
		return
	_despawning = true
	_fade_visual()
	_detach_trail_line()
	despawned.emit(_has_hit)
	ProjectilePool.release(self)
