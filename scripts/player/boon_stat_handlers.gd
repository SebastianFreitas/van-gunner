## Stat-based boon behavior handlers (add/mult traits, no flags required).
extends RefCounted


class FireDamageStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return (
			trait_add_active(traits, BoonTraitKeys.FIRE_DAMAGE_BONUS)
			or trait_mult_active(traits, BoonTraitKeys.FIRE_DAMAGE_MULT)
		)

	func modify_outgoing_damage(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info.damage_type != DamageType.Type.FIRE:
			return
		ctx.damage_info.amount += ctx.traits.get_add(BoonTraitKeys.FIRE_DAMAGE_BONUS)
		ctx.damage_info.amount *= ctx.traits.get_mult(BoonTraitKeys.FIRE_DAMAGE_MULT)


class ExtraPoisonToFireStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.EXTRA_POISON_TO_FIRE)

	func modify_outgoing_damage(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info.damage_type != DamageType.Type.FIRE:
			return
		if not ctx.status or not ctx.status.is_poisoned():
			return
		var poison_bonus := ctx.traits.get_add(BoonTraitKeys.EXTRA_POISON_TO_FIRE)
		if poison_bonus > 0.0:
			ctx.damage_info.amount += ctx.status.get_poison_dps() * poison_bonus


class FireToPhysStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.FIRE_TO_PHYS_RATIO)

	func modify_outgoing_damage(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info.damage_type != DamageType.Type.FIRE:
			return
		var ratio := clampf(ctx.traits.get_add(BoonTraitKeys.FIRE_TO_PHYS_RATIO), 0.0, 1.0)
		if ratio <= 0.0:
			return
		var converted := ctx.damage_info.amount * ratio
		ctx.damage_info.amount -= converted
		if converted <= 0.0:
			return
		if is_zero_approx(ctx.damage_info.amount):
			ctx.damage_info.amount = converted
			ctx.damage_info.damage_type = DamageType.Type.NORMAL
		else:
			ctx.bonus_phys += converted


class PhysDamageStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.PHYS_DAMAGE_BONUS)

	func modify_outgoing_damage(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info.damage_type != DamageType.Type.NORMAL:
			return
		ctx.damage_info.amount += ctx.traits.get_add(BoonTraitKeys.PHYS_DAMAGE_BONUS)


class PoisonedColdBonusStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.POISONED_COLD_BONUS)

	func modify_outgoing_damage(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info.damage_type != DamageType.Type.POISON or not ctx.status:
			return
		if ctx.status.is_frozen() or ctx.status.is_chilled():
			ctx.damage_info.amount *= 1.0 + ctx.traits.get_add(BoonTraitKeys.POISONED_COLD_BONUS)


class FrozenDamageMultStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_mult_active(traits, BoonTraitKeys.FROZEN_DAMAGE_MULT)

	func modify_outgoing_damage(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info.damage_type != DamageType.Type.COLD or not ctx.status:
			return
		if ctx.status.is_frozen() or ctx.status.is_chilled():
			ctx.damage_info.amount *= ctx.traits.get_mult(BoonTraitKeys.FROZEN_DAMAGE_MULT)


class FireAreaMultStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_mult_active(traits, BoonTraitKeys.FIRE_AREA_MULT)

	func modify_explosion_radius(ctx: BoonBehaviorContext) -> void:
		if not ctx.damage_info or ctx.damage_info.damage_type != DamageType.Type.FIRE:
			return
		ctx.explosion_radius *= ctx.traits.get_mult(BoonTraitKeys.FIRE_AREA_MULT)


class ColdFreezeStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return (
			trait_add_active(traits, BoonTraitKeys.FREEZE_CHANCE)
			or trait_add_active(traits, BoonTraitKeys.FREEZE_DURATION_BONUS)
		)

	func on_post_hit(ctx: BoonBehaviorContext) -> void:
		if not ctx.status or not ctx.damage_info:
			return
		if ctx.damage_info.damage_type != DamageType.Type.COLD:
			return
		ctx.status.try_apply_freeze(
			ctx.traits.get_add(BoonTraitKeys.FREEZE_CHANCE),
			ctx.traits.get_add(BoonTraitKeys.FREEZE_DURATION_BONUS)
		)


class VampiricPoisonDeathStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.VAMPIRIC_POISON_CHANCE)

	func on_enemy_death(ctx: BoonBehaviorContext) -> void:
		if not ctx.status or not ctx.status.is_poisoned():
			return
		var heal_chance := ctx.traits.get_add(BoonTraitKeys.VAMPIRIC_POISON_CHANCE)
		if heal_chance > 0.0 and randf() <= heal_chance:
			BoonCombat.spawn_heal_pickup(ctx.explosion_center, ctx.loot_container)


class FrozenLootDeathStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.FROZEN_LOOT_BONUS)

	func on_enemy_death(ctx: BoonBehaviorContext) -> void:
		if not ctx.status or not (ctx.status.is_frozen() or ctx.status.is_chilled()):
			return
		var extra_drops := int(ctx.traits.get_add(BoonTraitKeys.FROZEN_LOOT_BONUS))
		if extra_drops <= 0 or not ctx.enemy:
			return
		var loot_drop := ctx.enemy.get_node_or_null("LootDrop") as LootDropComponent
		if not loot_drop:
			return
		for _i in extra_drops:
			loot_drop.spawn_bonus_drop(ctx.explosion_center, ctx.loot_container)


class PoisonDurationStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.POISON_DURATION_BONUS)

	func configure_status(ctx: BoonBehaviorContext) -> void:
		ctx.poison_duration_bonus += ctx.traits.get_add(BoonTraitKeys.POISON_DURATION_BONUS)


class PoisonTickSpeedStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_mult_active(traits, BoonTraitKeys.POISON_TICK_SPEED_MULT)

	func configure_status(ctx: BoonBehaviorContext) -> void:
		ctx.poison_tick_speed_mult *= ctx.traits.get_mult(BoonTraitKeys.POISON_TICK_SPEED_MULT)


class PoisonedChillStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.POISONED_CHILL_BONUS)

	func configure_status(ctx: BoonBehaviorContext) -> void:
		ctx.poisoned_chill_bonus += ctx.traits.get_add(BoonTraitKeys.POISONED_CHILL_BONUS)


class PoisonedEnemyDamageStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.POISONED_ENEMY_DAMAGE_REDUCTION)

	func get_poisoned_damage_multiplier(ctx: BoonBehaviorContext) -> float:
		var reduction := ctx.traits.get_add(BoonTraitKeys.POISONED_ENEMY_DAMAGE_REDUCTION)
		return maxf(0.0, 1.0 - reduction)


class ColdProjectileStatBehavior extends BoonBehavior:
	func is_active(traits: BoonTraits) -> bool:
		return trait_add_active(traits, BoonTraitKeys.COLD_PROJECTILE_COUNT)

	func spawn_bonus_projectiles(ctx: BoonBehaviorContext) -> void:
		if not ctx.gun_stats:
			return
		var extra_cold := int(ctx.traits.get_add(BoonTraitKeys.COLD_PROJECTILE_COUNT))
		for i in extra_cold:
			var spread := deg_to_rad(6.0 * (i + 1))
			var spread_dir := ctx.fire_direction.rotated(
				Vector3.UP,
				spread if i % 2 == 0 else -spread
			)
			var cold_stats := ctx.gun_stats.duplicate_stats()
			cold_stats.damage_type = DamageType.Type.COLD
			cold_stats.damage_per_shot *= 0.65
			BoonCombat.spawn_projectile(
				ctx.tree,
				ctx.fire_origin,
				spread_dir,
				cold_stats,
				ctx.projectile_shooter
			)
