# Workflow: rules for every session

Shared by all the owner's projects. This file is a copy: the master
lives in the `claude-workflow` repo (path in `.claude/workflow.lock`),
and `sync.py` keeps the copies equal. The project's own `CLAUDE.md`
holds what is specific to it: stack, verify commands, screenshot tools,
domain rules. Where the two disagree, `CLAUDE.md` wins.

## Shared files

Every path listed in `.claude/workflow.lock` came from the master. Edit
them here like any file when the owner asks for a workflow change, then,
after the commit, send the change back to the master so every project
gets it:

    py -3 <master>/sync.py pull <project root>

The SessionStart hook prints `WORKFLOW SYNC:` when a shared file differs
from the master. `project-changed`: pull (above). `master-changed` or
`new`: `py -3 <master>/sync.py push <project root>`, then commit the
updated files by path. `conflict`: merge by hand and tell the owner. A
rule that only fits this project goes in `CLAUDE.md`, never here.

The project's half of the shared files lives in `.claude/project/`,
which sync never touches: `modes/<mode>.md` (printed by the hook after
the shared mode file: landing steps, literal Try/Commit paths),
`playbook.md`, `implementer.md` (the only project context implementers
get), `reviewer.md` (the project's invariants and runtime pitfalls the
reviewer checks), optional `autoplan.json` (`allowedTools` for unattended runs),
optional `file-guard.json` (extra binary suffixes and cache folders,
source suffixes, generated files and why), optional `settings.json`
(permissions and the project's own hooks: `sync.py push` merges it into
`.claude/settings.json`, so edit the fragment, never the merged file).
A project's own hook scripts sit in `.claude/hooks/` next to the shared
ones; sync leaves files it does not list alone.
`tools/try.py` and `tools/try_commit.py` call the project's optional
`tools/try_project.py` (`add_arguments` and `launch` for Try,
`before_commit` for landing steps and `verify` for checks, both on the
combined tree in the `-try` checkout). Every
project gitignores `.claude/handoff.md`, `.claude/specs/`,
`.claude/worktrees/`, `.claude/plans/HERE` and `.claude/autoplan/`.

## Session mode

The SessionStart hook prints `MODE: <mode>` and the matching
`.claude/modes/<mode>.md`, then the project's notes for that mode. The
mode file overrides this one on branches, pushing, shipping and the
report's commands.

- `worktree` (default): `.claude/worktrees/<name>`, own branch, never pushed.
- `cloud`: a fresh clone on a `claude/<name>` branch, pushed, with a PR.
- `shared`: the main checkout, with other sessions editing too; quick fixes.

No `MODE:` line means the hook did not run. Then `CLAUDE_CODE_REMOTE=true`
is cloud, a `git rev-parse --git-common-dir` outside this checkout is
worktree, and anything else is shared: read that mode file and say in
the report that the hook did not run. After `EnterWorktree`, read
`.claude/modes/worktree.md` before the next edit.

## Plans

Big work runs as a plan: `.claude/plans/<name>.md`, started with
`/plan new <name>: <brief>` and driven by the plan skill. Before touching
a plan read the file for its Stage in `.claude/skills/plan/`, only that
one: `interview.md` (planning, ready) or `run.md` (running); `SKILL.md`
is the index. While it runs, its state lives in
`.claude/plans/<name>.state.md`. The hook prints `PLAN: <name> ·
<stage>` when a plan is bound to this checkout, `PLANS:` when several
are active and none is bound here. Planning is an interview the app
session manages while `plan-writer` subagents do the work (owner,
2026-10-01); execution is one phase per fresh session (owner's rule,
2026-09-26), under `py -3 tools/autoplan.py <name>`. The ready gate
ends with `/clear`, then `go`: that fresh app session runs the phases
one at a time in the background, reports each, answers questions and
restarts, and stops everything on any other problem. The owner never
pastes a command or says `go` between phases. The runner sets `AUTOPLAN=1`: then read
`.claude/skills/plan/unattended.md`.

## One prompt: prepare, clear, run

Owner, 2026-10-01: *"i send prompt -> it prepares whatever it needs -> i
clear and tell it to run that prompt ... and it starts managing
instances, with the goal of never reaching its own limit on the context
window set by me"*. Work stays out of the window the owner talks to:
one window prepares, a fresh one manages helpers that do the work.
Sort each new prompt from its words and at most one `Explore` call:

