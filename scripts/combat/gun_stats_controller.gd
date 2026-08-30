class_name GunStatsController
extends Node

signal stats_changed

@export var base_stats: GunStats

var _modifiers: Array[StatModifier] = []
var _effective_stats: GunStats


func _ready() -> void:
	_rebuild()


func add_modifier(modifier: StatModifier) -> void:
	_modifiers.append(modifier)
	_rebuild()


func remove_modifier_by_id(id: StringName) -> void:
	_modifiers = _modifiers.filter(func(mod: StatModifier) -> bool: return mod.id != id)
	_rebuild()


func get_stats() -> GunStats:
	if not _effective_stats:
		_rebuild()
	return _effective_stats


func _rebuild() -> void:
	var stats := base_stats.duplicate_stats() if base_stats else GunStats.new()
	for modifier in _modifiers:
		_apply_modifier(stats, modifier)
	stats.fire_rate = maxf(stats.fire_rate, 0.1)
	stats.damage_per_shot = maxf(stats.damage_per_shot, 0.0)
	stats.bullet_speed = maxf(stats.bullet_speed, 1.0)
	stats.bullet_weight = maxf(stats.bullet_weight, 0.0)
	stats.bullet_size = maxf(stats.bullet_size, 0.01)
	stats.reload_speed = maxf(stats.reload_speed, 0.1)
	stats.mag_size = maxi(roundi(stats.mag_size), 1)
	stats.aim_range = maxf(stats.aim_range, 1.0)
	stats.explosion_radius = maxf(stats.explosion_radius, 0.1)
	_effective_stats = stats
	stats_changed.emit()


func _apply_modifier(stats: GunStats, modifier: StatModifier) -> void:
	match modifier.stat_name:
		&"fire_rate":
			stats.fire_rate = _modify_value(stats.fire_rate, modifier)
		&"damage_per_shot":
			stats.damage_per_shot = _modify_value(stats.damage_per_shot, modifier)
		&"bullet_speed":
			stats.bullet_speed = _modify_value(stats.bullet_speed, modifier)
		&"bullet_weight":
			stats.bullet_weight = _modify_value(stats.bullet_weight, modifier)
		&"bullet_size":
			stats.bullet_size = _modify_value(stats.bullet_size, modifier)
		&"reload_speed":
			stats.reload_speed = _modify_value(stats.reload_speed, modifier)
		&"mag_size":
			stats.mag_size = _modify_value(stats.mag_size, modifier)
		&"aim_range":
			stats.aim_range = _modify_value(stats.aim_range, modifier)
		&"explosion_radius":
			stats.explosion_radius = _modify_value(stats.explosion_radius, modifier)


func _modify_value(current: float, modifier: StatModifier) -> float:
	if modifier.mode == StatModifier.Mode.MULTIPLY:
		return current * modifier.value
	return current + modifier.value
