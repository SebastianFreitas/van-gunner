## Shared mode

This is the main checkout, `C:/Users/Traff/Documents/van-gunner`. The owner
works here too: their Godot editor may be open on it,
`resources/balance/game_balance.tres` holds their uncommitted test edit,
`export_presets.cfg` is untracked, and another local session may be
mid-task. Worktree and cloud branches land here through the owner's
`tools/try.py --commit`. Prefer a worktree session for anything longer than
a quick fix; this mode is for small changes.

- The SessionStart hook lists every path that was already uncommitted when
  you started: those are foreign, and git-guard refuses to stage them.
  Never stage, revert, stash or "clean up" them.
- Stage by path, only the files your specs named, and read `git status`
  before every commit: anything else modified is someone else's.
- A change that needs a file with foreign edits: don't start it. Staging
  that file would sweep the foreign hunks into your commit, and git-guard
  refuses to stage it anyway. Tell the owner to commit or discard their
  edit first, or to run the task in a worktree session. If a foreign edit
  breaks the check or the smoke test, report it; don't fix it.
- Commit straight to `main`, no branches (git-guard refuses `git checkout`
  and `git switch` here). **Never push, pull or merge.** The commit stays
  local until the owner pushes it with GitHub Desktop (Undo commit there
  takes it back). If `git status -sb` shows `main` behind `origin`, say so
  in Look at; the owner pulls in GitHub Desktop.
- The tools lock against each other, not against the owner's editor. If a
  check shows a flood of "Could not find type" errors while the editor is
  open, the editor was rewriting its class cache at the same moment: run
  it again once before chasing anything.
- `implementer-wt` is not used in this mode (its merges would land in a
  tree with foreign edits).

### Report commands

- **Try:** `py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py main`
  launches the game from this checkout with the owner's real profile (it
  is their game as it now stands; no try checkout, no import).
- **Commit:** no command: say "Already committed as <sha> on `main`; review
  it in GitHub Desktop and push there."

To land several worktree or cloud branches, the owner runs each branch's
Commit command, oldest first; nobody merges by hand.

### Context full

Finish the atomic step, commit, write `.claude/handoff.md` (format: the
`handoff` skill), then keep going with Next in the same turn.
Auto-compaction (the skill's "Auto-continue") summarizes the conversation
a little past the line, mid-turn, and the SessionStart hook prints the
handoff back in, so the owner types nothing. Never clear this session to
continue: in the desktop app a clear stops its process and nothing
restarts it. A handoff that waits on the owner (a question, a blocker)
ends the turn with the normal report as usual. (A new chat works too; the
hook prints the handoff at every start.)
