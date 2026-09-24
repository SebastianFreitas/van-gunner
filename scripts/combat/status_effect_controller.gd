class_name StatusEffectController
extends Node

## Poison stacks and the cold slow on one enemy. There is no burn and no freeze:
## fire is a blast and cold only slows. Durations and the tick live in GameBalance.

class PoisonStack:
	var remaining := 0.0
	var time_left := 0.0

var _owner: Node3D
var _poison_stacks: Array = []
var _poison_pending := 0.0
var _cold_slow := 1.0
var _cold_time_left := 0.0
var _poison_tick_timer := 0.0


func _ready() -> void:
	_owner = get_parent() as Node3D


## Hook for boons that tune status effects through configure_status; none do today.
func configure_from_traits(traits: BoonTraits) -> void:
	if not traits:
		return
	var ctx := BoonBehaviorContext.new()
	ctx.traits = traits
	BoonBehaviorRegistry.dispatch_configure_status(ctx)


func is_poisoned() -> bool:
	return not _poison_stacks.is_empty()


## Stacks run side by side; each one drains over the poison duration.
func apply_poison_stack(total: float, _source: Node3D = null) -> void:
	if total <= 0.0:
		return
	var stack := PoisonStack.new()
	stack.remaining = total
	stack.time_left = _poison_stack_duration()
	_poison_stacks.append(stack)


## The strongest slow wins and a new hit refreshes the duration.
func apply_cold(slow_strength: float, duration: float) -> void:
	_cold_slow = minf(_cold_slow, 1.0 - clampf(slow_strength, 0.0, 0.85))
	_cold_time_left = maxf(_cold_time_left, duration)


func get_attack_speed_multiplier() -> float:
	return _cold_slow


func get_move_speed_multiplier() -> float:
	return get_attack_speed_multiplier()


func get_outgoing_damage_multiplier() -> float:
	if not is_poisoned():
		return 1.0
	var traits := _find_attacker_traits()
	return BoonCombat.get_poisoned_damage_multiplier(traits)


func _poison_stack_duration() -> float:
	return GameBalance.POISON_DURATION


func _process(delta: float) -> void:
	_tick_poison(delta)
	_tick_cold(delta)


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
	if _poison_tick_timer >= GameBalance.POISON_TICK_INTERVAL or _poison_stacks.is_empty():
		_poison_tick_timer = 0.0
		_flush_poison_pending()


func _flush_poison_pending() -> void:
	if _poison_pending <= 0.001 or _owner == null or not _owner.has_method("take_damage"):
		_poison_pending = 0.0
		return
	## Ticks are shares of the hit that poisoned the enemy; nothing scales them again.
	var info := DamageInfo.create(_poison_pending)
	info.is_secondary = true
	info.hit_position = _owner.global_position + Vector3(0, 1.2, 0)
	_owner.take_damage(info)
	_poison_pending = 0.0


func _tick_cold(delta: float) -> void:
	if _cold_time_left <= 0.0:
		_cold_slow = 1.0
		return
	_cold_time_left -= delta
	if _cold_time_left <= 0.0:
		_cold_slow = 1.0


func _find_attacker_traits() -> BoonTraits:
	var player := _owner.get_tree().get_first_node_in_group(&"player") if _owner else null
	return BoonTraits.find_on(player)
