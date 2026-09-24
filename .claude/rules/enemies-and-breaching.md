---
paths:
  - "scripts/enemies/**"
  - "scenes/enemies/**"
  - "resources/enemies/**"
---

# Enemies, breaching and the cabin

## Van-local space

Enemies live in `EnemyContainer`, a child of the van rig on a `PathFollow3D`, so their positions are van-local. That is why chase speed is closing speed (`mob_world_speed - live_van_speed`), not a plain velocity.

## Pathing

Van raiders use a waypoint graph, not a navmesh. They are `Node3D`s under `EnemyContainer`; a `NavigationAgent3D` / `CharacterBody3D` on that parent slides and fights the van-local lerp. Indoor paths go through `CabinNav` (bulkhead doorway, occupancy slots): the graph, claims and occupancy stay on `cabin_nav.gd`, and A*, path compression and slot positions are in `cabin_nav_paths.gd`. Warehouse buildings are world-static; bake a `NavigationRegion3D` there later, not on the van.

## Breach points

A rear door and its window pane are two `BreachPoint`s. Door goons and agile climbers use separate pools, but the Outside markers sit about 15 cm apart. Occupancy is clustered on the opening (`BreachPoint._shares_opening`); `CabinNav` never occupies outside holes. Don't split that cluster or a mixed pack stacks.

## Raiders

- **`is_elite` is explicit.** Agile (window climbing, green tint) does not imply elite loot. Set elite on the raider export, or via `mark_as_boss()` / `spawn_boss` in `encounter_spawner.gd`.
- `window_raider.gd` keeps its state, every `await` chain (assault, breach, attack loop, interior combat, retreat, death) and every method `BikerBoss` inherits or overrides. It stays over 400 lines for that reason. Per-frame chase math is in `window_raider_motion.gd`; targeting, lookups and the hit flash are in `window_raider_targeting.gd`. Helpers pass the raider node, never themselves, to `BreachPoint`, `CabinNav` and `BreachController`.
- **`BikerBoss extends WindowRaider`** and calls `_snap_to_marker`, `_clear_motion`, `_current_van_speed`, `_apply_status_move_speed`, `_outgoing_damage`, `_release_breach` and `_breach_controller` as inherited methods. Moving or renaming any of them breaks the boss.

## Encounters

`EncounterDirector` runs waves as `_sequence_id`-guarded `await` chains (see `run-loop-and-acts.md`); spawning, enemy queries, despawns and the danger bump are in `encounter_spawner.gd`. `spawn_debug_raider` (console `summon enemy`) and `spawn_agile_raider` (BikerBoss) stay on the director. An enemy is a `.tres` in `resources/enemies/` plus a spawn pool entry, picked by `GameBalance.pick_spawn_enemy`.
