## Shared mode

This is the main checkout. Other sessions edit this tree at the same
time: another local chat may be mid-task with uncommitted edits, and
worktree or cloud branches land on `main` through the owner's `tools/try.py
--commit`. The owner will not say so every time. Prefer a worktree session
for any task longer than a quick fix; this mode is for small changes.

- The SessionStart hook lists every path that was already uncommitted
  when you started: those are foreign, and git-guard refuses to stage
  them. Never stage, revert, stash or "clean up" them.
- Stage by path, only the files your specs named, and read `git status`
  before every commit: anything else modified is someone else's.
- A change that needs a file with foreign edits: don't start it. Staging
  that file would sweep the foreign hunks into your commit, and git-guard
  refuses to stage it anyway. Tell the owner to commit or discard their
  edit first, or to run the task in a worktree session. If a foreign edit
  breaks a check, report it; do not fix it.
- Commit straight to `main`, no branches (git-guard refuses `git
  checkout` and `git switch` here). This mode runs the project's
  landing steps itself before such a commit (the project's notes below
  name them); worktree and cloud never do.
- **Never push, never pull, never merge anything into `main`.** Commit
  straight to `main` by path; the commit stays local until the owner
  pushes it with GitHub Desktop (the owner can Undo commit there before
  pushing). Until then new app sessions start from `origin/main` without
  it, so the report says to push it. If `git status -sb` shows `main` behind `origin`, say so in
  Look at; the owner pulls in GitHub Desktop.
- `implementer-wt` is not used in this mode (its merges would land in a
  tree with foreign edits); run parallel same-file work in a worktree
  session instead.
- `.claude/MAP.md` rows for a file another session is building belong to
  that session.

### Report commands

- **Try:** the project's notes below give the command.
- **Commit:** no command: say "Already committed as <sha> on `main`;
  review it in GitHub Desktop and push there (new sessions start from
  `origin/main`, so they miss it until it is pushed)."

### Merging by hand

Only when the owner asks you to merge branches. Merge the open branches
into `main` one at a time with `--no-ff`, oldest first. `.claude/MAP.md`
rows: keep both sides' rows, then re-count the changed files. The
project's notes below say how its own conflicts resolve. After the last
merge run the landing steps once and the project's full check (`CLAUDE.md`
§ Verify), commit, and end with the report (the owner pushes). Never
delete branches by hand; `tools/cleanup.py` removes merged ones once
idle 24 h.

### Context full

The rule is `workflow.md`'s "Context budget" (stop, handoff, owner
clears). List foreign uncommitted paths under the handoff's "Foreign
edits".
