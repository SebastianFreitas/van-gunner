class_name WeaponGenerator
extends RefCounted

## Pure create/roll API for generated guns. No flat damage mods.


static func create_weapon(
	level: int,
	force_definition_id: StringName = &"",
	force_mod_count: int = -1,
	rng: RandomNumberGenerator = null
) -> WeaponInstance:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var def_id := force_definition_id
	if def_id == &"":
		def_id = _pick_definition_id(rng)
	var def := WeaponCatalog.load_definition(def_id)
	if def == null:
		def_id = &"basic"
		def = WeaponCatalog.load_definition(def_id)

	var inst := WeaponInstance.new()
	inst.definition_id = def_id
	inst.weapon_level = maxi(level, 1)
	inst.grade_weight_interior = WeaponModCatalog.GRADE_WEIGHT_START
	inst.grade_weight_exterior = WeaponModCatalog.GRADE_WEIGHT_START
	inst.current_ammo = def.base_mag_size if def else 8

	var mod_count := force_mod_count
	if mod_count < 0:
		mod_count = WeaponModCatalog.roll_mod_count(rng)
	mod_count = clampi(mod_count, 0, WeaponModCatalog.MAX_MODS)

	for _i in mod_count:
		var rolled := roll_one_mod(inst, rng)
		if rolled:
			inst.mods.append(rolled)

	return inst


static func create_starter(level: int = 1) -> WeaponInstance:
	return create_weapon(level, &"basic", 0)


static func roll_one_mod(
	inst: WeaponInstance,
	rng: RandomNumberGenerator = null
) -> WeaponMod:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if not inst.can_add_mod():
		return null

	var grade := WeaponModCatalog.pick_grade(
		rng, inst.grade_weight_interior, inst.grade_weight_exterior
	)
	if grade == WeaponMod.Grade.INTERIOR:
		inst.grade_weight_interior = maxi(
			0, inst.grade_weight_interior - WeaponModCatalog.GRADE_WEIGHT_STEP
		)
	else:
		inst.grade_weight_exterior = maxi(
			0, inst.grade_weight_exterior - WeaponModCatalog.GRADE_WEIGHT_STEP
		)

	var exclude: Array[int] = []
	for mod in inst.mods:
		if mod.grade == grade:
			exclude.append(mod.mod_id)

	var def := WeaponModCatalog.pick_mod_def(rng, grade, exclude)
	if def == null:
		## Try the other grade if this one is exhausted.
		var other := (
			WeaponMod.Grade.EXTERIOR
			if grade == WeaponMod.Grade.INTERIOR
			else WeaponMod.Grade.INTERIOR
		)
		exclude.clear()
		for mod in inst.mods:
			if mod.grade == other:
				exclude.append(mod.mod_id)
		def = WeaponModCatalog.pick_mod_def(rng, other, exclude)
		grade = other
	if def == null:
		return null

	var rolled := WeaponModCatalog.roll_mod_value(rng, def, inst.weapon_level)
	var mod := WeaponMod.new()
	mod.grade = grade
	mod.mod_id = def.mod_id
	mod.display_name = def.display_name
	mod.operator = WeaponMod.Operator.INCREASED
	mod.value = float(rolled.value)
	mod.tier = int(rolled.tier)
	return mod


static func _pick_definition_id(rng: RandomNumberGenerator) -> StringName:
	var defs := WeaponCatalog.all_definitions()
	var total := 0
	for def in defs:
		total += maxi(def.drop_tickets, 0)
	if total <= 0:
		return &"basic"
	var roll := rng.randi_range(1, total)
	var acc := 0
	for def in defs:
		acc += maxi(def.drop_tickets, 0)
		if roll <= acc:
			return def.id
	return &"basic"
