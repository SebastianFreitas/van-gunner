# Playbook: read before writing the first spec of a turn

Moved out of CLAUDE.md (2026-09-28, workflow-port D16) so sessions that write no spec do not pay
for it every turn. Everything here is still a rule.

## Delegation

- Parallel implementer calls only on completely separate files. The tools lock each project
  folder, so their Godot runs wait for each other instead of colliding.
- Parallel tasks on the same file (worktree and cloud mode only): `implementer-wt`, each in its
  own worktree cut from your `HEAD`, so commit first. Merge their branches one at a time with
  `git merge --no-ff`, resolve, regenerate the map, re-run the check and the smoke test.
- A new file over about 250 lines: the spec writes a skeleton first and adds function groups with
  Edits. One big Write dies on the output cap.
- An implementer that reports "blocked" or "hit the context line": never resume it with
  SendMessage (that reloads its whole context); write a narrower spec for a fresh call.
- A plan phase that stops after designing saves each finished spec as
  `.claude/plans/<name>.spec-<phase>-<k>.md` in the format below (plan skill).

## Spec format

Complete enough that the implementer never chooses a name, a location or a design. Every
delegation contains:

1. **Target files:** the exact path of every file to create, edit or delete, and the function
   names to grep for.
2. **Symbols:** exact names and full typed signatures for everything added or changed.
3. **Logic steps:** the implementation as an ordered, numbered list.
4. **Edge cases:** each one and exactly how to handle it.
5. **Do not touch:** files, symbols and behaviour that must stay unchanged, including foreign
   edits already in a target file (shared mode).
6. **Rules:** the invariants and `.claude/rules/` pitfalls this change must respect (the
   implementer never sees CLAUDE.md or the rules; copy the values, e.g. from `art-style.md`).
7. **Verification:** the commands from Verify, plus a `git grep` proving deleted symbols are gone
   when the spec deletes something.

## Commands

The tools find Godot themselves (`GODOT`, then the Windows user variable, then `godot` on PATH)
and switch to the `_console` build, since the plain exe writes nothing to a pipe. Local tools run
with `py -3`; the cloud container has only `python3`.

- **Headless check:** `py -3 tools/check.py`.
- **Smoke test:** `py -3 tools/smoke.py [--bless | --shots DIR]`. Plays a run like a player
  headless with `-- --smoke-sandbox` (saves and the meta profile never touch `user://`): NEW,
  IDLE, class panel, GO, `summon enemy`, firing, bench, a REST pick, two forks in `speed` mode
  with an elevator stop and a rear-park stop, a save round-trip. Fails on any error line, a
  non-zero exit, the 300 s timeout, or any difference between `tools/smoke/fingerprint.txt` and
  `fingerprint.baseline.txt`. The `[waves]` section pins `segment_wave_min` and
  `segment_wave_max` to 2 and 4 while it plans, so the owner's balance edits never move the
  fingerprint and a clean clone reproduces the baseline.
- **Scene dump:** `py -3 tools/scene_dump.py [--bless]`. Instantiates `van.tscn` headless and
  fails on any difference from `tools/scene_dump/van.baseline.txt`. Run it for any change to the
  van's scenes that should not alter the built tree.
- **Lint the tree:** `py -3 .claude/hooks/gd-lint.py --scan [paths]`.
- **PROJECT_MAP:** `py -3 tools/gen_context.py`.
- **Boons and pools:** `py -3 tools/generate_boons.py`; icons: `py -3
  tools/generate_boon_icons.py`. Boon `.tres` files, pools and icons are generated: change the
  generator and re-run it (the file guard refuses hand edits).
- **Autoplan:** `py -3 tools/autoplan.py [<name>] [--dry-run] [--max-sessions N] [--budget USD]
  [--effort medium] [--line 120000] [--kill 140000] [--force]`. Owner-run from a terminal: runs a
  plan's phases unattended, one headless session each, in `.claude/worktrees/plan-<name>` on
  `claude/plan-<name>`, on the Max subscription only (no API key; stops at a usage limit, never
  retries), and stops on `Status: blocked` or `plan-done`. Logs and the run lock in
  `.claude/autoplan/`. `--dry-run` prints the command, the phase and the worktree without creating
  anything.
- **Try and Commit:** `tools/try.py`, commands in your mode file. Try belongs to the owner: print
  it, never run it. Commit: worktree mode runs it itself once verified; cloud and shared print it.
- **Probe:** `py -3 tools/probe.py [res://<scene>.tscn] [--cmd "<console line>"]...
  [--eval "<expr>"] [--frames N] [--shot out.png [--every <s> --max <n>]] [--timeout S]`. Loads
  one scene headless and evaluates the expression against its root (`PROBE EVAL: <value>`); with
  no scene it boots the run to the van at IDLE (`SceneRouter.go_to_van()`), always with
  `--smoke-sandbox`. `--cmd` lines run through `DebugCommands.run` in order first (most need the
  run, so no scene). `--shot` renders on the hidden desktop like `smoke.py --shots`; `--every`
  and `--max` write `<stem>-01.png`…. Fails on any error line, a non-zero exit, a timeout or a
  missing PNG; prints `PROBE CLEAN`. No verify stamp: it never replaces check or smoke.
- **Shots:** `py -3 tools/shots.py capture <name> [--van-seeds N]` runs `smoke.py --shots` into
  `.godot/shots/<name>/` (per checkout, gitignored, kept between sessions; a full windowed smoke
  on the hidden desktop, 1-2 minutes). `py -3 tools/shots.py compare <a> <b> [--raw]` prints
  `same`/`changed` (or `only-a`/`only-b`) per view with its mean pixel diff and tolerance, ends
  `SHOTS SAME` (exit 0) or `SHOTS CHANGED: k of n` (exit 1); `<a>`/`<b>` are set names or
  directories. Each view's tolerance is 2× the noise measured between two captures of one tree,
  written into the tool (`TOLERANCE`). A visible change: capture `before` on the parent commit,
  `after` on the change, compare; the phase's Verification names the views that must change.
- Never launch the editor or a windowed game yourself, and never run anything that waits for
  input. The exceptions are `tools/smoke.py --shots`, `tools/shots.py capture` and
  `tools/probe.py --shot`, which run on a hidden desktop the owner never sees and quit
  themselves.
