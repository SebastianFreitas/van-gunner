class_name WeaponModCatalog
extends RefCounted

## Interior/exterior mod pools + roll weights. No SPECIAL grade. No flat damage.

const MAX_MODS := 6

## Mod count tickets for counts 1..6.
const MOD_COUNT_TICKETS: Array[int] = [700, 900, 900, 700, 400, 80]

const GRADE_WEIGHT_START := 200
const GRADE_WEIGHT_STEP := 100

## Interior IDs (damage-adjacent % increased only).
const INT_PHYSICAL := 1
const INT_CRITICAL := 2
const INT_FIRE := 3
const INT_COLD := 4
const INT_POISON := 5

## Exterior IDs.
const EXT_MOVEMENT := 1
const EXT_RICOCHETS := 2
const EXT_FIRE_RATE := 3
const EXT_BULLET_SPEED := 4
const EXT_BULLET_SIZE := 5
const EXT_RELOAD_SPEED := 6
const EXT_MAG_SIZE := 7


class ModDef:
	var mod_id: int
	var display_name: String
	var lower: float
	var upper: float
	var weight: int

	func _init(
		p_id: int,
		p_name: String,
		p_lower: float,
		p_upper: float,
		p_weight: int
	) -> void:
		mod_id = p_id
		display_name = p_name
		lower = p_lower
		upper = p_upper
		weight = p_weight


static func interior_defs() -> Array:
	return [
		ModDef.new(INT_PHYSICAL, "Physical Damage", 2.0, 5.0, 1),
		ModDef.new(INT_CRITICAL, "Critical Damage", 2.0, 5.0, 1),
		ModDef.new(INT_FIRE, "Fire Damage", 2.0, 5.0, 1),
		ModDef.new(INT_COLD, "Cold Damage", 2.0, 5.0, 1),
		ModDef.new(INT_POISON, "Poison Damage", 2.0, 5.0, 1),
	]


static func exterior_defs() -> Array:
	return [
		ModDef.new(EXT_MOVEMENT, "Movement Speed", 1.0, 3.0, 3),
		ModDef.new(EXT_RICOCHETS, "Ricochets", 1.0, 6.0, 3),
		ModDef.new(EXT_FIRE_RATE, "Fire Rate", 1.0, 3.0, 2),
		ModDef.new(EXT_BULLET_SPEED, "Bullet Speed", 2.0, 5.0, 3),
		ModDef.new(EXT_BULLET_SIZE, "Bullet Size", 1.0, 5.0, 3),
		## Faster reloads → lower reload duration via WeaponStatsBuilder.
		ModDef.new(EXT_RELOAD_SPEED, "Reload Speed", 2.0, 5.0, 3),
		ModDef.new(EXT_MAG_SIZE, "Mag Size", 2.0, 5.0, 3),
	]


static func defs_for_grade(grade: WeaponMod.Grade) -> Array:
	if grade == WeaponMod.Grade.INTERIOR:
		return interior_defs()
	return exterior_defs()


static func find_def(grade: WeaponMod.Grade, mod_id: int) -> ModDef:
	for def in defs_for_grade(grade):
		if def.mod_id == mod_id:
			return def
	return null


static func roll_mod_count(rng: RandomNumberGenerator) -> int:
	var total := 0
	for t in MOD_COUNT_TICKETS:
		total += t
	var roll := rng.randi_range(1, total)
	var acc := 0
	for i in MOD_COUNT_TICKETS.size():
		acc += MOD_COUNT_TICKETS[i]
		if roll <= acc:
			return clampi(i + 1, 1, MAX_MODS)
	return 1


static func pick_grade(
	rng: RandomNumberGenerator,
	interior_weight: int,
	exterior_weight: int
) -> WeaponMod.Grade:
	var total := maxi(interior_weight, 0) + maxi(exterior_weight, 0)
	if total <= 0:
		return WeaponMod.Grade.INTERIOR if rng.randf() < 0.5 else WeaponMod.Grade.EXTERIOR
	var roll := rng.randi_range(1, total)
	if roll <= maxi(interior_weight, 0):
		return WeaponMod.Grade.INTERIOR
	return WeaponMod.Grade.EXTERIOR


static func pick_mod_def(
	rng: RandomNumberGenerator,
	grade: WeaponMod.Grade,
	exclude_ids: Array[int]
) -> ModDef:
	var pool: Array = []
	var total := 0
	for def in defs_for_grade(grade):
		if exclude_ids.has(def.mod_id):
			continue
		pool.append(def)
		total += def.weight
	if pool.is_empty() or total <= 0:
		return null
	var roll := rng.randi_range(1, total)
	var acc := 0
	for def in pool:
		acc += def.weight
		if roll <= acc:
			return def
	return pool[pool.size() - 1]


static func roll_mod_value(
	rng: RandomNumberGenerator,
	def: ModDef,
	weapon_level: int
) -> Dictionary:
	## Returns {tier, value}. Tier pool deepens with weapon_level > 2.
	var level_cap := 1
	if weapon_level > 2:
		level_cap = maxi(1, int(ceil(float(weapon_level) / 2.0)))
	level_cap = mini(level_cap, 5)
	var tier := _weighted_tier(rng, level_cap)
	var range_width := (def.upper - def.lower) * float(tier)
	var lo := def.lower + range_width
	var hi := def.upper + range_width
	var value := rng.randf_range(lo, hi)
	return {"tier": tier, "value": value}


static func _weighted_tier(rng: RandomNumberGenerator, level_cap: int) -> int:
	## Descending weight: prefer lower tiers.
	var total := 0
	var weights: Array[int] = []
	for t in range(1, level_cap + 1):
		var w := (level_cap + 1 - t) * 2
		weights.append(w)
		total += w
	var roll := rng.randi_range(1, maxi(total, 1))
	var acc := 0
	for i in weights.size():
		acc += weights[i]
		if roll <= acc:
			return i + 1
	return 1
