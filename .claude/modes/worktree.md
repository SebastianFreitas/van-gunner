## Worktree mode

This session has its own checkout under `.claude/worktrees/<name>` on its
own `claude/<name>` branch, cut from the main checkout's `HEAD`
(`worktree.baseRef: "head"`, so it starts from commits the owner landed but
hasn't pushed). It shares only `.git` with the main checkout, so no other
session touches these files. The first tool run copies the main checkout's
`.godot/` import cache in, so the first check takes seconds, not minutes.

- **Commit on this branch, by path. Never push, never open a PR, never
  merge into `main`.** Merging `main` INTO this branch is fine; it is how
  you resolve a conflict the owner reports. The branch stays local;
  `tools/try.py` reads it from here.
- **Commit everything before the report:** Commit lands commits only. The
  Stop hook refuses to end a turn with uncommitted files, or with Godot
  files newer than the last clean check, smoke test or scene dump.
- **Never run Godot or a tool in the main checkout.** The owner's editor may
  be open there (Claude Code also refuses commands whose working directory
  is the main checkout).
- `docs/PROJECT_MAP.md`: regenerate and commit it as usual. Commit
  regenerates it on the combined tree, so a conflict limited to it resolves
  itself.
- Baselines (`tools/smoke/fingerprint.baseline.txt`,
  `tools/scene_dump/van.baseline.txt`): bless only when the change is meant
  to alter them, and say so in the report. Two branches that both bless
  conflict at Commit; the owner then asks you to `git merge main` here,
  re-run the tool and bless again.
- The owner's uncommitted balance test edit is not in this checkout:
  `resources/balance/game_balance.tres` holds the committed values. Avoid
  changing that file; Commit refuses a branch that touches it while the
  owner's test edit is uncommitted. If the task needs it, say in Look at
  that the owner must commit or discard their test edit before Commit.
- Commands use `py -3`, exactly as in CLAUDE.md.

### Report commands

Replace `<branch>` with `git branch --show-current`.

- **Try:** `py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py <branch>`
  checks the branch out (detached) into `C:/Users/Traff/Documents/van-gunner-try`,
  runs an import scan and launches the game; errors print in the terminal
  and are counted when the window closes. Saves and the schematic go to a
  separate `van-gunner-try` profile, never the owner's real one. Typing
  `commit` at its prompt does the Commit step. Add `--editor` to open the
  Godot editor on the branch instead, or `--scene res://<path>.tscn` to
  play one scene.
- **Commit:** `py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py <branch> --commit`
  squashes the branch into one commit on top of local `main` without
  touching the main checkout's files, regenerates `docs/PROJECT_MAP.md` and
  runs the headless check on the combined tree in the try checkout (the
  smoke test too when `main` moved since the branch was cut), then
  fast-forwards local `main` to it, merges `main` back into this branch and
  pushes nothing; the owner reviews in GitHub Desktop and pushes there. On a
  conflict or a failed check it lands nothing and says why; then the owner
  asks you to `git merge main` here, resolve, verify, commit and re-report.

After a Commit, `main` is normally merged back into this branch already
(Commit says so, and takes `main`'s copy when `docs/PROJECT_MAP.md` is the
only conflict), so a follow-up round just commits on the same branch and
ends with the same report. If Commit said it could not merge `main` back,
start the next round with `git merge main` here. Archiving the session in the app removes the worktree.

### Context full

Finish the atomic step, commit on the branch, write `.claude/handoff.md`
(format: the `handoff` skill) in this worktree (gitignored, it stays here),
then keep going with Next in the same turn. Auto-compaction (the skill's
"Auto-continue") summarizes the conversation a little past the line,
mid-turn, and the SessionStart hook prints the handoff back in, so the
owner types nothing. Never clear this session to continue: in the desktop
app a clear stops its process and nothing restarts it. A handoff that
waits on the owner (a question, a blocker) ends the turn with the normal
report as usual. It is the same session in the same worktree on the same
branch: never open a new worktree or branch for it. If the owner starts a
new session instead, it gets a fresh worktree from `main`: it runs `git
merge <branch>` first and has no handoff, so put the Next list in the
report's "Look at" too.
