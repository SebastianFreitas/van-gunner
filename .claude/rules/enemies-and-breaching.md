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

- **`is_elite` is explicit.** Agile (window climbing) does not imply elite loot. Set elite on the raider export, or via `mark_as_boss()` / `spawn_boss` in `encounter_spawner.gd`.
- `window_raider.gd` keeps its state, every `await` chain (assault, breach, attack loop, interior combat, retreat, death) and every method `BikerBoss` inherits or overrides. It stays over 400 lines for that reason. Per-frame chase math is in `window_raider_motion.gd`; targeting, lookups and the hit flash are in `window_raider_targeting.gd`. Helpers pass the raider node, never themselves, to `BreachPoint`, `CabinNav` and `BreachController`.
- **`BikerBoss extends WindowRaider`** and calls `_snap_to_marker`, `_clear_motion`, `_current_van_speed`, `_apply_status_move_speed`, `_outgoing_damage`, `_release_breach` and `_breach_controller` as inherited methods. Moving or renaming any of them breaks the boss.

## Beast sprites and hitboxes

- `scenes/enemies/window_raider.tscn` holds the door raider, a hunched humanoid
  feral (the loper): `Sprite3D` at `pixel_size 0.024` on `door_raider.png`, an 832 x 240 sheet:
  row 0 thirteen 64 x 80 run frames, row 1 a 5-frame jump take-off (`hframes 13, vframes 3`;
  clip `jump`, 15 fps, no loop, plays on JUMPING), row 2 a 4-frame latch (clip `latch`, 10 fps,
  no loop: starts `LATCH_START` 0.55 s into a jump to the wall and holds its cling frame through
  GRIPPING and CLIMBING; a drop-off jump never latches, front-on like the run, never flipped; each 1.54 x 1.92 m; frame 0 is the still,
  `window_raider_anim.gd` is a clip player: named clips in `CLIPS` (sheet row, frames, fps,
  loop; `still`, `run`, `prowl`, `jump`, `latch` so far) set `frame_coords`, a new animation adds a sheet row
  (`SHEET_ROWS`) and a clip, and `_die` plays a `death` clip, when one exists, before the
  sink and fade; `run` steps at 18 fps while the raider moves and `still` rests
  it on 0, frames 6 to 8 are airborne, 6 the kick; the boss sets `hframes 1`), centred 0.66 m below the node so its claws
  sit at -1.62, the van floor under the 1.62 m breach markers. Outside (APPROACH and
  BREACHING) `window_raider_motion.gd` holds the loper's origin at `VanWheels.ROAD_Y + 1.62`
  so its feet stand on the road, 0.9 m under the floor, and ENTERING hops it up onto the
  floor over the last `HOP_RUN` 1.3 m; the window loper and the boss keep the marker heights. The body hitbox
  is a cylinder (r 0.7, h 1.75 at y -0.75: floor to the top of the hump) and the
  head a sphere (r 0.36 at y -0.5: the skull and the hanging jaw), both
  orientation-free because the sprite is a billboard and the node is not.
  The billboard is Y-only (`billboard = 2`): a full billboard tips toward the camera and
  the claws slide up and down as the player looks up or down (the owner saw it "swimming"
  in the van). Inside the cabin (ATTACKING_*) the anim loops `GROUNDED_FRAMES`, skipping
  the airborne 6 to 8, so it prowls instead of hopping. The 1.54 m card swings to face the
  camera, so `window_raider_motion.gd` keeps the loper's centre `CLEARANCE` 0.85 m off
  anything it could cut through. Outside, `clear_point`/`_push_out` keep it off
  `OUTSIDE_KEEP_OUT`: the body, both open rear-door leaves' swing, and the wheels. That
  puts it at z 5.85 at the rear doors, x ±3.6 at the side doors and x ±4.15 at the rear
  corners. Inside, `_clamp_in` holds it in the cabin shrunk by 0.85. ENTERING is exempt,
  the window loper is not pushed out outside, and the boss is never cleared. The bulkhead passage (1.55 m wide) is
  not cleared, so a brief clip there is expected.
  `EnemyHealthBar.height` sets the bar's height per scene.
- The window raider is the loper too (`agile_raider.tres`, `is_agile` true): same scene
  defaults, sheet, hitboxes and clips; `is_agile` only adds the `agile` group (window pool in
  `breach_controller.gd`) and exempts it from the road hold, so outside it floats at the
  1.62 m window marker with its claws at the van floor only in BREACHING. Before that
  (B3, 2026-10-03) it runs on the road in APPROACH (the road hold covers agile APPROACH),
  JUMPING from a launch point (x ±6.0 beside the window, z 8.0 behind a rear window) to a grip
  point on the skin (origin y 0.6), then CLIMBING to the attack spot, the Outside marker + 0.5. Wall maths, the four
  cling-and-wait spots (static owner map, released in `_die`/`retreat`/`_exit_tree`) and the
  jump/climb lerp are in `window_raider_wall.gd`; the awaits are in `window_raider.gd`. A run-up
  from behind goes via `approach_path`'s corner point (z 8.6), because the open rear-leaf
  keep-out pins a straight run. A loper never climbs between faces: it drops off and re-jumps.
  The smoke prints `loper wall climb:` and fails if CLIMBING is never reached. Inside the cabin it is clamped like the door
  loper; only the boss skips `clear_point`. The green crawler (`agile_raider.png`,
  `window_raider_look.gd`) was retired (owner, 2026-10-03).
- `biker_boss.tscn` overrides the sprite back to `pixel_size 0.006`, zero
  offset and the old capsule plus sphere, so Wanjna is unchanged until the
  pixel-art pass redraws it.
- The loper's sheet comes from `py -3 tools/gen_enemy_sprites.py` (`--out`,
  `--preview` to draft outside the repo); never paint over them.

## Encounters

`EncounterDirector` runs waves as `_sequence_id`-guarded `await` chains (see `run-loop-and-acts.md`); spawning, enemy queries, despawns and the danger bump are in `encounter_spawner.gd`. `spawn_debug_raider` (console `summon enemy`) and `spawn_agile_raider` (BikerBoss) stay on the director. An enemy is a `.tres` in `resources/enemies/` plus a spawn pool entry, picked by `GameBalance.pick_spawn_enemy`.
