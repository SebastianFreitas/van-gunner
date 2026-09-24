# van-gunner

A first-person roguelite played entirely inside a moving van (Godot 4.7, GDScript). The player walks the van's interior and shoots raiders who chase it down a street and try to breach it through the rear doors, the side cargo doors or the side windows. The van drives itself; the player picks which street to take at each fork.

The run is a phase machine on `GameSession.RunPhase`; every system reacts to `phase_changed`. IDLE (pick a class, yell GO) → TRAVELLING → COMBAT waves → REST (a 3-choice boon) → ROUTE_CHOICE at a fork → TURNING → a side stop (PARKING → STOP) → TRAVELLING again. An act is a deck of six street cards (3 BLESSING, 3 DANGER) revealed at a statue; each fork shows the top cards and taking one commits its combat modifier. After six streets, two face-down cards bind to the act boss; beat it and a new deck is drawn. Player HP or van hull at 0 is GAME_OVER.

The van rig rides a `PathFollow3D` and the world is spawned ahead and culled behind, so enemies are van-local and chase speed is closing speed. Per-area design notes and pitfalls live in `.claude/rules/`, loaded when you touch matching files. `docs/PROJECT_MAP.md` is the generated inventory.

## Active task

When the user points you at a file in `docs/tasks/`, that file is the task. Re-read it after every compaction, work its steps in order, and tick its checklist as each step's commit lands.

## Main session role

The main session directs exploration, designs the change, writes the spec, reviews the diff the implementer returns, and writes the follow-up spec if anything needs fixing.

- Don't Write or Edit source files: `.gd`, `.tscn`, `.tres`, `.gdshader`, `.py`, `.cfg`, `project.godot`. Don't use Bash to modify them either: no `sed -i`, no redirects, no heredocs, no scripts that write files.
- Exceptions: a single-line change where writing the spec would take longer than the edit, and Markdown files (this file, `.claude/rules/`, `docs/`). Cost and convenience are not exceptions.
- If the user says this session runs on Fable, implement directly instead of delegating. Every other rule in this file still applies.

## Always-on invariants

1. One damage number, no damage types: `BASE_DAMAGE_PER_SHOT * damage_mult`, scaled once by the `gun_damage_per_shot` trait in `GunStatsController`; blasts and poison are unscaled shares of the hit.
2. Shotgun pellets split damage; they don't multiply it.
3. Explosive, Poison and Cold Rounds are bullet boons with one `BoonBehavior` handler each, not damage types.
4. "Reload Speed %" lowers duration: `seconds / (1 + pct/100)`.
5. One gun per class, locked at the class board in IDLE. Projectile-only: no hitscan gun.
6. Gold buys at shops and the mechanic; Rare Parts buy schematic nodes only (boss drops, 3 per run).
7. Van speed changes only through allocated schematic nodes; never buy it with gold.
8. Run save version lives only on `SaveManager.SAVE_VERSION`; rejected saves warn with both versions and never become a new run.
9. `is_elite` is explicit; agile does not imply elite.
10. Player HP and van hull (the sum of the interior vitals) are both fail conditions.
11. Autoloads never get a `class_name`; helpers split off an autoload never name or preload it.
12. `GameBalance.get_act` vs `GameSession.run_act` is an open design question the owner holds: don't unify them. Wave counts in `game_balance.tres` are owner test values.
13. `SaveSandbox` is the only test hook in game code.

## Where things are

| Concept | Folder or file |
|---|---|
| Run state, phases, act deck, saves, vitals | `scripts/core/game_session.gd` + `session_save.gd`, `session_act_deck.gd`, `session_vitals.gd` |
| Balance numbers | `resources/balance/game_balance.tres` via `scripts/core/game_balance.gd` |
| Saves, meta progression, sandbox | `scripts/core/save_manager.gd`, `meta_progression.gd`, `save_sandbox.gd` |
| Street cards, reveal, REST boon | `scripts/acts/`, `resources/acts/cards/`, `scripts/ui/act_reveal_panel.gd` |
| Raiders, boss, cabin pathing, breach points, waves | `scripts/enemies/` |
| Road, turns, parking, elevator, statues | `scripts/travel/` |
| Side stops: shop, garage, mechanic, warehouse | `scripts/stops/`, `resources/side_stops/`, `scenes/corridor/` |
| Van shell, doors, windows, vitals, van root and HUD wiring | `scripts/van/` |
| Gun, projectiles, damage, status effects | `scripts/combat/` |
| Classes | `scripts/classes/`, `resources/classes/` |
| Player, boons, tools | `scripts/player/`, `scripts/items/`, `resources/items/` |
| HUD panels, bench, schematic, menus | `scripts/ui/` |
| Interactables, NPC talk | `scripts/interactions/`, `scripts/dialogue/npc_talk.gd`, `scripts/ui/dialogue_hud.gd` |
| Loot hopper, death popups | `scripts/core/loot_collector.gd`, `scripts/interactions/loot_machine.gd` |
| Weld kit (look-at repair) | `scripts/items/effects/repair_window_bars_effect.gd` |
| Yell at the driver (Shift GO / C EASY) | `travel_controller.gd` boost/slow, `scripts/van/van_driver_talk.gd`, `scripts/ui/driver_shout_hud.gd` |
| Pause menu | `scripts/ui/pause_menu.gd` |
| Debug console | `scripts/debug/` |
| Audio | `scripts/audio/`, `resources/audio/sound_bank.tres` |
| Smoke test | `tools/smoke/`, `tools/smoke.py` |

