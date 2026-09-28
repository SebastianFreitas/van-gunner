# Workflow port: Portfolio's planning and execution workflow, in Godot terms

Stage: running
Started: 2026-09-28
Procedure: `.claude/skills/plan/SKILL.md` today; this plan replaces it with
Portfolio's (the interview, then "go").
Interview: A, B, C done · 20 asked (focused, D1) · missed: does the first phase run in the planning turn or a fresh one? · missed: in an app-run phase, does a timed-out stop-line question block or wait? · missed: what happens to a migration target that finishes before its phase runs? · missed: does a worktree session run Commit itself? (D24) · missed: does autoplan land phases itself or do its sessions? (D27)

## Brief (owner's words, verbatim)

> Port the Claude workflow from C:\Users\Traff\Desktop\sebas\Portfolio into this repo.
> The planning and execution workflow should match (CLAUDE.md workflow sections, .claude/modes,
> .claude/skills/plan + handoff, plans/TEMPLATE.md, agents/implementer*, hooks, playbook.md,
> tools/autoplan.py, tools/try.py). Anything specific to the website (MAP.md content,
> rules/art-style, instruments, lore, snap.py, nav-flows, jscheck, gframes, toyshot, bump,
> merge-cachebust) should NOT be copied. Instead, propose Godot equivalents,
> especially for Verify (headless run, tests, screenshots).
> Also migrate this repo's existing plans to the new TEMPLATE format.
> Read the Portfolio files only; never write there.
> Run this as a plan: interview me first about what's Godot-specific, then execute phase by phase.

## Scope

- In: `CLAUDE.md` workflow sections, a new `.claude/playbook.md`, `.claude/modes/*`,
  `.claude/skills/plan/` (SKILL.md + a new unattended.md), `.claude/skills/handoff/`,
  `.claude/plans/TEMPLATE.md` and the existing plans, `.claude/agents/implementer*.md`,
  `.claude/hooks/*`, `.claude/settings.json`, a new `tools/autoplan.py`, `tools/try.py`
  / `try_commit.py`, new Godot verify tools (see Option map), `.gitignore`.
- Out (stays exactly as is): game code (`scripts/`, `scenes/`, `resources/`), the smoke
  fingerprint and scene-dump baselines, `.claude/rules/*` content, the invariants list,
  Portfolio (read only).

## Current state (explored 2026-09-28; anchors drift, grep the names)

- Portfolio source: `CLAUDE.md` 184 lines (Plans section 30-54 with autoplan), `.claude/playbook.md`
  (Delegation, Spec format, Commands moved out of CLAUDE.md), `skills/plan/SKILL.md` 366 lines
  (Part A ≥20 questions, Part B Initial idea walked piece by piece, Part C every phase reviewed
  with ≥2 questions, ready gate ≥40 questions and ≥2,500 words; `HERE` binds one plan per
  checkout, many plans active at once; PLAN_STATE.md starts with `Status:`; phase questions with
  `(auto)` after two timeouts; `.spec-<phase>-<k>.md` saved specs), `skills/plan/unattended.md`
  70 lines, `tools/autoplan.py` 937 lines (one headless `claude` session per phase in worktree
  `plan-<name>`, run lock, stream-json logs, safety commit, budget and session caps, reads
  PLAN_STATE `Status:`), `settings.json` compact window 200k at 65%.
- Here: planning is an iterative question loop (`skills/plan/SKILL.md` 222 lines), one plan bound by
  the committed `.claude/plans/ACTIVE`, `PLAN_STATE.md` at the root (van-exterior-2, running,
  phase 2 next). Here already has more than Portfolio in: `file-guard.py`, `gd-lint.py`,
  `stop-guard.py` verify stamps, `git-guard.py` quote masking / foreign paths / checkout guard,
  `context-watch.py` compact boundary + reviewer line, `reviewer` and `explore` agents,
  `docs/tasks/`, `try_commit.py` (verifies on the combined tree).
