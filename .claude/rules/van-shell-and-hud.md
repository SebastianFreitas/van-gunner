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

## Mouse capture

Godot ignores `MOUSE_MODE_CAPTURED` on the same frame as a GUI click. `van.gd` works around it with `_capture_mouse_after_ui_click()` and a `_mouse_capture_gen` counter. New overlays must call `refresh_mouse_mode()` on close rather than setting the mode themselves, and register in `has_modal_free_cursor()` (body in `van_overlays.gd`). Don't `gui_release_focus()` while the debug console is open: that unfocuses the LineEdit so you have to click it to type.

## Pause menu

Esc opens it and sets `get_tree().paused`. The overlay is `PROCESS_MODE_ALWAYS` so Resume still works. `SceneRouter` unpauses on every scene change; skip that and the main menu loads frozen. Don't open pause on `GAME_OVER` (those buttons are pausable). Bench, schematic, class panel and console still eat Esc first and close themselves.

## HUD eating clicks

Any non-interactive HUD control must be `MOUSE_FILTER_IGNORE`, otherwise clicking through it uncaptures the mouse. `make_combat_hud_mouse_passthrough()` in `van_overlays.gd` handles this; add genuinely interactive panels to `is_interactive_hud()` there.

## Loading

- Threaded loading of `van.tscn` fails. `SceneRouter.preload_van()` deliberately uses a synchronous `ResourceLoader.load`; the threaded path dies on the floor shader sub-resource. Don't "optimise" it back.
- `debug_console.tscn` is `load()`ed, not `preload()`ed (`van_overlays.build_debug_console()`), so a broken console scene doesn't hard-fail the van scene at compile time. The schematic HUD is instanced in `van.tscn` but not preloaded into `van.gd` for the same reason.
- `DebugConfig.ENABLED` is a `static var` from `OS.has_feature("debug")`. Editor and debug exports get the console (`H`); release exports don't. `DebugConfig.FORCE_ENABLED = true` ships it in a release build.

## Debug console

`DebugCommands` (autoload) keeps `run`, help, completion and the `_commands` table in a fixed key order; each command group lives in `scripts/debug/debug_*_commands.gd` and list/id helpers in `debug_catalog.gd`. Add a command by adding a `cmd_x` method to the right group and one entry in `_register_commands`.

In game, **H** opens it. `help` lists commands; `list commands|boons|items|classes|cards|stops|sounds|tree` enumerates content. `stop <id>` forces that side stop on the next fork (`stop rare_shop` or `stop elevator shop` for the elevator), `class <id>` equips a class in any phase, `parts [n]` grants Rare Parts, `tree_reset` wipes the schematic, `sound <cue>` auditions a cue. `speed` fast-forwards and auto-resolves reveals and boon picks, so it skips the panels; don't use it to test UI. `chill` / `unchill` pause and resume encounters without leaving the run. The main scene is `scenes/boot/boot.tscn`.

## Van hull and vitals

Player HP and van hull are both fail conditions: either bar at 0 is `GAME_OVER`. Van hull is the sum of interior vitals (bench, hopper, fuse box, cab relay), not door/window smash HP. Heal consumables restore player HP only; the weld kit (look-at, +50) repairs a machine, door or window. Max-HP boons still raise van hull, split across the vitals. Fuse box and cab relay vitals need an explicit `vital_id` on their `van.tscn` instances; the dummy scene leaves it empty, so both would become `&"van_vital"`.

## Dialogue

Talking frees the cursor (`has_modal_free_cursor`) so options highlight on hover and click to pick. E still walks away. Keys 1–4 route to `DialogueHud.try_choose` first so a leftover weld kit doesn't fire mid-talk.

## Van shell geometry

`VanSideWall` exposes the bow profile (`wall_x_at`, `local_x_on_wall`) and the curved mesh builders (`build_curved_shell_mesh`, `build_curved_pane_from_poly`, `build_curved_frame_ring_mesh`) that doors, windows, iron crosses, bulkhead and hull use. The builders delegate to `van_side_wall_shell.gd`; the wall's own panel is `van_side_wall_panel.gd`. Keep those public names on `VanSideWall`.
