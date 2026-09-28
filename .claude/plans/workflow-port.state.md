Status: phase-done

# Plan state: workflow-port

- **Plan:** `workflow-port`, `.claude/plans/workflow-port.md`. Phases 3-6 ran on branch
  `claude/workflow-port-state-next-890c49` (worktree `workflow-port-state-next-890c49`); phases 1-2
  on `claude/port-claude-workflow-godot-294f0c`. Worktree sessions land their own work with
  `try.py <branch> --commit` (D24).
- A fresh worktree has no HERE: with vanfix (ready) and workflow-port (running) both active the
  hook prints `PLANS:`; write `workflow-port` to the gitignored `.claude/plans/HERE` first.

## Architecture now
- `.claude/skills/plan/SKILL.md`, `.claude/skills/plan/unattended.md`, `.claude/plans/TEMPLATE.md`:
  the procedure (phase 1).
- `.claude/hooks/session-start.py`: HERE binding, `PLAN:`/`PLANS:` lines (phase 2).
- `.claude/hooks/context-watch.py`: main line `int(AUTOPLAN_LINE or 120_000)`.
- `.claude/settings.json`: `CLAUDE_CODE_AUTO_COMPACT_WINDOW` 200000, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` 65.
- `CLAUDE.md` (phase 4): Active plan (several plans, HERE, state files, autoplan), playbook pointer,
  120k line, worktree sessions self-run Commit.
- `.claude/playbook.md`: Delegation, Spec format, Commands. Autoplan and Probe are real Commands
  bullets. "Coming in workflow-port phase 7" lists only Shots. The last bullet names both
  hidden-desktop exceptions (`smoke.py --shots`, `probe.py --shot`).
- `tools/autoplan.py` (phase 5, 1050 lines): plan and state parsing, the worktree with HERE, the
  lock, headless sessions, the usage-limit stop and safety commits.
- `tools/probe.py` (phase 6), with these arguments: `[res://x.tscn] [--cmd line]... [--eval expr]
  [--frames N] [--shot out.png [--every s --max n]] [--timeout 180]`.
  - It always passes `--smoke-sandbox`, holds `project_lock`, and runs headless unless it takes a
    shot. Shots run windowed on the hidden desktop via `hidden_desktop.run_hidden` (win32 only).
  - It fails on any error line, a non-zero exit, a timeout, a missing `PROBE: done` or a missing
    PNG, prints `PROBE CLEAN`, and writes no stamp.
- `tools/probe/probe_runner.tscn` + `.gd` (164 lines): the entry scene spawns a worker under root,
  which parses the `--probe-*` user args.
  - With a scene argument it loads that scene. Without one it runs `SceneRouter.go_to_van()` and
    waits for the `van_run`, `gun_stats` and `player` groups.
  - Output: each command prints `PROBE CMD <line>` followed by its result. The eval runs
    `Expression` against the target root and prints `PROBE EVAL: <value>`. Each shot prints
    `PROBE SHOT: <path>`.

## Completed phase
- 6 · tools/probe.py · 3cb6c9b. Verified:
  - `py -3 tools/probe.py res://scenes/van/van.tscn --eval "get_child_count()"` printed
    `PROBE EVAL: 7` and `PROBE CLEAN`.
  - `--cmd floodlight --shot <scratch>/p.png --every 0.5 --max 3` wrote p-01..03; I read p-01
    and it shows the van at IDLE.
  - `py -3 tools/check.py` and `py -3 tools/smoke.py` were clean, and gd-lint found 0 issues.
  - The reviewer found no gaps.
  - D29 (auto).

## Next phase: 7 · tools/shots.py
- Deliverable (plan "### 7"): `py -3 tools/shots.py capture <name>` runs `tools/smoke.py --shots`
  into `.godot/shots/<name>/`, and `py -3 tools/shots.py compare <a> <b>` prints `same`/`changed`
  per view.
  - Noise is measured from two captures of one tree, and the tolerance of 2× the noise per view is
    written into the tool (D5, D11).
  - Remove the "Coming in workflow-port phase 7" bullet from `.claude/playbook.md`, and add a real
    `**Shots:**` Commands bullet.
- Verification: capture twice on this tree; `compare` must print all `same`. Record the measured
  noise in the plan's Carry forward. Then run `py -3 -m py_compile tools/shots.py`.
- Rests on: D5, D11 (D13 stop line; D24 landing).
- First action: read `.claude/rules/tooling.md`, then have Explore map the output layout of
  `tools/smoke.py --shots` (PNG names, the `v01-` van views) and `tools/shot_stats.py` (PIL use,
  kinds) into `file:line` anchors. One spec (py).

## Requirements / gotchas
- `.py`/`.gd` are source: the implementer writes them. Keep implementer specs narrow (60k line).
- Never write in Portfolio. Never launch a windowed Godot: shots only via the hidden desktop.
- A shots capture is a full windowed smoke (about 1-2 minutes); two captures are needed.

## Blocker
- none
