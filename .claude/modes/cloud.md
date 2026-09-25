## Cloud mode

A fresh Ubuntu x86_64 clone of GitHub, one container and one
`claude/<name>` branch per session, so parallel sessions never share files.
Nothing you push reaches `main` until the owner lands it with Commit.

- **Branch:** work, commit and push only on the branch this session was
  given (the GitHub proxy refuses pushes to any other). Never push to
  `main` and never merge into it.
- **In the same turn:** build, verify, commit, push, open a PR with `gh pr
  create` (title = the feature in plain words; body = what changed, what
  was verified, and `https://claude.ai/code/${CLAUDE_CODE_REMOTE_SESSION_ID/#cse_/session_}`),
  then the report. If `gh` is missing or refused, skip the PR and say so in
  "Look at"; the Commit command does not need it.
- **Godot:** the container has none until the environment's Setup script
  runs `bash tools/cloud_setup.sh`, which installs the checksum-pinned 4.7
  build as `godot` on PATH. A SessionStart `NO GODOT` line or a tool's "No
  Godot found": say so and stop; don't install anything by hand. If the
  setup script's download is refused, the network allowlist needs
  `release-assets.githubusercontent.com` (or Full access).
- **Commands:** there is no `py -3` here; run every tool with `python3`
  (`python3 tools/check.py`). The first check imports every asset into
  `.godot/`, so it takes a few minutes. `tools/smoke.py --shots` needs a
  display: skip it and say so; the owner sees the change with Try.
- **The clone is the committed tree:** the owner's balance test edit and
  `export_presets.cfg` aren't here. Avoid changing
  `resources/balance/game_balance.tres`: Commit refuses a branch that
  touches it while the owner's test edit is uncommitted (say so in Look at
  if the task needs it). The smoke fingerprint pins the wave
  bounds it reads, so the baseline still matches; if the smoke test fails
  on the fresh clone before you changed anything, report that instead of
  blessing.
- `docs/PROJECT_MAP.md` and the baselines: as in worktree mode (Commit
  regenerates the map; bless only on purpose and say so).
- No scratch files in the repo: logs and dumps go in the session's
  scratchpad.

### Report commands

- **Try:** `py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py <branch>`
  fetches the branch from origin into the try checkout
  (`C:/Users/Traff/Documents/van-gunner-try`), imports and launches the
  game with the separate `van-gunner-try` profile; typing `commit` at its
  prompt does the Commit step.
- **Commit:** `py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py <branch> --commit`
  fetches the branch, squashes it onto local `main`, verifies the combined
  tree in the try checkout, fast-forwards `main` and pushes nothing. On a
  conflict or a failed check it lands nothing and says why.

After the owner pushes `main`, they close the PR by hand (GitHub shows it
closed, not merged). Never use GitHub's merge button: it skips the
verification and the map regeneration.

### Context full

Finish the atomic step, commit, push, and put the handoff (the `handoff`
skill's headings) in the PR body under `## Handoff`. Also write it to
`.claude/handoff.md`, then keep going with Next in the same turn.
Auto-compaction (the skill's "Auto-continue") summarizes the conversation
a little past the line, mid-turn, and the SessionStart hook prints the
handoff back in, so the owner types nothing. Never clear this session to
continue. A handoff that waits on the owner (a question, a blocker) ends
the turn with the normal report as usual. It is the same session in this
container, on this branch and PR. If the session ends anyway, the owner
starts a new cloud session and says: "continue PR #<n>". That session runs
`gh pr view <n>` and stays on the same branch: it runs `git fetch origin
<old>`, then `git checkout <old>`, continues from Next and pushes to
`<old>`, so the PR is the same one. Only if that push is refused does it
merge `origin/<old>` into its own branch and open a PR that replaces the
old one (close the old PR with a link).
