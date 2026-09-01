extends Node

## Central balance sheet for encounter pacing and act scaling.
## Tweak ACT_MOB_APPROACH_SPEED — engagement windows fall out of spawn distance.

# --- Van ---------------------------------------------------------------------

const BASE_VAN_SPEED := 8.0

# --- Player baseline (from default_gun_stats.tres) ---------------------------

const BASE_DAMAGE_PER_SHOT := 1.0
const BASE_FIRE_RATE := 4.0
const BASE_DPS := BASE_DAMAGE_PER_SHOT * BASE_FIRE_RATE  # 4.0

# --- Spawn geometry (van-local units) ----------------------------------------

## Fixed spawn distance — mobs always appear this far behind the van.
## Was ~23.6; doubled so they start much farther out.
const SPAWN_DISTANCE := 47.2
## Corridor floor is 18 wide with walls at ±9; keep spawns inside with margin.
const SPAWN_HALF_WIDTH := 7.5
## Extra depth jitter on top of the random depth band below.
const SPAWN_Z_JITTER := 3.0
## Random depth band behind RearSpawnMarker (+Z = farther from van).
const SPAWN_Z_DEPTH_MIN := 0.0
const SPAWN_Z_DEPTH_MAX := 18.0
## Stagger each enemy in a wave so the pack doesn't arrive as one blob.
const SPAWN_DELAY_MIN := 0.5
const SPAWN_DELAY_MAX := 2.0

# --- Wave composition (per route segment) ------------------------------------
## Segment length: 1d6+3 → 4..9 waves before REST / route choice.
const SEGMENT_WAVE_MIN := 4
const SEGMENT_WAVE_MAX := 9
## Per-act wave sizing — Act 1 ramps gently; later acts spike harder on the finale.
const ACT_WAVE_BASE_COUNT: Array[int] = [2, 2, 2]
const ACT_WAVE_GROWTH_PER_STEP: Array[int] = [1, 1, 1]
const ACT_LAST_WAVE_EXTRA: Array[int] = [2, 2, 3]
## Middle waves: chance to drop back to base count (at most once, never last).
const ACT_BREATHER_CHANCE: Array[float] = [0.15, 0.3, 0.35]
## Pause between cleared waves while still in COMBAT.
const INTER_WAVE_DELAY := 1.25

# --- Enemy movement speed per act (primary tuning knob) ----------------------
## How fast mobs run toward the van.  Higher act = faster mobs.
## Sized so engagement windows land near 5s / 4s / 3s at SPAWN_DISTANCE.
##   Act 1: 47.2 / 9.44  ≈ 5.0 s
##   Act 2: 47.2 / 11.8  ≈ 4.0 s
##   Act 3: 47.2 / 15.73 ≈ 3.0 s

const ACT_MOB_APPROACH_SPEED := [9.44, 11.8, 15.73]

# --- Breach / entry ----------------------------------------------------------
## Rear doors are tough — about 12 hits at default raider damage (8).
const REAR_DOOR_BREACH_HP := 96.0
## Side windows open faster — about 4 hits at default raider damage.
const WINDOW_BREACH_HP := 32.0
## Door / window glass panes — one default shot is enough to shatter.
const REAR_WINDOW_GLASS_HP := 1.0
## Interior move speed after a breach (van-local units/sec).
const MOB_INTERIOR_SPEED := 4.5

# --- Derived engagement windows (SPAWN_DISTANCE / mob speed) -------------------

const ACT_ENGAGEMENT_SECONDS := [
	SPAWN_DISTANCE / ACT_MOB_APPROACH_SPEED[0],
	SPAWN_DISTANCE / ACT_MOB_APPROACH_SPEED[1],
	SPAWN_DISTANCE / ACT_MOB_APPROACH_SPEED[2],
]

# --- Van speed upgrade curve -------------------------------------------------

const ACT_TARGET_VAN_SPEED := [8.0, 9.0, 10.0]

const VAN_SPEED_MAX_LEVEL := 4
const VAN_SPEED_PER_LEVEL := (
	(ACT_TARGET_VAN_SPEED[2] - BASE_VAN_SPEED) / float(VAN_SPEED_MAX_LEVEL)
)
const VAN_SPEED_UPGRADE_BASE_COST := 50


# --- Helpers -----------------------------------------------------------------


func get_act(route_step: int) -> int:
	if route_step <= 1:
		return 1
	if route_step == 2:
		return 2
	return 3


func get_mob_approach_speed(route_step: int) -> float:
	var act := get_act(route_step)
	return ACT_MOB_APPROACH_SPEED[act - 1]


func get_engagement_seconds(route_step: int) -> float:
	var act := get_act(route_step)
	return ACT_ENGAGEMENT_SECONDS[act - 1]


func get_van_speed_for_level(level: int) -> float:
	return BASE_VAN_SPEED + VAN_SPEED_PER_LEVEL * clampi(level, 0, VAN_SPEED_MAX_LEVEL)


func get_van_speed_upgrade_cost(level: int) -> int:
	if level >= VAN_SPEED_MAX_LEVEL:
		return 0
	return VAN_SPEED_UPGRADE_BASE_COST * (level + 1)


## Roll segment length (1d6+3) and per-wave enemy counts.
## Index 0 = first wave. Growth is linear; one optional middle breather;
## the final wave always spikes above the normal curve.
func build_segment_wave_plan(route_step: int = 1) -> Array[int]:
	var act: int = get_act(route_step)
	var act_i: int = act - 1
	var base_count: int = ACT_WAVE_BASE_COUNT[act_i]
	var growth: int = ACT_WAVE_GROWTH_PER_STEP[act_i]
	var last_extra: int = ACT_LAST_WAVE_EXTRA[act_i]
	var breather_chance: float = ACT_BREATHER_CHANCE[act_i]

	var total := randi_range(SEGMENT_WAVE_MIN, SEGMENT_WAVE_MAX)
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


## Local offset from RearSpawnMarker: spread across corridor width and depth.
func spawn_offset_for_slot(slot: int, count: int) -> Vector3:
	var half := SPAWN_HALF_WIDTH
	var x := 0.0
	if count <= 1:
		x = randf_range(-half, half)
	else:
		var t := float(slot) / float(count - 1)
		var base_x := lerpf(-half, half, t)
		var slot_w := (2.0 * half) / float(count)
		x = base_x + randf_range(-slot_w * 0.65, slot_w * 0.65)
		x = clampf(x, -half, half)
	var z := randf_range(SPAWN_Z_DEPTH_MIN, SPAWN_Z_DEPTH_MAX)
	z += randf_range(-SPAWN_Z_JITTER, SPAWN_Z_JITTER)
	return Vector3(x, 0.0, z)
