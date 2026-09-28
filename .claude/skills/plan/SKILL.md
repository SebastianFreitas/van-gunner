---
name: plan
description: Start, continue or run a many-phase plan in .claude/plans/. Planning is an interview through AskUserQuestion that loops ask → write → review until the plan leaves zero choices to the LLM (no question quota); running does one phase per session, writes the plan's state file, then hard-stops for `/clear`. Owner-invoked only.
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

A plan is not a `docs/tasks/` file. A task is a short list of steps the
owner points a session at; a plan is phases with an interview behind
them. They never share a context: a session runs one plan phase or one
task step, never both.

Do **not** use Claude Code's built-in plan mode (Shift+Tab) for this: it
blocks every file write, and planning here writes research digests and
the plan itself into the repo. `/plan` is the plan mode.

## `/plan new <name>: <brief>` → Stage planning

1. Create `.claude/plans/<name>.md` from TEMPLATE, write `<name>` to
   this checkout's HERE (another active plan is bound here already: stop
   and say the new plan needs its own worktree), paste the owner's brief
   **verbatim** under Brief (condense later, never now: their words are
   the source every question quotes).
2. Run the interview below until the ready gate passes.

## `/plan` or `go` while Stage is `planning`

Read `Interview` (which part is open) and `Open items`, and continue the
interview from exactly there.

## The interview: how planning feels

The goal, in the owner's words (D2 of workflow-port, 2026-09-28): *"the
concept for the plan, is that during execution the LLM should never make
decisions on its own. So the planning phase is there to ask all the
specifics, if there's 100 questions so be it, if there's 5 then so be
it. But the goal is to specify everything."* **The finished plan leaves
zero choices to the LLM.** Questions are the tool, not the target: there
is no minimum count, no word count. A plan is done when a review finds
nothing left to choose. So planning is a loop:

> ask what is open → write it into the plan → review the plan → every
> uncertainty the review finds becomes a new question → repeat until a
> review finds none.

- **Every question goes through `AskUserQuestion`** (the UI), never as
  prose that ends the turn. Calls are consecutive in the **same turn**:
  ask, record, ask again. The turn ends only when the owner does not
  answer (the question stands, the handoff names it, the next "go" asks
  it again) or when the ready gate passes. A "you decide" answer is
  recorded as a D in Claude's words, marked `(owner: you decide)`.
- **What counts as an open choice.** Any spot where the implementer
  would have to pick: a name, number, colour, count, order, timing,
  caption or HUD text, a balance value, what the player sees, hears or
  feels in the first and last second, what happens when it fails, what
  stays exactly as is next to it. If two reasonable implementers could
  build it two different ways, it is open.
- **What is not asked.** A choice already fixed by the Brief, a D, the
  existing code, an invariant in `CLAUDE.md`, a domain rule
  (`.claude/rules/*.md`) or a memory is written into the plan as a D
  marked `(from <source>)`, not asked. Never ask to fill a count, never
  ask twice what a D settles, never ask a question whose every answer
  builds the same thing.
- **Detail by detail.** Planning decides specifics now. Nothing is left
  as `→ phase decides`: a phase's research while running only finds
  where things are, never what they should be.
