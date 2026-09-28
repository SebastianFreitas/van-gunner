Status: phase-done

# Plan state: workflow-port

- **Plan:** `workflow-port`, `.claude/plans/workflow-port.md`. Phases 3-7 ran on branch
  `claude/workflow-port-state-next-890c49` (worktree `workflow-port-state-next-890c49`); phases 1-2
  on `claude/port-claude-workflow-godot-294f0c`. Worktree sessions land their own work with
  `try.py <branch> --commit` (D24).
- A fresh worktree has no HERE. With vanfix (ready) and workflow-port (running) both active, the
  hook prints `PLANS:`, so write `workflow-port` to the gitignored `.claude/plans/HERE` first.

## Architecture now
- `.claude/skills/plan/SKILL.md`, `.claude/skills/plan/unattended.md` and
  `.claude/plans/TEMPLATE.md` hold the procedure (phase 1). SKILL.md's "Verify in a phase" now
  names probe and shots as present, not coming.
- `.claude/hooks/session-start.py` binds HERE and prints the `PLAN:`/`PLANS:` lines (phase 2).
- `.claude/hooks/context-watch.py`: main line `int(AUTOPLAN_LINE or 120_000)`.
- `.claude/settings.json` sets `CLAUDE_CODE_AUTO_COMPACT_WINDOW` to 200000 and
  `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` to 65.
- `CLAUDE.md` (phase 4) covers Active plan, the playbook pointer, the 120k line, and worktree
  sessions running Commit themselves.
- `.claude/playbook.md` has real Commands bullets for Autoplan, Probe and Shots, and nothing is
  left under "Coming". Its last bullet names three hidden-desktop exceptions: `smoke.py --shots`,
  `shots.py capture` and `probe.py --shot`.
- `tools/autoplan.py` (phase 5): runs plans unattended.
- `tools/probe.py` + `tools/probe/probe_runner.tscn/.gd` (phase 6): see the playbook's Probe bullet.
- `tools/shots.py` (phase 7, about 190 lines, pure Python with PIL):
  - `capture <name> [--van-seeds N]` runs `smoke.py --shots` into `.godot/shots/<name>/`.
  - `compare <a> <b> [--raw]` prints `same`, `changed`, `only-a` or `only-b` per PNG stem, then
    `SHOTS SAME` (exit 0) or `SHOTS CHANGED: k of n` (exit 1).
  - Metric: `view_diff`, the mean absolute RGB diff on 0..255.
  - Tolerance: `TOLERANCE` per stem (2x the measured noise), with `TOLERANCE_FLOOR` 0.05 and
    `DEFAULT_TOLERANCE` 1.0.

## Completed phase
- 7 · tools/shots.py · 599745c. Verified:
  - `capture noise-a`, `capture noise-b` and `capture noise-c` each wrote 28 views, with the smoke
    clean every time.
  - `compare noise-a noise-b --raw` gave the noise.
  - After the table was filled, `compare noise-a noise-b` and `compare noise-a noise-c` both
    printed `SHOTS SAME (28 views)`.
  - `py -3 -m py_compile tools/shots.py` passed. The implementer tested `compare` on synthetic
    PNGs: changed, only-a and same all came out right.
  - No Godot files changed, so check and smoke were not needed.
  - D30 (auto).

## Next phase: 8 · Docs and Stage done
- Deliverable (plan "### 8"):
  - `.claude/rules/tooling.md` covers probe, shots, autoplan, HERE and state files.
  - `py -3 tools/gen_context.py` is run.
  - `Stage: done`, this state file deleted, HERE cleared.
- Verification: `py -3 tools/check.py`; `py -3 tools/smoke.py`.
- Rests on: the plan's D list (D30 for shots). At Stage done, the report lists every `(auto)` D
  and every `missed:` line under Look at.
- First action: read `.claude/rules/tooling.md` (51 lines). Then read the Carry forward lines on
  phases 7 and 8 in the plan, and the playbook's Autoplan, Probe and Shots bullets. Write the
  tooling.md additions yourself (Markdown).

## Requirements / gotchas
- `.py` and `.gd` files are source, so only the implementer writes them. Phase 8 should need
  neither.
- Never launch a windowed Godot. Shots run only through the hidden desktop.
- `.godot/shots/noise-{a,b,c}` exist in this worktree (gitignored) and can be reused as the
  baseline.

## Blocker
- none
