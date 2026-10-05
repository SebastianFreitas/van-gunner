# Playbook: read the section you need, once per window

Shared by every project. The project's own part (spec style and
verification details, tool commands) is `.claude/project/playbook.md`:
read its matching section too.

## Delegation

- Every subagent call is foreground (`run_in_background: false`;
  `.claude/hooks/agent-guard.py` refuses the rest): the window has
  nothing else to do, and a background subagent's hand-back lands in a
  new turn that the Stop guard fights. Parallel calls are several Agent
  calls in one message: they run together and return together.
- **Reports:** every agent writes its full report to a file and returns
  at most about 150 words: a status or verdict line, the files changed,
  each blocker or must-fix finding in one line (at most five), and the
  report's path. The default path is
  `.claude/specs/reports/<agent>-<slug>.md` in the agent's checkout
  (gitignored with `.claude/specs/`; only a run's final commit deletes it); name
  another in the prompt when needed (`implementer-wt`: an absolute path
  in your checkout). Open a report only for a line the summary leaves
  unclear, by grep.
- **Built-in agents** get the contract as the last line of the prompt.
  `Explore` cannot write files: "Answer in at most 150 words: one line
  per finding with its `file:line`." `general-purpose`: "Write your
  findings to `<path>`; reply with at most 150 words and the path."
- Parallel implementer calls only on completely separate files. Several
  tasks each adding one line to the same file (a `<script>` tag, a
  registry entry): each edits only its own line with one `Edit`,
  re-reading and retrying if the file changed.
- Parallel tasks on the same file (worktree and cloud mode only):
  `implementer-wt`, each in its own worktree cut from your `HEAD`, so
  commit first. Merge their branches one at a time with `git merge
  --no-ff`, resolve, re-run the checks.
- A new file over about 250 lines: the spec says to write a skeleton
  first and add function groups with Edits. One big Write dies on the
  output cap.
- An implementer that reports "blocked" or "hit the context line": never
  resume it with SendMessage (that reloads its whole context); write a
  narrower spec for a fresh call.
- A prepared run saves each spec as `.claude/specs/<k>.md` and the run
  window sends only its path (`.claude/rules/workflow.md` "One prompt").
- A plan phase that stops after designing saves each finished spec as
  `.claude/plans/<name>.spec-<phase>-<k>.md` in the format below (plan
  skill).
- Over about 150 lines or three files (`.claude/` and `.md` files not
  counted): the `reviewer` gets the spec paths and the changed paths
  before you commit (`review-guard.py` enforces it, workflow.md Run).

## Run

The detail behind `workflow.md` "Run" steps 3 to 6.

- A prepared run's specs are gitignored and exist only in the worktree
  the go prompt names, so a run never moves to another checkout.
- Verify: the reviewer may re-run the implementer's checks.
- Review is not a judgement call: `.claude/hooks/review-guard.py` counts
  the real diff at `git commit` and at `try.py --commit` and refuses the
  command until a reviewer has run in this window; an earlier window's
  review does not count.
- Commit: worktree mode commits on its branch only and `try.py
  --commit` waits for the owner's OK (the mode file's Commit); shared
  mode's commit onto `main` itself waits for the OK.

## Models

Opus thinks and judges (main, plan runs, `plan-writer`, Plan,
`reviewer`, `plan-reviewer`), Sonnet does (`Explore`, `implementer`).
The reviewers moved to Opus because Sonnet 5.5 misses more on hard
reviews and more of its comments are noise; it matches Opus on
spec-driven code at half the cost (owner, 2026-10-05). When the owner
picks Fable (`claude-fable-5-1`) for a session, Fable takes Opus's place
and nothing else changes: it manages, writes specs and delegates every
code change exactly as Opus does (owner, 2026-10-02). `plan-writer` and
Plan inherit the session's model; a plan run uses Fable with
`autoplan.py --model claude-fable-5-1`. No Haiku: a missed caller costs
more than it saves (owner, 2026-10-01). Each project keeps its own
`.claude/agents/explore.md` with `model: sonnet`; without one the
built-in Explore runs on the main model (Opus). Effort: the main
session runs at low (`modelSettings` in `.claude/settings.json`, a
deliberate test, owner 2026-10-05); agents keep medium (the agent files'
`effort:`) and autoplan's headless phases pass `--effort medium`.

## Spec format

Intent, not a line-level design: the implementer reads the code and the
rules files the spec names, and settles the how. The spec fixes what the
owner or other code would notice (names others call, numbers, text,
look) and leaves the rest. Under about 40 lines, written once with one
Write and never read back; longer means two specs. Every spec has:

