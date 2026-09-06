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
## Channel % increased from weapon interior mods (baked into channels at create).
var weapon_phys_increased_pct := 0.0
var weapon_fire_increased_pct := 0.0
var weapon_cold_increased_pct := 0.0
var weapon_poison_increased_pct := 0.0
## Per-type amounts keyed by DamageType.Type. Dominant type syncs into amount/damage_type.
var channels: Dictionary = {}
## Poison/fire ticks must not re-apply status stacks.
var is_dot_tick := false


static func create(
	initial_amount: float,
	type: DamageType.Type = DamageType.Type.NORMAL,
	from: Node3D = null
) -> DamageInfo:
	var info := DamageInfo.new()
	info.source = from
	info.damage_type = type
	info.amount = initial_amount
	info.add_channel(type, initial_amount)
	return info


static func create_from_gun_stats(
	stats: GunStats,
	from: Node3D = null,
	damage_override: float = -1.0
) -> DamageInfo:
	var dmg := stats.damage_per_shot if damage_override < 0.0 else damage_override
	var info := DamageInfo.new()
	info.source = from
	info.explosion_radius = stats.explosion_radius
	info.headshot_bonus_mult = 1.0 + stats.crit_damage_increased_pct / 100.0
	info.weapon_phys_increased_pct = stats.phys_damage_increased_pct
	info.weapon_fire_increased_pct = stats.fire_damage_increased_pct
	info.weapon_cold_increased_pct = stats.cold_damage_increased_pct
	info.weapon_poison_increased_pct = stats.poison_damage_increased_pct
	info.add_channel(stats.damage_type, dmg)
	info.add_channel(
		DamageType.Type.NORMAL, dmg * stats.phys_damage_increased_pct / 100.0
	)
	info.add_channel(DamageType.Type.FIRE, dmg * stats.fire_damage_increased_pct / 100.0)
	info.add_channel(DamageType.Type.COLD, dmg * stats.cold_damage_increased_pct / 100.0)
	info.add_channel(
		DamageType.Type.POISON, dmg * stats.poison_damage_increased_pct / 100.0
	)
	return info


func add_channel(type: DamageType.Type, extra: float) -> void:
	if is_zero_approx(extra):
		return
	var next := get_channel(type) + extra
	if next <= 0.0001:
		channels.erase(type)
	else:
		channels[type] = next
	sync_dominant()


func set_channel(type: DamageType.Type, value: float) -> void:
	if value <= 0.0001:
		channels.erase(type)
	else:
		channels[type] = value
	sync_dominant()


func get_channel(type: DamageType.Type) -> float:
	return float(channels.get(type, 0.0))


func has_channel(type: DamageType.Type) -> bool:
	return get_channel(type) > 0.0001


func has_explosive() -> bool:
	return has_channel(DamageType.Type.FIRE) or has_channel(DamageType.Type.EXPLOSIVE)


func blast_amount() -> float:
	return get_channel(DamageType.Type.FIRE) + get_channel(DamageType.Type.EXPLOSIVE)


func total_channels() -> float:
	var total := 0.0
	for value in channels.values():
		total += float(value)
	return total


func dominant_type() -> DamageType.Type:
	return damage_type


func sync_dominant() -> void:
	var best_type: DamageType.Type = DamageType.Type.NORMAL
	var best := -1.0
	for key in channels.keys():
		var value := float(channels[key])
		if value > best:
			best = value
			best_type = key as DamageType.Type
	if best < 0.0:
		amount = 0.0
		return
	damage_type = best_type
	amount = best


func scale_channel(type: DamageType.Type, mult: float) -> void:
	set_channel(type, get_channel(type) * mult)


func scale_channels(mult: float) -> void:
	if is_equal_approx(mult, 1.0):
		return
	var keys: Array = channels.keys()
	for key in keys:
		set_channel(key as DamageType.Type, float(channels.get(key, 0.0)) * mult)


func replace_with_single_channel(type: DamageType.Type, value: float) -> void:
	channels.clear()
	add_channel(type, value)


func for_channel(type: DamageType.Type) -> DamageInfo:
	var copy := duplicate_info()
	copy.replace_with_single_channel(type, get_channel(type))
	copy.is_headshot = is_headshot
	copy.headshot_bonus_mult = headshot_bonus_mult
	copy.hit_position = hit_position
	copy.source = source
	copy.explosion_radius = explosion_radius
	copy.is_dot_tick = is_dot_tick
	return copy


func get_final_amount() -> float:
	var final_amount := total_channels()
	if final_amount <= 0.0:
		final_amount = amount
	if is_headshot:
		final_amount *= _headshot_mult()
	return final_amount


func get_final_channel(type: DamageType.Type) -> float:
	var value := get_channel(type)
	if is_headshot:
		value *= _headshot_mult()
	return value


func get_final_blast_amount() -> float:
	var value := blast_amount()
	if is_headshot:
		value *= _headshot_mult()
	return value


func _headshot_mult() -> float:
	var hs := 2.5 if has_channel(DamageType.Type.LIGHTNING) else 2.0
	return hs * headshot_bonus_mult


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
	copy.channels = channels.duplicate()
	copy.is_dot_tick = is_dot_tick
	return copy
