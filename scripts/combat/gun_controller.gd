class_name GunController
extends Node3D

## Hit/miss for the HUD once the first pellet resolves. Not a muzzle event.
signal fired(hit: bool)
## Round actually left the gun. AudioDirector listens here, never inside try_fire.
signal shot
signal ammo_changed(current: int, max_ammo: int)
signal reloading_changed(is_reloading: bool)

## Brief camera pitch punch on fire (radians). Recovers in feedback tween.
const CAMERA_KICK := 0.012

@export var stats_controller_path: NodePath
@export var muzzle_offset := Vector3(0.0, 0.0, -0.38)

@onready var camera: Camera3D = get_parent()
@onready var muzzle_flash: OmniLight3D = $MuzzleFlash
@onready var viewmodel: GunViewmodel = $GunViewmodel

@onready var _weapon_rest_position: Vector3 = position

var _stats_controller: GunStatsController
var _current_ammo := 0
var _next_shot_time := 0
var _is_reloading := false
## Absolute msec when the in-progress reload finishes; 0 if idle.
var _reload_ends_at_msec := 0
## Bumped on cancel/swap so in-flight reload awaits ignore stale completions.
var _reload_gen := 0
var _feedback_tween: Tween


func _ready() -> void:
	add_to_group(&"gun_controller")
	_stats_controller = get_node_or_null(stats_controller_path) as GunStatsController
	if not _stats_controller:
		_stats_controller = get_tree().get_first_node_in_group(&"gun_stats") as GunStatsController
	if _stats_controller:
		_stats_controller.stats_changed.connect(_on_stats_changed)
		_refill_magazine()
	else:
		push_warning("GunController: no GunStatsController found")


func try_fire() -> void:
	if _is_reloading:
		return
	var stats := _get_stats()
	var now := Time.get_ticks_msec()
	if now < _next_shot_time:
		return
	if _current_ammo <= 0:
		_start_reload()
		return

	# Hits come from screen center so point-blank targets aren't skipped.
	# The cosmetic trail still leaves the gun muzzle via visual_origin.
	var origin := camera.global_position
	var muzzle := _get_muzzle_position()
	var aim := _get_aim_point(stats.aim_range)
	aim = _resolve_path_obstruction(origin, aim)

	var direction := (aim - origin).normalized()
	if direction.length_squared() < 0.0001:
		direction = -camera.global_basis.z

	## Pellet damage is split so shotguns are coverage, not ×N DPS.
	var pellets := maxi(stats.pellets_per_shot, 1)
	var pellet_damage := stats.damage_per_shot / float(pellets)
	var pellet_stats := stats.duplicate_stats()
	pellet_stats.damage_per_shot = pellet_damage

	var first_projectile: Projectile = null
	for i in pellets:
		var shot_dir := direction
		if pellets > 1 and stats.pellet_spread_degrees > 0.0:
			shot_dir = _spread_direction(direction, stats.pellet_spread_degrees)
		var projectile := _spawn_projectile(
			origin, shot_dir, pellet_stats, Vector3.ZERO, muzzle, aim
		)
		if first_projectile == null:
			first_projectile = projectile

	var player := _get_player()
	var traits := BoonTraits.find_on(player)
	if traits:
		BoonCombat.dispatch_bonus_projectiles(
			get_tree(),
			origin,
			direction,
			stats,
			player as CollisionObject3D,
			traits,
			Vector3.ZERO
		)
	if first_projectile:
		_track_projectile_feedback(first_projectile)
	_current_ammo -= 1
	_next_shot_time = now + roundi(1000.0 / stats.fire_rate)
	_play_feedback()
	shot.emit()
	ammo_changed.emit(_current_ammo, stats.mag_size)
	if _current_ammo <= 0:
		_start_reload()


## Random cone offset around the aim direction (degrees half-angle).
func _spread_direction(base: Vector3, spread_degrees: float) -> Vector3:
	var axis := base.normalized()
	var up := Vector3.UP
	if absf(axis.dot(up)) > 0.95:
		up = Vector3.RIGHT
	var right := axis.cross(up).normalized()
	up = right.cross(axis).normalized()
	var yaw := deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	var pitch := deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	return (axis + right * tan(yaw) + up * tan(pitch)).normalized()