- **Quick fix:** one or two files, one clear change. Prepare and run in
  this window, no clear: steps 1 to 7 below, straight through.
- **Anything else:** **prepare** (steps 1 to 2), end the turn, the owner
  runs `/clear` and says `go`, and the fresh window **runs** (steps 3 to
  7). Unsure which: prepare.
- **Too big for one run:** more than about 20 specs is a plan. Say so
  and suggest `/plan new <name>: <prompt>`.

A plan, a handoff or a plan's questions in this checkout are handled as
their own files say, not sorted.

**Obvious questions come before the work.** Anything two reasonable
builders would do differently and the prompt, code, rules and memories
do not settle (what it looks like, where it goes, what happens when it
fails, what stays as it is next to it) is asked in one `AskUserQuestion`
round in step 1, never a plain-text question. A choice with only one
sensible answer is not asked: take it and name it under Look at. Once
the run starts it never stops to ask what could have been asked here. A
turn ends early only when something went really wrong, never just to
ask.

### Prepare

1. **Explore** through the `Explore` subagent, then ask the obvious
   questions (above) and keep working in the same turn once answered.
2. **Spec** one per implementer call (format in `.claude/playbook.md`).
   A step with more than about three deliverables becomes several specs.
   Size each spec so its implementer stays under its line: name the
   file, function and range. For a prepared run, save each spec as
   `.claude/specs/<k>.md` (gitignored), then write `.claude/handoff.md`
   (`handoff` skill) with `Run: prepared` as its first line and in Next
   the spec files in order (which may run in parallel), the Verify
   commands for the areas touched, whether a review is due (step 5) and
   the screenshots the report needs. End the turn with what will be
   built in two or three plain lines, then this as the last line:

   > Ready. Please run `/clear`, then prompt me with `go` to build it.

### Run

A `go` whose printed handoff starts with `Run: prepared`. This window
only manages: it never reads source, a spec or a diff, and never
explores; each spec costs it about 3k tokens (the call, the report, a
tailed check), so 20 specs fit well under its line (estimate from a
~40k start: check it on the first real runs and fix this line).

3. **Implement:** one `implementer` call per spec, the prompt saying
   only "Your spec is `.claude/specs/<k>.md`: read it and implement it";
   parallel where the handoff says so (playbook). A blocked implementer
   gets a narrower spec from one `Explore` call and a fresh
   implementer; still blocked, stop and tell the owner.
4. **Verify**: each spec's command (the implementer ran it), then what
   `CLAUDE.md` § Verify asks for the areas touched, output tailed.
5. **Review**: over about 150 lines or three files, the `reviewer`
   subagent (Sonnet, read-only, fresh context) gets the spec paths and
   the changed paths, checks `git diff` against them and reports only
   gaps that break the spec or a flow. A gap gets a new spec file and
   goes back to step 3.