- Godot verify today: `tools/check.py` (import, load all, warnings), `tools/smoke.py [--bless |
  --shots DIR | --van-seeds N]` (headless run + fingerprint; shots on a hidden desktop),
  `tools/scene_dump.py [--bless]`, `tools/shot_stats.py <dir>` (brightness stats).
- Existing plans: `van-exterior.md` (done), `van-exterior-2.md` (running, phase 2 next).

## Option map (planning only; struck lines are settled by a D)

### Planning procedure
- Portfolio's long interview verbatim (A/B/C, ≥40 questions, ≥2,500 words) → D?
- Portfolio's, with a smaller minimum for tooling plans → D?

### Several plans at once
- Portfolio `HERE` (gitignored, per checkout) replaces the committed `ACTIVE` → D?
- PLAN_STATE.md per plan (`.claude/plans/<name>.state.md`) so two plan branches never
  conflict at Commit → D?

### Unattended runs
- Port `autoplan.py` for Godot (worktree `plan-<name>`, Godot verify stamps, hidden desktop) → D?
- Skip autoplan; phases stay owner-prompted → D?

### Verify equivalents (website tool → Godot)
- snap.py capture/compare → named shot sets from `smoke.py --shots` + a pixel diff tool → D?
- jscheck.py / toyshot.py → one-scene headless probe with `--eval` and `--shot` → D?
- gframes.py → a frame sequence over time from one shot view → D?
- nav-flows.test.py → named smoke flows so a phase runs only the part it touched → D?
- bump.py, merge-cachebust.py, serve.py, MAP.md → nothing (PROJECT_MAP.md already covers MAP) → D?

### Plan migration
- van-exterior (done): format only.
- van-exterior-2 (running): new headers, Interview marked migrated, Initial idea written from D1-D9 → D?

## Open items

- none

## Decisions (owner answers; `(auto)` = taken while running, review at the end)

- **D1 · This plan's interview.** Focused: the Godot-specific questions, then each phase
  reviewed with 1-2 questions. Settles: interview length.
- **D2 · Planning procedure for future plans.** Portfolio's parts (A brief interview, B initial
  idea walked piece by piece, C phases reviewed), **without numeric minimums**. Owner: "the goal
  here is not a specific number ... we cant just force quesiton when they arent needed, the
  concept for the plan, is that durign execution the LLm should never make decisions on its own.
  So the planning phase is there to ask all the specifics, if theres 100 quyestions so be it, if
  theres 5 then so be it. but the goal is to specify everything". So the ready gate measures
  completeness (every choice execution will face is settled by a D), not question or word counts.
  Settles: Option map "Planning procedure".
- **D3 · Several plans at once.** Full concurrency. Owner: "it shoiuld work with full
  concurrency, once we finish this plan execution the goal is to update the main with it as
  well, and the current van exterior should be executed with the new workflow we are creating
  right now". So: gitignored `HERE` per checkout, per-plan state file (no shared root file), and
  van-exterior-2 continues under the new skill after its migration. Settles: "Several plans at
  once", van-exterior-2 migration direction.
- **D4 · Autoplan.** Port `tools/autoplan.py` with the same flags; Godot runs use the existing
  project lock and hidden desktop. Settles: "Unattended runs".
- **D5 · Shots.** New `tools/shots.py`: `capture <name>` runs `smoke.py --shots` into a named
  set, `compare <a> <b>` prints same/changed per view with a pixel tolerance. Phase
  Verification lines name the views that must change and say the rest stay `same`.
- **D6 · Probe.** New `tools/probe.py res://path.tscn [--eval "expr"] [--frames N] [--shot out.png]`:
  one scene headless (hidden desktop for `--shot`), evaluates a GDScript expression against it,
  prints the result, fails on any error line.
- **D7 · Frames.** Folded into probe: `--shot out --every <s> --max <n>` writes a numbered
  sequence.
