@AGENTS.md

# Working in this repo with Claude Code

AGENTS.md, imported above, is the game's design intent and code rules. This file is the workflow. Pass 2 rewrites both.

## Active task

When the user points you at a file in `docs/tasks/`, that file is the task. Re-read it after every compaction, work its steps in order, and tick its checklist as each step's commit lands.

## Main session role

The main session directs exploration, designs the change, writes the spec, reviews the diff the implementer returns, and writes the follow-up spec if anything needs fixing.

- Don't Write or Edit source files: `.gd`, `.tscn`, `.tres`, `.gdshader`, `.py`, `.cfg`, `project.godot`. Don't use Bash to modify them either: no `sed -i`, no redirects, no heredocs, no scripts that write files.
- Exceptions: a single-line change where writing the spec would take longer than the edit, and Markdown files (this file, AGENTS.md, `docs/`). Cost and convenience are not exceptions.
- If the user says this session runs on Fable, implement directly instead of delegating. Every other rule in this file still applies.

## Exploration

- Send searches and file reading to the `Explore` subagent and work from its summary. The project defines its own `Explore` in `.claude/agents/explore.md` so it runs on Haiku; the built-in one would run on the session's model.
- Explore prompts are narrow: name the file, function or concept, and ask for `file:line` anchors and a summary, not code bodies.
- Read directly only the file you are about to write a spec against, and only the range you need. A file read in the main session stays in its context for every later turn.
- Don't re-survey the repo. `docs/PROJECT_MAP.md` is generated: grep it for inventories (scripts with line counts, signals, groups, trait keys, resources, balance values). Never read it whole.

## Token budget

- Never read a whole script over 300 lines. Over 500 today: `scripts/run/travel_controller.gd` (1311), `scripts/run/van.gd` (1155), `scripts/run/van_side_wall.gd` (1110), `scripts/run/shop_counter_booth.gd` (1012), `scripts/core/game_session.gd` (910), `scripts/debug/debug_commands.gd` (754), `scripts/ui/bench_screen.gd` (719), `scripts/run/window_raider.gd` (680), `scripts/run/road_floor.gd` (608), `scripts/ui/act_reveal_panel.gd` (580), `scripts/run/side_doors.gd` (557). Grep `-n` for the function name, then Read with offset and limit. Function names don't drift; line numbers do.
- `scenes/van/van.tscn` is 87 KB: grep for the node name and read about 40 lines around the hit.
- Never open `*.png`, `*.wav`, `*.ogg`, `*.import`, `.godot/` or `__pycache__/`.

## Delegation

- Delegate every code change to the `implementer` subagent, one task per call, one file per call unless the change genuinely spans files.
- The implementer runs with `omitClaudeMd`, so it never sees this file or AGENTS.md. Put every rule it needs into the spec, including the Godot rules below when they apply.
- Run implementer calls in parallel only when they touch completely separate files.

## Spec format

Every delegation contains:

1. **Target files:** the exact path of every file to create, edit or delete, and the function names to grep for.
2. **Symbols:** exact names and full typed signatures for everything added or changed.
3. **Logic steps:** the implementation as an ordered, numbered list.
4. **Edge cases:** each one and exactly how to handle it.
5. **Do not touch:** files, symbols and behaviour that must stay unchanged.
6. **Verification:** the headless check below, plus a `git grep` proving deleted symbols are gone when the spec deletes something.

## Godot rules to restate in specs

- GDScript conventions from AGENTS §5.
- Editing `.tscn` or `.tres` as text: never change or renumber existing `id=`, `unique_id=` or `uid://` values; new ids must not collide with ids already in the file; removing a node also removes its children, every `[connection]` line that names it, and any ext_resource nothing else references.
- Moving or deleting a `.gd` moves or deletes its `.gd.uid`. A new script gets its `.gd.uid` from the next headless check; commit it with the script. Assets move or go together with their `.import` files.
- Duck-typed calls count as uses. Before deleting a method, grep for its name as `has_method(&"x")`, `call("x")` and `method="x"` in `.tscn` connections, as well as direct calls.
- Never launch the editor or the game with a window, and never run anything that waits for input.

## Commands

- **Headless check:** `py -3 tools/check.py` from the repo root. It runs `"$GODOT" --headless --path . --import` (the editor scan: imports new assets and writes missing `.gd.uid` files) and then `"$GODOT" --headless --path . --script res://tools/check_scripts.gd`, which loads every `.gd`, `.tscn`, `.tres` and `.gdshader` so parse errors and broken references surface. `--editor --quit` on its own never compiles scripts and misses parse errors; don't use it as the check. `GODOT` is an environment variable holding the full path to `Godot_v4.7-stable_win64_console.exe`; the runner switches to the `_console` build when `GODOT` points at the plain exe, which writes nothing to a pipe. Any output line containing `SCRIPT ERROR`, `Parse Error` or `ERROR:` is a failure; the runner prints those lines and exits 1, and the exit code of Godot alone is not reliable. Baseline on the untouched tree (2026-09-24): clean, 340 files loaded.
- **Smoke test:** `py -3 tools/smoke.py` from the repo root. Runs `res://tools/smoke/smoke_test.tscn` headless with `-- --smoke-sandbox` (the `SaveSandbox` switch: saves and the meta profile never touch `user://`), drives a run like a player (NEW, IDLE, class panel, GO, `summon enemy`, firing, bench, a REST pick) and fails on any `SCRIPT ERROR`, `Parse Error` or `ERROR:` line, a non-zero exit, the 180 s timeout, or any difference between `tools/smoke/fingerprint.txt` and the committed `fingerprint.baseline.txt`. `--bless` rewrites the baseline; only do that when a change is meant to alter the fingerprint. The `[waves]` section reads `game_balance.tres`, so an owner edit to wave counts shows up as a diff there and needs a re-bless.
- **PROJECT_MAP:** `py -3 tools/gen_context.py`
- **Boons and pools:** `py -3 tools/generate_boons.py`; icons: `py -3 tools/generate_boon_icons.py`. Boon `.tres` files and boon pools are generated: change the generator and re-run it, never hand-edit its output.

## Git

- Commit straight to `main` unless the user says otherwise. One commit per task step; every task ends with a commit, unasked.
- Stage files by path. Never `git add -A` or `git add .`: `resources/balance/game_balance.tres` holds an uncommitted test edit and `export_presets.cfg` is untracked, and both stay out of commits.
- Commit messages are one sentence saying what changed and why, like the existing history.

## Commands shown to the user

They run in Windows PowerShell 5.1. Never print `&&`, `||`, `$(...)` or bash `if` for them; chain with `;` or give one command per block. The Bash tool is fine for your own use.
