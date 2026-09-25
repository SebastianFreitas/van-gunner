---
paths:
  - "tools/*.py"
  - "tools/smoke/**"
  - "tools/scene_dump/**"
  - ".claude/hooks/**"
  - ".claude/settings.json"
---

# Tools, hooks and the Try / Commit workflow

## Who runs what

- `tools/check.py`, `smoke.py`, `scene_dump.py` run headless Godot. They share `tools/godot_env.py`: `find_godot()` (the `GODOT` env var, then on Windows the user-level `GODOT` from the registry, then `godot` on PATH, then `~/.local/bin/godot`; the `_console` sibling is preferred because the plain Windows build writes nothing to a pipe), `seed_import_cache()`, `project_lock()` and `stamp_clean()`.
- `tools/try.py` and `tools/try_commit.py` are the owner's Try and Commit. Sessions print them in the report and never run them: they operate on the main checkout and the owner's GitHub Desktop state.
- `tools/shot_stats.py <shots_dir>` is pure Python (PIL): mean and p95 linear luminance, clipped share and saturation per `--shots` PNG, checked against the targets table in `.claude/rules/art-style.md`.
- `tools/gen_context.py` is pure Python and writes `docs/PROJECT_MAP.md`; it skips `.claude/` and reads the balance file from `HEAD`, so the map is the same in every checkout.

## Design choices

- **Seeding `.godot/`.** A linked worktree starts with no import cache. `seed_import_cache` copies the main checkout's (about 16 MB) before the first Godot run, so the first check takes seconds. Godot decides reimports by source hash, not mtime, so the copy is safe. It never copies `export_credentials.cfg` (secrets), `tools.lock` or `claude-verify.json`.
- **One Godot per folder.** Parallel Godot runs on one project folder collide on `.godot/`. `project_lock` holds an OS file lock on `.godot/tools.lock` (msvcrt on Windows, flock on Linux); the OS releases it if the holder dies, so there are no stale locks, and a second tool waits up to 15 minutes. It doesn't lock against the owner's editor. Never test a PID with `os.kill(pid, 0)`: on Windows that terminates the process.
- **Warnings pass.** Godot prints GDScript warnings only to an attached debugger, so `check.py` runs the load a second time with `-d` and stdin at EOF (which ends any debugger break) and fails on any `WARNING:` whose next line is `at: GDScript::reload (res://...)`. The tree is kept at 0.
- **Verify stamps.** A clean check, smoke or scene dump writes the time it STARTED (after the lock, right before Godot runs) to `.godot/claude-verify.json`, so a file edited during the run still counts as newer. The Stop hook (worktree and cloud mode) compares it with the mtimes of the Godot files the branch changed, so a turn can't end on unverified code.
- **Try isolates saves.** `user://` is shared by every checkout of the project (`%APPDATA%/Godot/app_userdata/<name>`), so `try.py` writes an `override.cfg` in the try checkout that points `user://` at a separate `van-gunner-try` profile; `--real-saves` skips it. `override.cfg` is gitignored.
- **Commit never touches the main checkout's files until the end.** It builds the squash with `git merge-tree --write-tree` + `git commit-tree`, verifies it in `../van-gunner-try` (never in the main checkout: the owner's editor may be open there, and an editor rewriting its class cache while another Godot starts floods "Could not find type" errors), then `git merge --ff-only`. The owner's uncommitted edits survive; git refuses only if the branch changes one of those files.
- **Screenshots need a window.** Headless Godot renders nothing. `smoke.py --shots <dir>` runs the smoke windowed at `--position -10000,-10000` with an `override.cfg` that sets `display/window/size/no_focus=true`, so the off-screen window renders (checked on this machine, Forward+ on d3d12) without taking the owner's keyboard focus. The game never sets `MOUSE_MODE_CAPTURED` while `SaveSandbox.enabled` (`fps_player._ready`, its click re-capture, `van._capture_mouse_after_ui_click`): capturing in the off-screen window clipped and hid the owner's real cursor and pulled them into it. Any new capture site needs the same guard. A minimized window stops drawing, so never minimize it. Cloud containers have no display. `tools/smoke/smoke_shots.gd` does the capturing: after a one-second settle (the rear doors take 0.9 s to open at a stop) it saves the player's view, the player turned 180° (the player only turns on mouse input, so the turn holds until undone), and a temporary Camera3D on `VanRig` 9 m up and 8 m ahead of the cab looking back (van-local -Z is the cab), hiding every CanvasLayer for the last two because the act reveal panel and the HUD cover the view. The van is an enclosed box: without the outside camera no shot shows the street.

## Hooks

`.claude/settings.json` runs every hook through `.claude/hooks/run.sh` (the `py` launcher on Windows, where `python3` is often the Store stub). Hooks never fail on their own errors (any exception exits 0).

- `session-start.py`: the mode and its `.claude/modes/<mode>.md`, a `NO GODOT` line, the dirty paths, the handoff; in shared mode it writes the dirty paths to `<session dir>/foreign-paths.json`.
- `git-guard.py`: blanket git, pushes, merges into main, branch deletion, worktree removal, checkout or switch in the main checkout, and staging a foreign path.
- `file-guard.py`: whole reads over 300 lines, binaries and caches, edits of generated files, main-session multi-line source edits (skipped when the transcript's model is Fable), renumbered header ids.
- `gd-lint.py`: lints the lines an edit wrote, plus whole-file checks; `py -3 .claude/hooks/gd-lint.py --scan` lints the tree.
- `context-watch.py`: context lines per agent type; subagents past 1.5 times their line get every tool call denied.
- `stop-guard.py`: uncommitted files, unpushed cloud commits, unverified Godot changes (a deleted file counts from its folder's mtime).
- `git-guard.py` matches its rules against the command with quoted text masked, so commit messages and search strings ("raiders push the van", `git grep "checkout"`) never trip them; a cloud push is refused only when it targets `main` or `master`.

Context-full sessions continue by auto-compaction (`CLAUDE_CODE_AUTO_COMPACT_WINDOW` = 180000 in `settings.json`, a little past the 140k handoff line), and `session-start.py` prints the handoff again with source `compact`. Never `clear_session("self")`: in the desktop app a clear stops the session's process, and any `CronCreate` job dies with it.

The first tool call after a compaction runs before its assistant line reaches the transcript, so the last `usage` in the file is the old, pre-compaction context: `context-watch.py` stops at a `compact_boundary` line and reports nothing. SubagentStop also fires for the compaction agent, which has no transcript of its own; a subagent is only ever measured from its own transcript.

Hook input carries `agent_id` and `agent_type` inside subagents; `cwd` follows the session into a worktree while `${CLAUDE_PROJECT_DIR}` stays where the session started.

## Pitfalls

- Bash heredocs on this machine write CRLF and mangle `\\n`: write Python with the Write tool. Python that writes repo files passes `newline="\n"`.
- `git merge-tree --write-tree` needs git 2.38 or later (this machine has 2.47).
- The smoke's save round-trip drops `saved_at` (wall clock) before comparing; anything else time-based in the fingerprint would flake the same way.
