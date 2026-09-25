---
paths:
  - "scripts/travel/**"
  - "scripts/stops/**"
  - "resources/side_stops/**"
  - "resources/facades/**"
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
- **Elevator stops ride `PathFollow3D.v_offset`.** The van stays on the road curve; the pad is a sibling in the corridor, not a new parent. Don't reparent `VanRig` onto the platform. Open the shaft (hide collision as well as the mesh) as the ride starts, or a street-height `StaticBody` holds the player at grade while the van drops. Keep the pad below the van deck and inside the shaft so it doesn't z-fight the interior floor. Vestibule yaw is `-PI/2` so shop `+X` faces the van rear (`+Z`); `+PI/2` puts the door at the nose and walking out the back falls into the shaft. Don't place the shop slab under the van deck.
- **Van speed is tree-written.** `van_speed_level` feeds the chase formula (`closing = mob_world_speed - live_van_speed`). Only allocated schematic nodes change it; pending requests wait until the next run (or apply in `IDLE`). Don't buy speed with gold at the bench, and pending node buys must not emit `van_speed_changed` or the chase window jumps mid-street.

## Facades (street buildings)

Every corridor tile builds its buildings procedurally: `scenes/corridor/corridor_segment.gd` owns a `corridor_facades.gd` helper that, per side, plans buildings (`facade_plan.gd`), emits bodies (`facade_body.gd`), then upper props, ground props, signs, fixtures, and finally a rare set-piece. All the code is in `scripts/travel/facades/`; data is `.tres` under `resources/facades/districts/` (5 districts) and `resources/facades/set_pieces/` (22 rares), both scanned by `facade_registry.gd`. The skin is `scenes/corridor/facade_surface.gdshader`, and its UV is metres (u along the wall, v above the base).

- **Keep-out is the invariant.** `facade_keep_out.gd` holds the boxes, in tile-local metres (right side; left mirrors x): LANE x ±7.6, y < 6.0 (always: the raider lane and the road); MOUTH x 6.0..15.0, y < 7.85, z ±4.45 (bay side, bodies and props); APPROACH x 6.0..9.4, y < 8.5, z ±10 (bay side, props: the reverse-park sweep); MOUTH_SKY x 6.0..9.4, y 8.5..9.5, z ±6; FLANK x > 7.6 (a side-street side builds nothing). They derive from `stop_vestibule.gd` (`DOOR_X`, `MOUTH_WIDTH`, `MOUTH_HEIGHT`): change them only together.
- **Everything is gated.** Boxes go through `facade_mesh_kit.add_box` / `add_box_node` / `add_cylinder_node`. `add_box_ungated` is only for sub-parts of a box that already passed; otherwise a merged family mesh's AABB straddles the mouth and the smoke fails. Quads go only through `facade_body.add_quad`, whose runtime winding oracle handles Godot's clockwise front faces. Never write another emitter.
- **The bay-side building is three meshes** (`Body%dHeader`, `Body%dFlankNeg`, `Body%dFlankPos`) plus `BayFlankSurfaces` collision, because the tile's own wall collision on that side is disabled.
- **Seeding never touches `TravelController._rng`.** Tile `hash([run_seed, segment_index])`, per side `hash([seed, side_idx])`, rare roll `hash([seed, &"rare"])`, span `hash([seed, &"span"])`, overhead `hash([seed, &"overhead"])`. Families roll their chance first in a fixed order, so a new family goes at the END to keep earlier output stable.
- **Rares.** `FacadeSetPiece` (Resource) hooks are `can_apply`, `pick_plan`, `apply_plans` (mutates plan params before bodies), `build(ctx)`. A piece targets a NONE side; span pieces need both sides NONE and build under `Facades/Span`. Any opening change drops the rare, its span and `Facades/Overhead` (industrial cross-street dressing, only on rare-free tiles). A piece takes a plan with `plan[&"rare"] = id` and lists the ordinary families it replaces in `plan[&"suppress"]` (`trim`, `ac_units`, `fire_escape`, `balconies`, `roof_clutter`, `wall_pipes`, `awnings`, `furniture`, `signs`), each skipped before its chance roll. Height lives in three places (`plan.height`, `plan.floors`, `params.facade_height`) and ground kind/units in two (`plan` ints for props, `params` for the shader): change all of them together.
- **Lights.** Wall lamps are shadowless `SpotLight3D`s pointing straight down (`facade_fixtures.gd`: a pool about 3.9 m across the sidewalk with dark between lamps; an omni 0.7 m off the wall only whitened the wall), set-piece lights are shadowless `OmniLight3D`s; all `light_cull_mask = 1`, group `facade_lights`, world cap 12, checked live with an `is_inside_tree()` guard; never on a bay or side-street side. Set `light_cull_mask` before `add_child` and never change it on a live light: a mask change after pairing crashes Godot 4.7 when the lamp is freed (see the render-layers note in the van rules). `visibility_range_end` is a `GeometryInstance3D` property: every mesh under a side root gets 64 m, and setting it on a light is a SCRIPT ERROR.
- **Headless can't see MultiMesh.** `MultiMesh` readback is zero under the headless renderer, so every prop family is an `ArrayMesh` per building so the audits can read AABBs.
- **Junctions and branches** get buildings through `facade_spans.gd` (`build_span`, `build_corner_tower`). `corridor_t_junction.gd` and `side_street_branch.gd` expose `configure(...)`, and the branch creates its `Facades` node after `_ready`'s mirror loop.
- **Near the cap:** `facade_props_upper.gd`, `facade_props_ground.gd` and `facade_materials.gd` are over 300 lines. New families go in new helpers.
- **Debug:** `facade list|district|rare|reseed|stats|dump|check|stress` (`scripts/debug/debug_facade_commands.gd`). `facade_audit.gd` holds the mouth and lane audits that both the console and the smoke use.