6. **Commit** by path, as your mode says, with a message that describes
   the work (a squash takes the branch tip's message). In worktree mode
   run the mode's `try.py --commit` yourself once verified. Delete
   `.claude/specs/` and `.claude/handoff.md`.
7. **Report**: end the turn with exactly this:
   1. **Name:** the feature in plain words, then the branch (and PR in cloud).
   2. **How it looks:** one or two screenshots of what changed (the
      project's screenshot tools, named in `CLAUDE.md`), saved outside
      the repo and sent to the owner.
   3. **Try:** one `bash` block with one command from your mode file, and
      one line on where to look and what to do.
   4. **Commit:** one `bash` block from your mode file, or which commit
      already landed on local `main`.
   5. **Look at:** at most three bullets, plus anything left open.

If the owner replies with changes, sort the reply the same way (a
quick fix is done here; anything else is prepared again) on the same
branch, and end with the same report.

## Main session role

You explore, design, write specs, review what the implementer returns
and write the follow-up spec. Source files are written by `implementer`,
because the main context is paid again on every turn.

- Do not edit source files yourself (Write, Edit, or Bash that writes).
  The one exception is a single-line change where a spec would take
  longer than the edit. Cost and convenience are not exceptions.
- Docs, `.claude/MAP.md` rows, `.claude/handoff.md` and the markdown in
  `.claude/` are not source: edit those directly.
- Before designing, grep `.claude/MAP.md`, then send code reading to
  `Explore`. Read yourself only the range you are writing a spec against.
- Explore and Plan never load this file or `CLAUDE.md`: name the file,
  function or concept, tell them to grep `.claude/MAP.md` first, and ask
  for `file:line` anchors and a summary, not code bodies.
- Models: Opus thinks (main, plan runs, `plan-writer`, Plan), Sonnet
  does (`Explore`, `implementer`, `reviewer`, `plan-reviewer`). No
  Haiku: every spec is written from Explore's anchors, so a missed
  caller costs more than it saved (owner, 2026-10-01). Each project
  keeps its own `.claude/agents/explore.md` with `model: sonnet`;
  without one the built-in Explore runs on the main model (Opus).
- Every code change goes to `implementer` (Sonnet), one spec per call,
  one file per call unless the change genuinely spans files. It sees
  only the spec, never these rules. Read `.claude/playbook.md` before
  the first spec of a turn: parallel calls, big new files, blocked
  implementers, the Spec format and the tool commands.
- Domain rules in `.claude/rules/` with `paths:` load only when a
  matching file is read, and you delegate reading, so read the ones
  `CLAUDE.md` names yourself before designing in those areas.

## Context budget

Auto-compact is off (`DISABLE_AUTO_COMPACT` in `.claude/settings.json`,
owner's rule 2026-09-29): no session runs on past its line; it stops
and the owner clears or opens a new chat. Never compact, never clear
yourself. `.claude/hooks/context-watch.py` prints `CONTEXT WATCH` near
each line: main and headless plan sessions 160k (the runner kills at
185k), Explore and Plan 100k, plan-writer 120k, implementer 60k,
reviewer and plan-reviewer 80k. A subagent
at 1.5 times its line is denied further tools, which means the prompt
was too wide: next time name the file, function and range, or split.

- Main session past its line: finish only the current atomic step,
  verify, commit, write `.claude/handoff.md` (`handoff` skill) and end
  the turn with the normal report plus your mode file's "Context full"
  extras. Look at's first bullet: "Context full: run `/clear` (or open
  a new chat) and say `go`." Plans stop their own way (plan skill). In a
  run, the handoff keeps `Run: prepared` and lists in Next the spec
  files still to send, so `go` carries on managing.
- A handoff printed at session start: restate the plan in two lines,
  continue from Next, never redo Done, delete the file once absorbed.
  One that starts `Run: prepared` is a run ("Run" above): it stays
  until the run's commit.

## Token rules (every agent)

- Never read a whole file over 300 lines (MAP.md lists those over 500):
  grep the name, then read around the hit. Names do not drift; line
  numbers do.
- Never open the binary and media paths `CLAUDE.md` lists; list them
  for names only. Never open `__pycache__/`.
- Keep command output short: `tail -n 30`, `Select-Object -Last 30`, or
  grep for errors.
- Numbers before pictures: a view a tool measures (pixel count, compare
  against a baseline) is judged by its number, not by reading the
  picture. Read a picture only for a look no tool measures, once, with
  one line on what it shows; never re-read one already described.
- A new file, moved function or new export gets its MAP.md row fixed in
  the same commit (branches: see your mode file).

## Git and the owner's commands

- Stage by path. Never push (cloud: only your own `claude/` branch),
  never merge or commit onto `main` except a shared-mode commit, never
  delete branches by hand, never `gh pr merge`. `tools/cleanup.py`
  deletes local session branches and their worktrees once they have
  landed on `main` and sat idle 24 h; it runs at session start and after
  `try.py --commit`. Only `try.py --commit` (run by you in worktree
  mode) reaches local `main` from a branch; only the owner's GitHub
  Desktop reaches origin.
- `.claude/hooks/git-guard.py` blocks blanket git (`add -A`/`.`,
  `commit -a`, `stash`, `checkout --`, `restore`, `reset --hard`,
  `clean`, `rebase`, force push). Do not work around it; the owner runs
  those themselves if wanted.
- Commands shown to the owner go in fenced `bash` blocks (the app adds a
  Run button), one command per block, and must also work pasted into
  Windows PowerShell 5.1: forward-slash paths, no `&&`, `||`, `$(...)`
  or bash `if`.
- No scratch files in the repo. Logs, notes and screenshots go in the
  session's scratchpad.