func set_ammo_state(current: int, reloading: bool = false) -> void:
	_invalidate_reload_waits()
	_current_ammo = maxi(current, 0)
	_is_reloading = reloading
	if not reloading:
		_reload_ends_at_msec = 0
	ammo_changed.emit(_current_ammo, _get_stats().mag_size)
	reloading_changed.emit(_is_reloading)


func apply_weapon_ammo_from_instance(instance: WeaponInstance) -> void:
	## Drop any in-flight reload completion from the previous gun.
	_invalidate_reload_waits()
	if viewmodel:
		viewmodel.snap_rest()
	if instance == null:
		_is_reloading = false
		_reload_ends_at_msec = 0
		_refill_magazine()
		reloading_changed.emit(false)
		return
	var mag := _get_stats().mag_size
	if instance.current_ammo < 0:
		_current_ammo = mag
	else:
		_current_ammo = mini(instance.current_ammo, mag)

	if instance.is_reloading:
		if instance.reload_ends_at_msec > Time.get_ticks_msec():
			_resume_reload(instance)
			return
		## Reload finished while this gun was holstered.
		instance.is_reloading = false
		instance.reload_ends_at_msec = 0
		_current_ammo = mag
		instance.current_ammo = mag

	_is_reloading = false
	_reload_ends_at_msec = 0
	ammo_changed.emit(_current_ammo, mag)
	reloading_changed.emit(false)


func capture_ammo_to_instance(instance: WeaponInstance) -> void:
	if instance == null:
		return
	instance.current_ammo = _current_ammo
	instance.is_reloading = _is_reloading
	if _is_reloading:
		instance.reload_ends_at_msec = _reload_ends_at_msec
	else:
		instance.reload_ends_at_msec = 0


func _invalidate_reload_waits() -> void:
	_reload_gen += 1


func _resume_reload(instance: WeaponInstance) -> void:
	_is_reloading = true
	_reload_ends_at_msec = instance.reload_ends_at_msec
	instance.is_reloading = true
	instance.reload_ends_at_msec = _reload_ends_at_msec
	_reload_gen += 1
	var token := _reload_gen
	ammo_changed.emit(_current_ammo, _get_stats().mag_size)
	reloading_changed.emit(true)
	var remaining_ms := maxi(_reload_ends_at_msec - Time.get_ticks_msec(), 0)
	var remaining_sec := remaining_ms / 1000.0
	if viewmodel:
		viewmodel.play_reload(remaining_sec)
	await get_tree().create_timer(remaining_sec).timeout
	if not _reload_wait_still_valid(token):
		return
	_complete_reload(instance)


func _track_projectile_feedback(projectile: Projectile) -> void:
	projectile.hit_target.connect(
		func(_target: Node) -> void: fired.emit(true),
		CONNECT_ONE_SHOT
	)
	projectile.despawned.connect(
		func(was_hit: bool) -> void:
			if not was_hit:
				fired.emit(false),
		CONNECT_ONE_SHOT
	)


func try_reload() -> void:
	if _is_reloading or _current_ammo >= _get_stats().mag_size:
		return
	_start_reload()


func get_current_ammo() -> int:
	return _current_ammo


func get_mag_size() -> int:
	return _get_stats().mag_size


func is_reloading() -> bool:
	return _is_reloading


## Seconds left on the active reload, or 0 when not reloading.
func get_reload_remaining() -> float:
	if not _is_reloading or _reload_ends_at_msec <= 0:
		return 0.0
	return maxf((_reload_ends_at_msec - Time.get_ticks_msec()) / 1000.0, 0.0)


func _get_stats() -> GunStats:
	if _stats_controller:
		return _stats_controller.get_stats()
	var stats := GunStats.new()
	stats.fire_rate = GameBalance.BASE_FIRE_RATE
	stats.damage_per_shot = GameBalance.BASE_DAMAGE_PER_SHOT
	return stats


func _get_player() -> Node:
	return camera.get_parent().get_parent()


func _get_muzzle_position() -> Vector3:
	return global_transform * muzzle_offset