- **D8 · Flows.** None: one smoke run, one fingerprint, as today.
- **D9 · Questions while running.** Owner: "when the plan execution is running, its on the
  console it wont be able to ask ui questions, it should oinly stop if a big problem happens or
  an important question, in that case it stops, leaves something written about it. and i can run
  an instance on claude code app to get the question ui, and then go back to run it on the
  console". So unattended phases never ask; they stop on a blocker or an important question,
  write it into the plan state, and the owner answers it in an app session, then restarts
  autoplan. Settles: phase questions.
- **D10 · van-exterior-2 migration.** Rewrite into the new TEMPLATE (Initial idea from D1-D9, `[?]`
  where it guesses) and set it back to `Stage: planning` at Part B, so its next session asks the
  walk-through and phase reviews before phase 2 runs.
- **D11 · Shot store.** `.godot/shots/<name>/` (per checkout, gitignored, survives autoplan
  sessions). The phase that builds `shots.py` captures the same tree twice and sets `same` to
  twice the measured noise per view, written into the tool.
- **D12 · Probe commands.** `--cmd "<console line>"`, repeatable, run through
  `DebugCommands.run` in order before `--eval` / `--shot`; a probe that needs the session boots
  main with the smoke sandbox.
- **D13 · Stop line.** An unattended phase stops on: anything seen, heard or felt in the game; a
  gameplay or balance number; a change outside the phase's Scope; deleting files; code that
  contradicts the plan; a failing check it can't fix. It decides alone (recorded `D<n> (auto)`,
  listed at Stage done): internal names, file splits, helper structure, test tooling.
- **D14 · Unblock round-trip.** A bare `go` in an app session on the plan's checkout sees
  `Status: blocked`, asks the written questions with the UI, records them as D's, sets the status
  back so the phase can run, commits, and prints the exact autoplan command. It never runs the
  phase itself.
- **D15 · Context numbers.** Portfolio's: main line 120k, compaction at 65% of a 200k window;
  autoplan `--line 120000 --kill 140000`.
- **D16 · Playbook.** `.claude/playbook.md` gets Delegation, Spec format and Commands (Godot tools,
  probe, shots, autoplan); CLAUDE.md keeps a pointer. Invariants, Where things are, Code rules and
  Verify stay in CLAUDE.md.
- **D17 · Autoplan defaults and money.** Model claude-opus-5-5, **effort medium**, permission mode
  auto, max 30 sessions. Owner: "if it used all the he usage of my max plan on claude, it should
  stop NEVER spend my money". So autoplan runs on the Max subscription only: it removes
  `ANTHROPIC_API_KEY` (and any other API-billing variable) from the child environment, never
  enables extra usage, and when a session ends on a usage or rate limit it stops the chain with a
  clear message (the phase stays resumable) instead of retrying. `--budget` stays as an optional
  extra cap.
- **D18 · Bootstrap.** This plan follows the new procedure from phase 2 on (state in
  `.claude/plans/workflow-port.state.md`); phases 6-8 may run through autoplan once phase 5 lands.
- **D19 · Phase list.** The eight phases below, in order, one per session. Start after a `/clear`.
- **D20 (auto) · First phase after the ready gate.** Runs in the planning turn, as Portfolio's
  skill does (the old skill here started it in a fresh context). Reason: the Brief says the
  workflow should match Portfolio's.
- **D21 (auto) · Timed-out phase questions in the app.** A stop-line question that times out
  blocks (`Status: blocked`, written into the state file) instead of Portfolio's two-timeout
  `(auto)`; below-line choices are never asked. Reason: D13 forbids `(auto)` on the stop line.
- **D22 (auto) · askUserQuestionTimeout.** Not added to `settings.json`: Portfolio's settings.json
  does not set it (only its skill mentions it); it stays the app's own setting. Phase 2.
- **D23 · van-exterior-2 stays done.** Owner, phase 3 start: keep it as the finished record, only
  its header lines change. Overtakes D10: the owner closed it (all 7 phases) before phase 3 and
  vanfix picks up its leftovers; `van-exterior.md` and root `PLAN_STATE.md` were already gone.
