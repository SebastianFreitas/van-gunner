class_name GameBalanceData
extends Resource

## Inspector-editable balance sheet for encounter pacing and act scaling.
## Primary knob: act_mob_approach_speed — engagement windows fall out of spawn_distance.

@export_group("Van")
@export var base_van_speed := 8.0

@export_group("Player baseline")
## Reference values mirrored from default_gun_stats.tres (not applied at runtime).
@export var base_damage_per_shot := 1.0
@export var base_fire_rate := 4.0

@export_group("Spawn geometry")
## Fixed spawn distance — mobs always appear this far behind the van.
@export var spawn_distance := 47.2
## Corridor floor is 18 wide with walls at ±9; keep spawns inside with margin.
@export var spawn_half_width := 7.5
## Extra depth jitter on top of the random depth band below.
@export var spawn_z_jitter := 3.0
## Random depth band behind RearSpawnMarker (+Z = farther from van).
@export var spawn_z_depth_min := 0.0
@export var spawn_z_depth_max := 18.0
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
@export var inter_wave_delay := 1.25

@export_group("Enemy approach")
## How fast mobs run toward the van per act. Higher act = faster mobs.
## Sized so engagement windows land near 5s / 4s / 3s at spawn_distance.
@export var act_mob_approach_speed: PackedFloat32Array = PackedFloat32Array([9.44, 11.8, 15.73])

@export_group("Breach / entry")
## Rear doors are tough — about 12 hits at default raider damage (8).
@export var rear_door_breach_hp := 96.0
## Side windows open faster — about 4 hits at default raider damage.
@export var window_breach_hp := 32.0
## Door / window glass panes — one default shot is enough to shatter.
@export var rear_window_glass_hp := 1.0
## Interior move speed after a breach (van-local units/sec).
@export var mob_interior_speed := 4.5

@export_group("Van speed upgrades")
@export var act_target_van_speed: PackedFloat32Array = PackedFloat32Array([8.0, 9.0, 10.0])
@export var van_speed_max_level := 4
@export var van_speed_upgrade_base_cost := 50


func get_base_dps() -> float:
	return base_damage_per_shot * base_fire_rate


func get_engagement_seconds_for_act(act_index: int) -> float:
	var speed := act_mob_approach_speed[act_index]
	if speed <= 0.0:
		return 0.0
	return spawn_distance / speed


func get_van_speed_per_level() -> float:
	if van_speed_max_level <= 0 or act_target_van_speed.is_empty():
		return 0.0
	var target := act_target_van_speed[act_target_van_speed.size() - 1]
	return (target - base_van_speed) / float(van_speed_max_level)
