class_name WeaponStatsBuilder
extends RefCounted

## Builds seed GunStats from balance + weapon definition + weapon mods (no flats).
## Reload Speed % reduces duration: seconds / (1 + pct/100).


static func build(instance: WeaponInstance) -> GunStats:
	var stats := GunStats.new()
	stats.damage_per_shot = GameBalance.BASE_DAMAGE_PER_SHOT
	stats.fire_rate = GameBalance.BASE_FIRE_RATE
	stats.bullet_weight = 0.35
	stats.aim_range = 80.0
	stats.explosion_radius = 1.8
	stats.bounce_speed_retention = 0.6
	stats.bounce_damage_retention = 0.8
	stats.pellets_per_shot = 1
	stats.pellet_spread_degrees = 0.0
	stats.phys_damage_increased_pct = 0.0
	stats.crit_damage_increased_pct = 0.0
	stats.fire_damage_increased_pct = 0.0
	stats.cold_damage_increased_pct = 0.0
	stats.poison_damage_increased_pct = 0.0

	if instance == null:
		return stats

	var def := instance.get_definition()
	if def:
		stats.fire_rate = GameBalance.BASE_FIRE_RATE * def.fire_rate_mult
		stats.damage_per_shot = GameBalance.BASE_DAMAGE_PER_SHOT
		stats.bullet_speed = def.bullet_speed
		stats.bullet_size = def.bullet_size
		stats.max_bounces = def.max_bounces
		stats.mag_size = def.base_mag_size
		stats.reload_speed = def.base_reload_seconds
		stats.damage_type = def.to_damage_type()
		stats.pellets_per_shot = maxi(def.pellets_per_shot, 1)
		stats.pellet_spread_degrees = maxf(def.pellet_spread_degrees, 0.0)
	else:
		stats.bullet_speed = 100.0
		stats.bullet_size = 0.045
		stats.max_bounces = 1
		stats.mag_size = 8
		stats.reload_speed = 1.2

	_apply_mods(stats, instance.mods)
	return stats


static func _apply_mods(stats: GunStats, mods: Array[WeaponMod]) -> void:
	for mod in mods:
		if mod.operator != WeaponMod.Operator.INCREASED:
			continue
		var pct := mod.value
		var mult := 1.0 + pct / 100.0
		if mod.grade == WeaponMod.Grade.INTERIOR:
			match mod.mod_id:
				WeaponModCatalog.INT_PHYSICAL:
					stats.phys_damage_increased_pct += pct
				WeaponModCatalog.INT_CRITICAL:
					stats.crit_damage_increased_pct += pct
				WeaponModCatalog.INT_FIRE:
					stats.fire_damage_increased_pct += pct
				WeaponModCatalog.INT_COLD:
					stats.cold_damage_increased_pct += pct
				WeaponModCatalog.INT_POISON:
					stats.poison_damage_increased_pct += pct
		else:
			match mod.mod_id:
				WeaponModCatalog.EXT_RICOCHETS:
					## % toward bounce count: round(base * (1+pct/100))
					stats.max_bounces = maxi(0, roundi(float(stats.max_bounces) * mult))
				WeaponModCatalog.EXT_FIRE_RATE:
					stats.fire_rate *= mult
				WeaponModCatalog.EXT_BULLET_SPEED:
					stats.bullet_speed *= mult
				WeaponModCatalog.EXT_BULLET_SIZE:
					stats.bullet_size *= mult
				WeaponModCatalog.EXT_RELOAD_SPEED:
					## Faster reloads → lower duration (do not add % onto seconds).
					stats.reload_speed = stats.reload_speed / mult
				WeaponModCatalog.EXT_MAG_SIZE:
					stats.mag_size = maxi(1, roundi(float(stats.mag_size) * mult))