- **D24 · Worktree sessions run Commit themselves.** Owner, phase 4 start: like Portfolio, a
  worktree session runs `try.py <branch> --commit` once the work is verified and committed (local
  `main` only, never pushes); the report names the commit on `main`. Try stays printed. Autoplan
  phases land each phase on `main` too. Phase 4 itself still printed Commit (the rule lands with it).
- **D25 (auto) · Tools not built yet are listed as coming.** The playbook names autoplan, probe and
  shots under "Coming in workflow-port phases 5-7 (not there yet)", so D16's list and phase 4's
  "every command named exists" both hold; phases 5-7 drop the marker when each lands.
- **D26 (auto) · try.py branch listing unchanged.** `list_branches` already lists every
  `refs/heads/claude/*` (so `claude/plan-*`) and `resolve` accepts `plan-<name>`. Phase 5.
- **D27 (auto) · Autoplan does not land phases itself.** Each headless session runs
  `try.py <branch> --commit` per the worktree mode file (D24); autoplan's end message names the
  command for anything left unlanded. Reason: Portfolio's runner never lands; one path, not two.
- **D28 (auto) · Headless compaction.** Autoplan keeps Portfolio's `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`
  in its `--settings`, and `--dry-run` skips the dirty-tree gate. Reason: port as is; test tooling.
- **D29 (auto) · Probe entry and defaults.** The probe runs a `.tscn` entry
  (`tools/probe/probe_runner.tscn`) that spawns a worker under root, because `go_to_van` frees the
  current scene. With no scene argument it boots the run to the van at IDLE. `--smoke-sandbox` is
  always passed. `--timeout` defaults to 180 s, and the game's watchdog fires 20 s before that.
  Shot sequences are named `<stem>-NN.png`. The probe writes no verify stamp. Reason: most console
  lines need the run, and a probe must never stand in for check or smoke.
- **D30 (auto) · Shots metric.** The diff is the mean absolute RGB difference on 0..255.
  `TOLERANCE_FLOOR` is 0.05, so views measured at 0 don't flag float jitter.
  `DEFAULT_TOLERANCE` is 1.0, for views missing from the table (new views and `--van-seeds`).
  `compare` exits 1 on any `changed`, `only-a` or `only-b`. Reason: this is test tooling, and a
  simple metric is enough for same/changed.

## Initial idea (Part B)

Skipped by D1 (tooling plan, focused interview): the phases below carry every piece.

## Walk-through

## Constraints (every phase)

- Portfolio is read-only. Nothing website-specific is copied.
- Here's extras (file-guard, gd-lint, verify stamps, reviewer, docs/tasks, try_commit) stay.
- Other plans (vanfix, ready) keep their plan files readable by whatever skill is current.

## Progress

| # | Phase | Kind | Rests on | Status |
|---|---|---|---|---|
| 1 | Plan skill, template, unattended.md | doc | D2 D3 D9 D13 D14 | done 3c7a388 |
| 2 | Plan hooks: HERE, per-plan state, context numbers | code (py) | D3 D15 | done 87e1138 |
| 3 | Migrate plans | doc | D3 D10 D23 | done fa81eda |
| 4 | CLAUDE.md, playbook, modes, handoff, implementer agents | doc | D15 D16 | done 857f7c9 |
| 5 | tools/autoplan.py (+ try branch listing) | code (py) | D4 D9 D13 D15 D17 | done 8dc395d |
| 6 | tools/probe.py | code (py + gd) | D6 D7 D12 | done 3cb6c9b |
| 7 | tools/shots.py capture/compare | code (py) | D5 D11 | done 599745c |
| 8 | Docs, tooling rules, PROJECT_MAP, Stage done | doc | all | todo |

## Phases

