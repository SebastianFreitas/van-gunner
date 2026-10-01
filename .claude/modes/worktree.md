## Worktree mode

This session has its own checkout under `.claude/worktrees/<name>` on its
own `claude/<name>` branch, cut from the main checkout's `HEAD`
(`worktree.baseRef: "head"`, so it starts from commits the owner landed
but hasn't pushed). It shares only `.git` with the main checkout, so no
other session touches these files and there are no foreign edits.

- **Commit on this branch, by path. Never push, never open a PR, never
  merge into `main`** (merging `main` INTO this branch is fine and is how
  you resolve a conflict the owner reports). The branch stays local;
  `try.py` reads it from here.
- **Landing steps are not yours.** Never run a step the project's notes
  below reserve for landing (a cache-bust, a version bump) and never
  change the line count of an existing `.claude/MAP.md` row. Add rows for
  new files and update descriptions only. Those two are where merge
  conflicts between parallel branches came from; `--commit` runs the
  landing steps once on merge.
- Commit everything before the report: `--commit` merges commits only,
  and the Stop hook refuses to end a turn with uncommitted files.
- Baselines (the project's snapshots, fingerprints, dumps): re-record
  one only when the change is meant to alter it, and say so in the
  report. Two branches that both re-record conflict at Commit; then
  `git merge main` here, re-run the tool and re-record again.
- Anything gitignored (snapshots, build output) is not shared with the
  main checkout: produce your own "before" here before any code changes.
- Commands use `py -3`, exactly as in `CLAUDE.md`.

### Report commands

Replace `<branch>` with `git branch --show-current` and `<main
checkout>` with the path in the `MODE:` line.

- **Try:** `py -3 <main checkout>/tools/try.py <branch>` plus the
  project's Try flags (its notes below) checks the branch out into a
  sibling `-try` worktree and launches it; typing `commit` at its prompt
  does the Commit step.
- **Commit:** `py -3 <main checkout>/tools/try.py <branch> --commit`
  builds one squash commit on top of local `main` without touching the
  main checkout's files, runs the project's landing steps and checks on
  the combined tree in the `-try` checkout, then fast-forwards `main`,
  merges `main` back into this branch and pushes nothing; the owner
  reviews in GitHub Desktop and pushes there. On a conflict, a failed
  check, or the owner's uncommitted edits in a file the branch changes,
  it lands nothing and says why; then run `git merge main` here,
  resolve, verify, commit, and run it again.
  **You run it yourself** (owner's call, 2026-09-26) once the work is
  verified and committed, then keep going; the report names the commit
  now on `main` instead of handing over the command. Make the branch
  tip's message describe the work first: the squash takes its message.

After a Commit, the command already merged `main` back into this branch, so
a follow-up round just commits on the same branch and ends with the same
report. If Commit said it could not merge `main` back, start the next
round with `git merge main` here. Archiving the session in the app
removes the worktree.

### Context full

The rule is `workflow.md`'s "Context budget" (stop, handoff, owner
clears). Commit on the branch first; `.claude/handoff.md` stays in this
worktree (gitignored). After `/clear` it is the same worktree and branch:
never open a new one for the same work; the go prompt names both and the
fresh window checks them (`workflow.md` "The go prompt"). If the owner
opens a new chat instead, that gets a fresh worktree from `main` with no
handoff: it runs `git merge <branch named in the go prompt>` first, so
put the Next list in the report's "Look at" too.
