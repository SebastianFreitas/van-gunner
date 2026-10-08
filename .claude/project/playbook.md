# Van Gunner playbook: the project half of `.claude/playbook.md`

## Delegation

- Parallel implementer calls on separate files are safe for Godot too:
  the tools lock each project folder, so their Godot runs wait for each
  other instead of colliding.
- After merging `implementer-wt` branches: regenerate the map (`py -3
  tools/gen_context.py`), re-run the check and the smoke test.

## Spec details

- **Read first:** the `.claude/rules/` file whose `paths:` cover the
  targets ("Rules files" below; "Where things are" maps areas);
  `art-style.md` plus the area's `art-*.md` file for anything visible,
  and `art-shots.md` when the change moves a shot's numbers.
- **Acceptance:** the commands from `CLAUDE.md` § Verify, and for a
  visible change the `--shots` views and numbers that must change.
- **Build-time budget:** a change that adds or grows generated content
  (a look rebuild, a tile, a pass list) states its `PerfStats` span and
  a ceiling in its Acceptance, measured with `tools/perf.py --compare`
  against a capture from before the change: a build that runs while the
  game is playing stays under 3 ms a frame (the tile build queue's step),
  and a one-off build at run start or on a reroll under 100 ms. Over it:
  split the work into frame steps or cache it, never raise the ceiling
  silently (2026-10-07: the salvage interior's `van_look` rebuild reached
  2.7 to 3.4 s per seed and no plan line had asked for a number).

## Commands

The tools find Godot themselves (`GODOT`, then the Windows user variable,
then `godot` on PATH) and switch to the `_console` build, since the plain
exe writes nothing to a pipe. Local tools run with `py -3`; the cloud
container has only `python3`.

- **Headless check:** `py -3 tools/check.py`.
- **Smoke test:** `py -3 tools/smoke.py [--bless | --shots DIR]`. Plays a
  run like a player headless with `-- --smoke-sandbox` (saves and the meta
  profile never touch `user://`): NEW, IDLE, class panel, GO, `summon
  enemy`, firing, bench, a REST pick, two forks in `speed` mode with an
  elevator stop and a rear-park stop, a save round-trip. Fails on any
  error line, a non-zero exit, the 300 s timeout, or any difference
  between `tools/smoke/fingerprint.txt` and `fingerprint.baseline.txt`.
  The `[waves]` section pins `segment_wave_min` and `segment_wave_max` to
  2 and 4 while it plans, so the owner's balance edits never move the
  fingerprint and a clean clone reproduces the baseline.
- **Scene dump:** `py -3 tools/scene_dump.py [--bless]`. Instantiates
  `van.tscn` headless and fails on any difference from
  `tools/scene_dump/van.baseline.txt`. Run it for any change to the van's
  scenes that should not alter the built tree.
- **Lint the tree:** `py -3 .claude/hooks/gd-lint.py --scan [paths]`.
- **PROJECT_MAP:** `py -3 tools/gen_context.py`.
- **Boons and pools:** `py -3 tools/generate_boons.py`; icons: `py -3
  tools/generate_boon_icons.py`. Boon `.tres` files, pools and icons are
  generated: change the generator and re-run it (the file guard refuses
  hand edits).
- **Probe:** `py -3 tools/probe.py [res://<scene>.tscn] [--cmd "<console
  line>"]... [--eval "<expr>"] [--frames N] [--shot out.png [--every <s>
  --max <n>]] [--timeout S]`. Loads one scene headless and evaluates the
  expression against its root (`PROBE EVAL: <value>`); with no scene it
  boots the run to the van at IDLE (`SceneRouter.go_to_van()`), always
  with `--smoke-sandbox`. `--cmd` lines run through `DebugCommands.run` in
  order first (most need the run, so no scene). `--shot` renders on the
  hidden desktop like `smoke.py --shots`; `--every` and `--max` write
  `<stem>-01.png`…. Fails on any error line, a non-zero exit, a timeout
  or a missing PNG; prints `PROBE CLEAN`. No verify stamp: it never
  replaces check or smoke.
- **Perf:** `py -3 tools/perf.py [--seconds N] [--save NAME] [--compare
  NAME] [--all] [--vsync] [--timeout S]`. Runs the real game with the real
  renderer on the hidden desktop (`--smoke-sandbox`, vsync off): opens the
  van, measures IDLE, then (speed and chill on) takes the first fork,
  waits for the stop, leaves it and waits for TRAVELLING, turns speed
  mode off and measures a normal-speed drive on an open street (`cruise`,
  `--seconds` long), a 5x drive down the same street for its full length
  (`rush`) and a fight with speed mode off (`combat`). Prints `PERF
  key=value` lines: open times, FPS, frame-time percentiles, hitches over
  25 ms with the build that caused each, draw calls, and count/avg/max ms
  per `PerfStats` span (`tile_spawn`, `tile_step`, `road_floor`,
  `road_wreck`, `facade_side`, `arms_build`, `van_look`, `van_load`,
  `street_art`). `--save` writes
  `.godot/perf/NAME.json` (per checkout, gitignored); `--compare` prints
  before, after and the change. `--timeout` defaults to 320 s. Ends `PERF
  CLEAN`. No verify stamp. FPS and hitch counts swing with whatever else
  uses the GPU (the same code read 14 fps and 104 fps in one afternoon
  with a game running beside it), while span counts and span milliseconds
  stayed within about 10 %. Compare counts and span milliseconds between
  runs; compare FPS and hitches only between runs taken with nothing else
  on the GPU; to compare old code with new, measure both in the same
  sitting.
- **Hand shots:** `py -3 tools/hand_shots.py --out <scratchpad>/hands [--pose NAME | --pose "<arms console line>"]... [--views front,side,left,top,elbow,player] [--dress gear|rags|none]`: boots the run at IDLE once, applies the pose, saves `<view>.png` per view (probe `--shot DIR --views`; hidden desktop on Windows, xvfb-run on Linux). `--list` prints the named poses (rest, weave, reload, shot, knock, press, push, pull, slide_open, slide_close, walk).
- **Pose sheet:** `py -3 tools/pose_sheet.py --out <scratchpad>/sheets [--pose NAME]... [--views front,side,top,player] [--dress gear|rags|none] [--keep]`: one `<pose>.png` grid per named pose (default all), one Godot launch each.
- **Stipple:** `py -3 tools/stipple.py <png or folder>... [--mark DIR]` counts isolated dark
  pixels (at most 0.4 of their 3x3 median, median at least 30 of 255) and prints `STIPPLE <n>
  <file>` per picture and `STIPPLE TOTAL`. It also prints `OUTLIER light <n> dim <n> <file>`:
  isolated pixels at least 1.25 times, or at most 0.8 times, their 3x3 median and at least 6
  of 255 away from it (`--mark` paints them cyan and yellow; `--box X0,Y0,X1,Y1` limits the
  count). The meter for the black pixel lines on the
  first-person forearms, on the two wrist close-ups (`tools/probe.py --cmd "arms cam orbit 0
  70 0.2 left" --shot ...`, then `right`). `--mark DIR` saves copies with the counted pixels
  in magenta. Compare counts only between shots of the same view. No verify stamp.
- **Shots:** `py -3 tools/shots.py capture <name> [--van-seeds N]` runs
  `smoke.py --shots` into `.godot/shots/<name>/` (per checkout,
  gitignored, kept between sessions; a full windowed smoke on the hidden
  desktop, 1-2 minutes). `py -3 tools/shots.py compare <a> <b> [--raw]`
  prints `same`/`changed` (or `only-a`/`only-b`) per view with its mean
  pixel diff and tolerance, ends `SHOTS SAME` (exit 0) or `SHOTS CHANGED:
  k of n` (exit 1); `<a>`/`<b>` are set names or directories. Each view's
  tolerance is 2× the noise measured between two captures of one tree,
  written into the tool (`TOLERANCE`). A visible change: capture `before`
  on the parent commit, `after` on the change, compare; the phase's
  Verification names the views that must change and says the rest stay
  `same`.
- Never launch the editor or a windowed game yourself, and never run
  anything that waits for input. The exceptions are `tools/smoke.py
  --shots`, `tools/shots.py capture` and `tools/probe.py --shot`, which
  run on a hidden desktop the owner never sees and quit themselves.

## Shots

`py -3 tools/smoke.py --shots <scratchpad>/shots` saves three views at
IDLE, in combat, at the elevator stop and at the rear-park stop: what the
player sees, the player turned round (`*-back`: it faces the cab end; the
rear doors from inside are `g02-gap-rear-in-whole`), and a camera above the
cab looking back over the van at the street, raiders or stop (UI hidden
in the last two). On Windows it runs Godot on a separate hidden Win32
desktop (`tools/hidden_desktop.py`), so no window ever appears on, takes
focus from, or alt-tabs the owner out of what they are doing (they play
fullscreen games while sessions verify); Windows desktop only. Never
launch a windowed Godot any other way. For a before/after comparison use
`tools/shots.py` (`capture`, `compare`, under Commands).

## Rules files

Each loads only for a session that reads a file its `paths:` cover.

- `art-style.md` (mood, light, albedo, colour, checking), `art-shots.md`
  (shot targets), `art-3d.md` (procedural 3D, props, stop steel, van
  look, street art), `art-arms.md` and `art-arms-pose.md` (first-person
  arms), `art-pixel.md` and `art-loper.md` (sprites).
- `travel-and-stops.md`, `facades.md`, `street-paving.md`;
  `van-shell-and-hud.md`, `van-geometry.md`, `van-look.md`,
  `van-render-layers.md`;
  `enemies-and-breaching.md`, `combat-and-boons.md`,
  `run-loop-and-acts.md`, `saves-and-meta.md`, `audio.md`.
- `tooling.md` (Godot tools, Try/Commit), `tooling-shots.md`
  (screenshots, shot compare, van audit, arms tools), `tooling-hooks.md`
  (hooks, autoplan, plan files).

## Where things are

| Concept | Folder or file |
|---|---|
| Run state, phases, act deck, saves, vitals | `scripts/core/game_session.gd` + `session_save.gd`, `session_act_deck.gd`, `session_vitals.gd` |
| Balance numbers | `resources/balance/game_balance.tres` via `scripts/core/game_balance.gd` |
| Saves, meta progression, sandbox | `scripts/core/save_manager.gd`, `meta_progression.gd`, `save_sandbox.gd` |
| Street cards, reveal, REST boon | `scripts/acts/`, `resources/acts/cards/`, `scripts/ui/act_reveal_panel.gd` |
| Raiders, boss, cabin pathing, breach points, waves | `scripts/enemies/` |
| Road, turns, parking, elevator, statues | `scripts/travel/` |
| Street facades, districts, set-pieces | `scripts/travel/facades/`, `resources/facades/`, `scenes/corridor/facade_*.gdshader` |
| Side stops: shop, garage, mechanic, warehouse | `scripts/stops/`, `resources/side_stops/`, `scenes/corridor/` |
| Van shell, doors, windows, vitals, van root and HUD wiring | `scripts/van/` |
| Van look (seeded war-rig dressing, machine looks, cables) | `scripts/van/look/` (`van_look.gd` owns the seed; `machine_parts.gd`, `machine_motion.gd`, `machine_damage.gd`; cables `van_cable_runs.gd` + `van_cable_router.gd`) |
| Gun, projectiles, damage, status effects | `scripts/combat/` |
| First-person arms and held gun (seeded viewmodel) | `scripts/player/arms/`, `scripts/combat/gun_viewmodel.gd` |
| Classes | `scripts/classes/`, `resources/classes/` |
| Player, boons, tools | `scripts/player/`, `scripts/items/`, `resources/items/` |
| HUD panels, bench, schematic, menus | `scripts/ui/` |
| Interactables, NPC talk | `scripts/interactions/`, `scripts/dialogue/npc_talk.gd`, `scripts/ui/dialogue_hud.gd` |
| Loot hopper, death popups | `scripts/core/loot_collector.gd`, `scripts/interactions/loot_machine.gd` |
| Weld kit (look-at repair) | `scripts/items/effects/repair_window_bars_effect.gd` |
| Yell at the driver (Shift TURBO or go / C EASY then STOP), halt, mantle back in | `travel_controller.gd` boost/slow/halt, `scripts/van/van_driver_talk.gd`, `van_halt.gd`, `scripts/player/player_mantle.gd`, `scripts/ui/driver_shout_hud.gd` |
| Pause menu | `scripts/ui/pause_menu.gd` |
| Debug console (`H`) | `scripts/debug/` (`DebugCommands.run(line)`) |
| Perf overlay (`F3`, console `perf`), build spans, benchmark | `scripts/debug/perf_stats.gd` (`PerfStats.begin/end/mark`), `scripts/ui/perf_overlay.gd` (autoload `PerfOverlay`), `scripts/debug/debug_perf_commands.gd`, `tools/perf.py`, `tools/perf/` |
| Audio | `scripts/audio/`, `resources/audio/sound_bank.tres` |
| Smoke test and screenshots | `tools/smoke/`, `tools/smoke.py` |
| Scene dump | `tools/scene_dump/`, `tools/scene_dump.py` |
| Godot discovery, `.godot/` seeding, tool lock, verify stamps | `tools/godot_env.py` |
| The owner's Try and Commit | `tools/try.py`, `tools/try_commit.py` (shared), `tools/try_project.py` (van-gunner's hooks: Godot launch, map, check, smoke) |
| Double-click launch of the checkout it sits in (real saves, no editor) | `play.bat` |
| Claude Code workflow | `.claude/rules/workflow.md` (shared rules), `.claude/playbook.md` + `.claude/project/playbook.md` (specs, delegation, tool commands), `.claude/modes/` + `.claude/project/modes/`, `.claude/hooks/`, `.claude/agents/`, `.claude/skills/`, `.claude/rules/tooling.md` |
| Cloud session Godot install | `tools/cloud_setup.sh` |
