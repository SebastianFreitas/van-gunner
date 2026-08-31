class_name BoonBehavior
extends RefCounted

## Base class for boon combat behaviors.
## Flag behaviors override trait_key(). Stat behaviors override is_active().


func trait_key() -> StringName:
	return &""


func is_active(traits: BoonTraits) -> bool:
	return traits != null and trait_key() != &"" and traits.has_flag(trait_key())


static func trait_add_active(traits: BoonTraits, key: StringName) -> bool:
	return traits != null and not is_zero_approx(traits.get_add(key))


static func trait_mult_active(traits: BoonTraits, key: StringName) -> bool:
	return traits != null and not is_equal_approx(traits.get_mult(key), 1.0)


func modify_outgoing_damage(_ctx: BoonBehaviorContext) -> void:
	pass


func modify_explosion_radius(_ctx: BoonBehaviorContext) -> void:
	pass


func on_post_hit(_ctx: BoonBehaviorContext) -> void:
	pass


func on_ricochet(_ctx: BoonBehaviorContext) -> void:
	pass


func on_explosion_splash(_ctx: BoonBehaviorContext) -> void:
	pass


func on_explosion_displacement(_ctx: BoonBehaviorContext) -> void:
	pass


func should_delay_fire(_ctx: BoonBehaviorContext) -> bool:
	return false


func should_keep_alive_after_hit(_ctx: BoonBehaviorContext) -> bool:
	return false


func on_enemy_death(_ctx: BoonBehaviorContext) -> void:
	pass


func configure_status(_ctx: BoonBehaviorContext) -> void:
	pass


func get_poisoned_damage_multiplier(_ctx: BoonBehaviorContext) -> float:
	return 1.0


func spawn_bonus_projectiles(_ctx: BoonBehaviorContext) -> void:
	pass


## Return true to skip default status application for this hit.
func on_status_apply(_ctx: BoonBehaviorContext) -> bool:
	return false