### 1 · Plan skill, template, unattended.md
Deliverable: `.claude/skills/plan/SKILL.md` rewritten from Portfolio's (parts A/B/C, walk-through,
phase reviews, saved specs `.spec-<phase>-<k>.md`, one phase per session, "Running unattended")
with no numeric minimums: the ready gate is "every choice execution will face is settled by a D
or a Brief line; no `[?]`, no `→ phase decides`" (D2). Phase questions follow D9/D13/D14 (no
(auto) for anything on the stop line; `Status: blocked` + questions; `go` in the app unblocks
and prints the autoplan command). Plan state lives in `.claude/plans/<name>.state.md` (D3),
first line `Status: phase-done|partial|blocked|plan-done`. New `.claude/skills/plan/unattended.md`
from Portfolio's, Godot verify commands. `.claude/plans/TEMPLATE.md` from Portfolio's, minus the
count in `Interview:`.
Verification: `git grep -n "PLAN_STATE.md\|plans/ACTIVE" .claude/skills .claude/plans/TEMPLATE.md`
is empty; no website tool names (`git grep -n "snap.py\|jscheck\|gframes\|toyshot\|bump.py\|nav-flows\|MAP.md" .claude/skills`, only `PROJECT_MAP.md` hits).
Notes: done 3c7a388. SKILL.md 435 lines (adds "Verify in a phase", "The stop line", "Unblock",
state file format with ready-to-ask Blocker questions); unattended.md 88 lines; TEMPLATE drops the
count from `Interview:`. D20, D21 (auto).

### 2 · Plan hooks
Deliverable: `session-start.py` reads gitignored `.claude/plans/HERE`, prints `PLAN: <name> · <stage>`
plus the other active plans (or `PLANS:` when unbound with several), reads the bound plan's
`.state.md` Status, keeps its existing extras (NO GODOT, foreign paths, tasks); `.gitignore` adds
`.claude/plans/HERE` and `.claude/autoplan/`; `context-watch.py` main line 120k and honours
`AUTOPLAN_LINE`; `settings.json` compact window 200000 + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` 65
and `askUserQuestionTimeout` as Portfolio. Git guard and file guard unchanged.
Verification: run each hook by hand on sample stdin in the scratchpad; `py -3 tools/check.py`
not needed (no Godot files).
Notes: done 87e1138. `plan_lines()` replaces `active_plan()`; running adds ` · <Status>` (or
` · no state file`), blocked adds the Unblock hint. `LIMIT` reads `AUTOPLAN_LINE`. tooling.md
Hooks updated. D22 (auto).

### 3 · Migrate plans
Deliverable: `van-exterior.md` into the new headers (Stage done, content kept);
`van-exterior-2.md` into the new TEMPLATE, Initial idea written from D1-D9 with `[?]` where it
guesses, `Stage: planning`, `Interview: B open` (D10); root `PLAN_STATE.md` content moved into
`.claude/plans/van-exterior-2.state.md` and the root file deleted; `.claude/plans/ACTIVE`
deleted; this plan's own state file written.
Verification: `git grep -n "PLAN_STATE" -- . ':!.claude/plans/research'` shows only history
mentions; session-start prints both plans correctly from this worktree with HERE set.
Notes: done fa81eda. D23: van-exterior-2 kept done (headers only); vanfix headers moved to the
new Procedure/Interview lines; `ACTIVE` deleted; nothing else to move (main had already dropped
`van-exterior.md` and root `PLAN_STATE.md`).

### 4 · CLAUDE.md, playbook, modes, handoff, implementer agents
Deliverable: CLAUDE.md "Active plan" rewritten (several plans, HERE, state files, autoplan,
unblock); Delegation, Spec format, Commands moved to `.claude/playbook.md` with the new tools
(D16); Context budget 120k (D15); modes/*.md and `skills/handoff/SKILL.md` matched to Portfolio's
workflow wording with Godot commands; implementer agents gain any Portfolio workflow rule they
lack. Verify, invariants, Where things are, Code rules unchanged except new tool rows.
Verification: no website tool names in `CLAUDE.md .claude/`; every command named exists.

### 5 · tools/autoplan.py
Deliverable: port of Portfolio's 937-line `autoplan.py` (skeleton first, function groups by Edit):
same flags with D17 defaults (effort medium, subscription only, stop on usage limit), worktree `.claude/worktrees/plan-<name>` on `claude/plan-<name>`, reads
`<name>.state.md`, stops on `blocked`/`plan-done`, logs under `.claude/autoplan/`, uses
`godot_env` for nothing but leaves Godot runs to the session's tools; `try.py` lists
`claude/plan-*` branches. Two implementer specs.
Verification: `py -3 tools/autoplan.py --dry-run workflow-port` prints the command and the phase
it would run; `py -3 -m py_compile tools/autoplan.py`.
Notes: done 2bc2d36 + 8dc395d. 1050 lines; per-plan `read_state(name)`, `child_env` strips billing
vars, usage limit → exit 3, dry-run creates nothing, worktree gets HERE; playbook lists it. D26,
D27, D28 (auto). Reviewer: no gaps.

### 6 · tools/probe.py
Deliverable: `tools/probe.py` + `tools/probe/probe_runner.gd` (flags from D6, D7, D12), project
lock, hidden desktop for shots, error-line failure like smoke.
Verification: `py -3 tools/probe.py res://scenes/van/van.tscn --eval "get_child_count()"` prints
a number; `--cmd floodlight --shot <scratch>/p.png --every 0.5 --max 3` writes three PNGs (Read
them); `py -3 tools/check.py`, `py -3 tools/smoke.py`.
Notes: done 3cb6c9b. The van.tscn eval printed `PROBE EVAL: 7`. Floodlight wrote p-01..03, and
p-01 shows the van at IDLE. Check and smoke clean, lint 0, reviewer found no gaps. D29 (auto).

