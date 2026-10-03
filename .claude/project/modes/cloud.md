### Van Gunner notes (cloud)

- The container is Ubuntu x86_64.
- **Godot:** the container has none until the environment's Setup script
  runs `bash tools/cloud_setup.sh`, which installs the checksum-pinned 4.7
  build as `godot` on PATH. A SessionStart `NO GODOT` line or a tool's
  "No Godot found": say so and stop; don't install anything by hand. If
  the setup script's download is refused, the network allowlist needs
  `release-assets.githubusercontent.com` (or Full access).
- **Commands:** run every tool with `python3` (`python3 tools/check.py`).
  The first check imports every asset into `.godot/`, so it takes a few
  minutes. `tools/smoke.py --shots` needs a display: skip it and say so.
- The owner's balance test edit and `export_presets.cfg` aren't here.
  Avoid changing `resources/balance/game_balance.tres`: Commit refuses a
  branch that touches it while the owner's test edit is uncommitted (say
  so in Look at if the task needs it). The smoke fingerprint pins the
  wave bounds it reads, so the baseline still matches; if the smoke test
  fails on the fresh clone before you changed anything, report that
  instead of blessing.
- The shared rule about `.claude/MAP.md` row line counts does not apply
  here: the map is fully generated.
- No landing step to skip: `docs/PROJECT_MAP.md` is regenerated and
  committed as usual; Commit regenerates it on the combined tree.
  Baselines: `tools/smoke/fingerprint.baseline.txt` and
  `tools/scene_dump/van.baseline.txt` (`--bless` only on purpose, say so).
- No scratch files in the repo: logs and dumps go in the session's
  scratchpad.
- **Try:** `py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py <branch>`
  fetches the branch from origin into the try checkout
  (`C:/Users/Traff/Documents/van-gunner-try`), imports and launches the
  game with the separate `van-gunner-try` profile. Add `--editor` to open
  the Godot editor on the branch instead, or `--scene res://<path>.tscn`
  to play one scene.
- **Commit:** `py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py <branch> --commit`
  regenerates `docs/PROJECT_MAP.md` and runs the headless check on the
  combined tree in the try checkout (the smoke test too when `main` moved;
  `--smoke` always runs it). On a conflict or a failed check it lands
  nothing and says why.

- `docs/PROJECT_MAP.md` is gitignored and rebuilt at session start; where a line above says to commit or resolve it, skip that. Commit lands a branch with its tip as a second parent, so a branch that keeps going after it landed never conflicts with its own landed work.