1. **Goal:** what changes and why, in plain words.
2. **Where:** the files to create, edit or delete, and the functions or
   names to grep there (from `.claude/MAP.md` or an Explore's anchors).
3. **Read first:** the `.claude/rules/` files for the area (the project
   playbook says which) and any doc the change must follow.
4. **Constraints:** decisions already made (names, values, text, look),
   project invariants it touches, and what stays unchanged, including
   foreign edits already in a target file (shared mode).
5. **Acceptance:** what is true when done, and the exact checks: the
   verify commands (never one that blocks: a dev server, an editor
   window; the project playbook names those that run and exit), the
   numbers to report, the screenshots to take and what each must show,
   and a `git grep` proving deleted names are gone.

## Commands every project has

- **Try and Commit:** `tools/try.py`, commands in your mode file. Try
  belongs to the owner: print it, never run it. Commit (`--commit`) runs
  only on the owner's OK: the owner runs it, or replies "merge it" /
  "land it" and you run it (`git-guard.py` checks their latest message).
- **Autoplan:** `py -3 tools/autoplan.py [<name>] [--dry-run]
  [--max-sessions N] [--budget USD] [--effort medium] [--line 160000]
  [--kill 185000] [--force]`. The window that launches it (or whose go
  prompt runs a plan) is a plan run's supervisor, with a 160k line.
  Started by the app session in the
  background (`run_in_background`) with `--max-sessions 1`, one phase
  per launch, and relaunched by it after each phase (plan skill
  `run.md`); a terminal is only a fallback. Runs a plan's
  phases unattended, one headless session each, in
  `.claude/worktrees/plan-<name>`, on the subscription only (no API key;
  stops at the usage limit), and stops when questions wait, on a
  blocker, or at plan-done. Logs and the run lock in `.claude/autoplan/`.
- **Cleanup:** `py -3 tools/cleanup.py` deletes local session branches
  and their worktrees once they have landed on `main` and sat idle 24 h
  (it also runs at session start and after `try.py --commit`).
- **Sync:** `py -3 <master>/sync.py status|push|pull <project root>`
  ("Shared files" below). After committing a sync
  in a project, its `main` must be pushed: new app sessions start from
  `origin/main` and never see an unpushed sync.

## Shared files

Every path in `.claude/workflow.lock` came from the master. Edit them in
the project like any file when the owner asks for a workflow change,
then, after the commit, send the change back so every project gets it:
`py -3 <master>/sync.py pull <project root>`. At session start
`WORKFLOW SYNC:` names what differs: `project-changed`: pull (above);
`master-changed` or `new`: `py -3 <master>/sync.py push <project root>`,
then commit the updated files by path; `conflict`: merge by hand and
tell the owner.

The project's half lives in `.claude/project/`, which sync never
touches: `modes/<mode>.md` (printed by the hook after the shared mode
file: landing steps, literal Try/Commit paths), `playbook.md`,
`implementer.md` (the only project context implementers get),
`reviewer.md` (the invariants and runtime pitfalls the reviewer checks),
optional `autoplan.json` (`allowedTools` for unattended runs), optional
`file-guard.json` (extra binary suffixes and cache folders, source
suffixes, generated files and why), optional `settings.json`
(permissions and the project's own hooks: `sync.py push` merges it into
`.claude/settings.json`, so edit the fragment, never the merged file).
A project's own hook scripts sit in `.claude/hooks/` next to the shared
ones; sync leaves files it does not list alone. `tools/try.py` and
`tools/try_commit.py` call the project's optional `tools/try_project.py`
(`add_arguments` and `launch` for Try, `before_commit` for landing steps
and `verify` for checks, both on the combined tree in the `-try`
checkout). Every project gitignores `.claude/handoff.md`,
`.claude/specs/`, `.claude/worktrees/`, `.claude/plans/HERE` and
`.claude/autoplan/`.

## No MODE line

The SessionStart hook did not run. Then `CLAUDE_CODE_REMOTE=true` is
cloud, a `git rev-parse --git-common-dir` outside this checkout is
worktree, and anything else is shared: read that mode file and say in
the report that the hook did not run.

## Landed

Worktree mode, after you ran the Commit on the owner's OK and it printed
`LANDED:` (owner, 2026-10-02): rename the session with
`set_session_title` (`session_id` "self") to `Landed: ` plus its current
title, call `mark_completed` ("self"), and end the turn with one line:
"Landed as <sha> on `main` and pushed; this worktree is finished
(archive it, or reply here for a follow-up round)." When the owner runs
the command themselves, the `LANDED:` line is their signal.

## Merging by hand

Shared mode, only when the owner asks you to merge branches. Merge the
open branches into `main` one at a time with `--no-ff`, oldest first.
`.claude/MAP.md` rows: keep both sides' rows, then re-count the changed
files. The project's shared-mode notes say how its own conflicts
resolve. After the last
merge run the landing steps once and the project's full check (`CLAUDE.md`
§ Verify), commit, and end with the report (the owner pushes). Never
delete branches by hand; `tools/cleanup.py` removes merged ones once
idle 24 h.
