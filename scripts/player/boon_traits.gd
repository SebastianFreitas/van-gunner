class_name BoonTraits
extends Node

## Stores passive boon modifiers that combat systems query at runtime.
## Gun stat keys use the `gun_` prefix (see BoonTraitKeys) and are read by GunStatsController.
## Street overlay is a replaceable layer from the active act card (TempBoonTraitEffect).

signal traits_changed

var _adds: Dictionary = {}
var _mults: Dictionary = {}
var _flags: Dictionary = {}
var _street_adds: Dictionary = {}
var _street_mults: Dictionary = {}
var _street_flags: Dictionary = {}


func _ready() -> void:
	traits_changed.connect(_on_traits_changed)


func add_value(key: StringName, amount: float) -> void:
	_adds[key] = _adds.get(key, 0.0) + amount
	traits_changed.emit()


func multiply_value(key: StringName, factor: float) -> void:
	_mults[key] = _mults.get(key, 1.0) * factor
	traits_changed.emit()


func set_flag(key: StringName) -> void:
	_flags[key] = true
	traits_changed.emit()


func set_street_overlay(adds: Dictionary, mults: Dictionary, flags: Dictionary) -> void:
	_street_adds = adds.duplicate()
	_street_mults = mults.duplicate()
	_street_flags = flags.duplicate()
	traits_changed.emit()


func clear_street_overlay() -> void:
	if _street_adds.is_empty() and _street_mults.is_empty() and _street_flags.is_empty():
		return
	_street_adds.clear()
	_street_mults.clear()
	_street_flags.clear()
	traits_changed.emit()


func get_add(key: StringName) -> float:
	return float(_adds.get(key, 0.0)) + float(_street_adds.get(key, 0.0))


func get_mult(key: StringName) -> float:
	return float(_mults.get(key, 1.0)) * float(_street_mults.get(key, 1.0))


func has_flag(key: StringName) -> bool:
	return bool(_flags.get(key, false)) or bool(_street_flags.get(key, false))


static func find_on(node: Node) -> BoonTraits:
	if not node:
		return null
	return node.get_node_or_null("BoonTraits") as BoonTraits


func _on_traits_changed() -> void:
	var tree := get_tree()
	if tree:
		BoonCombat.refresh_all_enemy_status_effects(tree)