### 7 · tools/shots.py
Deliverable: `capture <name>` (smoke `--shots` into `.godot/shots/<name>/`), `compare <a> <b>`
(same/changed per view); noise measured from two captures of one tree, tolerance = 2× noise per
view, written into the tool (D11).
Verification: capture twice on this tree, compare prints all `same`; the measured noise is
recorded in Carry forward.
Notes: done 599745c. The captures noise-a and noise-b compared `SHOTS SAME (28 views)`, and a third
capture, noise-c, also compared all same. The playbook has a Shots bullet, and SKILL.md's
"Coming in" wording is gone. D30 (auto).

### 8 · Docs and Stage done
Deliverable: `.claude/rules/tooling.md` (probe, shots, autoplan, HERE, state files),
`py -3 tools/gen_context.py`, `Stage: done`, this plan's state file deleted, HERE cleared.
Verification: `py -3 tools/check.py`; `py -3 tools/smoke.py`.

## Carry forward

- Phases 4-8: `ACTIVE` is deleted (phase 3); each checkout needs HERE when two plans are active
  (vanfix ready + workflow-port running). A new worktree has no HERE: `go workflow-port` or the
  state-file prompt binds it. The main checkout prints `PLANS:` until the owner writes its HERE.
- Phase 5: the skill's Unblock prints
  `py -3 C:/Users/Traff/Documents/van-gunner/tools/autoplan.py <name>`: phase 5 must accept that.
- Phases 5-7: each drops its "Coming ... (not there yet)" entry in `.claude/playbook.md` (D25).
  Only Shots is left; phase 7 removes the whole "Coming in workflow-port phase 7" bullet.
- Phase 7 can use `tools/probe.py --shot` for quick single views (D29).
- Phase 7 measured the noise on 2026-09-28 as the mean abs RGB diff between two captures.
  - `06-combat-outside` measured 9.73 because the raiders move, and `v16-idle-van-lit-roof`
    measured 2.74.
  - `04-combat-front` measured 0.32. Every other view measured 0.15 or less, and the
    exterior van views measured 0.
  - `TOLERANCE` in `tools/shots.py` is 2x these values. A change to combat-outside or the lit
    roof is only seen when it is large.
- Phase 8: `.claude/rules/tooling.md` should describe shots.py: the store, the metric and the
  per-view tolerance table, and how to re-measure (`compare --raw`, then double).
- Phase 5+: worktree sessions run `try.py --commit` themselves (D24); autoplan sessions do too
  (D27). Autoplan's real run (a live `claude -p` stream) is untested here: phase 6 or 7 may be the
  first run through it; watch `.claude/autoplan/` logs.