## Shop booth

`shop_counter_booth.gd` keeps its exports, build order, lights and box primitives; materials, flyers (and the block-letter glyph table), frame and trim are helpers beside it. Flyer placement is seeded: keep RNG call order when touching it.

## Surfaces and lights (from the 3D art pass)

The numbers are in `.claude/rules/art-style.md`; these are the traps.

- **`industrial_surface.gdshader` lays panels out in model-space metres** (`panel_size_m`, `foot_y_m`), so every user must be an unscaled, centred `BoxMesh` sized through `mesh.size`. A node scale stretches the panels, and there is no `tile_count` or `surface_size_m` any more. Walls of different heights (the elevator shaft) leave `foot_y_m` at its off default instead of guessing one.
- **Merged prop meshes carry 0..1 UVs per box face**, so `facade_prop_grime.gdshader` picks its pattern plane from the face's dominant normal axis in model space. Reach it only through `facade_grime_materials.gd`'s `from_prop()`, which caches one material per budgeted `prop_material()`, so the colour never changes when a prop moves onto grime.
- **Facade walls fade their fine patterns with `fwidth(UV)`** (`pattern_fade`, `line_fade`, `soft_line` in `facade_surface.gdshader`). A new repeating pattern in that shader goes through them, or distant corrugated walls moiré again. Lit windows sit at `window_emission` 0.5 (under the 1.1 glow threshold); only fire windows bloom.
- **A stop light moves with its fixture.** Every stop, junction and statue light hangs under a fixture mesh; move or retune them together and keep the energy unless the shots say otherwise. The statue orb's `OrbLight` is a shadowless 6 m pool.
- **The smoke shots skip most of this.** They see the street, the shop on the lift and the garage; the mechanic, warehouse, junctions, statue and overheads need a temporary `stop elevator mechanic` or `stop warehouse` swap to shoot, reverted before committing.

## Testing

The smoke test drives two forks in `speed` mode: an elevator stop (shop) and a rear-park stop (garage), docking and leaving each. `speed` skips panels, so it doesn't test the reveal or boon UI. Before the first fork it runs `facade stress 1`, which builds every district × set-piece (plus none) × opening case and audits the mouth and lane boxes; after the garage docks it asserts `bay mouth clear:` on the live tile. Facades never feed the fingerprint, so never `--bless` for facade work.
