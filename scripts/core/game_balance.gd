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
## Rear door glass panes — one default shot is enough to shatter.
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
