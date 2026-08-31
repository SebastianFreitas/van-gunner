class_name StatusEffectController
extends Node

@export var poison_tick_interval := 0.5
@export var fire_tick_interval := 0.35
@export var fire_spread_radius := 1.4
@export var base_poison_duration := 4.0
@export var base_fire_duration := 3.5
@export var base_cold_duration := 2.5
@export var base_freeze_duration := 1.5

var _owner: Node3D
var _poison_dps := 0.0
var _poison_time_left := 0.0
var _fire_dps := 0.0
var _fire_time_left := 0.0
var _cold_slow := 1.0
var _cold_time_left := 0.0
var _frozen := false
var _freeze_time_left := 0.0
var _fire_source: Node3D
var _poison_tick_timer := 0.0
var _fire_tick_timer := 0.0
var _poison_duration_bonus := 0.0
var _poison_tick_speed_mult := 1.0
var _freeze_duration_bonus := 0.0
var _poisoned_chill_bonus := 0.0


func _ready() -> void:
	_owner = get_parent() as Node3D


func configure_from_traits(traits: BoonTraits) -> void:
	if not traits:
		return
	_poison_duration_bonus = traits.get_add(BoonTraitKeys.POISON_DURATION_BONUS)
	_poison_tick_speed_mult = traits.get_mult(BoonTraitKeys.POISON_TICK_SPEED_MULT)
	_freeze_duration_bonus = traits.get_add(BoonTraitKeys.FREEZE_DURATION_BONUS)
	_poisoned_chill_bonus = traits.get_add(BoonTraitKeys.POISONED_CHILL_BONUS)


func is_poisoned() -> bool:
	return _poison_time_left > 0.0


func get_poison_dps() -> float:
	return _poison_dps if is_poisoned() else 0.0


func get_poison_total_damage() -> float:
	if not is_poisoned():
		return 0.0
	var tick_interval := poison_tick_interval / maxf(_poison_tick_speed_mult, 0.1)
	var tick_count := _poison_time_left / tick_interval
	return _poison_dps * tick_interval * tick_count


func get_poison_total_damage_for_dps(dps: float) -> float:
	var tick_interval := poison_tick_interval / maxf(_poison_tick_speed_mult, 0.1)
	var duration := base_poison_duration + _poison_duration_bonus
	var tick_count := duration / tick_interval
	return dps * tick_interval * tick_count


func is_chilled() -> bool:
	return _cold_time_left > 0.0 and not _frozen


func is_frozen() -> bool:
	return _frozen


func apply_poison(dps: float, _source: Node3D = null) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_time_left = maxf(_poison_time_left, base_poison_duration + _poison_duration_bonus)


func apply_fire(dps: float, source: Node3D = null) -> void:
	_fire_dps = maxf(_fire_dps, dps)
	_fire_time_left = maxf(_fire_time_left, base_fire_duration)
	if source:
		_fire_source = source


func apply_cold(slow_strength: float, duration: float) -> void:
	var chill_bonus := 1.0
	if is_poisoned():
		chill_bonus += _poisoned_chill_bonus
	var effective_slow := slow_strength * chill_bonus
	_cold_slow = minf(_cold_slow, 1.0 - clampf(effective_slow, 0.0, 0.85))
	_cold_time_left = maxf(_cold_time_left, duration)


func try_apply_freeze(chance: float, duration_bonus: float = 0.0) -> void:
	if _frozen or chance <= 0.0:
		return
	if randf() > chance:
		return
	_frozen = true
	_freeze_time_left = base_freeze_duration + duration_bonus
	_cold_slow = 0.0


func get_attack_speed_multiplier() -> float:
	if _frozen:
		return 0.0
	return _cold_slow


func get_outgoing_damage_multiplier() -> float:
	if not is_poisoned():
		return 1.0
	var traits := _find_attacker_traits()
	if not traits:
		return 1.0
	var reduction := traits.get_add(BoonTraitKeys.POISONED_ENEMY_DAMAGE_REDUCTION)
	return maxf(0.0, 1.0 - reduction)


func _process(delta: float) -> void:
	_tick_poison(delta)
	_tick_fire(delta)
	_tick_cold(delta)
	_tick_freeze(delta)


func _tick_poison(delta: float) -> void:
	if _poison_time_left <= 0.0:
		_poison_dps = 0.0
		_poison_tick_timer = 0.0
		return
	_poison_time_left -= delta
	var tick_interval := poison_tick_interval / maxf(_poison_tick_speed_mult, 0.1)
	_poison_tick_timer += delta
	if _poison_tick_timer >= tick_interval:
		_poison_tick_timer = 0.0
		if _owner and _owner.has_method("take_damage"):
			var info := DamageInfo.create(
				_poison_dps * tick_interval,
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
		if not _frozen:
			_cold_slow = 1.0
		return
	_cold_time_left -= delta
	if _cold_time_left <= 0.0 and not _frozen:
		_cold_slow = 1.0


func _tick_freeze(delta: float) -> void:
	if not _frozen:
		return
	_freeze_time_left -= delta
	if _freeze_time_left <= 0.0:
		_frozen = false
		_cold_slow = 1.0


func _find_attacker_traits() -> BoonTraits:
	var player := _owner.get_tree().get_first_node_in_group(&"player") if _owner else null
	return BoonTraits.find_on(player)
