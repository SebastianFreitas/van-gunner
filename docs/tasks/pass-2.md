# Pass 2: structure refactor

This is the active task. Work the steps in order, tick each box when its commit lands, and delete this file in the final commit.

## Goal

Make every script small and easy to find, and rebuild the Claude Code docs, without changing what the game does. No gameplay, balance, UI or content changes. If something looks like a bug, put it in the final report instead of fixing it.

## Rules for the whole pass

- Behaviour-identical: after every commit the headless check shows nothing beyond its known baseline, and the smoke test passes with a fingerprint identical to the committed baseline.
- Names stay: class names, signals, groups, public methods, node names and node paths. Anything reached by name from another file, a `.tscn` `[connection]`, `has_method(&"x")`, `call("x")` or a StringName literal keeps its name and stays on the same node.
- Scenes keep their node trees. Splitting `van.tscn` or any other scene is out of scope; list candidates in the final report.
- Autoloads keep no `class_name`. A helper split off an autoload must not create a `class_name` cycle; the headless check proves it.
- The only new game code allowed is the test switch in step 1.

## Size target

Scripts: under 300 lines is the target, 400 is the hard cap. A script may stay over 400 only if splitting it would cut one responsibility in half; list each one and the reason in CLAUDE.md. Don't split a cohesive script that is already under 300 just to make it smaller. At 300 lines a script can be read whole in one call, which removes most grep-then-offset reads.

## Steps

- [x] 1. Smoke test and fingerprint, built and passing on the untouched tree before anything else changes.
  - `tools/smoke/` holds a scene and script that Godot runs headless as the main scene: `"$GODOT" --headless --path . res://tools/smoke/smoke_test.tscn`. A Python runner, `py -3 tools/smoke.py`, starts it with a 180 s timeout and fails on any output line containing `SCRIPT ERROR`, `Parse Error` or `ERROR:`, on a non-zero exit, or on the timeout. It prints the warning count.
  - It must never touch the player's files. Add one switch that stops `SaveManager` and `MetaProgression` from writing to `user://`; the smoke test turns it on before anything else runs. Prove it: the modification times of `user://save_slot_*.json` and `user://meta_progression.json` are the same before and after a run.
  - Drive the game the way a player does: start a new run the way the main menu's NEW does, wait in IDLE, equip each class through the class panel's code path, begin the run, spawn raiders with the debug console's `summon enemy`, fire the gun, open and close the bench and the class panel, let a REST offer resolve, then quit with exit code 0.
  - Fingerprint: call `seed(12345)`, then write deterministic values to `tools/smoke/fingerprint.txt`: each class's effective `GunStats`; the same with Double Damage, Chew Tobacco and Brawler's Bulk applied; every item pool's items and weights; the act deck `GameSession` builds for a fixed `run_seed`; `GameBalance.build_segment_wave_plan` for route steps 1 to 6; the rest offer for a fixed owned-boon list. Commit the first run's output as `tools/smoke/fingerprint.baseline.txt`. The runner diffs every later run against it and fails on any difference.
  - If the untouched tree already logs errors, stop and report them before refactoring anything.
  - Add the smoke test command to CLAUDE.md's Commands section.
- [x] 2. Dead files and dead code. Delete `scenes/van/vanSave.tscn`, `VanModel.tscn`, every `tools/bench_preview.*` file and the empty `.cursor/` folder. Before deleting each one, `git grep` its file name and the `uid://` in its header to confirm nothing references it. Then delete functions, constants and variables nothing uses, proven by `git grep` that includes the duck-typed forms above.
- [x] 3. Folders. Split `scripts/run/` (55 scripts plus `effects/`) into folders named for areas of the game, such as the van shell, travel, stops, enemies and acts. Decide the map with Explore and put it in the first commit message. Use `git mv`, and move each `.gd.uid` with its script. Update every `res://` path: `preload()` and `load()` strings, `ext_resource` lines in `.tscn` and `.tres`, autoloads in `project.godot`, and `tools/*.py`. Data folders read with `DirAccess` (`resources/acts/cards/`, `resources/side_stops/`, `resources/meta/tree/`, `resources/classes/`) don't move. One commit per destination folder.
- [x] 4. Split scripts over the cap, largest first. The node script stays the core: its state, signals, exported vars and every method something outside calls. Pure logic and UI building move to `RefCounted` helper scripts beside it; a helper that needs the core's state receives the core and reads its fields when called. Explore maps each file's sections first, and each spec names exactly which functions move where. Specific cases:
  - `debug_commands.gd`: one file per command group, each registering its commands in the existing dispatch table.
  - `game_session.gd` (an autoload): state and signals stay; save serialization, act deck logic and vital bookkeeping move to helpers that take the session as an argument.
- [ ] 5. Docs.
  - Rewrite `CLAUDE.md` under 200 lines. Keep the active-task rule, main-session role, exploration, delegation, spec format, token budget, Godot rules, commands, git and PowerShell rules and the Fable switch. Add a ten-line summary of the game and the run loop, the always-on invariants as one-liners, and a table from concept to folder or file.
  - Move the rest of AGENTS.md into `.claude/rules/`, one file per area with `paths:` frontmatter matching the scripts it is about, each under 100 lines. For example: run loop and acts; combat, damage and bullet boons; van shell, HUD, mouse capture and pause; travel, turns and stops; saves; enemies and breaching; audio. Then remove the `@AGENTS.md` import line from CLAUDE.md and delete AGENTS.md.
  - `tools/gen_context.py`: point its header at CLAUDE.md and `.claude/rules/`, and take each script's summary from its class doc comment (the first `##` block after `extends`). Add a one-line `##` summary to every script that has none. Regenerate PROJECT_MAP.
  - Update `.claude/agents/implementer.md` and `explore.md` for the new folders and the list of scripts still over 300 lines.
- [ ] 6. Final report to the owner: a before and after line-count table for the 15 largest scripts, the folder map, the deleted files, the smoke test command, the scenes worth splitting next and why, and anything that looked like a bug.