## Code rules

- GDScript: tabs, LF, about 100 columns, two blank lines between top-level functions, typed everything (`var x := 0.0`, `func f(a: int) -> void:`), `&"..."` StringName literals, `##` doc comments on classes and non-obvious fields. Comments explain why. Every script starts with a one-line `##` class summary right after `extends`; `tools/gen_context.py` reads it.
- `class_name` on reusable scripts, never on autoloads. Cross-system lookups use groups plus `has_method` duck typing.
- Data lives in `.tres`; new behaviour is a small `Resource` subclass (`ItemEffect`, `ActCardEffect`, `BoonBehavior`), not a branch in an existing system.
- Scripts: under 300 lines is the target, 400 the hard cap. A large node script splits into a core that keeps its state, signals, exports, virtuals, `await` chains and every method reached from outside, plus `RefCounted` helpers beside it that take the core and read its fields. Helpers have no `class_name`, no `await`, and pass the owner node (never themselves) to other systems.
- Over 400 on purpose: `scripts/travel/travel_controller.gd` (its state header, the API other scripts call and the `_sequence_id` await chains belong together) and `scripts/enemies/window_raider.gd` (its await-driven assault state machine plus the methods `BikerBoss` inherits).

## Keeping the docs honest

After a structural change, re-run `py -3 tools/gen_context.py`. A new always-on invariant goes in the list above; a design note, deliberate choice or pitfall that only matters in one area goes in the matching `.claude/rules/` file (check its `paths:` still cover the scripts). Delete a table row when you delete its system.

## Exploration

- Send searches and file reading to the `Explore` subagent and work from its summary. The project defines its own `Explore` in `.claude/agents/explore.md` so it runs on Haiku.
- Explore prompts are narrow: name the file, function or concept, and ask for `file:line` anchors and a summary, not code bodies.
- Read directly only the file you are about to write a spec against, and only the range you need.
- Don't re-survey the repo. Grep `docs/PROJECT_MAP.md` for inventories (scripts with summaries and line counts, signals, groups, trait keys, resources, balance values). Never read it whole.

## Token budget

- Never read a whole script over 300 lines. Over 300 today:
  - `scripts/travel/`: `travel_controller.gd` (603), `road_floor.gd` (364)
  - `scripts/enemies/`: `window_raider.gd` (522), `breach_point.gd` (364), `cabin_nav.gd` (332), `encounter_director.gd` (318), `biker_boss.gd` (309)
  - `scripts/van/`: `van_side_wall_shell.gd` (400), `van_hull_mesh.gd` (399), `rear_doors.gd` (399), `van.gd` (390), `van_side_wall_panel.gd` (388), `van_ceiling.gd` (379), `van_side_wall.gd` (377), `iron_cross.gd` (354), `van_floor.gd` (339), `side_windows.gd` (333)
  - `scripts/core/`: `game_session.gd` (361), `meta_progression.gd` (344)
  - `scripts/stops/`: `shop_booth_flyers.gd` (368), `stop_elevator.gd` (354), `mechanic_workshop.gd` (307)
  - `scripts/combat/`: `gun_controller.gd` (321), `projectile.gd` (319), `explosion_fx.gd` (303)
  - `scripts/ui/`: `skill_tree_hud.gd` (337), `act_reveal_panel.gd` (305), `act_reveal_cards.gd` (302)
  - `scripts/audio/audio_director.gd` (367), `tools/smoke/smoke_driver.gd` (338)
  Grep `-n` for the function name, then Read with offset and limit. Function names don't drift; line numbers do.
