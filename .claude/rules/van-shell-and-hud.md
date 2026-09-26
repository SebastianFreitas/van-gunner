---
paths:
  - "scripts/van/**"
  - "scripts/ui/**"
  - "scripts/interactions/**"
  - "scripts/dialogue/**"
  - "scripts/debug/**"
  - "scripts/core/scene_router.gd"
  - "scenes/van/**"
  - "scenes/ui/**"
---

# Van shell, HUD, mouse capture and pause

## How van.gd is split

`scripts/van/van.gd` is the root script of `van.tscn` and has no `class_name` (cycle rule). It keeps every `@onready` node, all state, the awaits, mouse capture and every method other files call. Helpers beside it take the van and read its fields: `van_route_choice.gd` (fork panel), `van_hud.gd` (HUD handlers, phase toasts), `van_driver_talk.gd` (driver talk, boost/slow requests), `van_overlays.gd` (bench / schematic / class panel / console / pause routing, `has_modal_free_cursor`, HUD passthrough). `tools/smoke/smoke_driver.gd` reads `van.get("_class_panel")`, `van.get("_boon_choice")` and `van.get("bench_screen")`, so those stay on van.

## Van scene files

`van.tscn` instances three sub-scenes at their old paths: `Interior/Shell` is `scenes/van/van_shell.tscn`, `EnemyContainer/BreachController` is `scenes/van/van_breach_points.tscn`, and `HUD` is `scenes/ui/run_hud.tscn`. Node paths from the van root are unchanged. The HUD's 25 unique-named nodes are owned by `run_hud.tscn`, so `van.gd` reaches them as `$HUD/%Name`; a bare `%Name` from the van root returns null. The HUD buttons' `pressed` connections to the van root live in `van.tscn`, since their target is outside the HUD scene. The shell, front wall and cab door share one wall material, `scenes/van/van_wall_material.tres`; `cab_door.gd`, `van_front_wall.gd` and `rear_doors.gd` read it through `walls.wall_material` (the front wall duplicates it to set `wall_size_m`). Keep it one shared resource. `py -3 tools/scene_dump.py` proves a van scene edit leaves the built tree unchanged.

## Mouse capture

Godot ignores `MOUSE_MODE_CAPTURED` on the same frame as a GUI click. `van.gd` works around it with `_capture_mouse_after_ui_click()` and a `_mouse_capture_gen` counter. New overlays must call `refresh_mouse_mode()` on close rather than setting the mode themselves, and register in `has_modal_free_cursor()` (body in `van_overlays.gd`). Don't `gui_release_focus()` while the debug console is open: that unfocuses the LineEdit so you have to click it to type.

## Pause menu

Esc opens it and sets `get_tree().paused`. The overlay is `PROCESS_MODE_ALWAYS` so Resume still works. `SceneRouter` unpauses on every scene change; skip that and the main menu loads frozen. Don't open pause on `GAME_OVER` (those buttons are pausable). Bench, schematic, class panel and console still eat Esc first and close themselves.

## HUD eating clicks

Any non-interactive HUD control must be `MOUSE_FILTER_IGNORE`, otherwise clicking through it uncaptures the mouse. `make_combat_hud_mouse_passthrough()` in `van_overlays.gd` handles this; add genuinely interactive panels to `is_interactive_hud()` there.

## Loading

- Threaded loading of `van.tscn` fails. `SceneRouter.preload_van()` deliberately uses a synchronous `ResourceLoader.load`; the threaded path dies on the floor shader sub-resource. Don't "optimise" it back.
- `debug_console.tscn` is `load()`ed, not `preload()`ed (`van_overlays.build_debug_console()`), so a broken console scene doesn't hard-fail the van scene at compile time. The schematic HUD is instanced in `run_hud.tscn` but not preloaded into `van.gd` for the same reason.
- `DebugConfig.ENABLED` is a `static var` from `OS.has_feature("debug")`. Editor and debug exports get the console (`H`); release exports don't. `DebugConfig.FORCE_ENABLED = true` ships it in a release build.

## Debug console

`DebugCommands` (autoload) keeps `run`, help, completion and the `_commands` table in a fixed key order; each command group lives in `scripts/debug/debug_*_commands.gd` and list/id helpers in `debug_catalog.gd`. Add a command by adding a `cmd_x` method to the right group and one entry in `_register_commands`.

In game, **H** opens it. `help` lists commands; `list commands|boons|items|classes|cards|stops|sounds|tree` enumerates content. `stop <id>` forces that side stop on the next fork (`stop rare_shop` or `stop elevator shop` for the elevator), `class <id>` equips a class in any phase, `parts [n]` grants Rare Parts, `tree_reset` wipes the schematic, `sound <cue>` auditions a cue. `speed` fast-forwards and auto-resolves reveals and boon picks, so it skips the panels; don't use it to test UI. `chill` / `unchill` pause and resume encounters without leaving the run. The main scene is `scenes/boot/boot.tscn`.

Inspection lights: `torch [on|off]` hangs a `DebugTorch` SpotLight3D under the player camera (rides along in `ghost`); `floodlight [on|off]` adds `DebugFloodlights`, four omnis at the rig's corners, so the whole exterior is lit at once. Both are cull mask 3 (layers 1 and 2), built once and toggled with `visible` (never re-masked: light pairing, below), and off by default. `tools/smoke.py --shots` saves the `van-lit-*` views with the floodlight on; those are outside the `*-outside` brightness budget in `art-style.md`, the unlit shots are not.

## Van hull and vitals

