# Workflow: rules for every session

Shared by the owner's projects, synced from the `claude-workflow`
master. The project's `CLAUDE.md` holds what is specific to it and wins
where they disagree. Detail only some windows need is in
`.claude/playbook.md`, the mode files and the skills: read the named
section when you need it.

## Coordinator

The main session plans, delegates, decides and talks to the owner; every
token in it is paid again each turn. It never reads source, rules files,
logs or images, runs verify only as a one-line spot check (Run step 4),
and makes at most two quick lookups (a grep, a short range) before
delegating; more goes to `Explore`. Agent prompts name paths, never
pasted content. Agents write the full report to a file and return at
most about 150 words plus its path; every `Explore` or `general-purpose`
prompt ends with the playbook's report line (playbook Delegation).

## Shared files

The paths in `.claude/workflow.lock` come from the master. For a
workflow change or a `WORKFLOW SYNC:` line read playbook "Shared files"
(edit here, commit, then `sync.py pull`). A rule
that only fits this project goes in `CLAUDE.md`, never here.

## Session mode

The SessionStart hook prints `MODE: <mode>` and that mode's rules
(`.claude/modes/<mode>.md` plus the project's notes), which override
this file on branches, pushing, shipping and the report's commands. `worktree` (default): `.claude/worktrees/<name>`, own branch,
never pushed (landing it pushes `main`). `cloud`: a fresh clone on a
pushed `claude/<name>` branch with a PR. `shared`: the main checkout,
other sessions editing too; quick fixes.

No `MODE:` line: the hook did not run (playbook "No MODE line"). After
`EnterWorktree`, read `.claude/modes/worktree.md` before the next edit.

## The go prompt

A turn that hands its work to a fresh window (a prepared run, a
context-full handoff, a plan's ready gate, a paused interview, a plan
waiting for answers) never ends with "say `go`": a bare `go` in a fresh
window guessed its worktree and branch wrong (owner, 2026-10-01). It
ends, after the report, with the exact prompt in a plain fenced block
(not `bash`: no Run button) as the last thing in the turn:

    Ready. Please run `/clear`, then paste this:

    ```
    go: <what to do>. Checkout <path> on branch <branch>, <mode> mode. Read <file> first.
    ```

- `<what to do>`: one plain clause ("build the prepared specs",
  "continue the handoff", "run plan <name> one phase at a time",
  "answer plan <name>'s questions"). A stage file may give another first clause
  without `go:`; the rest of the line stays.
- `<path>`, `<branch>`: from `git rev-parse --show-toplevel` and `git
  branch --show-current` run now, forward slashes, never from memory
  (cloud: add `PR #<n>`).
- `<file>`: `.claude/handoff.md` for a run or a handoff,
  `.claude/plans/<name>.md` for an interview, the plan's state file for
  a run or its questions.

**Receiving one** (bare `go` or not): `go-check.py` prints `GO CHECK:`
ok, or MISMATCH with what to do (no line: run the two git commands and
compare yourself). On a mismatch stop and say where each is. Never
switch checkout or branch to match, except as your mode file says
(cloud "continue PR #<n>"; worktree: a new chat merges the named branch
for a plain handoff); a prepared run never moves.

## Plans

Big work is a plan (`/plan new <name>: <brief>`, `.claude/plans/`). The
hook prints `PLAN: <name> · <stage>`; read only the stage file
`.claude/skills/plan/SKILL.md` names (`AUTOPLAN=1`: `unattended.md`).
One `/clear` after the ready gate, then one app window supervises every
headless `autoplan.py` phase; nobody clears or says `go` between phases.

## One prompt: prepare, clear, run

Owner, 2026-10-01: *"i send prompt -> it prepares whatever it needs -> i
clear and tell it to run that prompt ... and it starts managing
instances, with the goal of never reaching its own limit on the context
window set by me"*. One window prepares, a fresh one manages helpers
that do the work. Sort each new prompt from its words and at most one
`Explore` call:

- **Quick fix:** one or two files, one clear change: steps 1 to 7 in
  this window, no clear.
- **Anything else:** **prepare** (steps 1 to 2), end the turn; the owner
  runs `/clear` and pastes the go prompt; the fresh window **runs**
  (steps 3 to 7). Unsure: prepare.
- **Too big for one run** (over about 20 specs): a plan; suggest `/plan
  new <name>: <prompt>`.

A plan, a handoff or a plan's questions in this checkout follow their
own files, not this sort.

**Obvious questions come first.** Anything two reasonable builders would
do differently that the prompt, code, rules and memories do not settle
(the look, where it goes, what happens on failure, what stays as it is)
is asked in one `AskUserQuestion` round in step 1, never in plain text.
A choice with one sensible answer is taken and named under Look at. A
run never stops to ask what could have been asked here; a turn ends
early only when something went really wrong.

### Prepare

This window's line is 120k; two prepare windows reached 140k writing
specs and reading files themselves (2026-10-01).

1. **Explore** through `Explore` (the files, functions, `file:line`
   anchors and the rules files covering them), ask the obvious
   questions, and keep working in the same turn once answered. **Read
   nothing yourself:** a gap goes to a second, narrower Explore.
2. **Spec** one per implementer call (playbook "Spec format"): intent,
   under about 40 lines, at most about three deliverables (more: split).
   **Write each spec once**, one Write, never read back; an afterthought
   goes in the handoff's Next line for that spec. For a prepared run
   save each as `.claude/specs/<k>.md` (gitignored) and write
   `.claude/handoff.md` as the `handoff` skill's "Prepared run" says.
   End the turn with what will be built in two or three plain lines,
   then the go prompt (what: "build the prepared specs"; file:
   `.claude/handoff.md`), nothing after it.

### Run

A go prompt whose printed handoff starts `Run: prepared`, checkout and
branch checked first. This window only manages, never reads a spec or a
diff (about 3k tokens per spec, so 20 fit under its 175k line). Step
detail: playbook "Run".

3. **Implement:** one foreground `implementer` per spec, the prompt only
   "Your spec is `.claude/specs/<k>.md`: read it and implement it".
   Parallel specs (where the handoff says so) are several calls in one
   message. Blocked: one `Explore`, a narrower spec, a fresh
   implementer; still blocked, stop and tell the owner.
4. **Verify:** the implementer runs its checks and `CLAUDE.md` § Verify
   for the areas touched and reports pass or fail with the key numbers.
   This window runs one tailed command only when a report is ambiguous.
5. **Review:** over about 150 lines or three files (`.claude/` and `.md`
   not counted) the `reviewer` gets the spec and changed paths and
   reports only gaps that break the spec or a flow; a gap is a new spec,
   back to step 3. `review-guard.py` refuses `git commit` and `try.py
   --commit` until a reviewer ran in this window.
6. **Commit** by path as your mode says, the message describing the work
   (a squash takes the branch tip's message). Landing on `main` waits
   for the owner's OK (worktree: `try.py --commit`; shared: the commit
   itself). Only the run's final commit deletes `.claude/specs/` (this
   session's specs and reports, not another session's in shared mode)
   and `.claude/handoff.md`; a context-full commit keeps them.
