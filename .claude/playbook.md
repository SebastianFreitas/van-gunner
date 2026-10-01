# Playbook: read before writing the first spec of a turn

Shared by every project. The project's own part (spec style and
verification details, tool commands) is `.claude/project/playbook.md`:
read it too.

## Delegation

- Every subagent call is foreground (`run_in_background: false`;
  `.claude/hooks/agent-guard.py` refuses the rest). Parallel calls are
  several Agent calls in one message: they run together and return
  together.
- Parallel implementer calls only on completely separate files. Several
  tasks each adding one line to the same file (a `<script>` tag, a
  registry entry): each edits only its own line with one `Edit`,
  re-reading and retrying if the file changed.
- Parallel tasks on the same file (worktree and cloud mode only):
  `implementer-wt`, each in its own worktree cut from your `HEAD`, so
  commit first. Merge their branches one at a time with `git merge
  --no-ff`, resolve, re-run the checks.
- A new file over about 250 lines: the spec writes a skeleton first and
  adds function groups with Edits. One big Write dies on the output cap.
- An implementer that reports "blocked" or "hit the context line": never
  resume it with SendMessage (that reloads its whole context); write a
  narrower spec for a fresh call.
- A prepared run saves each spec as `.claude/specs/<k>.md` and the run
  window sends only its path (`.claude/rules/workflow.md` "One prompt").
- A plan phase that stops after designing saves each finished spec as
  `.claude/plans/<name>.spec-<phase>-<k>.md` in the format below (plan
  skill).
- Over about 150 lines or three files (`.claude/` and `.md` files not
  counted): the `reviewer` gets the spec(s) and the diff before you
  commit. `.claude/hooks/review-guard.py` counts the diff at `git
  commit` and `try.py --commit` and refuses the command until a
  reviewer has run in this window.

## Spec format

Complete enough that the implementer never chooses a name, a location or
a design. The implementer sees only the spec and
`.claude/project/implementer.md`, never `CLAUDE.md`. Under about 120
lines, written once with one Write and never read back (the writer's
window pays for every character twice over); longer means two specs.
Every spec has:

1. **Target files:** the exact path of every file to create, edit or
   delete, and the function names to grep so it reads only that region.
2. **Symbols:** exact names and full signatures (typed, where the
   language has types) to add or change.
3. **Logic steps:** an ordered, numbered list.
4. **Edge cases:** each one and exactly how to handle it.
5. **Do not touch:** files, symbols and behaviour that stay unchanged,
   including foreign edits already in a target file (shared mode).
6. **Rules:** the project invariants and `.claude/rules/` values this
   change must respect, copied in (the implementer never sees
   `CLAUDE.md` or the rules); the project playbook says which.
7. **Verification:** the exact commands, or "none", plus a `git grep`
   proving deleted names are gone when the spec deletes something. Never
   a command that blocks (a dev server, an editor window); the project
   playbook names the checks that run and exit.

## Commands every project has

- **Try and Commit:** `tools/try.py`, commands in your mode file. Try
  belongs to the owner: print it, never run it. Commit: worktree mode
  runs it itself once verified; cloud and shared print it.
- **Autoplan:** `py -3 tools/autoplan.py [<name>] [--dry-run]
  [--max-sessions N] [--budget USD] [--effort high] [--line 160000]
  [--kill 185000] [--force]`. Started by the app session in the
  background (`run_in_background`) with `--max-sessions 1`, one phase
  per launch, and relaunched by it after each phase (plan skill
  `run.md`); a terminal is only a fallback. Runs a plan's
  phases unattended, one headless session each, in
  `.claude/worktrees/plan-<name>`, on the subscription only (no API key;
  stops at the usage limit), and stops when questions wait, on a
  blocker, or at plan-done. Logs and the run lock in `.claude/autoplan/`.
- **Cleanup:** `py -3 tools/cleanup.py` deletes landed, idle session
  branches and their worktrees (it also runs at session start).
- **Sync:** `py -3 <master>/sync.py status|push|pull <project root>`
  (`.claude/rules/workflow.md` "Shared files").
