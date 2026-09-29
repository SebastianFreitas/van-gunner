### Van Gunner notes (worktree)

- Main checkout: `C:/Users/Traff/Documents/van-gunner`. **Never run Godot
  or a tool there.** The owner's editor may be open on it (Claude Code
  also refuses commands whose working directory is the main checkout).
- The first tool run copies the main checkout's `.godot/` import cache
  in, so the first check takes seconds, not minutes.
- The shared rule about `.claude/MAP.md` row line counts does not apply
  here: the map is fully generated.
- No landing step to skip: `docs/PROJECT_MAP.md` is regenerated and
  committed as usual (`py -3 tools/gen_context.py`). Commit regenerates
  it on the combined tree, so a conflict limited to it resolves itself.
- The Stop hook (`verify-guard.py`) also refuses to end a turn with
  Godot files newer than the last clean check, smoke test or scene dump.
- Baselines: `tools/smoke/fingerprint.baseline.txt` and
  `tools/scene_dump/van.baseline.txt` (`--bless`).
- The owner's uncommitted balance test edit is not in this checkout:
  `resources/balance/game_balance.tres` holds the committed values. Avoid
  changing that file; Commit refuses a branch that touches it while the
  owner's test edit is uncommitted. If the task needs it, say in Look at
  that the owner must commit or discard their test edit before Commit.
- **Try:** `py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py <branch>`
  checks the branch out (detached) into
  `C:/Users/Traff/Documents/van-gunner-try`, runs an import scan and
  launches the game; errors print in the terminal and are counted when
  the window closes. Saves and the schematic go to a separate
  `van-gunner-try` profile, never the owner's real one. Add `--editor` to
  open the Godot editor on the branch instead, or `--scene
  res://<path>.tscn` to play one scene.
- **Commit:** `py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py <branch> --commit`
  regenerates `docs/PROJECT_MAP.md` and runs the headless check on the
  combined tree in `C:/Users/Traff/Documents/van-gunner-try` (the smoke
  test too when `main` moved since the branch was cut; `--smoke` always
  runs it). When `docs/PROJECT_MAP.md` is the only conflict merging
  `main` back, it takes `main`'s copy.
