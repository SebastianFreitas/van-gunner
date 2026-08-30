class_name GunStats
extends Resource

@export var fire_rate := 4.0
@export var damage_per_shot := 1.0
@export var bullet_speed := 140.0
@export var bullet_weight := 1.0
@export var bullet_size := 0.045
@export var reload_speed := 1.2
@export var mag_size := 12
@export var aim_range := 80.0
@export var damage_type: DamageType.Type = DamageType.Type.NORMAL
@export var explosion_radius := 1.8


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
	return copy
