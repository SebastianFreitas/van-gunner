class_name DamageInfo
extends RefCounted

var amount: float
var damage_type: DamageType.Type = DamageType.Type.NORMAL
var source: Node3D
var is_headshot := false
var hit_position := Vector3.ZERO
var explosion_radius := 1.8
## Extra headshot multiplier from weapon Critical Damage % mods (1.0 = none).
var headshot_bonus_mult := 1.0
## Channel % increased from weapon interior mods (applied in get_final_amount).
var weapon_phys_increased_pct := 0.0
var weapon_fire_increased_pct := 0.0
var weapon_cold_increased_pct := 0.0
var weapon_poison_increased_pct := 0.0


static func create(
	initial_amount: float,
	type: DamageType.Type = DamageType.Type.NORMAL,
	from: Node3D = null
) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = initial_amount
	info.damage_type = type
	info.source = from
	return info


static func create_from_gun_stats(
	stats: GunStats,
	from: Node3D = null,
	damage_override: float = -1.0
) -> DamageInfo:
	var dmg := stats.damage_per_shot if damage_override < 0.0 else damage_override
	var info := create(dmg, stats.damage_type, from)
	info.explosion_radius = stats.explosion_radius
	info.headshot_bonus_mult = 1.0 + stats.crit_damage_increased_pct / 100.0
	info.weapon_phys_increased_pct = stats.phys_damage_increased_pct
	info.weapon_fire_increased_pct = stats.fire_damage_increased_pct
	info.weapon_cold_increased_pct = stats.cold_damage_increased_pct
	info.weapon_poison_increased_pct = stats.poison_damage_increased_pct
	return info


func get_final_amount() -> float:
	var final_amount := amount
	## Weapon interior % increased — channel-aware, never flat adds.
	match damage_type:
		DamageType.Type.FIRE:
			final_amount *= 1.0 + weapon_fire_increased_pct / 100.0
		DamageType.Type.COLD:
			final_amount *= 1.0 + weapon_cold_increased_pct / 100.0
		DamageType.Type.POISON:
			final_amount *= 1.0 + weapon_poison_increased_pct / 100.0
		_:
			final_amount *= 1.0 + weapon_phys_increased_pct / 100.0
	if is_headshot:
		var hs := 2.5 if damage_type == DamageType.Type.LIGHTNING else 2.0
		final_amount *= hs * headshot_bonus_mult
	return final_amount


func duplicate_info() -> DamageInfo:
	var copy := DamageInfo.new()
	copy.amount = amount
	copy.damage_type = damage_type
	copy.source = source
	copy.is_headshot = is_headshot
	copy.hit_position = hit_position
	copy.explosion_radius = explosion_radius
	copy.headshot_bonus_mult = headshot_bonus_mult
	copy.weapon_phys_increased_pct = weapon_phys_increased_pct
	copy.weapon_fire_increased_pct = weapon_fire_increased_pct
	copy.weapon_cold_increased_pct = weapon_cold_increased_pct
	copy.weapon_poison_increased_pct = weapon_poison_increased_pct
	return copy