7. **Report:** end the turn with exactly this:
   1. **Name:** the feature in plain words, then the branch (and PR in cloud).
   2. **How it looks:** one or two screenshots the implementer took
      (tools named in `CLAUDE.md`) outside the repo, sent with
      SendUserFile (else their paths); never Read here.
   3. **Try:** one `bash` block, one command from your mode file, and
      one line on where to look and what to do.
   4. **Commit:** one `bash` block from your mode file, or which commit
      already landed on local `main`.
   5. **Look at:** at most three bullets, plus anything left open.

Changes in the owner's reply are sorted the same way (quick fix here,
anything else prepared again) on the same branch, with the same report.

## Main session role

- Do not edit source files yourself (Write, Edit, or Bash that writes),
  except a single-line change where a spec would take longer than the
  edit. Cost and convenience are not exceptions. Docs, `.claude/MAP.md`
  rows, `.claude/handoff.md` and the markdown in `.claude/` are not
  source: edit those directly.
- Every code change goes to `implementer`, one spec per call, one file
  per call unless the change genuinely spans files; it sees the spec and
  what it names, never these rules.
- Explore and Plan never load this file or `CLAUDE.md`: name the file,
  function or concept, tell them to grep `.claude/MAP.md` first, and ask
  for `file:line` anchors, not code bodies.