func _get_exclude_rids() -> Array[RID]:
	var exclude: Array[RID] = []
	var player := _get_player()
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	return exclude


## Camera-center raycast — where the crosshair is actually looking.
func _get_aim_point(max_range: float) -> Vector3:
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var end := origin + direction * max_range
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		end,
		DamageResolver.ENEMY_MASK | DamageResolver.WORLD_MASK
	)
	query.collide_with_areas = true
	query.exclude = _get_exclude_rids()
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return end
	return result.position


## If anything sits on the camera→aim path (window frame, close enemy), aim there.
func _resolve_path_obstruction(origin: Vector3, aim: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		aim,
		DamageResolver.ENEMY_MASK | DamageResolver.WORLD_MASK
	)
	query.collide_with_areas = true
	query.exclude = _get_exclude_rids()
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return aim
	return result.position


func _spawn_projectile(
	origin: Vector3,
	direction: Vector3,
	stats: GunStats,
	inherited_velocity: Vector3,
	visual_origin: Vector3,
	aim_point: Vector3
) -> Projectile:
	var shooter := _get_player() as CollisionObject3D
	return BoonCombat.spawn_projectile(
		get_tree(),
		origin,
		direction,
		stats,
		shooter,
		visual_origin,
		inherited_velocity,
		aim_point
	)


func _start_reload() -> void:
	if _is_reloading:
		return
	var stats := _get_stats()
	if _current_ammo >= stats.mag_size:
		return
	_is_reloading = true
	var duration := stats.reload_speed
	_reload_ends_at_msec = Time.get_ticks_msec() + roundi(duration * 1000.0)
	var inst: WeaponInstance = null
	if _stats_controller:
		inst = _stats_controller.get_weapon_instance()
		if inst:
			inst.is_reloading = true
			inst.reload_ends_at_msec = _reload_ends_at_msec
			inst.current_ammo = _current_ammo
	_reload_gen += 1
	var token := _reload_gen
	reloading_changed.emit(true)
	if viewmodel:
		viewmodel.play_reload(duration)
	await get_tree().create_timer(duration).timeout
	if not _reload_wait_still_valid(token):
		return
	_complete_reload(inst)


func _reload_wait_still_valid(token: int) -> bool:
	return is_inside_tree() and token == _reload_gen


func _complete_reload(instance: WeaponInstance) -> void:
	_is_reloading = false
	_reload_ends_at_msec = 0
	if instance:
		instance.is_reloading = false
		instance.reload_ends_at_msec = 0
	if viewmodel:
		viewmodel.snap_rest()
	_refill_magazine()
	if instance:
		instance.current_ammo = _current_ammo
	reloading_changed.emit(false)


func _refill_magazine() -> void:
	_current_ammo = _get_stats().mag_size
	ammo_changed.emit(_current_ammo, _current_ammo)


func apply_weapon_visual(instance: WeaponInstance) -> void:
	var family := WeaponDefinition.Family.BASIC
	if instance:
		var def := instance.get_definition()
		if def:
			family = def.family
	if viewmodel:
		muzzle_offset = Vector3(0.0, 0.0, viewmodel.apply_family(family))
	if muzzle_flash:
		muzzle_flash.position = muzzle_offset


func _on_stats_changed() -> void:
	var stats := _get_stats()
	_current_ammo = mini(_current_ammo, stats.mag_size)
	ammo_changed.emit(_current_ammo, stats.mag_size)


func _play_feedback() -> void:
	muzzle_flash.show()
	muzzle_flash.light_energy = 2.5
	if viewmodel:
		viewmodel.play_shot()
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	position = _weapon_rest_position
	position.z += 0.08
	camera.rotation.x = -CAMERA_KICK
	_feedback_tween = create_tween()
	_feedback_tween.set_parallel()
	_feedback_tween.tween_property(self, "position", _weapon_rest_position, 0.09)
	_feedback_tween.tween_property(muzzle_flash, "light_energy", 0.0, 0.06)
	_feedback_tween.tween_property(camera, "rotation:x", 0.0, 0.11)
	_feedback_tween.chain().tween_callback(_reset_flash)


func _reset_flash() -> void:
	muzzle_flash.hide()
	muzzle_flash.light_energy = 2.5
