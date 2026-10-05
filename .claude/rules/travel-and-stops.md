---
paths:
  - "scripts/travel/*.gd"
  - "scripts/stops/**"
  - "resources/side_stops/**"
  - "scenes/corridor/**"
  - "scenes/shop/**"
---

# Travel, turns and side stops

## World model

The van rig is parented to a `PathFollow3D`; the world (corridor segments, junctions, side stops) is spawned ahead and culled behind. The player never steers.

## How TravelController is split

`travel_controller.gd` keeps its state header, every method other files call (speed orders, stop and act queries, `leave_stop`, debug speed), the `_sequence_id` await chains (intro, act resume, elevator ride) and the lifecycle. It stays over 400 lines on purpose. Helpers take the controller as `tc` (untyped: `TravelController` and `ActDeckController` avoid naming each other's class): `travel_world.gd` (corridor tiles, junctions, statues, pruning), `travel_routes.gd` (turn, park and leave curves; `route_chosen` connects straight to it), `travel_stops.gd` (stop fork, placement, elevator pad, cleanup).

## Side stops

Every offered road at a fork gets a stop (shop, garage, … from `resources/side_stops/`), blessing and DANGER alike, straight included. The card is only that street's combat modifier; taking a road commits the card and visits the stop. While docked (`STOP`) the rear doors stay open so you can walk the room.

How the van arrives is data on the stop: a stop is `arrival(content)`. `Arrival.REAR_PARK` reverse-parks into the shared vestibule; `Arrival.ELEVATOR` halts on the road and drops a pad to the same vestibule and roll-up door. Content scenes mount just behind the door (no dock markers). Swap `arrival` on the `.tres` (and optionally `spawn_weight`) to put any interior on the lift; debug `stop elevator shop` composes the same pairing without a new file.

`SideStopRegistry` scans `res://resources/side_stops/` with `DirAccess`. Arrival hosts (`stop_vestibule.tscn`, `stop_elevator.tscn`) expose `DockPoint` and `ExitPoint`. Content scenes start just inside the roll-up (`ContentMount` at the door, +X inward) and must not include those markers. `DockPoint.x` is negative so the rear bumper sits in the vestibule, not inside the door.

## Pitfalls

- **Stop attach ignores leftover tiles after a curve swap.** Left/right turns replace `travel_path.curve` and reset progress to 0. Old tiles keep their `route_progress`, so a naive "first tile ahead" pick can parent the garage to the street you just left and the van reverse-parks with the building on its side. `TravelController` stamps `_route_gen` and only attaches to tiles still on the live curve.
- **The rig rests lifted, not at identity.** `VanRig` sits `VanWheels.BODY_LIFT` (0.7 m) above its `PathFollow3D` so the body rides high while the wheels reach the road (`VanWheels.ROAD_Y`). Reset it with `VanWheels.rig_rest_transform()`, and build route paths and road-level placements (statues) from `van_follow.global_transform`, never `van_rig`'s, or every turn raises the road path by the lift. Raiders, breach markers and the rear ramp are still body-relative, so they ride the lift too.
- **Elevator stops ride `PathFollow3D.v_offset`.** The van stays on the road curve; the pad is a sibling in the corridor, not a new parent. Don't reparent `VanRig` onto the platform. Open the shaft (hide collision as well as the mesh) as the ride starts, or a street-height `StaticBody` holds the player at grade while the van drops. Keep the pad below the van deck and inside the shaft so it doesn't z-fight the interior floor. Vestibule yaw is `-PI/2` so shop `+X` faces the van rear (`+Z`); `+PI/2` puts the door at the nose and walking out the back falls into the shaft. Don't place the shop slab under the van deck.
- **The halt is a speed order, not a phase.** `TravelController.try_halt()` (C while already EASY) sets `_halted` and `travel_speed` 0, only in TRAVELLING, COMBAT or REST ("CAN'T STOP HERE" at a fork or in a turn). It persists through ACT_REVEAL, BOSS_PICK, ROUTE_CHOICE and TURNING and clears only on a Shift resume, IDLE, GAME_OVER, STOP or PARKING; `halted_changed` drives `van_halt.gd` (rear exit and side door bays; the player jumps back in with a mantle, `player_mantle.gd`). Raiders keep spawning and close at full mob speed, and the wave, REST and pre-encounter timers are wall-clock, so a long halt does not freeze the run. Turbo cooldown is 45 s; C cancels a running turbo but not its cooldown; Shift while EASY or halted resumes cruise with no turbo and no cooldown.
- **A tile spawned ahead of the moving van is not finished when `spawn_world_segment` returns.** Tiles from `spawn_segments_ahead` are sliced: `CorridorSegment.build_steps` hands its facade sides, side streets, floors and the six sidewalk wreck sides to `TileBuildQueue` (`tile_build_queue.gd`, owned by `travel_world.gd`), which `TravelController._physics_process` drains at about 3 ms a frame (`step_builds`). Every other spawn (stops, junctions, turns, the first street) calls `flush_builds()` first and builds at once, and so does `corridor_segment_near_progress`. Code that reads or reshapes a tile ahead (parks on it, hangs a set-piece on it, counts its children) must go through one of those or call `flush_builds()` itself. `pick_district` and `pick_side_streets` still draw from `tc._rng` at spawn, in the old order; only the build is deferred. A hidden side-street branch never builds its `RoadFloor` at all (`begin_build` clears its `rebuild_on_ready`; opening the branch sets its end trims, which builds it).
- **Van speed is tree-written.** `van_speed_level` feeds the chase formula (`closing = mob_world_speed - live_van_speed`). Only allocated schematic nodes change it; pending requests wait until the next run (or apply in `IDLE`). Don't buy speed with gold at the bench, and pending node buys must not emit `van_speed_changed` or the chase window jumps mid-street.

## Facades and paving

Street buildings are `facades.md`; the sidewalk paving and its destruction map are `street-paving.md`.

## Shop booth

`shop_counter_booth.gd` keeps its exports, build order, lights and box primitives; materials, flyers (and the block-letter glyph table), frame and trim are helpers beside it. Flyer placement is seeded: keep RNG call order when touching it.

## Surfaces and lights (from the 3D art pass)

The numbers are in `.claude/rules/art-style.md` and `art-3d.md`; these are the traps.

- **`industrial_surface.gdshader` lays panels out in model-space metres** (`panel_size_m`, `foot_y_m`), so every user must be an unscaled, centred `BoxMesh` sized through `mesh.size`. A node scale stretches the panels, and there is no `tile_count` or `surface_size_m` any more. Walls of different heights (the elevator shaft) leave `foot_y_m` at its off default instead of guessing one.
- **Merged prop meshes carry 0..1 UVs per box face**, so `facade_prop_grime.gdshader` picks its pattern plane from the face's dominant normal axis in model space. Reach it only through `facade_grime_materials.gd`'s `from_prop()`, which caches one material per budgeted `prop_material()`, so the colour never changes when a prop moves onto grime.
- **Facade walls fade their fine patterns with `fwidth(UV)`** (`pattern_fade`, `line_fade`, `soft_line` in `facade_surface.gdshader`). A new repeating pattern in that shader goes through them, or distant corrugated walls moiré again. Lit windows sit at `window_emission` 0.5 (under the 1.1 glow threshold); only fire windows bloom.
- **A stop light moves with its fixture.** Every stop, junction and statue light hangs under a fixture mesh; move or retune them together and keep the energy unless the shots say otherwise. The statue orb's `OrbLight` is a shadowless 6 m pool.
- **The smoke shots skip most of this.** They see the street, the shop on the lift and the garage; the mechanic, warehouse, junctions, statue and overheads need a temporary `stop elevator mechanic` or `stop warehouse` swap to shoot, reverted before committing.

## Testing

The smoke test drives two forks in `speed` mode: an elevator stop (shop) and a rear-park stop (garage), docking and leaving each. `speed` skips panels, so it doesn't test the reveal or boon UI. Facade stress testing: `facades.md` "Testing".
