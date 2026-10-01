---
paths:
  - "scripts/enemies/**"
  - "scenes/enemies/**"
  - "resources/enemies/**"
  - "scenes/van/van_breach_points.tscn"
---

# Enemies, breaching and the cabin

## Van-local space

Enemies live in `EnemyContainer`, a child of the van rig on a `PathFollow3D`, so their positions are van-local. That is why chase speed is closing speed (`mob_world_speed - live_van_speed`), not a plain velocity.

## Pathing

Van raiders use a waypoint graph, not a navmesh. They are `Node3D`s under `EnemyContainer`; a `NavigationAgent3D` / `CharacterBody3D` on that parent slides and fights the van-local lerp. Indoor paths go through `CabinNav` (bulkhead doorway, occupancy slots): the graph, claims and occupancy stay on `cabin_nav.gd`, and A*, path compression and slot positions are in `cabin_nav_paths.gd`. Warehouse buildings are world-static; bake a `NavigationRegion3D` there later, not on the van.

## Breach points

A rear door and its window pane are two `BreachPoint`s. Door goons and agile climbers use separate pools, but the Outside markers sit about 15 cm apart. Occupancy is clustered on the opening (`BreachPoint._shares_opening`); `CabinNav` never occupies outside holes. Don't split that cluster or a mixed pack stacks.

The points live in `scenes/van/van_breach_points.tscn`, instanced at `VanRig/EnemyContainer/BreachController`. The six window points' `bars_path` NodePaths reach out of that scene into the shell (`../../../Interior/Shell/.../IronCross`). `breach_point.gd` resolves them at runtime, relative to the node, so they hold only while both scenes sit at their current paths in `van.tscn`.

## Raiders

- **`is_elite` is explicit.** Agile (window climbing, green tint) does not imply elite loot. Set elite on the raider export, or via `mark_as_boss()` / `spawn_boss` in `encounter_spawner.gd`.
- `window_raider.gd` keeps its state, every `await` chain (assault, breach, attack loop, interior combat, retreat, death) and every method `BikerBoss` inherits or overrides. It stays over 400 lines for that reason. Per-frame chase math is in `window_raider_motion.gd`; targeting, lookups and the hit flash are in `window_raider_targeting.gd`. Helpers pass the raider node, never themselves, to `BreachPoint`, `CabinNav` and `BreachController`.
- **`BikerBoss extends WindowRaider`** and calls `_snap_to_marker`, `_clear_motion`, `_current_van_speed`, `_apply_status_move_speed`, `_outgoing_damage`, `_release_breach` and `_breach_controller` as inherited methods. Moving or renaming any of them breaks the boss.

## Beast sprites and hitboxes

- `scenes/enemies/window_raider.tscn` holds the door raider, a hunched humanoid
  feral (the loper): `Sprite3D` at `pixel_size 0.024` on `door_raider.png`, a 256 x 80 sheet of
  four 64 x 80 run frames (`hframes 4`, each 1.54 x 1.92 m; frame 0 is the still,
  `window_raider_anim.gd` steps `frame` at 8 fps while the raider moves and rests
  it on 0; the crawler and the boss set `hframes 1`), centred 0.66 m below the node so its claws
  sit at -1.62, the van floor under the 1.62 m breach markers; the body hitbox
  is a cylinder (r 0.7, h 1.75 at y -0.75: floor to the top of the hump) and the
  head a sphere (r 0.36 at y -0.5: the skull and the hanging jaw), both
  orientation-free because the sprite is a billboard and the node is not.
  `EnemyHealthBar.height` sets the bar's height per scene.
- The window crawler (`agile_raider.png`, 80 x 48) is fitted at `_ready` by
  `window_raider_look.gd`: sprite centred on the node (at a window the node
  is in the opening) with a 16 px `Sprite3D.offset` so the head drawn on the
  left sits over the origin (a node offset would not follow the billboard),
  a cylinder body (r 0.75, h 0.65) and a head sphere (r 0.36). The body and
  tail trailing to the right have no hitbox yet.
- `biker_boss.tscn` overrides the sprite back to `pixel_size 0.006`, zero
  offset and the old capsule plus sphere, so Wanjna is unchanged until the
  pixel-art pass redraws it.
- Both PNGs come from `py -3 tools/gen_enemy_sprites.py` (`--out`,
  `--preview` to draft outside the repo); never paint over them.

## Encounters

`EncounterDirector` runs waves as `_sequence_id`-guarded `await` chains (see `run-loop-and-acts.md`); spawning, enemy queries, despawns and the danger bump are in `encounter_spawner.gd`. `spawn_debug_raider` (console `summon enemy`) and `spawn_agile_raider` (BikerBoss) stay on the director. An enemy is a `.tres` in `resources/enemies/` plus a spawn pool entry, picked by `GameBalance.pick_spawn_enemy`.