- **Never stop early.** Never end a planning turn to "let the owner
  think"; never write "ready when you are"; never skip an open choice
  because the answer seems obvious or the owner seems tired of questions.
  If the owner types "just build it" or "stop asking", record that
  verbatim as a D, ask one question ("Take Recommended for every open
  choice left?" with "No, keep going (Recommended)" first) and follow the
  answer.

### Question rules (every call)

- Up to 4 questions per call; consecutive calls until the open list is
  empty. Never carry a known open choice into a later turn or a later
  phase.
- 2 to 4 options each, the recommended one first with "(Recommended)".
  Options are concrete and different from each other, written as what
  the owner will see or get, never "Yes / No" unless the choice is truly
  binary. `multiSelect: true` when several can be true; `preview` when a
  caption, palette, layout or table decides it.
- The owner always has "Other" for free text. A free-text answer is
  recorded verbatim; if it opens new choices, they join the open list.
- One question per decision. A question that needs research explained
  first puts the explanation in its own text: the owner has not read the
  research digest.
- Every question quotes or points at the Brief line, the D, or the piece
  of the Initial idea it is about, so the owner knows where they are.
- After each call: write every answer into the plan as `D<n>`, bump the
  count under `Interview`, commit the plan by path. Then the next call.

### The review pass (used after every part)

Read the plan section (or the whole plan) **as the implementer who must
build it from that text alone**, and list every open choice (above) you
would have to make, plus every place two lines could be read two ways or
contradict a D. Each item is either fixed from a source (write the D,
`(from <source>)`) or becomes a question. Ask them all, apply the
answers, then review again. The part is done when a review returns an
empty list.

### Part A · Brief and direction

1. **Intake.** Explore the current state through `Explore` (grep
   `docs/PROJECT_MAP.md` first; `file:line` anchors, no code bodies).
   Write it under Current state.
2. **Research** the areas the brief touches, as wide as the choices
   need (other games, films, painters, techniques, Godot docs). Load
   `WebSearch`/`WebFetch`. Digest into
   `.claude/plans/research/<name>-00-intake.md`: sources, what we take
   from each, in our own words. Never copy art or long text.
3. **Option map.** For each area where the research found real
   alternatives, list them: one line each, with one precedent and what
   it would look like in *our* result. Include areas the brief did not
   mention but the work forces (HUD text, performance, the smoke
   fingerprint, the art rules, what stays as is) only where they are
   actually open.
4. **Open list.** Read the Brief clause by clause and list the choices it
   leaves open that shape the whole result (direction, scope, what it
   is), plus the option-map areas. Details that only matter inside one
   piece wait for Part B, where they have context.
5. **Ask the list** by the question rules. Contradictions with an earlier
   D are asked as their own question, never resolved silently. Write
   `Interview: A done · <count> asked` and go to Part B in the same turn.

### Part B · Initial idea, reviewed piece by piece

1. **Write the Initial idea** under its section: the whole result in
   prose, beginning to end, as the owner will experience it (what is on
   screen, what moves, what is heard, what the player does, in order).
   Every sentence rests on a D, the Brief or a `(from <source>)` fact;
   anything else is a guess and is marked `[?]`. Split it into numbered
   **pieces** (a beat, a screen, a system, a rule), as many as the work
   has, each a heading with its lines under it. Commit.
2. **Show every piece to the owner.** One question per piece, up to 4
   pieces per call: *"Piece <n>, <name>: <the piece's lines, in full>.
   Right?"* with "That is it (Recommended) / Close, but change something
   (say what in Other) / Different direction / Explain the choices
   first". A change or new direction rewrites the piece and it is shown
   again; "Explain" is answered in the next call's question text, then
   the piece is shown again. Record each under `Walk-through` (piece,
   answer, D numbers).
3. **Review pass** over the pieces: every `[?]` and every open choice the
   review finds becomes a question. Rewrite the prose with the answers
   and review again until the list is empty and no `[?]` remains. Write
   `Interview: B done · <count> asked`.

A plan with no player-facing result (tooling, workflow) may record
"Initial idea skipped" as a D the owner chose; its phases then carry
every piece.

### Part C · Phases and their review

1. **Write the phases** from the Initial idea. Each phase: kind
   (research/doc/code/review), the pieces it implements, research
   topics, deliverables, verification, the D numbers it rests on. **No
   phase may be of kind "owner talk"**: every question is asked here,
   now. **Size:** a code phase is at most two implementer specs and at
   most two files it reads to design (name them); more than that is two
   phases. A phase's section is self-contained (it names its D numbers
   and pieces), because an unattended session sees only that section.
   Verification names the check that actually sees the change (see
   "Verify in a phase"). Fill Scope, Constraints, the Progress table.
   Commit.
