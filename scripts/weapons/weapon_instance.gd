class_name WeaponInstance
extends RefCounted

## Runtime generated gun: definition + mods + per-weapon ammo/reload state.

var uid: int = 0
var definition_id: StringName = &"basic"
var weapon_level: int = 1
var mods: Array[WeaponMod] = []
## Leftover grade bias for craft add-mod (interior, exterior).
var grade_weight_interior: int = WeaponModCatalog.GRADE_WEIGHT_START
var grade_weight_exterior: int = WeaponModCatalog.GRADE_WEIGHT_START
var current_ammo: int = -1
var is_reloading: bool = false
## Absolute msec when reload finishes; 0 if not reloading.
var reload_ends_at_msec: int = 0
## How many times Add Mod was used on this gun (craft cost multiplier).
var times_add_used: int = 0

static var _next_uid: int = 1


static func alloc_uid() -> int:
	var id := _next_uid
	_next_uid += 1
	return id


func _init() -> void:
	uid = alloc_uid()


func get_definition() -> WeaponDefinition:
	return WeaponCatalog.load_definition(definition_id)


func has_mod(grade: WeaponMod.Grade, mod_id: int) -> bool:
	for mod in mods:
		if mod.grade == grade and mod.mod_id == mod_id:
			return true
	return false


func can_add_mod() -> bool:
	return mods.size() < WeaponModCatalog.MAX_MODS


func display_name() -> String:
	var def := get_definition()
	if def:
		return def.display_name
	return String(definition_id)


func family_code() -> String:
	var def := get_definition()
	if def:
		return def.family_code()
	return "?"


func duplicate_instance() -> WeaponInstance:
	var copy := WeaponInstance.new()
	copy.uid = uid
	copy.definition_id = definition_id
	copy.weapon_level = weapon_level
	copy.mods.clear()
	for mod in mods:
		copy.mods.append(mod.duplicate_mod())
	copy.grade_weight_interior = grade_weight_interior
	copy.grade_weight_exterior = grade_weight_exterior
	copy.current_ammo = current_ammo
	copy.is_reloading = is_reloading
	copy.reload_ends_at_msec = reload_ends_at_msec
	copy.times_add_used = times_add_used
	return copy


func to_dict() -> Dictionary:
	var mod_dicts: Array = []
	for mod in mods:
		mod_dicts.append(mod.to_dict())
	return {
		"uid": uid,
		"definition_id": String(definition_id),
		"weapon_level": weapon_level,
		"mods": mod_dicts,
		"grade_weight_interior": grade_weight_interior,
		"grade_weight_exterior": grade_weight_exterior,
		"current_ammo": current_ammo,
		"is_reloading": is_reloading,
		"reload_ends_at_msec": reload_ends_at_msec,
		"times_add_used": times_add_used,
	}


static func from_dict(data: Dictionary) -> WeaponInstance:
	var inst := WeaponInstance.new()
	inst.uid = int(data.get("uid", alloc_uid()))
	inst.definition_id = StringName(str(data.get("definition_id", "basic")))
	inst.weapon_level = int(data.get("weapon_level", 1))
	inst.mods.clear()
	for entry in data.get("mods", []):
		if entry is Dictionary:
			inst.mods.append(WeaponMod.from_dict(entry))
	inst.grade_weight_interior = int(
		data.get("grade_weight_interior", WeaponModCatalog.GRADE_WEIGHT_START)
	)
	inst.grade_weight_exterior = int(
		data.get("grade_weight_exterior", WeaponModCatalog.GRADE_WEIGHT_START)
	)
	inst.current_ammo = int(data.get("current_ammo", -1))
	inst.is_reloading = bool(data.get("is_reloading", false))
	inst.reload_ends_at_msec = int(data.get("reload_ends_at_msec", 0))
	inst.times_add_used = int(data.get("times_add_used", 0))
	return inst
