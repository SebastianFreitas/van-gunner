extends RefCounted
## Concrete boon behavior handlers. Each inner class maps one trait to combat logic.


class RicochetStackBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.RICOCHET_STACK_POWER

	func on_ricochet(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info:
			ctx.damage_info.scale_amount(1.0 + float(ctx.bounce_count) * 0.15)


## Explosive Rounds: a bullet's first contact adds a blast at the contact point
## worth a share of the hit. Projectile stops the bullet ricocheting while the
## trait is on, and splash is secondary, so a blast can never chain another one.
class ExplosiveRoundsBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.EXPLOSIVE_ROUNDS)

	func on_post_hit(ctx: BoonBehaviorContext) -> void:
		if not ctx.damage_info or not ctx.space_state:
			return
		var share := ctx.traits.get_add(BoonTraitKeys.EXPLOSIVE_ROUNDS)
		var blast := DamageInfo.create(
			ctx.damage_info.get_final_amount() * share, ctx.damage_info.source
		)
		blast.hit_position = ctx.damage_info.hit_position
		blast.explosion_radius = ctx.damage_info.explosion_radius
		DamageResolver.apply_explosion(
			ctx.damage_info.hit_position,
			ctx.damage_info.explosion_radius,
			blast,
			ctx.space_state,
			ctx.exclude,
			ctx.traits
		)


## Poison Rounds: every bullet hit on an enemy adds a poison stack worth a share
## of the hit. A blast does the same with the damage each enemy took from it.
class PoisonRoundsBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.POISON_ROUNDS)

	func on_post_hit(ctx: BoonBehaviorContext) -> void:
		_poison(ctx)

	func on_explosion_splash(ctx: BoonBehaviorContext) -> void:
		_poison(ctx)

	func _poison(ctx: BoonBehaviorContext) -> void:
		if not ctx.status or not ctx.damage_info:
			return
		var share := ctx.traits.get_add(BoonTraitKeys.POISON_ROUNDS)
		ctx.status.apply_poison_stack(
			ctx.damage_info.get_final_amount() * share, ctx.damage_info.source
		)


## Cold Rounds: every bullet hit or blast slows the enemy's movement and attacks
## by the trait's share for the cold duration. A new hit refreshes the timer.
class ColdRoundsBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.COLD_ROUNDS)

	func on_post_hit(ctx: BoonBehaviorContext) -> void:
		_slow(ctx)

	func on_explosion_splash(ctx: BoonBehaviorContext) -> void:
		_slow(ctx)

	func _slow(ctx: BoonBehaviorContext) -> void:
		if not ctx.status:
			return
		ctx.status.apply_cold(
			ctx.traits.get_add(BoonTraitKeys.COLD_ROUNDS), GameBalance.COLD_SLOW_DURATION
		)
