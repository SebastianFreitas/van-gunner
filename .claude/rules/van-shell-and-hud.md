---
paths:
  - "scripts/van/van.gd"
  - "scripts/van/van_driver_talk.gd"
  - "scripts/van/van_halt.gd"
  - "scripts/van/van_hud.gd"
  - "scripts/van/van_overlays.gd"
  - "scripts/van/van_route_choice.gd"
  - "scripts/van/van_lighting.gd"
  - "scripts/van/van_vital.gd"
  - "scripts/van/van_player_containment.gd"
  - "scripts/van/room_zone.gd"
  - "scripts/ui/**"
  - "scripts/interactions/**"
  - "scripts/dialogue/**"
  - "scripts/debug/**"
  - "scripts/core/scene_router.gd"
  - "scenes/van/van.tscn"
  - "scenes/van/van_vital_dummy.tscn"
  - "scenes/van/*_board.tscn"
  - "scenes/van/loot_machine.tscn"
  - "scenes/ui/**"
---

# Van shell, HUD, mouse capture and pause

The shell's geometry and seams are `van-geometry.md`; the war-rig look is `van-look.md`.

## How van.gd is split

`scripts/van/van.gd` is the root script of `van.tscn` and has no `class_name` (cycle rule). It keeps every `@onready` node, all state, the awaits, mouse capture and every method other files call. Helpers beside it take the van and read its fields: `van_route_choice.gd` (fork panel), `van_hud.gd` (HUD handlers, phase toasts), `van_driver_talk.gd` (driver talk, boost/slow requests), `van_overlays.gd` (bench / schematic / class panel / console / pause routing, `has_modal_free_cursor`, HUD passthrough). `tools/smoke/smoke_driver.gd` reads `van.get("_class_panel")`, `van.get("_boon_choice")` and `van.get("bench_screen")`, so those stay on van.

## Van scene files

`van.tscn` instances three sub-scenes at their old paths: `Interior/Shell` is `scenes/van/van_shell.tscn`, `EnemyContainer/BreachController` is `scenes/van/van_breach_points.tscn`, and `HUD` is `scenes/ui/run_hud.tscn`. Node paths from the van root are unchanged. The HUD's 25 unique-named nodes are owned by `run_hud.tscn`, so `van.gd` reaches them as `$HUD/%Name`; a bare `%Name` from the van root returns null. The HUD buttons' `pressed` connections to the van root live in `van.tscn`, since their target is outside the HUD scene. The shell, front wall and cab door share one wall material, `scenes/van/van_wall_material.tres`; `cab_door.gd`, `van_front_wall.gd` and `rear_doors.gd` read it through `walls.wall_material` (the front wall duplicates it to set `wall_size_m`). Keep it one shared resource. `py -3 tools/scene_dump.py` proves a van scene edit leaves the built tree unchanged.

## Driver orders and leaving the van

Shift and C are driver orders only while the player is inside the van (`VanHalt.is_player_inside` = `VanPlayerContainment.is_inside_interior`: inside the cabin walls, 2.24 by 4.68 half sizes with no margin, and local y above -0.35, because the road is -0.9 and the deck 0.05; owner, 2026-10-03: the old test used the containment box with its 0.8 m margin, so standing outside against the hull counted as inside). Outside, `VanDriverTalk.shout_keys_blocked` leaves them unhandled so a later dash and crouch can take them, and the van will not start ("GET BACK IN THE VAN"). While the van is halted the rear exit and both side door bays are open to walk out (`VanPlayerContainment.set_halt_exit`: its side panels are split per side into Front, Door and Rear boxes and only `LeftDoor`/`RightDoor` turn off, so a closed leaf's layer-1 `Blocker` still stops the player; side stops stay rear-only; `van_hud.gd` skips its re-seal while halted) and the rear doors are opened with E; when it starts again the doors close by themselves. There is no climb-in interact (owner, 2026-10-03: "i dont want an interact to climb into the van"): the player jumps at the open rear or an open side door bay and `player_mantle.gd` climbs them onto the deck (rise about 0.9 m, under its 1.3 m limit). Jump works anywhere outside the cabin and never inside it. `van.gd` is at its line cap: `VanHalt` is created by `van_driver_talk.gd` and connects itself deferred.

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

`DebugCommands` (autoload) keeps `run`, help, completion and the `_commands` table in a fixed key order; each command group lives in `scripts/debug/debug_*_commands.gd` and list/id helpers in `debug_catalog.gd`. Add a command by adding a `cmd_x` method to the right group, one entry in `_register_commands` and one line in `_usage_lines()` (help is built from it; a missing line asserts). Completion lives in `debug_completion.gd` (`_arg_candidates` is the one source of argument lists). `arms` subs come from `SUBS` in `debug_arms_commands.gd`; their hints and current-value read-backs are in `debug_arms_hints.gd`, so a new arms sub needs a `SUBS` entry and an `INFO` line there. Tab on `arms <sub> ` with nothing after it fills the current values.

The console sits bottom-left and is in group `debug_console` with `is_typing()`. Event handlers are swallowed by its `_unhandled_input`, but `Input.*` polling ignores that: any game code that polls keys (like `fps_player.gd` movement, jump, shoot, interact hold) must check `is_typing()` through the group, or typing WASD walks the player.

In game, **H** opens it. `help` lists commands; `list commands|boons|items|classes|cards|stops|sounds|tree` enumerates content. `stop <id>` forces that side stop on the next fork (`stop rare_shop` or `stop elevator shop` for the elevator), `class <id>` equips a class in any phase, `parts [n]` grants Rare Parts, `tree_reset` wipes the schematic, `sound <cue>` auditions a cue. `speed` fast-forwards and auto-resolves reveals and boon picks, so it skips the panels; don't use it to test UI. `chill` / `unchill` pause and resume encounters without leaving the run. The main scene is `scenes/boot/boot.tscn`.

Inspection lights: `torch [on|off]` hangs a `DebugTorch` SpotLight3D under the player camera (rides along in `ghost`); `floodlight [on|off]` adds `DebugFloodlights`, four omnis at the rig's corners, so the whole exterior is lit at once. Both are cull mask 3 (layers 1 and 2), built once and toggled with `visible` (never re-masked: light pairing, below), and off by default. `tools/smoke.py --shots` saves the `van-lit-*` views with the floodlight on; those are outside the `*-outside` brightness budget in `art-shots.md`, the unlit shots are not.

## Van hull and vitals

Player HP and van hull are both fail conditions: either bar at 0 is `GAME_OVER`. Van hull is the sum of interior vitals (bench, hopper, fuse box, cab relay), not door/window smash HP. Heal consumables restore player HP only; the weld kit (look-at, +50) repairs a machine, door or window. Max-HP boons still raise van hull, split across the vitals. Fuse box and cab relay vitals need an explicit `vital_id` on their `van.tscn` instances; the dummy scene leaves it empty, so both would become `&"van_vital"`.

## Dialogue

Talking frees the cursor (`has_modal_free_cursor`) so options highlight on hover and click to pick. E still walks away. Keys 1–4 route to `DialogueHud.try_choose` first so a leftover weld kit doesn't fire mid-talk.

## Render layers and light pairing

In `van-render-layers.md` (loads for every `scripts/van/**` and `scenes/van/**` file).
