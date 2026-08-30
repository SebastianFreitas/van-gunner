class_name DamageInfo
extends RefCounted

var amount: float
var damage_type: DamageType.Type = DamageType.Type.NORMAL
var source: Node3D
var is_headshot := false
var hit_position := Vector3.ZERO
var explosion_radius := 1.8


static func create(
	initial_amount: float,
	type: DamageType.Type = DamageType.Type.NORMAL,
	from: Node3D = null
) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = initial_amount
	info.damage_type = type
	info.source = from
	return info


func get_final_amount() -> float:
	var final_amount := amount
	if is_headshot:
		if damage_type == DamageType.Type.LIGHTNING:
			final_amount *= 2.5
		else:
			final_amount *= 2.0
	return final_amount


func duplicate_info() -> DamageInfo:
	var copy := DamageInfo.new()
	copy.amount = amount
	copy.damage_type = damage_type
	copy.source = source
	copy.is_headshot = is_headshot
	copy.hit_position = hit_position
	copy.explosion_radius = explosion_radius
	return copy
