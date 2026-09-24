class_name DamageInfo
extends RefCounted

## One hit: a single damage number plus where it landed. There are no damage
## types. Blasts and poison ticks are secondary hits: shares of the hit that
## caused them, never scaled again and never a trigger for bullet boons.

## A headshot doubles the hit. The old lightning 2.5 and crit-mod bonus are gone.
const HEADSHOT_MULT := 2.0

var amount: float
var source: Node3D
var is_headshot := false
var hit_position := Vector3.ZERO
var explosion_radius := 1.8
## True for blast splash and poison ticks.
var is_secondary := false


static func create(initial_amount: float, from: Node3D = null) -> DamageInfo:
	var info := DamageInfo.new()
	info.source = from
	info.amount = initial_amount
	return info


## Bullets start from the gun's damage_per_shot, which GunStatsController has
## already run through the boon traits. Nothing scales it again after this.
static func create_from_gun_stats(
	stats: GunStats,
	from: Node3D = null,
	damage_override: float = -1.0
) -> DamageInfo:
	var dmg := stats.damage_per_shot if damage_override < 0.0 else damage_override
	var info := create(dmg, from)
	info.explosion_radius = stats.explosion_radius
	return info


## The number the target takes.
func get_final_amount() -> float:
	if is_headshot:
		return amount * HEADSHOT_MULT
	return amount


func scale_amount(mult: float) -> void:
	amount *= mult
