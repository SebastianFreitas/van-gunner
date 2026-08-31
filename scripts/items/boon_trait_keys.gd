class_name BoonTraitKeys
extends RefCounted

## StringName keys for passive boon traits stored on BoonTraits.

# Fire
const FIRE_DAMAGE_BONUS := &"fire_damage_bonus"
const FIRE_AREA_MULT := &"fire_area_mult"
const FIRE_DAMAGE_MULT := &"fire_damage_mult"
const RICOCHET_EXPLOSIVE := &"ricochet_explosive"
const DELAYED_FIRE := &"delayed_fire"
const FIRE_PUSH_MULT := &"fire_push_mult"
const FIRE_PULL := &"fire_pull"
const EXTRA_POISON_TO_FIRE := &"extra_poison_to_fire"
const FIRE_DEATH := &"fire_death"

# Poison
const POISON_TICK_SPEED_MULT := &"poison_tick_speed_mult"
const POISON_DURATION_BONUS := &"poison_duration_bonus"
const POISON_FOLLOW := &"poison_follow"
const POISONED_ENEMY_DAMAGE_REDUCTION := &"poisoned_enemy_damage_reduction"
const POISONED_COLD_BONUS := &"poisoned_cold_bonus"
const VAMPIRIC_POISON_CHANCE := &"vampiric_poison_chance"
const INSTANT_POISON := &"instant_poison"
const POISON_EXPLOSIONS := &"poison_explosions"

# Cold
const FREEZE_CHANCE := &"freeze_chance"
const FREEZE_DURATION_BONUS := &"freeze_duration_bonus"
const PHYS_TO_COLD_ON_CRIT := &"phys_to_cold_on_crit"
const FROZEN_DAMAGE_MULT := &"frozen_damage_mult"
const COLD_PROJECTILE_COUNT := &"cold_projectile_count"
const COLD_SHATTERING_RICOCHET := &"cold_shattering_ricochet"
const COLD_SHATTER := &"cold_shatter"
const POISONED_CHILL_BONUS := &"poisoned_chill_bonus"

# Physical / general combat
const PHYS_DAMAGE_BONUS := &"phys_damage_bonus"
const DOUBLE_PHYS_COLD := &"double_phys_cold"
const TRIPLE_CRIT_PHYS := &"triple_crit_phys"
const FIRE_TO_PHYS_RATIO := &"fire_to_phys_ratio"
const RICOCHET_STACK_POWER := &"ricochet_stack_power"
const FROZEN_LOOT_BONUS := &"frozen_loot_bonus"

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
		# Fire
		FIRE_DAMAGE_BONUS: "Fire damage",
		FIRE_AREA_MULT: "Fire blast radius",
		FIRE_DAMAGE_MULT: "Fire damage",
		RICOCHET_EXPLOSIVE: "Explosive ricochets",
		DELAYED_FIRE: "Delayed fire blasts",
		FIRE_PUSH_MULT: "Fire explosion push",
		FIRE_PULL: "Fire explosion pull",
		EXTRA_POISON_TO_FIRE: "Bonus fire vs poisoned",
		FIRE_DEATH: "Death explosions",
		# Poison
		POISON_TICK_SPEED_MULT: "Poison tick speed",
		POISON_DURATION_BONUS: "Poison duration",
		POISON_FOLLOW: "Poison-seeking ricochets",
		POISONED_ENEMY_DAMAGE_REDUCTION: "Poisoned enemy damage",
		POISONED_COLD_BONUS: "Poison vs chilled/frozen",
		VAMPIRIC_POISON_CHANCE: "Heal on poisoned kill",
		INSTANT_POISON: "Instant poison damage",
		POISON_EXPLOSIONS: "Poison fire explosions",
		# Cold
		FREEZE_CHANCE: "Freeze chance",
		FREEZE_DURATION_BONUS: "Freeze duration",
		PHYS_TO_COLD_ON_CRIT: "Crits apply cold",
		FROZEN_DAMAGE_MULT: "Damage vs frozen/chilled",
		COLD_PROJECTILE_COUNT: "Extra cold shots",
		COLD_SHATTERING_RICOCHET: "Cold ricochet bursts",
		COLD_SHATTER: "Cold death shatter",
		POISONED_CHILL_BONUS: "Chill on poisoned",
		# Physical / general
		PHYS_DAMAGE_BONUS: "Physical damage",
		DOUBLE_PHYS_COLD: "Double phys vs frozen",
		TRIPLE_CRIT_PHYS: "Headshot phys bonus",
		FIRE_TO_PHYS_RATIO: "Fire converts to physical",
		RICOCHET_STACK_POWER: "Stacking ricochet damage",
		FROZEN_LOOT_BONUS: "Extra loot vs frozen",
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
		RICOCHET_EXPLOSIVE: "Fire explosions can ricochet once more",
		DELAYED_FIRE: "Fire blasts detonate after a short delay",
		FIRE_PULL: "Fire explosions pull enemies inward",
		FIRE_DEATH: "Enemies explode on death",
		POISON_FOLLOW: "Ricochets seek poisoned enemies",
		INSTANT_POISON: "Poison hits deal instant damage",
		POISON_EXPLOSIONS: "Fire explosions apply poison",
		PHYS_TO_COLD_ON_CRIT: "Headshots apply cold and freeze",
		COLD_SHATTERING_RICOCHET: "Ricochets spawn cold shards",
		COLD_SHATTER: "Cold kills release cold shards",
		DOUBLE_PHYS_COLD: "Double physical damage vs frozen",
		TRIPLE_CRIT_PHYS: "Headshots deal +50% physical damage",
		RICOCHET_STACK_POWER: "Each ricochet adds +15% damage",
	}