Player HP and van hull are both fail conditions: either bar at 0 is `GAME_OVER`. Van hull is the sum of interior vitals (bench, hopper, fuse box, cab relay), not door/window smash HP. Heal consumables restore player HP only; the weld kit (look-at, +50) repairs a machine, door or window. Max-HP boons still raise van hull, split across the vitals. Fuse box and cab relay vitals need an explicit `vital_id` on their `van.tscn` instances; the dummy scene leaves it empty, so both would become `&"van_vital"`.

## Dialogue

Talking frees the cursor (`has_modal_free_cursor`) so options highlight on hover and click to pick. E still walks away. Keys 1–4 route to `DialogueHud.try_choose` first so a leftover weld kit doesn't fire mid-talk.

## Van shell geometry

`VanSideWall` exposes the bow profile (`wall_x_at`, `local_x_on_wall`) and the curved mesh builders (`build_curved_shell_mesh`, `build_curved_pane_from_poly`, `build_curved_frame_ring_mesh`) that doors, windows, iron crosses, bulkhead and hull use. The builders delegate to `van_side_wall_shell.gd`; the wall's own panel is `van_side_wall_panel.gd`. Keep those public names on `VanSideWall`.

`VanBodyProfile` (`scripts/van/van_body_profile.gd`, RefCounted, built by `VanBodyProfile.from_interior(Interior)`) is the one cross-section inside and outside sample: `inner_x_at(y)`, `outer_x_at(y)` (+0.12 wall), `roof_y_at(x)`, `outer_roof_y_at(x)`, `section_points(steps, outer)` and `build_reveal_mesh`. It lives beside `VanSideWall` because that script is near the 400-line cap. Anything new that must meet the walls or the vault (a partition, a cab back, a skin) takes its outline from here, never from its own constants: the old front end was three slabs with their own insets and it deformed against the vault.

The cab end is one piece, `Interior/FrontWall` (`VanFrontWall`): a slab triangulated from `section_points` with a doorway notch (x ±0.775, y 0..2.30), a `CollisionPolygon3D` from the same outline, and casings. `CabDoor` is a recessed barred leaf inside that notch. Change the outline only through the profile or the notch constants, so mesh and collision stay one shape.

Outside, `VanLook/Hull` still pushes the liner out 6 cm for the skin; `van_hull_lines.gd` adds the body lines (rub rail, belt line, drip rail broken around every opening, bowed corner posts) at `inner_x_at(y) + 0.06`. `VanLook/MarkerLights` holds the clearance, tail and ID lamps: each light sits at its fixture on layer 1, with energies tuned against the `*-outside` budget in `art-style.md`.

## Render layers and light pairing

Van interior and player meshes sit on render layer 2 (`VanLighting.LAYER_VAN_INTERIOR`) so the door-spill lights (cull mask 1) light the corridor through openings without washing the cabin. Set `layers` before `add_child`, as the shell builders do. To change it on a mesh already in the tree, go through `VanLighting.retarget_layers`, which hides the render instance first. Godot 4.7's Forward+ renderer keeps a light↔mesh pairing across a `layers` or `light_cull_mask` change, then skips the unpair once the masks stop overlapping, so when either side is freed (a street lamp culled behind the van) the game crashes right after `BUG, indexing did not unpair geometries from light`. Hiding only the van's own lights is not enough: any world light near the van pairs too.

## Van look (the war-rig)

`VanLook` (`scripts/van/look/van_look.gd`, node `VanRig/VanLook`) owns the look seed: `seed_for_run(run_seed)` hashes the run seed, but with no run or in the smoke sandbox it is `DEFAULT_VAN_SEED` (1337), so the scene dump and smoke fingerprint stay stable. Its children (hull, cab, wheels, armour, roof, markings, cables, inner shell, rear dressing) each implement `rebuild_look(look)` and take their randomness from `look.rng_for(&"part")`, one RNG stream per part, so adding a part never reshuffles the others. It rebuilds on a run-seed change and on `session_loaded`; a debug reroll pins the seed until the run changes. Doors, windows, breach points, machine positions and the walk space never vary; only the dressing does.

Machine looks (`van_generator.gd`, `van_relay_rack.gd`, `van_welding_bench.gd`, `van_scrap_hopper.gd`, `van_pc_rig.gd`, each with a `*_parts.gd` RefCounted helper) hide the original mesh in `_ready`, rebuild it from `MachineParts.*` primitives, wire `MachineMotion` (spin, pump, wobble, `add_flicker`) and `MachineDamage`, keep the collision box matched to the visible footprint, and hang an `OmniLight3D` (energy 0.35 to 0.9, range 1.6 to 2.4, shadow off, `light_cull_mask` = `VanLighting.LAYER_VAN_INTERIOR`) under a visible lamp housing. Set `layers` and `light_cull_mask` before `add_child`.

Power ports: each machine adds a `Marker3D` `PowerPort` to group `&"machine_power_ports"` with meta `machine` (`generator`, `relay_rack`, `welding_bench`, `scrap_hopper`, `pc_rig`) and `role` (`source` generator, `hub` relay rack, `out` the relay rack's `LoadPort`, `load` the rest). `van_cable_runs.gd` reads those markers at rebuild time, so cables always end at a real plug; never hard-code a machine's port position. `van_cable_router.gd` keeps every cable vertex inside `wall_x_at(y) - 0.10` and out of the machines' collision AABBs and the aisle (|x| < 0.6 below y 2.2). Ceiling trunks sit at `min(2.2, wall_x_at(2.95) - 0.14)`: the wall bows in with height, so a fixed x clips it.

The DoorSpill, RearCone and moon lights are a deliberate exception (see `art-style.md`); the look never dims or replaces them.