- `scenes/van/van.tscn` is 87 KB: grep for the node name and read about 40 lines around the hit.
- Never open `*.png`, `*.wav`, `*.ogg`, `*.import`, `.godot/` or `__pycache__/`.

## Delegation

- Delegate every code change to the `implementer` subagent, one task per call, one file per call unless the change genuinely spans files.
- The implementer runs with `omitClaudeMd` and never sees this file or `.claude/rules/`. Put every rule it needs into the spec, including the Godot rules below and any invariant or pitfall from the matching rules file.
- Run implementer calls in parallel only when they touch completely separate files, and never let two of them run Godot at once: parallel headless runs on one project collide. Parallel edits then need one check and smoke run at the end.

## Spec format

Every delegation contains:

1. **Target files:** the exact path of every file to create, edit or delete, and the function names to grep for.
2. **Symbols:** exact names and full typed signatures for everything added or changed.
3. **Logic steps:** the implementation as an ordered, numbered list.
4. **Edge cases:** each one and exactly how to handle it.
5. **Do not touch:** files, symbols and behaviour that must stay unchanged.
6. **Verification:** the headless check and the smoke test below, plus a `git grep` proving deleted symbols are gone when the spec deletes something.

## Godot rules to restate in specs

- The GDScript conventions under Code rules.
- Editing `.tscn` or `.tres` as text: never change or renumber existing `id=`, `unique_id=` or `uid://` values; new ids must not collide with ids already in the file; removing a node also removes its children, every `[connection]` line that names it, and any ext_resource nothing else references.
- Moving or deleting a `.gd` moves or deletes its `.gd.uid`. A new script gets its `.gd.uid` from the next headless check; commit it with the script. Assets move or go together with their `.import` files.
- Duck-typed calls count as uses. Before deleting or moving a method, grep for its name as `has_method(&"x")`, `call("x")`, `call_deferred(&"x")` and `method="x"` in `.tscn` connections, as well as direct calls and subclasses (`extends <Class>`).
- A helper that reads its owner through an untyped variable breaks `:=` inference; give those locals explicit types.
- Never launch the editor or the game with a window, and never run anything that waits for input.

## Commands

- **Headless check:** `py -3 tools/check.py` from the repo root. It runs `"$GODOT" --headless --path . --import` (imports new assets, writes missing `.gd.uid` files) and then `--script res://tools/check_scripts.gd`, which loads every `.gd`, `.tscn`, `.tres` and `.gdshader` so parse errors and broken references surface. `GODOT` holds the full path to the Godot 4.7 exe; the runner switches to the `_console` build next to it, since the plain exe writes nothing to a pipe. Any line containing `SCRIPT ERROR`, `Parse Error` or `ERROR:` is a failure; Godot's exit code alone is not reliable. Right after moving files, the first run can print stale `uid_cache` errors; run it again.
- **Smoke test:** `py -3 tools/smoke.py`. Runs `res://tools/smoke/smoke_test.tscn` headless with `-- --smoke-sandbox` (saves and the meta profile never touch `user://`), plays a run like a player (NEW, IDLE, class panel, GO, `summon enemy`, firing, bench, a REST pick, two forks in `speed` mode with an elevator stop and a rear-park stop, a save round-trip) and fails on any error line, a non-zero exit, the 300 s timeout, or any difference between `tools/smoke/fingerprint.txt` and `fingerprint.baseline.txt`. `--bless` rewrites the baseline; only when a change is meant to alter the fingerprint. The `[waves]` section reads `game_balance.tres`, so an owner edit to wave counts needs a re-bless. Neither command exercises panel UI that `speed` skips (reveal, boon pick), so review UI changes by reading.
- **PROJECT_MAP:** `py -3 tools/gen_context.py`
- **Boons and pools:** `py -3 tools/generate_boons.py`; icons: `py -3 tools/generate_boon_icons.py`. Boon `.tres` files and boon pools are generated: change the generator and re-run it, never hand-edit its output.

## Git

- Commit straight to `main` unless the user says otherwise. One commit per task step; every task ends with a commit, unasked.
- Stage files by path. Never `git add -A` or `git add .`: `resources/balance/game_balance.tres` holds an uncommitted test edit and `export_presets.cfg` is untracked, and both stay out of commits.
- Commit messages are one sentence saying what changed and why, like the existing history.

## Commands shown to the user

They run in Windows PowerShell 5.1. Never print `&&`, `||`, `$(...)` or bash `if` for them; chain with `;` or give one command per block. The Bash tool is fine for your own use.
