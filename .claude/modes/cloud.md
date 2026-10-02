## Cloud mode

A fresh Linux clone of GitHub, one container and one `claude/<name>`
branch per session, so parallel sessions never share files. Nothing you
push reaches `main` until the owner lands it with Commit.

- **Branch:** work, commit and push only on the branch this session was
  given (the GitHub proxy refuses pushes to any other). Never push to
  `main` and never merge into it.
- **In the same turn:** build, verify, commit, push, open a PR with `gh pr
  create` (title = the feature in plain words; body = what changed, what
  was verified, and `https://claude.ai/code/${CLAUDE_CODE_REMOTE_SESSION_ID/#cse_/session_}`),
  then the report. If `gh` is missing or refused, skip the PR and say so in
  "Look at"; the Commit command does not need it.
- **Landing steps are not yours.** Never run a step the project's notes
  below reserve for landing (a cache-bust, a version bump) and never
  rewrite an existing `.claude/MAP.md` row beyond what your change
  needs. Add rows for new files and update descriptions only. `try.py --commit` runs the
  landing steps once on merge.
- **Commands:** there is no `py -3` here; run every tool with `python3`.
  Screenshots: send them with SendUserFile when the tool exists. A tool
  that needs a display: skip it and say so; the owner sees the change
  with Try.
- **The clone is the committed tree:** the owner's uncommitted edits
  aren't here. If a check fails on the fresh clone before you changed
  anything, report that instead of re-recording a baseline.
- Baselines: as in worktree mode (re-record only on purpose, say so).

### Report commands

The project's notes below give the literal paths.

- **Try:** `py -3 <main checkout>/tools/try.py <branch>` plus the
  project's Try flags checks the branch out into a sibling `-try` worktree of the owner's
  main checkout and launches it; typing `commit` at its prompt does the
  Commit step.
- **Commit:** `py -3 <main checkout>/tools/try.py <branch> --commit`
  (the same command as Try's prompt): fetches the branch from origin,
  builds one squash commit on local `main` without touching the main
  checkout's files, runs the landing steps and checks on the combined
  tree in the `-try` checkout, fast-forwards `main`, and pushes `main`. On a conflict it lands and
  pushes nothing and says so.

Once `main` is pushed, the owner closes the PR by hand (GitHub shows it
closed, not merged). Never use GitHub's merge button: it skips the
landing steps and the checks.

### Context full

The rule is `workflow.md`'s "Context budget" (stop, handoff, owner
clears). Commit and push first, and put the handoff in the PR body under
`## Handoff` as well as in `.claude/handoff.md`. The go prompt names
the branch and `PR #<n>`.

If the owner starts a new cloud session for the same work and says
"continue PR #<n>", that session runs `gh pr view <n>` and stays on the
same branch: `git fetch origin <old>`, `git checkout <old>`, continue
from the handoff's Next and push to `<old>`, so the PR is the same one.
Only if that push is refused does it merge `origin/<old>` into its own
branch and open a PR that replaces the old one (close the old PR with a
link).
