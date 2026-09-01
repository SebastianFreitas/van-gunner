class_name GameBalanceData
extends Resource

## Inspector-editable balance sheet for encounter pacing and act scaling.
##
## Baseline identity (rear-door path):
##   mob_world_speed = expected_van_speed + spawn_distance / engagement_seconds
## Runtime closing (van-local):
##   closing = mob_world_speed - live_van_speed
## So a van boost slows / reverses approach; expected upgrades are baked into mob speed.

@export_group("Van")
@export var base_van_speed := 8.0

@export_group("Player baseline")
## Applied at runtime by GunStatsController as the gun's starting damage / fire rate.
@export var base_damage_per_shot := 1.0
@export var base_fire_rate := 1.0

@export_group("Spawn geometry")
## Nominal distance from rear-door Outside markers to the spawn line.
## EncounterDirector places raiders here at runtime (scene marker is only a visual/debug aid).
@export var spawn_distance := 47.2
## Corridor floor is 18 wide with walls at ±9; keep spawns inside with margin.
@export var spawn_half_width := 7.5
## Extra depth jitter on top of the random depth band below.
@export var spawn_z_jitter := 1.0
## Random depth band around spawn_distance (+Z = farther behind the van).
## Keep this small so engagement_seconds stays meaningful.
@export var spawn_z_depth_min := -3.0
@export var spawn_z_depth_max := 3.0
## Stagger each enemy in a wave so the pack doesn't arrive as one blob.
@export var spawn_delay_min := 0.5
@export var spawn_delay_max := 2.0

@export_group("Wave composition")
## Segment length: 1d6+3 → 4..9 waves before REST / route choice.
@export var segment_wave_min := 4
@export var segment_wave_max := 9
## Per-act wave sizing — Act 1 ramps gently; later acts spike harder on the finale.
@export var act_wave_base_count: PackedInt32Array = PackedInt32Array([2, 2, 2])
@export var act_wave_growth_per_step: PackedInt32Array = PackedInt32Array([1, 1, 1])
@export var act_last_wave_extra: PackedInt32Array = PackedInt32Array([2, 2, 3])
## Middle waves: chance to drop back to base count (at most once, never last).
@export var act_breather_chance: PackedFloat32Array = PackedFloat32Array([0.15, 0.3, 0.35])
## Pause between cleared waves while still in COMBAT.
@export var inter_wave_delay := 10.0

@export_group("Enemy approach")
## Designer intent: unpaid seconds for a rear-door approach at spawn_distance,
## when the van is running at the expected upgraded speed for that act.
## Mob world speed is derived from this — edit these to get 5 / 10 / 100 / 1s windows.
@export var act_engagement_seconds: PackedFloat32Array = PackedFloat32Array([10.0, 8.0, 6.0])
## How much of the van upgrade curve we assume when sizing each act's mob speed.
## Default Act 1 = 1/3, Act 2 = 2/3, Act 3 = full.
@export var act_expected_upgrade_fraction: PackedFloat32Array = PackedFloat32Array([
	0.333333, 0.666667, 1.0
])

@export_group("Breach / entry")
## Rear doors are tough — about 12 hits at default raider damage (8).
@export var rear_door_breach_hp := 96.0
## Side windows open faster — about 4 hits at default raider damage.
@export var window_breach_hp := 32.0
## Door / window glass panes — applied by breakable_glass at runtime.
@export var rear_window_glass_hp := 1.0
## Interior move speed after a breach (van-local units/sec).
@export var mob_interior_speed := 4.5
## Chance a spawned raider is agile (window climber) instead of door-only.
@export_range(0.0, 1.0) var agile_spawn_chance := 0.2

@export_group("Van speed upgrades")
## End-of-curve van speed targets (meta shop). Last entry is the fully-upgraded speed.
@export var act_target_van_speed: PackedFloat32Array = PackedFloat32Array([8.0, 9.0, 10.0])
@export var van_speed_max_level := 4
@export var van_speed_upgrade_base_cost := 50


func get_base_dps() -> float:
	return base_damage_per_shot * base_fire_rate


func get_max_van_speed() -> float:
	if act_target_van_speed.is_empty():
		return base_van_speed
	return act_target_van_speed[act_target_van_speed.size() - 1]


func get_engagement_seconds_for_act(act_index: int) -> float:
	if act_engagement_seconds.is_empty():
		return 0.01
	var i := clampi(act_index, 0, act_engagement_seconds.size() - 1)
	return maxf(act_engagement_seconds[i], 0.01)


func get_expected_upgrade_fraction_for_act(act_index: int) -> float:
	if act_expected_upgrade_fraction.is_empty():
		return clampf(float(act_index + 1) / 3.0, 0.0, 1.0)
	var i := clampi(act_index, 0, act_expected_upgrade_fraction.size() - 1)
	return clampf(act_expected_upgrade_fraction[i], 0.0, 1.0)


## Van speed assumed when deriving mob world speed for this act.
func get_expected_van_speed_for_act(act_index: int) -> float:
	var fraction := get_expected_upgrade_fraction_for_act(act_index)
	return lerpf(base_van_speed, get_max_van_speed(), fraction)


## Closing rate (m/s) needed to cover spawn_distance in engagement_seconds.
func get_baseline_closing_speed_for_act(act_index: int) -> float:
	return spawn_distance / get_engagement_seconds_for_act(act_index)


## Derived mob world speed for this act.
## mob_world = expected_van + spawn_distance / engagement_seconds
func get_mob_world_speed_for_act(act_index: int) -> float:
	return (
		get_expected_van_speed_for_act(act_index)
		+ get_baseline_closing_speed_for_act(act_index)
	)


## Live van-local closing speed. Negative = van is pulling away (boost / overspeed).
func get_closing_speed(act_index: int, current_van_speed: float) -> float:
	return get_mob_world_speed_for_act(act_index) - current_van_speed


func get_van_speed_per_level() -> float:
	if van_speed_max_level <= 0:
		return 0.0
	return (get_max_van_speed() - base_van_speed) / float(van_speed_max_level)
