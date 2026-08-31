class_name GunController
extends Node3D

signal fired(hit: bool)
signal ammo_changed(current: int, max_ammo: int)
signal reloading_changed(is_reloading: bool)

const PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")

@export var stats_controller_path: NodePath
@export var muzzle_offset := Vector3(0.0, 0.0, -0.38)

@onready var camera: Camera3D = get_parent()
@onready var muzzle_flash: OmniLight3D = $MuzzleFlash

var _stats_controller: GunStatsController
var _current_ammo := 0
var _next_shot_time := 0
var _is_reloading := false


func _ready() -> void:
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

	var aim := _get_aim_point(stats.aim_range)
	var muzzle := _get_muzzle_position()
	var direction := (aim - muzzle).normalized()
	if direction.length_squared() < 0.0001:
		direction = -camera.global_basis.z

	var projectile := _spawn_projectile(muzzle, direction, stats)
	_spawn_bonus_projectiles(muzzle, direction, stats)
	_track_projectile_feedback(projectile)
	_current_ammo -= 1
	_next_shot_time = now + roundi(1000.0 / stats.fire_rate)
	_play_feedback()
	ammo_changed.emit(_current_ammo, stats.mag_size)
	if _current_ammo <= 0:
		_start_reload()


func _track_projectile_feedback(projectile: Projectile) -> void:
	projectile.hit_target.connect(
		func(_target: Node) -> void: fired.emit(true),
		CONNECT_ONE_SHOT
	)
	projectile.tree_exited.connect(func() -> void:
		if not projectile.has_hit():
			fired.emit(false)
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


func _get_stats() -> GunStats:
	if _stats_controller:
		return _stats_controller.get_stats()
	return GunStats.new()


func _get_muzzle_position() -> Vector3:
	return global_transform * muzzle_offset


func _get_aim_point(max_range: float) -> Vector3:
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var end := origin + direction * max_range
	var query := PhysicsRayQueryParameters3D.create(origin, end, DamageResolver.ENEMY_MASK | DamageResolver.WORLD_MASK)
	query.collide_with_areas = true
	var player := camera.get_parent().get_parent()
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return end
	return result.position


func _spawn_bonus_projectiles(origin: Vector3, direction: Vector3, stats: GunStats) -> void:
	var player := camera.get_parent().get_parent()
	var traits := BoonTraits.find_on(player)
	if not traits:
		return
	var extra_cold := int(traits.get_add(BoonTraitKeys.COLD_PROJECTILE_COUNT))
	for i in extra_cold:
		var spread := deg_to_rad(6.0 * (i + 1))
		var spread_dir := direction.rotated(Vector3.UP, spread if i % 2 == 0 else -spread)
		var cold_stats := stats.duplicate_stats()
		cold_stats.damage_type = DamageType.Type.COLD
		cold_stats.damage_per_shot *= 0.65
		_spawn_projectile(origin, spread_dir, cold_stats)


func _spawn_projectile(origin: Vector3, direction: Vector3, stats: GunStats) -> Projectile:
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	var shooter := camera.get_parent().get_parent() as CollisionObject3D
	var info := DamageInfo.create(stats.damage_per_shot, stats.damage_type, shooter)
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_tree().root
	spawn_parent.add_child(projectile)
	projectile.global_position = origin
	projectile.setup(direction, stats, info, shooter)
	return projectile


func _start_reload() -> void:
	if _is_reloading:
		return
	var stats := _get_stats()
	if _current_ammo >= stats.mag_size:
		return
	_is_reloading = true
	reloading_changed.emit(true)
	await get_tree().create_timer(stats.reload_speed).timeout
	if not is_inside_tree():
		return
	_is_reloading = false
	_refill_magazine()
	reloading_changed.emit(false)


func _refill_magazine() -> void:
	_current_ammo = _get_stats().mag_size
	ammo_changed.emit(_current_ammo, _current_ammo)


func _on_stats_changed() -> void:
	var stats := _get_stats()
	_current_ammo = mini(_current_ammo, stats.mag_size)
	ammo_changed.emit(_current_ammo, stats.mag_size)


func _play_feedback() -> void:
	muzzle_flash.show()
	var rest_position := position
	position.z += 0.08
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "position", rest_position, 0.09)
	tween.tween_property(muzzle_flash, "light_energy", 0.0, 0.06)
	tween.chain().tween_callback(_reset_flash)


func _reset_flash() -> void:
	muzzle_flash.hide()
	muzzle_flash.light_energy = 2.5
