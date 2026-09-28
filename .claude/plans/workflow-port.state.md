Status: phase-done

# Plan state: workflow-port

- **Plan:** `workflow-port`, `.claude/plans/workflow-port.md`; branch
  `claude/port-claude-workflow-godot-294f0c` (worktree `port-claude-workflow-godot-294f0c`).
- This worktree has the gitignored `.claude/plans/HERE` = `workflow-port`, so the hook prints
  `PLAN: workflow-port · running · <Status>` and lists van-exterior-2 as another active plan.
  Root `PLAN_STATE.md` is still van-exterior-2's until phase 3 moves it.

## Architecture now
- `.claude/skills/plan/SKILL.md` (435 lines), `.claude/skills/plan/unattended.md` (88 lines),
  `.claude/plans/TEMPLATE.md`: the new procedure (phase 1).
- `.claude/hooks/session-start.py`: `plan_lines(root)` scans `.claude/plans/*.md` (skips
  TEMPLATE and `*.state.md`) for `Stage: planning|ready|running`, binds by HERE or the only
  active plan, appends the state file's Status while running, lists others, else `PLANS:`.
  `ACTIVE` is ignored.
- `.claude/hooks/context-watch.py`: main line `int(AUTOPLAN_LINE or 120_000)`.
- `.claude/settings.json`: `CLAUDE_CODE_AUTO_COMPACT_WINDOW` 200000,
  `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` 65.
- `.gitignore`: `.claude/plans/HERE`, `.claude/autoplan/`.
- `.claude/rules/tooling.md` Hooks: describes HERE binding and the 120k / 65% numbers.
- Unchanged: git guard, file guard, CLAUDE.md (phase 4), root `PLAN_STATE.md` and `ACTIVE`
  (phase 3).

## Completed phase
- 2 · Plan hooks · 87e1138. Verified: `py -3 -m py_compile` on both hooks; session-start run on
  sample stdin: no HERE → `PLANS: van-exterior-2 · running, workflow-port · running`; HERE set →
  `PLAN: workflow-port · running · phase-done` + Other line; temp plan folders covered HERE
  naming an unknown plan, a blocked state file, no state file, no active plans with HERE set;
  `git grep "plans/ACTIVE\|active_plan" .claude/hooks` empty; settings.json parses;
  context-watch honours `AUTOPLAN_LINE`. D22 (auto): no `askUserQuestionTimeout` key.

## Next phase: 3 · Migrate plans
- Deliverable (plan "### 3"): `van-exterior.md` into the new headers (Stage done, content
  kept); `van-exterior-2.md` into the new TEMPLATE, Initial idea written from D1-D9 with `[?]`
  where it guesses, `Stage: planning`, `Interview: B open` (D10); root `PLAN_STATE.md` content
  moved into `.claude/plans/van-exterior-2.state.md` and the root file deleted;
  `.claude/plans/ACTIVE` deleted; this plan's own state file kept current.
- Verification: `git grep -n "PLAN_STATE" -- . ':!.claude/plans/research'` shows only history
  mentions; session-start prints both plans correctly from this worktree with HERE set.
- Rests on: D3, D10.
- First action: read `.claude/plans/TEMPLATE.md` (headers), then `grep -n "^#"` on
  `van-exterior.md` and `van-exterior-2.md` and read root `PLAN_STATE.md`.

## Requirements / gotchas
- All phase-3 files are Markdown: the main session may edit them directly.
- van-exterior-2 at `Stage: planning` stops being "running": its state file then only matters
  once it is running again; say so in its state file.
- Deleting `ACTIVE` changes nothing for the hooks (already ignored). The main checkout prints
  `PLANS:` until its HERE names a plan: mention it in the report's Look at.
- Never write in Portfolio.

## Blocker
- none
