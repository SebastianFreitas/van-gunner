class_name VitalMaxHealthEffect
extends SkillNodeEffect

## Raises interior-machine max HP. Empty vital_id applies `amount` to each of
## bench, hopper, fuse_box, and cab_relay.

@export var vital_id: StringName = &""
@export var amount := 0.0


func describe() -> String:
	if is_zero_approx(amount):
		return ""
	var n := ItemDescriber.format_number(amount)
	if vital_id == &"":
		return "+%s max HP to every van machine" % n
	return "+%s max HP to %s" % [n, _vital_label()]


func vital_max_bonus(query_id: StringName) -> float:
	if is_zero_approx(amount) or query_id == &"":
		return 0.0
	if vital_id == &"" or vital_id == query_id:
		return amount
	return 0.0


func _vital_label() -> String:
	match vital_id:
		&"bench":
			return "the crafting bench"
		&"hopper":
			return "the loot hopper"
		&"fuse_box":
			return "the fuse box"
		&"cab_relay":
			return "the cab relay"
		_:
			return String(vital_id).replace("_", " ")
