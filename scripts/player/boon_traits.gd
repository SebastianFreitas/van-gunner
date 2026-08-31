class_name BoonTraits
extends Node

## Stores passive boon modifiers that combat systems query at runtime.

var _adds: Dictionary = {}
var _mults: Dictionary = {}
var _flags: Dictionary = {}


func add_value(key: StringName, amount: float) -> void:
	_adds[key] = _adds.get(key, 0.0) + amount


func multiply_value(key: StringName, factor: float) -> void:
	_mults[key] = _mults.get(key, 1.0) * factor


func set_flag(key: StringName) -> void:
	_flags[key] = true


func get_add(key: StringName) -> float:
	return float(_adds.get(key, 0.0))


func get_mult(key: StringName) -> float:
	return float(_mults.get(key, 1.0))


func has_flag(key: StringName) -> bool:
	return bool(_flags.get(key, false))


static func find_on(node: Node) -> BoonTraits:
	if not node:
		return null
	return node.get_node_or_null("BoonTraits") as BoonTraits