2. **Show every phase to the owner.** One question per phase, up to 4
   per call: *"Phase <n>, <name>, delivers <deliverables>, must not touch
   <Out list>, verified by <commands / views>. Right?"* with "Right
   (Recommended) / Missing something (say what in Other) / Too big,
   split it / Merge with the previous phase". Splits and merges rewrite
   the Progress table and the changed phases are shown again. Record
   under each phase: `Reviewed: <answer, D numbers>`.
3. **Review pass** over each phase as the session that will run it,
   seeing only that section: every choice it would still have to make
   becomes a question. Repeat until empty. Write
   `Interview: C done · <count> asked`.

### Ready gate (all true, or keep going)

- **Everything specified.** Every choice execution will face is settled
  by a D or a Brief line. No `[?]` anywhere, no `→ phase decides`, Open
  items: none.
- **Fresh-eyes review.** A `Plan` subagent that has not seen the
  interview reads the plan file (give it the path; it does not load
  CLAUDE.md) and lists, per phase, every choice it would have to make
  to build it and every line it could read two ways, with the line
  quoted. Each item is fixed from a source or asked; then a new fresh
  review runs. The gate needs one review that returns nothing.
- `Interview` shows A, B and C done.
- Every piece has a Walk-through line; every phase has a `Reviewed:`
  line, cites at least one D or Brief line, and is `todo` in the
  Progress table. Constraints and Scope are filled.

Then set `Stage: ready`, commit the plan and research by path, and ask
one last `AskUserQuestion`: "Start running the plan? (Recommended) /
Change something first / Hold". Start → `Stage: running` and run the
first phase in the same turn, ending with the Handoff protocol and the
hard stop below (one phase, never two). Change → record the change as a
D, show the pieces and phases it touches again, and run the gate again.

Context: at `CONTEXT WATCH` commit the plan file as it stands, write
`.claude/handoff.md` with the part and the open list still to ask, and
keep going. The plan file *is* the handoff for everything settled; the
interview continues after compaction from the same part.

## `go` while Stage is `running`: one phase per session

Two ways to run it: the owner prompts each phase in the app (below), or
`py -3 tools/autoplan.py <name>` runs every phase in a terminal, one
fresh session each (see "Running unattended"). Planning, and answering
a blocked phase's questions, always happen in the app.

The owner's rule (2026-09-26): *"we never do 2 continues work, we must
always separate stuff."* A running plan is a chain of short, isolated
sessions. Each prompt executes **exactly one phase**, then the session
halts and the owner clears the context. Never run two phases in one
turn, never "keep going with Next", never let auto-compaction carry a
plan across phases.

1. **Enter.** Read `.claude/plans/<name>.state.md` first. `Status:
   blocked` → do "Unblock" below instead, never the phase. Otherwise its
   "Next phase" section is the starting point and overrides guessing
   from the Progress table; with no state file, read Progress and take
   the first `todo` row. Read only that phase, its pieces of the Initial
   idea, Brief, Decisions, Constraints, Carry forward, and any saved
   spec files it names. Nothing from any other phase.
2. **Phase questions** come before the first spec (rules below).
3. **Execute that phase only:** research where things are (digest to
   `research/<name>-<NN>.md` when it is more than a few anchors), read
   the `.claude/rules/` files for every area it touches, design, specs,
   implementer, verify, and the `reviewer` over about 150 lines or more
   than three files, as `CLAUDE.md` says. Anything the phase reveals
   about a later phase goes into Carry forward or the state file, never
   into this session's work.
