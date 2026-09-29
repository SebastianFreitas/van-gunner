# Running a plan phase unattended (`AUTOPLAN=1`)

`tools/autoplan.py` runs one fresh headless session per phase, in the
worktree `.claude/worktrees/plan-<name>` on `claude/plan-<name>`, on the
owner's Max subscription (no API key; defaults: `claude-opus-5-5`,
effort medium, permission mode auto, at most 30 sessions). Your prompt
starts with `[autoplan | plan <name> | session <k>]` and carries the
**phase brief**: the state file `.claude/plans/<name>.state.md`, this
phase's section of the plan, the Decisions it cites, Carry forward, and
any saved spec files. Read this file once; do not open `SKILL.md`, the
plan file or the state file for what the brief already holds. Open the
plan only for a D or piece the brief does not carry, by grep, never
whole.

Everything in `SKILL.md` "one phase per session" still holds (one phase,
Handoff protocol, Verify in a phase, state file format, commit by path).
The differences:

## Budget

The prompt names your context line (`CONTEXT WATCH` warns at it) and
the runner's kill line above it. The phase has to fit between the
~35k you start with and the line, so:

- **Code reading goes to `Explore`**, always, with a named file,
  function and question, asking for `file:line` anchors and a summary.
  Read yourself only the range a spec is written against (under about
  150 lines). A 1,000-line script read in main costs 30k and writes no
  code.
- **Implementers run in the foreground** (`run_in_background: false`).
  Never launch one in the background and wait: no sleeps, no "waiting"
  messages, no ending the turn while one runs. Its commit must land
  before you write the state file.
- **Verify what you touched, once.** `py -3 tools/check.py` for any
  Godot file; `py -3 tools/smoke.py` for anything under `scripts/`,
  `scenes/`, `resources/` or `tools/smoke/`; `py -3 tools/scene_dump.py`
  for the van's scenes; `py -3 tools/smoke.py --shots <dir>` once for a
  visible change, then Read the PNGs the phase's Verification names.
  The tools lock the project folder and run shots on a hidden desktop,
  so a Godot run never collides with another or shows a window. Never
  `--bless` unless the phase's Deliverable says so.
- Screenshots and scratch scripts go under `%TEMP%` (the session's
  scratchpad), never the repo.

## Three ways a session ends

1. **Phase done.** Handoff protocol complete, `Status: phase-done`
   (`plan-done` when it was the last phase and Stage is now done).
2. **Design saved** (`Status: partial`). When the design alone brings
   you near the line (past about two thirds of it) or the phase needs
   more than two implementer specs: write each finished spec to
   `.claude/plans/<name>.spec-<phase>-<k>.md` in the Spec format from
   `CLAUDE.md`, complete enough to send as is. Commit them with the
   state file, whose Next phase says "send spec-<phase>-<k> to the
   implementer".
3. **Blocked** (`Status: blocked`). Finish what can be finished, commit,
   and write the Blocker as ready questions (below).

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
question by the stop line in `SKILL.md`:

- **Below it** (internal names, file splits, helper structure, test
  tooling): decide at once as `D<n> (auto)` with one line of reason, plus
  a `missed: <question>` on the plan's Interview line, and keep going.
- **On it** (anything seen, heard or felt in the game; a gameplay or
  balance number; a change outside the phase's Scope; deleting files;
  code that contradicts the plan; two decisions that conflict; a failing
  check you can't fix): stop. Commit what is finished and verified, then
  `Status: blocked` with each question under Blocker written ready to
  ask: the question, 2 to 4 options with the recommended one first, and
  the plan line it is about. The owner answers it with `go` in an app
  session on this worktree and restarts the runner.
- **`Questions: auto` in the plan header:** on-the-line questions don't
  stop either. Take the recommended option, record it as `D<n> (auto,
  owner-delegated)` with one line of reason, and keep going; Stage done
  lists them under Look at. Only a failing check you can't fix blocks.

Keep going until the session ends one of the three ways. Do not end with
a progress update. The report and hard-stop message are still written;
the runner logs them.