- `.claude/rules/` files load only for a session that reads a matching
  file: the spec names those `CLAUDE.md` maps to the area, the
  implementer reads them.
- A plan, state file or handoff: grep the heading, never re-read the
  whole file.
- Models and effort (Opus judges, Sonnet does, Fable in Opus's place,
  no Haiku; main session effort low, agents and autoplan medium):
  playbook "Models".

## Context budget

Auto-compact is off (`DISABLE_AUTO_COMPACT`, owner's rule 2026-09-29): a
session never runs past its line; it stops and the owner clears or
opens a new chat. Never compact or clear yourself. `context-watch.py`
prints `CONTEXT WATCH` once when a window crosses 90% of its line, once
when it passes it, and once per new prompt while it stays there. Lines:
a prepared run's window, a plan run's supervisor and headless plan
sessions 175k (the runner kills headless ones at 200k); every other app
window 120k; Explore, Plan, general-purpose and claude-code-guide 100k,
plan-writer 120k, implementer 60k, reviewer and plan-reviewer 80k. A
subagent at 1.25 times its line is denied further tools: the prompt was
too wide; next time name file, function and range, or split. Every
subagent runs in the foreground (playbook Delegation).

- Main session past its line: finish only the current atomic step,
  verify, commit (keep `.claude/specs/`: pending specs and any report
  the handoff names stay for the next window), write
  `.claude/handoff.md` (`handoff` skill), end with
  the normal report plus your mode file's "Context full" extras, then
  the go prompt (what: "continue the handoff"; a run's: `handoff`
  skill). Plans stop their own way.
- A handoff at session start: restate the plan in two lines, continue
  from Next, never redo Done, delete the file once absorbed; a `Run:
  prepared` one stays until the run's commit.

## Token rules (every agent)

- Never read a whole file over 300 lines (file-guard refuses it): grep
  the name, then read around the hit. Names do not drift; line numbers do.
- Search with the Grep and Glob tools, not `grep`/`find` in Bash: they
  skip gitignored paths such as `.claude/worktrees/`.
- Never open `__pycache__/` or the binary and media paths `CLAUDE.md`
  lists (names only).
- Keep command output short: `tail -n 30` or grep for errors.
- Numbers before pictures: a view a tool measures (pixel count, compare
  against a baseline) is judged by its number. A subagent reads a
  picture only for a look no tool measures, once, with one line on what
  it shows, never one already described. The main session never Reads
  an image: it passes the path on.
- A new file, moved function or new export gets its MAP.md row fixed in
  the same commit (branches: see your mode file). Rows hold purpose and
  exports, no line counts, no line over 300 characters (Grep prints
  "[Omitted long matching line]" instead); detail goes on bullets under
  the table, each starting with the file name. `review-guard.py`
  refuses a commit once when either slips.
- The map's "Owner's words" section maps the owner's nicknames to code
  names; when the owner uses a word the code does not, add a line.

## Git and the owner's commands

- Stage by path. Never push (cloud: only your own `claude/` branch),
  never merge or commit onto `main` except a shared-mode commit the
  owner OK'd (their latest message says commit, merge or land), never
  delete branches by hand (`tools/cleanup.py` does), never `gh pr
  merge`. Only `try.py --commit` reaches local `main` from a branch (run
  by the owner, or by you when their latest message says merge or
  land), and it pushes `main` once landed: new worktrees are cut from
  `origin/main` (2026-10-01). Nothing else reaches origin except the
  owner's GitHub Desktop.
- `git-guard.py` blocks blanket git (`add -A`/`.`, `commit -a`,
  `stash`, `checkout --`, `restore`, `reset --hard`, `clean`, `rebase`,
  force push). Do not work around it; the owner runs those if wanted.
- Commands shown to the owner go in fenced `bash` blocks (the app adds a
  Run button), one command per block, and must also work pasted into
  Windows PowerShell 5.1: forward-slash paths, no `&&`, `||`, `$(...)`
  or bash `if`.
- No scratch files in the repo: logs, notes and screenshots go in the
  session's scratchpad.
