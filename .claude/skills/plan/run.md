# Running a plan (Stage `running`)

One of the plan skill's two stage files (`SKILL.md` is the index). A
session running a phase reads this file, not `interview.md`. One plan
per checkout; other active plans belong to other checkouts: never edit
their plan files, state files, research or code areas. Plan files and
state files only change on the branch that runs them.

## `go` while Stage is `running`: one phase per session

Execution is `tools/autoplan.py`: every phase in its own fresh headless
session. The run is supervised from a **fresh app session** (the ready
gate ends with `/clear`, then the go prompt) that stays small because it
never
does a phase's work (owner, 2026-10-01: *"I say go and you just
basically say go phase 1, go phase 2, go phase 3, until it's done; if
there's an error or problem stop it all and tell me what's up ... the
execution window will never go above its threshold"*). The owner never
opens a terminal and never says `go` between phases. A phase runs in the
app only when the owner's prompt says to run it there, or while
`tools/autoplan.py` does not exist yet; then the steps below end with
the `/clear` hard stop.

A bare `go` (or `/plan`) in the app while Stage is `ready`, or `running`
with `Status` neither `blocked` nor `questions`: when no run is live
(`.claude/autoplan/` lock, or no `py` running `autoplan.py <name>`),
start one; when one is live, report where it is (below) and stop.

### Supervising the run (the app session)

- **One phase per launch:** Bash with `run_in_background: true`:
  `py -3 <main checkout, absolute, forward slashes>/tools/autoplan.py <name> --max-sessions 1`
  (no `| tail`, no `--claude`: it finds the CLI itself). Say in one
  line which phase runs. Do not poll or sleep:
  the harness notifies when it exits.
