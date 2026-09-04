class_name WeaponMod
extends RefCounted

## One rolled gun mod. INCREASED % only — no flats (C1).

enum Grade { INTERIOR, EXTERIOR }
enum Operator { INCREASED }

var grade: Grade = Grade.INTERIOR
var mod_id: int = 0
var display_name := ""
var operator: Operator = Operator.INCREASED
## Rolled percent value (e.g. 3.5 means +3.5% increased).
var value: float = 0.0
var tier: int = 1


func duplicate_mod() -> WeaponMod:
	var copy := WeaponMod.new()
	copy.grade = grade
	copy.mod_id = mod_id
	copy.display_name = display_name
	copy.operator = operator
	copy.value = value
	copy.tier = tier
	return copy


func to_dict() -> Dictionary:
	return {
		"grade": int(grade),
		"mod_id": mod_id,
		"display_name": display_name,
		"operator": int(operator),
		"value": value,
		"tier": tier,
	}


static func from_dict(data: Dictionary) -> WeaponMod:
	var mod := WeaponMod.new()
	mod.grade = int(data.get("grade", 0)) as Grade
	mod.mod_id = int(data.get("mod_id", 0))
	mod.display_name = str(data.get("display_name", ""))
	mod.operator = int(data.get("operator", 0)) as Operator
	mod.value = float(data.get("value", 0.0))
	mod.tier = int(data.get("tier", 1))
	return mod


func format_line() -> String:
	return "%s +%.1f%%" % [display_name, value]
