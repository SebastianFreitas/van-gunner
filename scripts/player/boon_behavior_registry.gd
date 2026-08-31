class_name BoonBehaviorRegistry
extends RefCounted

## Dispatches combat events to registered boon behavior handlers.
## Stat handlers run before flag handlers so damage math stays ordered.

const _FlagHandlers := preload("res://scripts/player/boon_behavior_handlers.gd")
const _StatHandlers := preload("res://scripts/player/boon_stat_handlers.gd")

static var _handlers: Array[BoonBehavior] = []
static var _initialized := false


static func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_handlers = [
		# Stat-based (order matters for damage pipeline)
		_StatHandlers.FireDamageStatBehavior.new(),
		_StatHandlers.ExtraPoisonToFireStatBehavior.new(),
		_StatHandlers.FireToPhysStatBehavior.new(),
		_StatHandlers.PhysDamageStatBehavior.new(),
		_StatHandlers.PoisonedColdBonusStatBehavior.new(),
		_StatHandlers.FrozenDamageMultStatBehavior.new(),
		_StatHandlers.FireAreaMultStatBehavior.new(),
		_StatHandlers.ColdFreezeStatBehavior.new(),
		_StatHandlers.VampiricPoisonDeathStatBehavior.new(),
		_StatHandlers.FrozenLootDeathStatBehavior.new(),
		_StatHandlers.PoisonDurationStatBehavior.new(),
		_StatHandlers.PoisonTickSpeedStatBehavior.new(),
		_StatHandlers.PoisonedChillStatBehavior.new(),
		_StatHandlers.PoisonedEnemyDamageStatBehavior.new(),
		_StatHandlers.ColdProjectileStatBehavior.new(),
		# Flag-based
		_FlagHandlers.DoublePhysColdBehavior.new(),
		_FlagHandlers.TripleCritPhysBehavior.new(),
		_FlagHandlers.PhysToColdCritBehavior.new(),
		_FlagHandlers.RicochetStackBehavior.new(),
		_FlagHandlers.ColdShatteringRicochetBehavior.new(),
		_FlagHandlers.PoisonFollowBehavior.new(),
		_FlagHandlers.DelayedFireBehavior.new(),
		_FlagHandlers.RicochetExplosiveBehavior.new(),
		_FlagHandlers.ColdShatterBehavior.new(),
		_FlagHandlers.PoisonExplosionsBehavior.new(),
		_FlagHandlers.FireExplosionDisplacementBehavior.new(),
		_FlagHandlers.InstantPoisonBehavior.new(),
		_FlagHandlers.FireDeathBehavior.new(),
	]


static func register_handler(handler: BoonBehavior) -> void:
	ensure_initialized()
	if handler:
		_handlers.append(handler)


static func dispatch_modify_damage(ctx: BoonBehaviorContext) -> void:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return
	for handler in _handlers:
		if handler.is_active(ctx.traits):
			handler.modify_outgoing_damage(ctx)


static func dispatch_modify_explosion_radius(ctx: BoonBehaviorContext) -> void:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return
	for handler in _handlers:
		if handler.is_active(ctx.traits):
			handler.modify_explosion_radius(ctx)


static func dispatch_post_hit(ctx: BoonBehaviorContext) -> void:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return
	for handler in _handlers:
		if handler.is_active(ctx.traits):
			handler.on_post_hit(ctx)


static func dispatch_ricochet(ctx: BoonBehaviorContext) -> void:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return
	for handler in _handlers:
		if handler.is_active(ctx.traits):
			handler.on_ricochet(ctx)


static func dispatch_explosion_splash(ctx: BoonBehaviorContext) -> void:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return
	for handler in _handlers:
		if handler.is_active(ctx.traits):
			handler.on_explosion_splash(ctx)


static func dispatch_explosion_displacement(ctx: BoonBehaviorContext) -> void:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return
	var handled_targets: Array[int] = []
	for handler in _handlers:
		if not handler.is_active(ctx.traits):
			continue
		var target_id := ctx.target.get_instance_id() if ctx.target else 0
		if target_id in handled_targets:
			continue
		handler.on_explosion_displacement(ctx)
		if target_id != 0:
			handled_targets.append(target_id)


static func dispatch_should_delay_fire(ctx: BoonBehaviorContext) -> bool:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return false
	for handler in _handlers:
		if handler.is_active(ctx.traits) and handler.should_delay_fire(ctx):
			return true
	return false


static func dispatch_should_keep_alive_after_hit(ctx: BoonBehaviorContext) -> bool:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return false
	for handler in _handlers:
		if handler.is_active(ctx.traits) and handler.should_keep_alive_after_hit(ctx):
			return true
	return false


static func dispatch_enemy_death(ctx: BoonBehaviorContext) -> void:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return
	for handler in _handlers:
		if handler.is_active(ctx.traits):
			handler.on_enemy_death(ctx)


static func dispatch_status_apply(ctx: BoonBehaviorContext) -> bool:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return false
	for handler in _handlers:
		if handler.is_active(ctx.traits) and handler.on_status_apply(ctx):
			return true
	return false


static func dispatch_configure_status(ctx: BoonBehaviorContext) -> void:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return
	for handler in _handlers:
		if handler.is_active(ctx.traits):
			handler.configure_status(ctx)


static func dispatch_poisoned_damage_multiplier(ctx: BoonBehaviorContext) -> float:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return 1.0
	var multiplier := 1.0
	for handler in _handlers:
		if handler.is_active(ctx.traits):
			multiplier = minf(multiplier, handler.get_poisoned_damage_multiplier(ctx))
	return multiplier


static func dispatch_bonus_projectiles(ctx: BoonBehaviorContext) -> void:
	ensure_initialized()
	if not ctx or not ctx.traits:
		return
	for handler in _handlers:
		if handler.is_active(ctx.traits):
			handler.spawn_bonus_projectiles(ctx)
