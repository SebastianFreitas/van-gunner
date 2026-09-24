class_name BoonTraitKeys
extends RefCounted

## StringName keys for passive boon traits stored on BoonTraits.

# General combat
const RICOCHET_STACK_POWER := &"ricochet_stack_power"

# Bullet boons. The add value is the share of the hit each bullet turns into a
# blast, a poison stack or a slow; the owner tunes it on the boon's .tres.
const EXPLOSIVE_ROUNDS := &"explosive_rounds"
const POISON_ROUNDS := &"poison_rounds"
const COLD_ROUNDS := &"cold_rounds"

# Gun stats (stored on BoonTraits, applied by GunStatsController)
const GUN_FIRE_RATE := &"gun_fire_rate"
const GUN_DAMAGE_PER_SHOT := &"gun_damage_per_shot"
const GUN_BULLET_SPEED := &"gun_bullet_speed"
const GUN_BULLET_WEIGHT := &"gun_bullet_weight"
const GUN_BULLET_SIZE := &"gun_bullet_size"
const GUN_RELOAD_SPEED := &"gun_reload_speed"
const GUN_MAG_SIZE := &"gun_mag_size"
const GUN_AIM_RANGE := &"gun_aim_range"
const GUN_EXPLOSION_RADIUS := &"gun_explosion_radius"
const GUN_MAX_BOUNCES := &"gun_max_bounces"
const GUN_BOUNCE_SPEED_RETENTION := &"gun_bounce_speed_retention"
const GUN_BOUNCE_DAMAGE_RETENTION := &"gun_bounce_damage_retention"


static func gun_stat_key(stat_name: StringName) -> StringName:
	return StringName("gun_%s" % stat_name)


static func all_trait_labels() -> Dictionary:
	return {
		# General combat
		RICOCHET_STACK_POWER: "Stacking ricochet damage",
		# Bullet boons
		EXPLOSIVE_ROUNDS: "Blast share of the hit",
		POISON_ROUNDS: "Poison share of the hit",
		COLD_ROUNDS: "Slow strength",
		# Gun stats
		GUN_FIRE_RATE: "Fire rate",
		GUN_DAMAGE_PER_SHOT: "Damage per shot",
		GUN_BULLET_SPEED: "Bullet speed",
		GUN_BULLET_WEIGHT: "Bullet weight",
		GUN_BULLET_SIZE: "Bullet size",
		GUN_RELOAD_SPEED: "Reload time",
		GUN_MAG_SIZE: "Magazine size",
		GUN_AIM_RANGE: "Aim range",
		GUN_EXPLOSION_RADIUS: "Blast radius",
		GUN_MAX_BOUNCES: "Ricochets",
		GUN_BOUNCE_SPEED_RETENTION: "Bounce speed kept",
		GUN_BOUNCE_DAMAGE_RETENTION: "Bounce damage kept",
	}


static func flag_trait_labels() -> Dictionary:
	return {
		RICOCHET_STACK_POWER: "Each ricochet adds +15% damage",
	}
