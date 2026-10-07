# Running a plan phase unattended (`AUTOPLAN=1`)

`tools/autoplan.py` runs one fresh headless session per phase, in the
worktree `.claude/worktrees/plan-<name>` on `claude/plan-<name>`, on the
owner's subscription (no API key; it stops the chain at the usage
limit). Your prompt starts with `[autoplan | plan <name> | session <k>]`
and carries the **phase brief**: the state file
`.claude/plans/<name>.state.md`, this phase's section of the plan, the
Decisions it cites, Carry forward, and any saved spec files. Read this
file once; do not open `SKILL.md`, `run.md`, the plan file or the state
file for what the brief already holds. Open the plan only for a D, piece
or Progress row the brief does not carry, by grep, never whole.

Everything in `run.md` "one phase per session" still holds (one phase,
Handoff protocol, Which phase runs next, Verify in a phase, state file
format, commit by path) except the in-app `/clear` hard stop; open it by
grep for one of those headings, never whole. The differences:

## Budget

The prompt names your context line (`CONTEXT WATCH` warns at it) and
the runner's kill line above it. The phase has to fit between the
~35k you start with and the line, so:

- **Code reading goes to `Explore`**, always, with a named file,
  function and question, asking for `file:line` anchors. Read no source
  or rules yourself: the spec names them and the implementer reads them
  (`workflow.md` "Coordinator"). A 1,000-line file read in main costs
  30k and writes no code.
- **Implementers run in the foreground** (`run_in_background: false`).
  Never launch one in the background and wait: no sleeps, no "waiting"
  messages, no ending the turn while one runs. Its commit must land
  before you write the state file.
- **Verify what you touched, once**, with the cheapest check `CLAUDE.md`
  § Verify names for it, run by the implementer (the spec's Acceptance). Run the slow full checks only when the phase
  needs them, and capture a "before" once per run, not per phase, if an
  earlier phase's capture is named in the brief. Never re-record a
  baseline unless the phase's Deliverable says so.
- **Numbers before pictures.** A view a tool measures (a pixel count, a
  compare against a baseline) is judged by its number. Never read a
  picture yourself: the implementer or reviewer does, as `run.md`
  "Verify in a phase" says.
- **Look checks** go to the `look-judge` (foreground, `run.md` "Verify
  in a phase"); SendUserFile does not exist here, so write the shot
  paths and the verdict in the state file's Completed phase for the
  supervisor to send. The run never waits for the owner's reply.
- **The plan's numbers are built as written:** measure once, and apply
  the fallback written next to a number only when its check fails
  (`D<n> (auto)`). Do not re-derive them.
- Screenshots and scratch scripts go under `%TEMP%` (the session's
  scratchpad), never the repo.

## Four ways a session ends

1. **Phase done.** Handoff protocol complete, `Status: phase-done`
   (`plan-done` when it was the last phase and Stage is now done).
2. **Design saved** (`Status: partial`). When the design alone brings
   you near the line (past about two thirds of it) or the phase needs
   more than two implementer specs: write each finished spec to
   `.claude/plans/<name>.spec-<phase>-<k>.md` in the playbook's Spec
   format, complete enough to send as is. Commit them with the state
   file, whose Next phase says "send spec-<phase>-<k> to the
   implementer".
3. **Phase deferred.** A question you may not decide alone (below):
   commit what it does not touch, write it under Questions, mark the
   row `deferred Q<k>`, and hand off to the next runnable phase with
   `Status: phase-done`, or `Status: questions` when none is left.
4. **Blocked** (`Status: blocked`). The run is broken for every later
   phase: finish what can be finished, commit, and write the Blocker.

A session whose brief lists spec files starts by sending them to the
implementer, one call each, in order, unchanged unless the code has
moved. It does not re-explore what the spec already names. Delete a
spec file in the commit that lands its work.

Hitting the line mid-implementation: finish the atomic step, commit,
`Status: partial` with the rest as Next phase. The runner kills the
session at its kill line and commits leftovers as unverified work; that
is a fallback, not the plan.

## Nobody answers

`AskUserQuestion` is disabled and nobody is watching. Sort every phase
question as `run.md` "Phase questions" says (summarised here):

- **Decide** (the usual case): record `D<n> (auto)` with one line of
  reason, plus a `missed: <question>` on the plan's Interview line, and
  keep going.
- **Defer the phase** (rare: no option clearly wins and the answer
  changes what the owner sees, hears or feels or a tuning number, costly
  to redo; or a change outside Scope; or deleting files the plan does
  not name): session end 3 above. Write the question ready to ask: the
  phase, the plan line, the question, 2 to 4 options with the
  recommended one first, and what was finished without it.
- **Stop the run** (the code contradicts the plan, two D's conflict, a
  failing check you can't fix, a step that would lose work or spend
  money, the Pass test or a look check still FAIL after its fallback):
  session end 4.
- **`Questions: auto` in the plan header:** nothing defers; take the
  recommended option as `D<n> (auto, owner-delegated)`. Only "stop the
  run" still stops. A choice that would make the Pass test harder to
  pass (a piece that can't go where the Brief wants it, a cap the look
  runs into) is never auto: it is a stop.

The owner answers deferred questions and blockers later with `go` in an
app session on this worktree, then restarts the runner.

Keep going until the session ends one of the four ways. Do not end with
a progress update. End with a short phase report for the supervisor
(what landed, `Status`, Next phase), never `/clear` or a go prompt: the
session just ends and the supervisor launches the next.
