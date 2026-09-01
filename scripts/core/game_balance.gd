extends Node

## Runtime facade over the Inspector-editable GameBalanceData resource.
## Edit: res://resources/balance/game_balance.tres
## Primary knob: act_engagement_seconds.
## Mob world speed = expected_van (base + upgrade fraction) + spawn_distance / seconds.
## Live closing = mob_world_speed - current_van_speed.

## Preload-as-type avoids autoload parse order issues with global class_name.
const _GameBalanceData := preload("res://scripts/core/game_balance_data.gd")
const DATA_PATH := "res://resources/balance/game_balance.tres"

## Loaded in _ready so Inspector saves on the .tres always win over stale caches.
var data: _GameBalanceData = preload(DATA_PATH)


func _ready() -> void:
	# CACHE_MODE_REPLACE so a saved .tres wins over a stale preload cache.
	var loaded := ResourceLoader.load(
		DATA_PATH, "", ResourceLoader.CACHE_MODE_REPLACE
	) as _GameBalanceData
	if loaded:
		data = loaded
	else:
		push_error("GameBalance: failed to load %s" % DATA_PATH)

# --- Forwarded tunables (keep call-site names stable) -------------------------

var BASE_VAN_SPEED: float:
	get:
		return data.base_van_speed

var BASE_DAMAGE_PER_SHOT: float:
	get:
		return data.base_damage_per_shot

var BASE_FIRE_RATE: float:
	get:
		return data.base_fire_rate

var BASE_DPS: float:
	get:
		return data.get_base_dps()

var SPAWN_DISTANCE: float:
	get:
		return data.spawn_distance

var SPAWN_HALF_WIDTH: float:
	get:
		return data.spawn_half_width

var SPAWN_Z_JITTER: float:
	get:
		return data.spawn_z_jitter

var SPAWN_Z_DEPTH_MIN: float:
	get:
		return data.spawn_z_depth_min

var SPAWN_Z_DEPTH_MAX: float:
	get:
		return data.spawn_z_depth_max

var SPAWN_DELAY_MIN: float:
	get:
		return data.spawn_delay_min

var SPAWN_DELAY_MAX: float:
	get:
		return data.spawn_delay_max

var SEGMENT_WAVE_MIN: int:
	get:
		return data.segment_wave_min

var SEGMENT_WAVE_MAX: int:
	get:
		return data.segment_wave_max

var ACT_WAVE_BASE_COUNT: PackedInt32Array:
	get:
		return data.act_wave_base_count

var ACT_WAVE_GROWTH_PER_STEP: PackedInt32Array:
	get:
		return data.act_wave_growth_per_step

var ACT_LAST_WAVE_EXTRA: PackedInt32Array:
	get:
		return data.act_last_wave_extra

var ACT_BREATHER_CHANCE: PackedFloat32Array:
	get:
		return data.act_breather_chance

var INTER_WAVE_DELAY: float:
	get:
		return data.inter_wave_delay

var ACT_ENGAGEMENT_SECONDS: PackedFloat32Array:
	get:
		return data.act_engagement_seconds

var ACT_EXPECTED_UPGRADE_FRACTION: PackedFloat32Array:
	get:
		return data.act_expected_upgrade_fraction

## Derived mob world speeds per act (expected_van + distance / seconds).
var ACT_MOB_WORLD_SPEED: PackedFloat32Array:
	get:
		var speeds := PackedFloat32Array()
		for i in mini(3, data.act_engagement_seconds.size()):
			speeds.append(data.get_mob_world_speed_for_act(i))
		return speeds

## Baseline closing rates at expected van speed (distance / seconds).
var ACT_MOB_APPROACH_SPEED: PackedFloat32Array:
	get:
		var speeds := PackedFloat32Array()
		for i in mini(3, data.act_engagement_seconds.size()):
			speeds.append(data.get_baseline_closing_speed_for_act(i))
		return speeds

var REAR_DOOR_BREACH_HP: float:
	get:
		return data.rear_door_breach_hp

var WINDOW_BREACH_HP: float:
	get:
		return data.window_breach_hp

var REAR_WINDOW_GLASS_HP: float:
	get:
		return data.rear_window_glass_hp

