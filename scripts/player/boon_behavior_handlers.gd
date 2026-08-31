## Concrete boon behavior handlers. Each inner class maps one trait to combat logic.
extends RefCounted


class DoublePhysColdBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.DOUBLE_PHYS_COLD

	func modify_outgoing_damage(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info.damage_type != DamageType.Type.NORMAL:
			return
		if ctx.status and ctx.status.is_frozen():
			ctx.damage_info.amount *= 2.0


class TripleCritPhysBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.TRIPLE_CRIT_PHYS

	func modify_outgoing_damage(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info.damage_type != DamageType.Type.NORMAL:
			return
		if ctx.damage_info.is_headshot:
			ctx.damage_info.amount *= 1.5


class PhysToColdCritBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.PHYS_TO_COLD_ON_CRIT

	func on_post_hit(ctx: BoonBehaviorContext) -> void:
		if not ctx.status or not ctx.damage_info:
			return
		if not ctx.damage_info.is_headshot or ctx.damage_info.damage_type != DamageType.Type.NORMAL:
			return
		ctx.status.apply_cold(0.55, 3.0)
		ctx.status.try_apply_freeze(
			ctx.traits.get_add(BoonTraitKeys.FREEZE_CHANCE) * 2.0,
			ctx.traits.get_add(BoonTraitKeys.FREEZE_DURATION_BONUS)
		)


class RicochetStackBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.RICOCHET_STACK_POWER

	func on_ricochet(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info:
			ctx.damage_info.amount *= 1.0 + float(ctx.bounce_count) * 0.15


class ColdShatteringRicochetBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.COLD_SHATTERING_RICOCHET

	func on_ricochet(ctx: BoonBehaviorContext) -> void:
		if not ctx.tree or not ctx.damage_info:
			return
		BoonCombat.spawn_cold_projectiles_from_direction(
			ctx.tree,
			ctx.projectile.global_position if ctx.projectile else Vector3.ZERO,
			ctx.velocity.normalized(),
			BoonCombat.RICOCHET_COLD_COUNT,
			ctx.damage_info.amount * 0.55
		)


class PoisonFollowBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.POISON_FOLLOW

	func on_ricochet(ctx: BoonBehaviorContext) -> void:
		if not ctx.tree or not ctx.projectile:
			return
		var follow_target := BoonCombat.find_poison_follow_target(
			ctx.tree,
			ctx.projectile.global_position,
			10.0
		)
		if not follow_target:
			return
		var aim := follow_target.global_position + Vector3(0.0, 1.0, 0.0) - ctx.projectile.global_position
		if aim.length_squared() > 0.001:
			ctx.velocity = aim.normalized() * ctx.velocity.length()


class DelayedFireBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.DELAYED_FIRE

	func should_delay_fire(ctx: BoonBehaviorContext) -> bool:
		return ctx.damage_info != null and ctx.damage_info.damage_type == DamageType.Type.FIRE


class RicochetExplosiveBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.RICOCHET_EXPLOSIVE

	func should_keep_alive_after_hit(ctx: BoonBehaviorContext) -> bool:
		if not ctx.projectile or not ctx.damage_info:
			return false
		return (
			ctx.damage_info.damage_type == DamageType.Type.FIRE
			and ctx.projectile.get_bounces_left() > 0
		)


class ColdShatterBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.COLD_SHATTER

	func on_enemy_death(ctx: BoonBehaviorContext) -> void:
		if ctx.last_damage_type != DamageType.Type.COLD or not ctx.tree:
			return
		BoonCombat.spawn_radial_cold_projectiles(
			ctx.tree,
			ctx.explosion_center,
			5,
			8.0
		)


class PoisonExplosionsBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.POISON_EXPLOSIONS

	func on_explosion_splash(ctx: BoonBehaviorContext) -> void:
		if not ctx.damage_info or ctx.damage_info.damage_type != DamageType.Type.FIRE:
			return
		var damageable := DamageResolver.find_damageable(ctx.target)
		if not damageable:
			return
		var poison_info := ctx.damage_info.duplicate_info()
		poison_info.damage_type = DamageType.Type.POISON
		poison_info.amount *= 0.35
		DamageResolver.apply_status_from_hit(poison_info, damageable)


class FireExplosionDisplacementBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return traits != null

	func on_explosion_displacement(ctx: BoonBehaviorContext) -> void:
		if not ctx.target is Node3D:
			return
		var push_mult := ctx.traits.get_mult(BoonTraitKeys.FIRE_PUSH_MULT)
		var offset := (ctx.target as Node3D).global_position - ctx.explosion_center
		offset.y = 0.0
		if offset.length_squared() < 0.001:
			return
		var direction := offset.normalized()
		if ctx.traits.has_flag(BoonTraitKeys.FIRE_PULL):
			direction = -direction
		(ctx.target as Node3D).global_position += direction * DamageResolver.EXPLOSION_PUSH_FORCE * push_mult


class InstantPoisonBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.INSTANT_POISON

	func on_status_apply(ctx: BoonBehaviorContext) -> bool:
		if not ctx.status or not ctx.damage_info or not ctx.target:
			return false
		var instant := ctx.status.get_poison_total_damage_for_dps(ctx.damage_info.amount * 0.35) * 0.5
		if instant <= 0.0:
			return true
		var poison_hit := ctx.damage_info.duplicate_info()
		poison_hit.amount = instant
		poison_hit.damage_type = DamageType.Type.POISON
		var damageable := DamageResolver.find_damageable(ctx.target)
		if damageable:
			damageable.take_damage(poison_hit)
		return true


class FireDeathBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.FIRE_DEATH

	func on_enemy_death(ctx: BoonBehaviorContext) -> void:
		if not ctx.space_state:
			return
		var info := DamageInfo.create(12.0, DamageType.Type.FIRE)
		info.explosion_radius = 2.2
		DamageResolver.apply_explosion(
			ctx.explosion_center,
			info.explosion_radius,
			info,
			ctx.space_state,
			[],
			ctx.traits
		)