4. **Handoff protocol** (every step, in this order, before anything
   else):
   1. **Verify:** the phase's Verification line and every command
      "Verify in a phase" requires pass. A phase that does not verify
      is not complete: fix it, or stop with the blocker named in the
      state file (`Status: blocked`).
   2. **Commit** by path with a message that describes the phase, as the
      mode file says (cloud: also push and open or update the PR).
   3. **Write the state file** (format below), set the Progress row
      `done <sha>`, fill the phase's Notes line, add Carry forward, and
      commit those too (same path rules). The state file is committed: in
      cloud mode the next session is a fresh clone and reads it from the
      branch.
5. **Hard stop.** End the turn with the normal report, and its last
   line is this exact message (with the plan's name), nothing after it:

   > Phase complete. Please run `/clear` to flush the context window,
   > then prompt me with: 'Read .claude/plans/<name>.state.md and execute the next phase.'

   Do not start the next phase. Do not ask whether to continue. The
   mode files' "Context full" rule (auto-continue, never clear) does
   not apply at a phase boundary: the clear is the owner's, on purpose.
6. **The next prompt** ("Read .claude/plans/<name>.state.md and execute
   the next phase", or a bare "go") starts at step 1 in a fresh context.

### Verify in a phase

The Verify section of `CLAUDE.md` decides which commands a change needs;
a phase runs them all, once, on its finished change:

- Any `.gd`, `.tscn`, `.tres`, `.gdshader` or `project.godot` change:
  `py -3 tools/check.py`.
- Anything under `scripts/`, `scenes/`, `resources/`, `tools/smoke/` or
  `project.godot`: also `py -3 tools/smoke.py`.
- The van's scenes: also `py -3 tools/scene_dump.py`.
- Anything visible: `py -3 tools/smoke.py --shots <scratchpad>/shots`,
  then Read the PNGs. Also
  `tools/probe.py` (one scene headless, `--cmd`, `--eval`, `--shot`
  with a frame sequence) and `tools/shots.py` (`capture <name>`,
  `compare <a> <b>` printing `same`/`changed` per view). A visible phase's Verification names the views that must change and
  says the rest stay `same`.
- Panel UI the smoke's `speed` mode skips (act reveal, boon pick) is
  reviewed by reading, and the report's Try line says where to look.
- `--bless` only when the phase is meant to change the fingerprint or
  the van tree, and the phase's Deliverable says so.

A failure is any output line with `SCRIPT ERROR`, `Parse Error`,
`ERROR:` or a GDScript warning, whatever the exit code.

### The state file (`.claude/plans/<name>.state.md`; exists only while a plan is running)

Under 80 lines, no code. The first line is `Status: <s>`, where `<s>`
is `phase-done`, `partial`, `blocked` or `plan-done`
(`tools/autoplan.py` reads it to decide what happens next). Then
`# Plan state: <name>` and these headings in this order:

- **Plan:** `<name>` and the plan file path; branch and worktree
  (cloud: PR link).
- **Architecture now:** the files, autoloads, scenes and signals this
  plan has touched so far, one line each, as they are after this phase.
- **Completed phase:** number, name, commit hash, what was verified
  (exact commands, and the shot views read).
- **Next phase:** number, name, its deliverables and Verification line
  copied from the plan, the D numbers it rests on, and the exact first
  action (the file and function to open, the saved spec to send, or the
  rules file to read).
- **Requirements / gotchas:** anything the next phase needs that is
  not in the plan file or `docs/PROJECT_MAP.md`.
- **Blocker:** `none`, or the questions only the owner can answer, each
  written as a ready `AskUserQuestion`: the question, 2 to 4 options with
  the recommended one first, and the line of the plan it is about.

It replaces `.claude/handoff.md` for plans: never write both at a phase
boundary. The `handoff` skill still applies inside a phase that is run
in the app (an error you cannot get past mid-step): that is a mid-phase
continuation, not a phase boundary. When the last phase is done, delete
the state file in the Stage-done commit.

### Phase questions: the stop line

A phase's research or design will sometimes force a decision the plan
does not cover (something the interview missed). That is a phase
question. Look for them on purpose: before the first spec of a phase,
list every decision the phase forces that no `D`, piece or Brief line
settles. Sort each by the **stop line** (D13 of workflow-port):

- **On the stop line** (never decided alone): anything seen, heard or
  felt in the game; a gameplay or balance number; a change outside the
  phase's Scope; deleting files; code that contradicts the plan; two
  decisions that conflict; a failing check you can't fix.
- **Below it** (decided alone, recorded as `D<n> (auto)` with one line
  of reason, listed at Stage done): internal names, file splits, helper
  structure, test tooling.

In the app, ask every on-the-line question in one `AskUserQuestion`
round (same question rules as planning) at the **start** of the phase,
never after the implementer has run, and record the answers as D's.
Below-the-line choices are not asked: take the one you would have marked
"(Recommended)" and record it as `D<n> (auto)`. The tool's
`askUserQuestionTimeout` setting decides how long a question waits. A
question that times out is never taken as `(auto)`: finish what can be
finished without it, write the question into the state file's Blocker,
set `Status: blocked`, commit, and end the turn with the normal report.

Unattended (`AUTOPLAN=1`) nothing is asked: on-the-line questions block
the same way at once; see `unattended.md`.

Every `(auto)` and every blocker names a question the interview should
have asked: add it to the plan's `Interview` line as `missed:
<question>` so the next plan's Part A list grows.

Context inside one phase: a phase too big for one context was split
wrong. At `CONTEXT WATCH` finish the atomic step, commit, and write the
state file with `Status: partial`, "Completed phase" as `<n> (partial)`
and "Next phase" as the rest of it; then hard-stop. Next session, split
the phase in the Progress table before continuing. A session that stops
after designing saves each finished spec as
`.claude/plans/<name>.spec-<phase>-<k>.md` (the Spec format in
`.claude/playbook.md`, ready to send) and names them in Next phase; the next
session sends them to the implementer instead of exploring again, and
deletes each in the commit that lands its work.

### Unblock (`go` in the app while `Status: blocked`)

The owner reads a blocked run in the app, where the question UI works
(D14 of workflow-port). A bare `go` (or `/plan`) on the plan's checkout
that finds `Status: blocked`:

1. Asks every question under the state file's Blocker with
   `AskUserQuestion`, as written there, by the question rules.
2. Records each answer as a `D<n>` in the plan, adds the `missed:` line,
   clears Blocker to `none`, and sets `Status:` back to `partial` when
   "Completed phase" shows `(partial)` and `phase-done` otherwise.
3. Commits the plan and state file by path.
4. Ends with the normal report, whose last lines give the exact command
   to continue unattended, in a `bash` block:
   `py -3 C:/Users/Traff/Documents/van-gunner/tools/autoplan.py <name>`,
   or, to run it in the app instead, `/clear` and then 'Read
   .claude/plans/<name>.state.md and execute the next phase.'

It never runs the phase itself.

### Running unattended (`AUTOPLAN=1`)

`py -3 tools/autoplan.py <name>` runs the phases from a terminal, one
fresh headless session per phase, on the Max subscription only: it
never uses an API key and stops the chain when the usage limit is hit.
Started from the main checkout, it makes (or reuses) the worktree
`.claude/worktrees/plan-<name>` on branch `claude/plan-<name>` and runs
there; the owner lands it with
`py -3 tools/try.py claude/plan-<name> --commit`. A session it starts
has `AUTOPLAN=1` and a prompt that begins `[autoplan | ...]` and carries
the phase brief: read `.claude/skills/plan/unattended.md` (short) and
not the rest of this file.

## Last phase done → Stage done

Set `Stage: done`, delete this checkout's HERE and the plan's state
file, list every `D<n> (auto)` and every `missed:` line in the report
under **Look at**, commit. The plan file stays as the record. This last
phase ends with the hard-stop message too; the owner's next prompt is a
fresh task.

## `/plan` with no plan bound here

List `.claude/plans/*.md` with their Stage lines and stop.
