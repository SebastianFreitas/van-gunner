# Van Gunner playbook: the project half of `.claude/playbook.md`

## Delegation

- Parallel implementer calls on separate files are safe for Godot too:
  the tools lock each project folder, so their Godot runs wait for each
  other instead of colliding.
- After merging `implementer-wt` branches: regenerate the map (`py -3
  tools/gen_context.py`), re-run the check and the smoke test.

## Spec details

- **Rules:** copy the values, e.g. from `.claude/rules/art-style.md`.
- **Verification:** the commands from `CLAUDE.md` § Verify.

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
- **Hand shots:** `py -3 tools/hand_shots.py --out <scratchpad>/hands [--pose NAME | --pose "<arms console line>"]... [--views front,side,left,top,elbow,player] [--dress gear|rags|none]`: boots the run at IDLE once, applies the pose, saves `<view>.png` per view (probe `--shot DIR --views`; hidden desktop on Windows, xvfb-run on Linux). `--list` prints the named poses (rest, weave, reload, shot, knock, press, push, pull, slide_open, slide_close, walk).
- **Pose sheet:** `py -3 tools/pose_sheet.py --out <scratchpad>/sheets [--pose NAME]... [--views front,side,top,player] [--dress gear|rags|none] [--keep]`: one `<pose>.png` grid per named pose (default all), one Godot launch each.
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
  Verification names the views that must change.
- Never launch the editor or a windowed game yourself, and never run
  anything that waits for input. The exceptions are `tools/smoke.py
  --shots`, `tools/shots.py capture` and `tools/probe.py --shot`, which
  run on a hidden desktop the owner never sees and quit themselves.