- **When it exits:** read the run's last 12 lines of output (the
  session row and `stop reason:`), the state file (`Status`, Completed
  phase, Next phase) and `git log --oneline` of the new commits on
  `claude/plan-<name>`, nothing else. A normal phase end is exit 0 with
  `stop reason: max sessions reached · last session: phase-done` (or
  `partial`, or `plan-done` after the last phase); a usage limit is
  exit 3 with `stop reason: usage limit`. Report the phase in at most three
  lines: what it built in plain words, the pictures' paths, every
  `D<n> (auto)` as a Look at the owner can reverse. Then by `Status`:
  - `phase-done` or `partial` → launch the next one at once, same turn,
    no question to the owner. The same phase ending `partial` twice in a
    row (the state file's Completed phase says `<n> (partial)` for the
    same `<n>` as the last launch, or the Progress row has two partial
    notes) is a problem (below).
  - `plan-done` → "Last phase done → Stage done" below.
  - `questions` / `blocked` → "Answer" below, which restarts the run.
  - a usage-limit stop → say when it resets and that `go` restarts it.
  - **anything else stops everything:** any other `stop reason:` (a
    session killed at the kill line, errored twice, no progress, a
    failed safety commit, not logged in), a crash with no summary, the
    same phase `partial` twice. Launch nothing; tell the owner what happened
    in plain words (the phase, what landed, the log's last lines) and
    what you would do about it. The owner decides.
- **Never** read a log whole, a picture, a diff, the plan's phase
  sections or source; never run a phase or fix anything yourself.
  Each phase costs this session a few thousand tokens, so a whole plan
  fits under its line. Past the line anyway: finish the report and end
  with the go prompt (`workflow.md` "The go prompt"; what: "carry on
  running plan <name>"; file: the state file, which holds where the run
  is).
- **Asked "where is it?"** Read only the state file's `Status` and Next
  phase, `git log --oneline -5` on `claude/plan-<name>`, and the newest
  `.claude/autoplan/<name>/<run>/s<k>.jsonl`'s last few assistant texts
  and its context size (from `usage`).
- **Closed app:** the run dies with the session. The state file holds
  where it was: `go` in any new session starts it again (`--force` if a
  stale lock is reported). The terminal command stays a fallback the
  owner may use, never a step you hand them.

The owner's rule (2026-09-26): *"we never do 2 continues work, we must
always separate stuff."* A running plan is a chain of short, isolated
sessions, each executing **exactly one phase**. A headless `autoplan`
session then simply ends (step 5); the supervisor launches the next. The
owner clears the app window once, between the ready gate and the run,
never between phases. Never run two phases in one turn, never "keep
going with Next".

1. **Enter.** Read `.claude/plans/<name>.state.md` first. `Status:
   blocked` or `Status: questions` → do "Answer" below instead, never a
   phase. Otherwise its "Next phase" section is the starting point and
   overrides guessing from the Progress table; with no state file, take
   the first runnable row (see "Which phase runs next"). Read only that
   phase, its pieces of the Initial idea, Brief, Decisions, Constraints,
   Carry forward, and any saved spec files it names. Nothing from any
   other phase.
2. **Phase questions** come before the first spec (rules below).
3. **Execute that phase only:** research its topics (digest to
   `research/<name>-<NN>.md` when it is more than a few anchors), specs
   naming the `.claude/rules/` files for every area it touches,
   implementer (which verifies), and the `reviewer` over about 150 lines or more
   than three files, as `CLAUDE.md` says. Anything the phase reveals
   about a later phase goes into Carry forward or the state file, never
   into this session's work.
4. **Handoff protocol** (every step, in this order, before anything
   else):
   1. **Verify:** the phase's Verification line and what "Verify in a
      phase" requires pass. A phase that does not verify is not
      complete: fix it, or stop with the failure under Blocker
      (`Status: blocked`).
   2. **Commit** by path with a message that describes the phase, as the
      mode file says (cloud: also push and open or update the PR).
   3. **Write the state file** (format below), set the Progress row
      `done <sha>` (or `deferred Q<k>`), fill the phase's Notes line, add
      Carry forward, and commit those too (same path rules). The state
      file is committed: in cloud mode the next session is a fresh clone
      and reads it from the branch.
5. **Hard stop.** Headless (`AUTOPLAN=1`): end with a short phase
   report for the supervisor (what landed, `Status`, Next phase); no
   `/clear`, no go prompt. **In-app fallback only** (no
   `tools/autoplan.py`, or the owner said to run the phase in the app):
   end the turn with the normal report, then the go prompt (`workflow.md`
   "The go prompt"; checkout and branch from git, now) as the last
   thing, nothing after it:

       Phase complete. Please run `/clear`, then paste this:

       ```
       Read .claude/plans/<name>.state.md and execute the next phase. Checkout <path> on branch <branch>, <mode> mode.
       ```

   With `Status: questions` the block is instead `go: answer plan
   <name>'s questions. Checkout <path> on branch <branch>, <mode> mode.
   Read .claude/plans/<name>.state.md first.`, introduced with "No phase
   can run until the questions are answered." Do not start the next
   phase. Do not ask whether to continue.
6. **The next prompt** (fallback: "Read .claude/plans/<name>.state.md
   and execute the next phase") starts at step 1 in a fresh context. A
   bare "go" starts or reports the supervised run instead (above).

### Which phase runs next

The first Progress row that is `todo` and whose Needs names no
`deferred` row, directly or through another held row (its status stays
`todo`: it runs once the answers are in). A plan with no Needs column
treats every phase as needing all earlier ones. No runnable row left:
every row `done` → "Stage done" below; some `deferred` → `Status:
questions`.

### Verify in a phase

`CLAUDE.md` § Verify decides which commands a change needs; the phase's
implementer runs every one of them for the areas it touched, once, on
the finished change, and reports the numbers. **Pictures** (owner, 2026-10-01: "when we check images we
shouldn't repeat it if we get text from it"): a view a tool measures (a
pixel count, a compare against a baseline) is judged by its number, and
its picture is not read, including views measured clean. The
implementer or reviewer (never the phase session) reads a picture only
for a look no tool measures, or when a number says a view changed
and the question is how; read each one once, write one line on what it
shows, and never re-read a picture an earlier phase or session already
described. A visible phase's Verification names the screenshots or views
that must change and says the rest stay the same. A baseline is
re-recorded (bless, update snapshots) only when the phase's Deliverable
says so.

### The state file (`.claude/plans/<name>.state.md`; exists only while a plan is running)

Under 80 lines, no code. The first line is `Status: <s>`, where `<s>`
is `phase-done`, `partial`, `questions`, `blocked` or `plan-done`
(`tools/autoplan.py` reads it to decide what happens next). Then
`# Plan state: <name>` and these `## ` headings in this order:

- **Plan:** `<name>` and the plan file path; branch and worktree
  (cloud: PR link).
- **Architecture now:** the files, globals, entry points and wiring this
  plan has touched so far, one line each, as they are after this phase.
- **Completed phase:** number, name, commit hash, what was verified
  (exact commands with their numbers, and one line per picture read on
  what it shows).
- **Next phase:** number, name, its deliverables and Verification line
  copied from the plan, the D numbers it rests on, and the exact first
  action (the file and function to open, the saved spec to send, or the
  rules file to read).
- **Requirements / gotchas:** anything the next phase needs that is
  not in the plan file or `.claude/MAP.md`.
- **Questions:** `none`, or every deferred question so far, numbered
  `Q1`, `Q2`… across the run, each written as a ready `AskUserQuestion`:
  the phase, the plan line it is about, the question, 2 to 4 options
  with the recommended one first, and one line on what the phase already
  finished without it.
- **Blocker:** `none`, or what stopped the run, with its questions in
  the same ready form.

It replaces `.claude/handoff.md` for plans: never write both at a phase
boundary. The `handoff` skill still applies inside a phase run in the
app (an error you cannot get past mid-step): that is a mid-phase
continuation, not a phase boundary. When the last phase is done, delete
the state file in the Stage-done commit.

### Phase questions: decide, defer, or stop

A phase's research or design will sometimes force a decision the plan
does not cover (something the interview missed, or a `→ phase
decides`). That is a phase question. Look for them on purpose: before
the first spec of a phase, list every decision the phase forces that no
`D`, piece or Brief line settles, and sort each one:

- **Decide** (the usual case). You would mark one option
  "(Recommended)" with confidence, or the choice is cheap to change
  later: internal names, file splits, helper structure, test tooling,
  and most visible details a D or rule points toward. Take it, record
  `D<n> (auto)` with one line of reason, keep going. Never asked, in the
  app or unattended.
- **Defer the phase** (rare). No option clearly wins, and the answer
  changes what the owner sees, hears or feels, or a tuning number, in a
  way that means redoing the phase to change later; or the phase would
  change something outside its Scope, or delete files the plan does not
  name. In the app, ask these in one `AskUserQuestion` round at the
  **start** of the phase (never after the implementer has run) and
  record the answers as D's. Unanswered (the owner is away, or the run
  is unattended): finish and commit what the question does not touch,
  write it under Questions, mark the row `deferred Q<k>` (plus `· partial
  <sha>` when part landed), and hand off to the next runnable phase
  (`Status: phase-done`), or `Status: questions` when none is left.
- **Stop the run** (really broken, for every later phase too): the code
  contradicts the plan, so later phases would build on a wrong premise;
  two D's conflict; a failing check you can't fix; a step that would
  lose work or spend money. Finish what can be finished, commit, write
  it under Blocker, `Status: blocked`, hard stop.

**`Questions: auto` in the plan header** (the owner's standing choice
for that plan, set at the ready gate's last question or any time; the
default is `Questions: ask`) turns every defer into a decide, recorded as `D<n>
(auto, owner-delegated)`; only "stop the run" still stops.

A number the plan worked out (its working, check and fallback) is
built as written: measure once, and apply the fallback only when the
check fails, as `D<n> (auto)`; that is no question.

Every `(auto)`, deferred question and blocker names a question the
interview should have asked: add it to the plan's `Interview` line as
`missed: <question>` so the next plan's Part A list grows. Stage done
lists them all under Look at, where the owner can reverse any `(auto)`.

Context inside one phase: a phase too big for one context was split
wrong. At `CONTEXT WATCH` finish the atomic step, commit, and write the
state file with `Status: partial`, "Completed phase" as `<n> (partial)`
and "Next phase" as the rest of it; then hard-stop. Next session, split
the phase in the Progress table before continuing. A session that stops
after designing saves each finished spec as
`.claude/plans/<name>.spec-<phase>-<k>.md` (the Spec format in
`.claude/playbook.md`, ready to send) and names them in Next phase; the
next session sends them to the implementer instead of exploring again,
and deletes each in the commit that lands its work.

### Answer (`go` in the app while `Status: questions` or `blocked`)

The owner answers a run's questions in the app, where the question UI
works. A `go` prompt (bare or the full one, or `/plan`) on the plan's
checkout that finds either status:

1. Asks every question under Questions and Blocker with
   `AskUserQuestion`, as written there, up to 4 per call, by the
   "Question rules" in `interview.md` (read only that section).
2. Records each answer as a `D<n>` in the plan, adds its `missed:` line,
   sets every `deferred` row back to `todo` (keeping any `partial <sha>`
   note), clears Questions and Blocker to `none`, and sets `Status:
   phase-done` with Next phase = the first runnable row (for a partial
   row, the part still to do).
3. Commits the plan and state file by path.
4. Starts the run again ("Supervising the run", one phase per launch)
   and ends with the normal report, saying it is running.

It never runs a phase itself. When the answer came in the supervising
session (the run stopped on questions), steps 1 to 4 happen there,
without the owner typing `go`.

### Running unattended (`AUTOPLAN=1`)

`py -3 tools/autoplan.py <name>` runs the phases, started by the app
session (or from a terminal as a fallback), one fresh headless session
per phase, on the owner's subscription only: it
never uses an API key and stops the chain when the usage limit is hit.
Started from the main checkout, it makes (or reuses) the worktree
`.claude/worktrees/plan-<name>` on branch `claude/plan-<name>` and runs
there; each phase commits on that branch and nothing lands on `main`
(the runner's sessions are refused `try.py --commit`). The owner lands
the finished run, after the Stage done report. A session it starts has `AUTOPLAN=1` and a prompt that
begins `[autoplan | ...]` and carries the phase brief: read
`.claude/skills/plan/unattended.md` (short) and not the rest of this
file.

## Last phase done → Stage done

Only when every Progress row is `done`. Set `Stage: done`, delete this
checkout's HERE and the plan's state file, list every `D<n> (auto)` and
every `missed:` line in the report under **Look at**, commit. The plan
file stays as the record. This last phase ends with the hard-stop
message too; the owner's next prompt is a fresh task. The supervising
session, on the run's `plan-done`, reports the whole plan: what each
phase built, Look at, and the worktree mode's Commit command for
`claude/plan-<name>`, which waits for the owner's OK like any branch.
