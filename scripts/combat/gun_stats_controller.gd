class_name GunStatsController
extends Node

signal stats_changed

@export var base_stats: GunStats

var _modifiers: Array[StatModifier] = []
var _effective_stats: GunStats
var _traits: BoonTraits
var _weapon_instance: WeaponInstance


func _ready() -> void:
	_traits = BoonTraits.find_on(get_parent())
	if _traits:
		_traits.traits_changed.connect(_rebuild)
	_rebuild()


func set_weapon_instance(instance: WeaponInstance) -> void:
	_weapon_instance = instance
	_rebuild()


func get_weapon_instance() -> WeaponInstance:
	return _weapon_instance


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
	var stats: GunStats
	if _weapon_instance:
		## Balance floor + definition identity + weapon mods, then boons/temp mods.
		stats = WeaponStatsBuilder.build(_weapon_instance)
	else:
		stats = base_stats.duplicate_stats() if base_stats else GunStats.new()
		stats.fire_rate = GameBalance.BASE_FIRE_RATE
		stats.damage_per_shot = GameBalance.BASE_DAMAGE_PER_SHOT
		stats.pellets_per_shot = maxi(stats.pellets_per_shot, 1)
	if _traits:
		_apply_traits(stats, _traits)
	for modifier in _modifiers:
		_apply_modifier(stats, modifier)
	stats.fire_rate = maxf(stats.fire_rate, 0.1)
	stats.damage_per_shot = maxf(stats.damage_per_shot, 0.0)
	stats.bullet_speed = maxf(stats.bullet_speed, 1.0)
	stats.bullet_weight = maxf(stats.bullet_weight, 0.0)
	stats.bullet_size = maxf(stats.bullet_size, 0.01)
	stats.reload_speed = maxf(stats.reload_speed, 0.1)
	stats.mag_size = maxi(stats.mag_size, 1)
	stats.aim_range = maxf(stats.aim_range, 1.0)
	stats.explosion_radius = maxf(stats.explosion_radius, 0.1)
	stats.max_bounces = maxi(stats.max_bounces, 0)
	stats.bounce_speed_retention = clampf(stats.bounce_speed_retention, 0.05, 1.0)
	stats.bounce_damage_retention = clampf(stats.bounce_damage_retention, 0.0, 1.0)
	stats.pellets_per_shot = maxi(stats.pellets_per_shot, 1)
	stats.pellet_spread_degrees = maxf(stats.pellet_spread_degrees, 0.0)
	_effective_stats = stats
	stats_changed.emit()


func _apply_traits(stats: GunStats, traits: BoonTraits) -> void:
	stats.fire_rate *= traits.get_mult(BoonTraitKeys.GUN_FIRE_RATE)
	stats.damage_per_shot += traits.get_add(BoonTraitKeys.GUN_DAMAGE_PER_SHOT)
	stats.damage_per_shot *= traits.get_mult(BoonTraitKeys.GUN_DAMAGE_PER_SHOT)
	stats.bullet_speed += traits.get_add(BoonTraitKeys.GUN_BULLET_SPEED)
	stats.bullet_speed *= traits.get_mult(BoonTraitKeys.GUN_BULLET_SPEED)
	stats.bullet_weight += traits.get_add(BoonTraitKeys.GUN_BULLET_WEIGHT)
	stats.bullet_weight *= traits.get_mult(BoonTraitKeys.GUN_BULLET_WEIGHT)
	stats.bullet_size += traits.get_add(BoonTraitKeys.GUN_BULLET_SIZE)
	stats.bullet_size *= traits.get_mult(BoonTraitKeys.GUN_BULLET_SIZE)
	stats.reload_speed += traits.get_add(BoonTraitKeys.GUN_RELOAD_SPEED)
	stats.reload_speed *= traits.get_mult(BoonTraitKeys.GUN_RELOAD_SPEED)
	stats.mag_size += int(traits.get_add(BoonTraitKeys.GUN_MAG_SIZE))
	stats.mag_size = roundi(float(stats.mag_size) * traits.get_mult(BoonTraitKeys.GUN_MAG_SIZE))
	stats.aim_range += traits.get_add(BoonTraitKeys.GUN_AIM_RANGE)
	stats.aim_range *= traits.get_mult(BoonTraitKeys.GUN_AIM_RANGE)
	stats.explosion_radius += traits.get_add(BoonTraitKeys.GUN_EXPLOSION_RADIUS)
	stats.explosion_radius *= traits.get_mult(BoonTraitKeys.GUN_EXPLOSION_RADIUS)
	stats.max_bounces += int(traits.get_add(BoonTraitKeys.GUN_MAX_BOUNCES))
	stats.max_bounces = roundi(float(stats.max_bounces) * traits.get_mult(BoonTraitKeys.GUN_MAX_BOUNCES))
	stats.bounce_speed_retention += traits.get_add(BoonTraitKeys.GUN_BOUNCE_SPEED_RETENTION)
	stats.bounce_speed_retention *= traits.get_mult(BoonTraitKeys.GUN_BOUNCE_SPEED_RETENTION)
	stats.bounce_damage_retention += traits.get_add(BoonTraitKeys.GUN_BOUNCE_DAMAGE_RETENTION)
	stats.bounce_damage_retention *= traits.get_mult(BoonTraitKeys.GUN_BOUNCE_DAMAGE_RETENTION)


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
			stats.mag_size = roundi(_modify_value(float(stats.mag_size), modifier))
		&"aim_range":
			stats.aim_range = _modify_value(stats.aim_range, modifier)
		&"explosion_radius":
			stats.explosion_radius = _modify_value(stats.explosion_radius, modifier)
		&"max_bounces":
			stats.max_bounces = roundi(_modify_value(float(stats.max_bounces), modifier))
		&"bounce_speed_retention":
			stats.bounce_speed_retention = _modify_value(stats.bounce_speed_retention, modifier)
		&"bounce_damage_retention":
			stats.bounce_damage_retention = _modify_value(stats.bounce_damage_retention, modifier)


func _modify_value(current: float, modifier: StatModifier) -> float:
	if modifier.mode == StatModifier.Mode.MULTIPLY:
		return current * modifier.value
	return current + modifier.value
