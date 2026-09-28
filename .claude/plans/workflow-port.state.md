Status: phase-done

# Plan state: workflow-port

- **Plan:** `workflow-port`, `.claude/plans/workflow-port.md`. Phases 3-5 ran on branch
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
- `.claude/playbook.md`: Delegation, Spec format, Commands; Autoplan is now a real Commands bullet;
  "Coming in workflow-port phases 6-7" lists probe and shots.
- `tools/autoplan.py` (phase 5, 1050 lines): `resolve_plan` (arg → HERE → single ready/running),
  `read_plan`, `read_state(name)` (`.claude/plans/<name>.state.md`), `ensure_plan_worktree` (writes
  HERE), `acquire_lock` (`.claude/autoplan/`), `phase_brief`, `session_prompt`, `build_cmd`,
  `child_env` (strips billing vars), `run_session` (stream-json, kill line, usage-limit detection),
  `safety_commit` (by path), `main` (exit 3 on usage limit; `--dry-run` creates nothing).
- `tools/try.py`: unchanged; already lists `claude/*` branches (D26).

## Completed phase
- 5 · tools/autoplan.py · 2bc2d36 + 8dc395d. Verified: `py -3 -m py_compile tools/autoplan.py`;
  `py -3 tools/autoplan.py --dry-run workflow-port` printed the claude.exe path, the command
  (`--model --effort --permission-mode --disallowedTools --allowedTools --settings`, no billing
  flag), `phase: 5 · ...`, `state: phase-done`, the worktree line, and created nothing; reviewer
  found no gaps. D26, D27, D28 (auto). Not run live (a real headless session).

## Next phase: 6 · tools/probe.py
- Deliverable (plan "### 6"): `tools/probe.py` + `tools/probe/probe_runner.gd` (flags from D6, D7,
  D12: `res://path.tscn [--cmd "<console line>"]... [--eval "expr"] [--frames N] [--shot out.png
  [--every <s> --max <n>]]`), project lock, hidden desktop for shots, error-line failure like smoke;
  a probe needing the session boots main with the smoke sandbox. Drop probe's "coming" entry in
  `.claude/playbook.md`.
- Verification: `py -3 tools/probe.py res://scenes/van/van.tscn --eval "get_child_count()"` prints
  a number; `--cmd floodlight --shot <scratch>/p.png --every 0.5 --max 3` writes three PNGs (Read
  them); `py -3 tools/check.py`, `py -3 tools/smoke.py`.
- Rests on: D6, D7, D12 (D13 stop line; D24 landing).
- First action: read `.claude/rules/tooling.md`, then have Explore map `tools/smoke.py` and
  `tools/godot_env.py` (lock, Godot discovery, hidden desktop, error-line scan, sandbox flag) and
  `scripts/debug/` `DebugCommands.run` into `file:line` anchors. Two specs max (py, gd).

## Requirements / gotchas
- `.py`/`.gd` are source: the implementer writes them. Keep implementer specs narrow: the phase-5
  part-2 implementer went over its 60k line reading a 440-line source range.
- Never write in Portfolio. Never launch a windowed Godot: shots only via the hidden desktop.

## Blocker
- none
