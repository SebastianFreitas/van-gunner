---
name: plan
description: Start, continue or run a many-phase plan in .claude/plans/. Planning is an interview the app session manages: plan-writer subagents explore, research, work out the math and write the plan; the app session asks the owner their questions through AskUserQuestion; one fresh-eyes review round (a second only for build-breaking findings). The ready gate ends with /clear then go; that fresh session runs tools/autoplan.py one phase at a time, reports each, and stops everything on a problem. Owner-invoked only.
disable-model-invocation: true
argument-hint: "new <name>: <brief>  |  (nothing: continue the plan bound here)"
---

# Plan: one procedure, two states

A plan is a file `.claude/plans/<name>.md` built from
`.claude/plans/TEMPLATE.md`. The plan's `Stage:` line is the state:
`planning` → `ready` → `running` → `done`. Every plan whose Stage is
planning, ready or running is active; any number can be active at once.
While a plan runs, its state file `.claude/plans/<name>.state.md`
(committed, format below) says where it stands.

## Several plans at once

One plan per checkout. Concurrent plans run in separate checkouts: the
main checkout and worktrees (or cloud clones). `.claude/plans/HERE`
(one line, gitignored, so each checkout has its own) binds this
checkout's plan. A checkout with no HERE and exactly one active plan
runs that one.

The SessionStart hook prints `PLAN: <name> · <stage>` for the bound
plan (plus its state file's `Status:` while running) and lists the other
active plans; those belong to other checkouts: never edit their plan
files, state files, research or code areas. With several active plans
and none bound it prints `PLANS: ...`: `go <name>` writes `<name>` to
HERE and continues it, a bare `go` asks which. No `PLAN:`/`PLANS:` line
means no plan is active: a bare "go" is then an ordinary prompt.

Each plan has its own state file, and each checkout keeps its own
`.claude/handoff.md` (gitignored), so neither ever crosses plans or
conflicts at Commit. Plan files and state files only ever change on the
branch that runs them; they reach `main` with that branch's
`try.py --commit`. Two plans that would edit the same source files: say
so at planning and record which runs first as a D.

Do **not** use Claude Code's built-in plan mode (Shift+Tab) for this: it
blocks every file write, and planning here writes research digests and
the plan itself into the repo. `/plan` is the plan mode.

## `/plan new <name>: <brief>` → Stage planning

1. Create `.claude/plans/<name>.md` from TEMPLATE, write `<name>` to
   this checkout's HERE (another active plan is bound here already: stop
   and say the new plan needs its own worktree), paste the owner's brief
   **verbatim** under Brief (condense later, never now: their words are
   the source every question quotes).
2. Run the interview in `.claude/skills/plan/interview.md` until its
   ready gate passes.

## Which file to read

This file is the index. The procedure is in two stage files; read only
the one for the plan's `Stage:` line, never both:

- `planning` or `ready` (and right after `/plan new`):
  `.claude/skills/plan/interview.md`.
- `running`: `.claude/skills/plan/run.md` (phases, the state file, phase
  questions, Answer, Stage done). A session started by
  `tools/autoplan.py` reads `.claude/skills/plan/unattended.md` instead.

The planning session is a manager: `plan-writer` subagents do the
exploring, research, math and writing, and it asks the owner what they
return (`interview.md`, "Who does what"). No phase runs in the app
session: after the ready gate the owner clears, says `go`, and that
fresh session runs `tools/autoplan.py` one phase at a time in the
background, reporting each (the first section of `run.md`); the owner
never opens a terminal or says `go` between phases. A run that stops
`blocked` or with `questions` is answered in the app, and the run
restarts; any other problem stops it and goes to the owner.

## `/plan` with no plan bound here

List `.claude/plans/*.md` with their Stage lines and stop.
