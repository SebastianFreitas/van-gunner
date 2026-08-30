class_name DamageInfo
extends RefCounted

var amount: float
var damage_type: DamageType.Type = DamageType.Type.NORMAL
var source: Node3D
var is_headshot := false
var hit_position := Vector3.ZERO
var explosion_radius := 1.8


static func create(
	amount: float,
	type: DamageType.Type = DamageType.Type.NORMAL,
	source: Node3D = null
) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	info.damage_type = type
	info.source = source
	return info


func get_final_amount() -> float:
	var final_amount := amount
	if damage_type == DamageType.Type.LIGHTNING and is_headshot:
		final_amount *= 2.5
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
