class_name GunStats
extends Resource

## Defaults match game_balance.tres; GunStatsController still re-seeds from GameBalance.
@export var fire_rate := 1.0
@export var damage_per_shot := 1.0
@export var bullet_speed := 140.0
@export var bullet_weight := 1.0
@export var bullet_size := 0.045
@export var reload_speed := 1.2
@export var mag_size := 12
@export var aim_range := 80.0
@export var damage_type: DamageType.Type = DamageType.Type.NORMAL
@export var explosion_radius := 1.8

@export_group("Ricochet")
## How many times a bullet may bounce off world geometry before it dies.
@export var max_bounces := 0
## Share of speed a bullet keeps after each bounce.
@export_range(0.05, 1.0, 0.01) var bounce_speed_retention := 0.6
## Share of damage a bullet keeps after each bounce.
@export_range(0.0, 1.0, 0.01) var bounce_damage_retention := 0.8

@export_group("Weapon identity")
## Shotgun-style multi-projectile. Damage is split across pellets in GunController.
@export var pellets_per_shot := 1
@export var pellet_spread_degrees := 0.0

@export_group("Weapon mod damage %")
## Applied in DamageInfo — never as flat damage_per_shot.
@export var phys_damage_increased_pct := 0.0
@export var crit_damage_increased_pct := 0.0
@export var fire_damage_increased_pct := 0.0
@export var cold_damage_increased_pct := 0.0
@export var poison_damage_increased_pct := 0.0


func duplicate_stats() -> GunStats:
	var copy := GunStats.new()
	copy.fire_rate = fire_rate
	copy.damage_per_shot = damage_per_shot
	copy.bullet_speed = bullet_speed
	copy.bullet_weight = bullet_weight
	copy.bullet_size = bullet_size
	copy.reload_speed = reload_speed
	copy.mag_size = mag_size
	copy.aim_range = aim_range
	copy.damage_type = damage_type
	copy.explosion_radius = explosion_radius
	copy.max_bounces = max_bounces
	copy.bounce_speed_retention = bounce_speed_retention
	copy.bounce_damage_retention = bounce_damage_retention
	copy.pellets_per_shot = pellets_per_shot
	copy.pellet_spread_degrees = pellet_spread_degrees
	copy.phys_damage_increased_pct = phys_damage_increased_pct
	copy.crit_damage_increased_pct = crit_damage_increased_pct
	copy.fire_damage_increased_pct = fire_damage_increased_pct
	copy.cold_damage_increased_pct = cold_damage_increased_pct
	copy.poison_damage_increased_pct = poison_damage_increased_pct
	return copy
