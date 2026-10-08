---
paths:
  - "tools/*.py"
  - "tools/check.py"
  - "tools/check_scripts.gd"
  - "tools/smoke.py"
  - "tools/smoke_jobs.py"
  - "tools/scene_dump.py"
  - "tools/godot_env.py"
  - "tools/try*.py"
  - "tools/probe.py"
  - "tools/perf.py"
  - "tools/gen_context.py"
  - "tools/smoke/**"
  - "tools/scene_dump/**"
  - "tools/probe/**"
  - "tools/perf/**"
---

# Tools, hooks and the Try / Commit workflow

Screenshots, shot comparison, the van audit and the arms tools are `tooling-shots.md`; hooks, autoplan and plan files are `tooling-hooks.md`.

## Who runs what

- `tools/check.py`, `smoke.py`, `scene_dump.py` run headless Godot. They share `tools/godot_env.py`: `find_godot()` (the `GODOT` env var, then on Windows the user-level `GODOT` from the registry, then `godot` on PATH, then `~/.local/bin/godot`; the `_console` sibling is preferred because the plain Windows build writes nothing to a pipe), `seed_import_cache()`, `project_lock()` and `stamp_clean()`.
- `tools/try.py` and `tools/try_commit.py` (shared with the owner's other projects) are the owner's Try and Commit; `tools/try_project.py` holds van-gunner's hooks (flags `--editor`, `--scene`, `--real-saves`, `--smoke`; Godot launch with the error count; `.godot/` seeding; the map regenerated and check, plus smoke when main moved or with `--smoke`, on the combined tree). Try is always the owner's: sessions print it and never run it. Commit (`try.py <branch> --commit`) is run by a worktree session itself once its work is verified and committed (workflow-port D24), including autoplan's headless sessions (D27); cloud and shared sessions print it. It only ever moves local `main` and never pushes.
- `tools/probe.py` (+ `tools/probe/probe_runner.tscn/.gd`) runs one scene or the run at IDLE headless for a quick question (`--eval`, `--cmd`) or a few frames of pictures (`--shot`). `tools/shots.py` captures whole `--shots` sets and compares two of them. `tools/autoplan.py` runs a plan's phases unattended. Usage lines are in `.claude/playbook.md`; the choices behind them are below.
- `tools/perf.py` (+ `tools/perf/perf_test.tscn`, `perf_runner.gd`) is the benchmark: a real-renderer run on the hidden desktop that reads `PerfStats` (frame times, spans, hitches) and prints `PERF` lines. It never stamps a verify: it measures, it does not check. To time a new piece of work, wrap it in `var perf_t := PerfStats.begin()` / `PerfStats.end(&"label", perf_t)`; both are free while `PerfStats.enabled` is false. In the game, F3 cycles the overlay (off, FPS, full) and the console has `perf log` and `perf spans`. Reading it: FPS and hitch counts swing with whatever else uses the GPU (14 fps and 104 fps for the same code in one afternoon with a game running beside it), while span counts and span milliseconds stayed within about 10 %. Compare counts and span milliseconds between runs; compare FPS and hitches only between runs taken with nothing else on the GPU; to compare old code with new, measure both in the same sitting.
- `tools/gen_context.py` is pure Python and writes `docs/PROJECT_MAP.md`, which is gitignored (parallel branches kept conflicting on it) and rebuilt by `godot-session.py` at every session start and by Commit; it skips `.claude/` and reads the balance file from `HEAD`, so the map is the same in every checkout.

## Design choices

- **Seeding `.godot/`.** A linked worktree starts with no import cache. `seed_import_cache` copies the main checkout's (about 16 MB) before the first Godot run, so the first check takes seconds. Godot decides reimports by source hash, not mtime, so the copy is safe. It never copies `export_credentials.cfg` (secrets), `tools.lock`, `claude-verify.json` or tool output (`shots/`, 166 MB of PNGs on this machine, `van_audit/`, `try-last.log`). The test is `has_import_cache` (`.godot/imported/` holds something), never "`.godot/` exists": a tool makes `.godot/` for its lock or its `--shots` folder before it seeds, which is how the first `shots.py capture` in a fresh worktree skipped the seed, ran the game cold and timed out (2026-10-01). The game runtime never imports, so a longer timeout would not have helped; when no seed is possible (the main checkout has no cache, or this is the main checkout) `smoke.py` runs the import scan (`check.run_pass`) first and fails on its error lines.
- **One Godot per folder.** Parallel Godot runs on one project folder collide on `.godot/`. `project_lock` holds an OS file lock on `.godot/tools.lock` (msvcrt on Windows, flock on Linux); the OS releases it if the holder dies, so there are no stale locks, and a second tool waits up to 15 minutes. It doesn't lock against the owner's editor. Never test a PID with `os.kill(pid, 0)`: on Windows that terminates the process.
- **Except inside smoke.py.** Headless runs that only read an already-imported project run side by side cleanly (measured 2026-10-03: the game run and the van audit together, no errors, no slowdown). `smoke.py` takes `project_lock` once, does any import scan first, then runs its jobs (`tools/smoke_jobs.py`: game run, five `facade_stress.tscn` shards, seven audit passes) up to `--jobs N` at a time (default cores, max 6; `--serial` is 1). 4 cores: 259 s serial before, about 80 s now.
- **Warnings pass.** Godot prints GDScript warnings only to an attached debugger, so `check.py` runs the load a second time with `-d` and stdin at EOF (which ends any debugger break) and fails on any `WARNING:` whose next line is `at: GDScript::reload (res://...)`. The tree is kept at 0.
- **Verify stamps.** A clean check, smoke or scene dump writes the time it STARTED (after the lock, right before Godot runs) to `.godot/claude-verify.json`, so a file edited during the run still counts as newer. `verify-guard.py` (a Stop hook, worktree and cloud mode) compares it with the mtimes of the Godot files the branch changed, so a turn can't end on unverified code.
- **Try isolates saves.** `user://` is shared by every checkout of the project (`%APPDATA%/Godot/app_userdata/<name>`), so `try.py` writes an `override.cfg` in the try checkout that points `user://` at a separate `van-gunner-try` profile; `--real-saves` skips it. `override.cfg` is gitignored.
- **Commit never touches the main checkout's files until the end.** It builds the squash with `git merge-tree --write-tree` + `git commit-tree`, verifies it in `../van-gunner-try` (never in the main checkout: the owner's editor may be open there, and an editor rewriting its class cache while another Godot starts floods "Could not find type" errors), then `git merge --ff-only`. The owner's uncommitted edits survive; git refuses only if the branch changes one of those files.
- **Probe runs a runner scene, not the target.** `probe.py` launches `tools/probe/probe_runner.tscn`, which spawns a worker under the root, because `SceneRouter.go_to_van()` frees the current scene and would take the probe with it. With no scene argument it boots the run to the van at IDLE, since most console lines need the run. `--smoke-sandbox` is always passed, so a probe never touches real saves. `--timeout` defaults to 180 s and the game's own watchdog fires 20 s earlier, so a hang still prints its error lines. `--shot` goes through the hidden desktop like the smoke; a sequence names itself `<stem>-NN.png`. It takes the project lock but writes no verify stamp: a probe is a question, never a stand-in for check or smoke (D29).

## Pitfalls

- Bash heredocs on this machine write CRLF and mangle `\\n`: write Python with the Write tool. Python that writes repo files passes `newline="\n"`.
- `git merge-tree --write-tree` needs git 2.38 or later (this machine has 2.47).
- The smoke's save round-trip drops `saved_at` (wall clock) before comparing; anything else time-based in the fingerprint would flake the same way.