var MOB_INTERIOR_SPEED: float:
	get:
		return data.mob_interior_speed

var ACT_TARGET_VAN_SPEED: PackedFloat32Array:
	get:
		return data.act_target_van_speed

var VAN_SPEED_MAX_LEVEL: int:
	get:
		return data.van_speed_max_level

var VAN_SPEED_PER_LEVEL: float:
	get:
		return data.get_van_speed_per_level()

var VAN_SPEED_UPGRADE_BASE_COST: int:
	get:
		return data.van_speed_upgrade_base_cost


# --- Helpers -----------------------------------------------------------------


func get_act(route_step: int) -> int:
	if route_step <= 1:
		return 1
	if route_step == 2:
		return 2
	return 3


func get_engagement_seconds(route_step: int) -> float:
	return data.get_engagement_seconds_for_act(get_act(route_step) - 1)


func get_expected_van_speed_for_act(act_index: int) -> float:
	return data.get_expected_van_speed_for_act(act_index)


func get_mob_world_speed(route_step: int) -> float:
	return data.get_mob_world_speed_for_act(get_act(route_step) - 1)


func get_mob_world_speed_for_act(act_index: int) -> float:
	return data.get_mob_world_speed_for_act(act_index)


## Baseline closing at the expected van speed (not live). Prefer get_closing_speed at runtime.
func get_mob_approach_speed(route_step: int) -> float:
	return data.get_baseline_closing_speed_for_act(get_act(route_step) - 1)


func get_closing_speed(route_step: int, current_van_speed: float) -> float:
	return data.get_closing_speed(get_act(route_step) - 1, current_van_speed)


func get_van_speed_for_level(level: int) -> float:
	return data.base_van_speed + data.get_van_speed_per_level() * clampi(
		level, 0, data.van_speed_max_level
	)


func get_van_speed_upgrade_cost(level: int) -> int:
	if level >= data.van_speed_max_level:
		return 0
	return data.van_speed_upgrade_base_cost * (level + 1)


## Roll segment length (1d6+3) and per-wave enemy counts.
## Index 0 = first wave. Growth is linear; one optional middle breather;
## the final wave always spikes above the normal curve.
func build_segment_wave_plan(route_step: int = 1) -> Array[int]:
	var act: int = get_act(route_step)
	var act_i: int = act - 1
	var base_count: int = data.act_wave_base_count[act_i]
	var growth: int = data.act_wave_growth_per_step[act_i]
	var last_extra: int = data.act_last_wave_extra[act_i]
	var breather_chance: float = data.act_breather_chance[act_i]

	var total := randi_range(data.segment_wave_min, data.segment_wave_max)
	var plan: Array[int] = []
	var had_breather := false
	for wave_index in range(1, total + 1):
		var is_first := wave_index == 1
		var is_last := wave_index == total
		if is_first:
			plan.append(base_count)
			continue
		if is_last:
			plan.append(_normal_wave_count(wave_index, base_count, growth) + last_extra)
			continue
		if not had_breather and randf() < breather_chance:
			plan.append(base_count)
			had_breather = true
		else:
			plan.append(_normal_wave_count(wave_index, base_count, growth))
	return plan


func _normal_wave_count(wave_index: int, base_count: int, growth: int) -> int:
	return base_count + (wave_index - 1) * growth


## Local offset from the nominal spawn line: corridor X spread + depth jitter.
## +Z is farther behind the van (EnemyContainer space).
func spawn_offset_for_slot(slot: int, count: int) -> Vector3:
	var half := data.spawn_half_width
	var x := 0.0
	if count <= 1:
		x = randf_range(-half, half)
	else:
		var t := float(slot) / float(count - 1)
		var base_x := lerpf(-half, half, t)
		var slot_w := (2.0 * half) / float(count)
		x = base_x + randf_range(-slot_w * 0.65, slot_w * 0.65)
		x = clampf(x, -half, half)
	var z := randf_range(data.spawn_z_depth_min, data.spawn_z_depth_max)
	z += randf_range(-data.spawn_z_jitter, data.spawn_z_jitter)
	return Vector3(x, 0.0, z)
