class_name StatusEffectController
extends Node

@export var poison_tick_interval := 0.5
@export var fire_tick_interval := 0.35
@export var fire_spread_radius := 1.4

var _owner: Node3D
var _poison_dps := 0.0
var _poison_time_left := 0.0
var _fire_dps := 0.0
var _fire_time_left := 0.0
var _cold_slow := 1.0
var _cold_time_left := 0.0
var _fire_source: Node3D
var _poison_tick_timer := 0.0
var _fire_tick_timer := 0.0


func _ready() -> void:
	_owner = get_parent() as Node3D


func apply_poison(dps: float, _source: Node3D = null) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_time_left = maxf(_poison_time_left, 4.0)


func apply_fire(dps: float, source: Node3D = null) -> void:
	_fire_dps = maxf(_fire_dps, dps)
	_fire_time_left = maxf(_fire_time_left, 3.5)
	if source:
		_fire_source = source


func apply_cold(slow_strength: float, duration: float) -> void:
	_cold_slow = minf(_cold_slow, 1.0 - clampf(slow_strength, 0.0, 0.85))
	_cold_time_left = maxf(_cold_time_left, duration)


func get_attack_speed_multiplier() -> float:
	return _cold_slow


func _process(delta: float) -> void:
	_tick_poison(delta)
	_tick_fire(delta)
	_tick_cold(delta)


func _tick_poison(delta: float) -> void:
	if _poison_time_left <= 0.0:
		_poison_dps = 0.0
		_poison_tick_timer = 0.0
		return
	_poison_time_left -= delta
	_poison_tick_timer += delta
	if _poison_tick_timer >= poison_tick_interval:
		_poison_tick_timer = 0.0
		if _owner and _owner.has_method("take_damage"):
			var info := DamageInfo.create(
				_poison_dps * poison_tick_interval,
				DamageType.Type.POISON
			)
			info.hit_position = _owner.global_position + Vector3(0, 1.2, 0)
			_owner.take_damage(info)
	if _poison_time_left <= 0.0:
		_poison_dps = 0.0


func _tick_fire(delta: float) -> void:
	if _fire_time_left <= 0.0:
		_fire_dps = 0.0
		_fire_tick_timer = 0.0
		return
	_fire_time_left -= delta
	_fire_tick_timer += delta
	if _fire_tick_timer >= fire_tick_interval:
		_fire_tick_timer = 0.0
		if _owner and _owner.has_method("take_damage"):
			var info := DamageInfo.create(
				_fire_dps * fire_tick_interval,
				DamageType.Type.FIRE
			)
			info.hit_position = _owner.global_position + Vector3(0, 1.2, 0)
			_owner.take_damage(info)
		_try_spread_fire()
	if _fire_time_left <= 0.0:
		_fire_dps = 0.0


func _try_spread_fire() -> void:
	if not _owner or not _owner.is_inside_tree():
		return
	var space_state := _owner.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = fire_spread_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), _owner.global_position)
	params.collision_mask = DamageResolver.ENEMY_MASK
	params.collide_with_areas = true
	for result in space_state.intersect_shape(params, 8):
		var collider := result.collider as Node
		if not collider:
			continue
		var other := DamageResolver.find_damageable(collider)
		if not other or other == _owner:
			continue
		var controller := other.get_node_or_null("StatusEffects") as StatusEffectController
		if controller:
			controller.apply_fire(_fire_dps * 0.65, _fire_source)


func _tick_cold(delta: float) -> void:
	if _cold_time_left <= 0.0:
		_cold_slow = 1.0
		return
	_cold_time_left -= delta
	if _cold_time_left <= 0.0:
		_cold_slow = 1.0
