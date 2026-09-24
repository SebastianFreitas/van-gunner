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

var BASE_DAMAGE_PER_SHOT: float:
	get:
		return data.base_damage_per_shot

var BASE_FIRE_RATE: float:
	get:
		return data.base_fire_rate

var SPAWN_DISTANCE: float:
	get:
		return data.spawn_distance

var SPAWN_DELAY_MIN: float:
	get:
		return data.spawn_delay_min

var SPAWN_DELAY_MAX: float:
	get:
		return data.spawn_delay_max

var INTER_WAVE_DELAY: float:
	get:
		return data.inter_wave_delay

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

var VAN_SPEED_MAX_LEVEL: int:
	get:
		return data.van_speed_max_level

var MECHANIC_FULL_REPAIR_COST: int:
	get:
		return data.mechanic_full_repair_cost

var MECHANIC_VAN_BOON_COST: int:
	get:
		return data.mechanic_van_boon_cost

var POISON_DURATION: float:
	get:
		return data.poison_duration

var POISON_TICK_INTERVAL: float:
	get:
		return data.poison_tick_interval

var COLD_SLOW_DURATION: float:
	get:
		return data.cold_slow_duration

var WAREHOUSE_RARE_BOON_CHANCE: float:
	get:
		return data.warehouse_rare_boon_chance


# --- Helpers -----------------------------------------------------------------


func pick_spawn_enemy() -> EnemyDefinition:
	if data.segment_spawn_pool:
		return data.segment_spawn_pool.pick_enemy()
	return null


func get_act(route_step: int) -> int:
	if route_step <= 1:
		return 1
	if route_step == 2:
		return 2
	return 3


func get_expected_van_speed_for_act(act_index: int) -> float:
	return data.get_expected_van_speed_for_act(act_index)


func get_mob_world_speed(route_step: int) -> float:
	return data.get_mob_world_speed_for_act(get_act(route_step) - 1)


func get_mob_world_speed_for_act(act_index: int) -> float:
	return data.get_mob_world_speed_for_act(act_index)


func get_closing_speed(route_step: int, current_van_speed: float) -> float:
	return data.get_closing_speed(get_act(route_step) - 1, current_van_speed)


func get_van_speed_for_level(level: int) -> float:
	return data.base_van_speed + data.get_van_speed_per_level() * clampi(
		level, 0, data.van_speed_max_level
	)


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
