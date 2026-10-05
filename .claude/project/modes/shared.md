### Van Gunner notes (shared)

- This is the main checkout, `C:/Users/Traff/Documents/van-gunner`. The
  owner works here too: their Godot editor may be open on it,
  `resources/balance/game_balance.tres` holds their uncommitted test
  edit, and `export_presets.cfg` is untracked.
- Landing steps: no cache-bust or version bump. `docs/PROJECT_MAP.md` is
  gitignored and rebuilt (`py -3 tools/gen_context.py`), never
  hand-edited or committed.
- The tools lock against each other, not against the owner's editor. If
  a check shows a flood of "Could not find type" errors while the editor
  is open, the editor was rewriting its class cache at the same moment:
  run it again once before chasing anything.
- **Try:** `py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py main`
  launches the game from this checkout with the owner's real profile (it
  is their game as it now stands; no try checkout, no import).
- To land several worktree or cloud branches, the owner runs each
  branch's Commit command, oldest first. Merging by hand (only when the
  owner asks): after the last merge regenerate the map and re-run the
  check and the smoke test.
