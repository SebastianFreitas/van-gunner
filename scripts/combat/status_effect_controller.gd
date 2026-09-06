class_name StatusEffectController
extends Node

@export var poison_tick_interval := 0.5
@export var fire_tick_interval := 0.35
@export var fire_spread_radius := 1.4
@export var base_poison_duration := 2.0
@export var base_fire_duration := 3.5
@export var base_cold_duration := 2.5
@export var base_freeze_duration := 1.5

class PoisonStack:
	var remaining := 0.0
	var time_left := 0.0

var _owner: Node3D
var _poison_stacks: Array = []
var _poison_pending := 0.0
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
var _poisoned_chill_bonus := 0.0


func _ready() -> void:
	_owner = get_parent() as Node3D


func configure_from_traits(traits: BoonTraits) -> void:
	_poison_duration_bonus = 0.0
	_poison_tick_speed_mult = 1.0
	_poisoned_chill_bonus = 0.0
	if not traits:
		return
	var ctx := BoonBehaviorContext.new()
	ctx.traits = traits
	BoonBehaviorRegistry.dispatch_configure_status(ctx)
	_poison_duration_bonus = ctx.poison_duration_bonus
	_poison_tick_speed_mult = ctx.poison_tick_speed_mult
	_poisoned_chill_bonus = ctx.poisoned_chill_bonus


func is_poisoned() -> bool:
	return not _poison_stacks.is_empty()


func get_poison_dps() -> float:
	if not is_poisoned():
		return 0.0
	var dps := 0.0
	for stack in _poison_stacks:
		var poison := stack as PoisonStack
		if poison.time_left > 0.001:
			dps += poison.remaining / poison.time_left
	return dps


func get_poison_total_damage() -> float:
	var total := 0.0
	for stack in _poison_stacks:
		total += (stack as PoisonStack).remaining
	return total


func get_poison_total_damage_for_dps(dps: float) -> float:
	return dps * _poison_stack_duration()


func is_chilled() -> bool:
	return _cold_time_left > 0.0 and not _frozen


func is_frozen() -> bool:
	return _frozen


func apply_poison(dps: float, source: Node3D = null) -> void:
	apply_poison_stack(dps * _poison_stack_duration(), source)


func apply_poison_stack(total: float, _source: Node3D = null) -> void:
	if total <= 0.0:
		return
	var stack := PoisonStack.new()
	stack.remaining = total
	stack.time_left = _poison_stack_duration()
	_poison_stacks.append(stack)


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


func get_move_speed_multiplier() -> float:
	return get_attack_speed_multiplier()


func get_outgoing_damage_multiplier() -> float:
	if not is_poisoned():
		return 1.0
	var traits := _find_attacker_traits()
	return BoonCombat.get_poisoned_damage_multiplier(traits)


func _poison_stack_duration() -> float:
	return (base_poison_duration + _poison_duration_bonus) / maxf(_poison_tick_speed_mult, 0.1)


func _process(delta: float) -> void:
	_tick_poison(delta)
	_tick_fire(delta)
	_tick_cold(delta)
	_tick_freeze(delta)


func _tick_poison(delta: float) -> void:
	if _poison_stacks.is_empty():
		_poison_pending = 0.0
		_poison_tick_timer = 0.0
		return
	var i := 0
	while i < _poison_stacks.size():
		var stack := _poison_stacks[i] as PoisonStack
		var dt := minf(delta, stack.time_left)
		if stack.time_left <= 0.001:
			_poison_pending += stack.remaining
			_poison_stacks.remove_at(i)
			continue
		var dealt := stack.remaining * (dt / stack.time_left)
		stack.remaining -= dealt
		stack.time_left -= dt
		_poison_pending += dealt
		if stack.time_left <= 0.001 or stack.remaining <= 0.001:
			_poison_pending += maxf(stack.remaining, 0.0)
			_poison_stacks.remove_at(i)
		else:
			i += 1
	_poison_tick_timer += delta
	var tick_interval := poison_tick_interval / maxf(_poison_tick_speed_mult, 0.1)
	if _poison_tick_timer >= tick_interval or _poison_stacks.is_empty():
		_poison_tick_timer = 0.0
		_flush_poison_pending()


func _flush_poison_pending() -> void:
	if _poison_pending <= 0.001 or _owner == null or not _owner.has_method("take_damage"):
		_poison_pending = 0.0
		return
	var info := DamageInfo.create(_poison_pending, DamageType.Type.POISON)
	info.is_dot_tick = true
	info.hit_position = _owner.global_position + Vector3(0, 1.2, 0)
	var traits := _find_attacker_traits()
	if traits:
		BoonCombat.modify_outgoing_damage(info, traits, _owner)
	ActCardCombat.modify_outgoing_damage(info, _owner)
	_owner.take_damage(info)
	_poison_pending = 0.0


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
			info.is_dot_tick = true
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
