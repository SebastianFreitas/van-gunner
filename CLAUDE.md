# van-gunner

A first-person roguelite played entirely inside a moving van (Godot 4.7, GDScript). The player walks the van's interior and shoots raiders who chase it down a street and try to breach it through the rear doors, the side cargo doors or the side windows. The van drives itself; the player picks which street to take at each fork.

The run is a phase machine on `GameSession.RunPhase`; every system reacts to `phase_changed`. IDLE (pick a class, yell GO) → TRAVELLING → COMBAT waves → REST (a 3-choice boon) → ROUTE_CHOICE at a fork → TURNING → a side stop (PARKING → STOP) → TRAVELLING again. An act is a deck of six street cards (3 BLESSING, 3 DANGER) revealed at a statue; each fork shows the top cards and taking one commits its combat modifier. After six streets, two face-down cards bind to the act boss; beat it and a new deck is drawn. Player HP or van hull at 0 is GAME_OVER.

The van rig rides a `PathFollow3D` and the world is spawned ahead and culled behind, so enemies are van-local and chase speed is closing speed. Per-area design notes and pitfalls live in `.claude/rules/`; `docs/PROJECT_MAP.md` is the generated inventory. `.claude/` also holds `modes/`, `hooks/`, `agents/` and `skills/`.

## Session mode

The SessionStart hook prints `MODE: <mode>` and the matching `.claude/modes/<mode>.md`, which overrides this file on branches, pushing and the report's commands.

- `worktree` (the default for real work): `.claude/worktrees/<name>`, its own `claude/<name>` branch, never pushed.
- `cloud`: a fresh Ubuntu clone on its `claude/<name>` branch, pushed, with a PR.
- `shared`: the main checkout, where the owner and other sessions work too; quick fixes committed straight to `main`.

No `MODE:` line in context means the hook didn't run: `CLAUDE_CODE_REMOTE=true` is cloud, a `git rev-parse --git-common-dir` outside this checkout is worktree, anything else is shared. Read `.claude/modes/<mode>.md` and say in the report that the hook didn't run.

## One prompt, one finished result

The owner sends one prompt and comes back to a finished, verified change plus two commands: **Try** (play it) and **Commit** (land it as one commit on local `main`; the owner pushes with GitHub Desktop). Never stop at "ready to commit": a reply that only says "go" costs a whole extra turn.

1. **Explore** through the `Explore` subagent. Ask the owner only when the answer changes what you build, always with the `AskUserQuestion` tool (never a plain-text question), then keep working in the same turn once they answer. A turn ends early only when something went really wrong, never just to ask.
2. **Read the rules** for every area you will touch (see Domain rules).
3. **Spec:** one per implementer call (see Spec format). A step with more than about three deliverables becomes several specs.
4. **Implement** with the `implementer` subagent.
5. **Verify:** the commands in Verify; look at the screenshots yourself for anything visible.
6. **Review:** over about 150 lines or more than three files, the `reviewer` subagent checks the diff against the spec and reports only gaps that break the spec, an invariant or a check; fix them with a follow-up spec.
7. **Commit** by path, as your mode says.
8. **Report:** end the turn with exactly this and nothing after it:
   1. **Name:** the feature in plain words, then the branch (and the PR in cloud).
   2. **How it looks:** for a visible change, one or two PNGs from `tools/smoke.py --shots`, sent with SendUserFile and never committed; otherwise one line saying why there is none.
   3. **Try:** one `bash` block, one command, from your mode file, plus one line saying what to do in the game to see the change as exact steps a new player can follow (name the class and where to pick it, which fork, or the exact debug console command; `H` opens the console); never "any class" or "any fork".
   4. **Commit:** one `bash` block, one command, from your mode file (shared mode: the one line it gives).
   5. **Look at:** at most three bullets, plus anything left open.

If the owner replies with changes, do another round on the same branch and end with the same report.

## Active task

When the user points you at a file in `docs/tasks/`, that file is the task. Re-read it after every compaction (the SessionStart hook reminds you), work its steps in order, and tick its checklist as each step's commit lands. The task's last commit deletes the file.

## Active plan

A many-phase plan lives in `.claude/plans/<name>.md` (from `TEMPLATE.md`), run by the owner-invoked `/plan` skill (`.claude/skills/plan/SKILL.md`). When the SessionStart hook prints `PLAN: <name> · <stage>`, read the skill and the plan before anything else: a bare "go" continues it (planning rounds while `planning`, the next `todo` phase while `running`). Planning asks every question up front; running asks phase questions only at a phase's start. Never use the built-in plan mode (Shift+Tab) for this.

## Main session role

The main session explores through `Explore`, designs the change, writes the spec, reviews the diff the implementer returns, and writes the follow-up spec if anything needs fixing.

- Don't Write or Edit source files: `.gd`, `.tscn`, `.tres`, `.gdshader`, `.py`, `.cfg`, `project.godot`. Don't use Bash to modify them either: no `sed -i`, no redirects, no heredocs, no scripts that write files. `.claude/hooks/file-guard.py` refuses multi-line source edits from the main session.
- Exceptions: a single-line change where writing the spec would take longer than the edit, and Markdown, `.claude/settings.json` and `.gitignore`. Cost and convenience are not exceptions.
- If this session runs on Fable, implement directly instead of delegating (the guard reads the model from the transcript and lets it through). Every other rule in this file still applies.
- Explore prompts are narrow: name the file, function or concept, say to grep `docs/PROJECT_MAP.md` first, and ask for `file:line` anchors and a summary, not code bodies. Read directly only the range of the file you are about to write a spec against: every file read here is paid again on every later turn.

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
14. Nothing the facade system places may enter a stop-bay mouth, the reverse-park approach or the raider lane: every placement passes `FacadeKeepOut.allows`, bodies are gated by construction, and the smoke test asserts it (`facade stress 1` before the first fork, `bay mouth clear:` after the garage docks).
15. Two art styles, one dark look: low-poly 3D skinned with procedural grime shaders in the road's recipe (the road and the van are the references), and flat pixel-art sprites (NPCs, enemies, items, icons); it is always night and light comes only from sources you can point at. Read `.claude/rules/art-style.md` before any change someone can see, and copy its values into the spec.

## Where things are

| Concept | Folder or file |
|---|---|
| Run state, phases, act deck, saves, vitals | `scripts/core/game_session.gd` + `session_save.gd`, `session_act_deck.gd`, `session_vitals.gd` |
| Balance numbers | `resources/balance/game_balance.tres` via `scripts/core/game_balance.gd` |
| Saves, meta progression, sandbox | `scripts/core/save_manager.gd`, `meta_progression.gd`, `save_sandbox.gd` |
| Street cards, reveal, REST boon | `scripts/acts/`, `resources/acts/cards/`, `scripts/ui/act_reveal_panel.gd` |
| Raiders, boss, cabin pathing, breach points, waves | `scripts/enemies/` |
| Road, turns, parking, elevator, statues | `scripts/travel/` |
| Street facades, districts, set-pieces | `scripts/travel/facades/`, `resources/facades/`, `scenes/corridor/facade_*.gdshader` |
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
| Debug console (`H`) | `scripts/debug/` (`DebugCommands.run(line)`) |
| Audio | `scripts/audio/`, `resources/audio/sound_bank.tres` |
| Smoke test and screenshots | `tools/smoke/`, `tools/smoke.py` |
| Scene dump | `tools/scene_dump/`, `tools/scene_dump.py` |
| Godot discovery, `.godot/` seeding, tool lock, verify stamps | `tools/godot_env.py` |
| The owner's Try and Commit | `tools/try.py`, `tools/try_commit.py` |
| Claude Code workflow | `.claude/modes/`, `.claude/hooks/`, `.claude/agents/`, `.claude/skills/`, `.claude/settings.json`, `.claude/rules/tooling.md` |
| Cloud session Godot install | `tools/cloud_setup.sh` |

## Code rules

- GDScript: tabs, LF, about 100 columns, two blank lines between top-level functions, typed everything (`var x := 0.0`, `func f(a: int) -> void:`), `&"..."` StringName literals, `##` doc comments on classes and non-obvious fields. Comments explain why. Every script starts with a one-line `##` class summary right after `extends`; `tools/gen_context.py` reads it. `.claude/hooks/gd-lint.py` reports breaks of these in the lines an edit writes.
- `class_name` on reusable scripts, never on autoloads. Cross-system lookups use groups plus `has_method` duck typing.
- Data lives in `.tres`; new behaviour is a small `Resource` subclass (`ItemEffect`, `ActCardEffect`, `BoonBehavior`), not a branch in an existing system.
- Scripts: under 300 lines is the target, 400 the hard cap. A large node script splits into a core that keeps its state, signals, exports, virtuals, `await` chains and every method reached from outside, plus `RefCounted` helpers beside it that take the core and read its fields. Helpers have no `class_name`, no `await`, and pass the owner node (never themselves) to other systems. GDScript counts only same-file uses, so the core wraps private fields that only its helpers touch in `@warning_ignore_start("unused_private_class_variable")` … `@warning_ignore_restore(...)`, and a signal only helpers emit gets `@warning_ignore("unused_signal")`. A field nobody reads gets deleted, not silenced.
- Over 400 on purpose: `scripts/travel/travel_controller.gd` (its state header, the API other scripts call and the `_sequence_id` await chains belong together) and `scripts/enemies/window_raider.gd` (its await-driven assault state machine plus the methods `BikerBoss` inherits).

## Domain rules

Area notes live in `.claude/rules/*.md`, each scoped by `paths:` globs. Claude Code loads one only when this session itself reads a matching file, and you delegate the reading, so read the matching rules file yourself before designing in an area, and copy the pitfalls that apply into the spec: the implementer never sees rules or this file. The tools and hooks are `.claude/rules/tooling.md`.

## Delegation

- Every code change goes to `implementer`, one task per call, one file per call unless the change genuinely spans files. It runs with `omitClaudeMd`: it sees only the spec and its agent file, which already carries the GDScript conventions, the scene-text rules and the verification commands. The spec adds the invariants and area pitfalls that apply.
- Parallel implementer calls only on completely separate files. The tools lock each project folder, so their Godot runs wait for each other instead of colliding.
- Parallel tasks on the same file (worktree and cloud mode only): `implementer-wt`, each in its own worktree cut from your `HEAD`, so commit first. Merge their branches one at a time with `git merge --no-ff`, resolve, regenerate the map, re-run the check and the smoke test.
- A new file over about 250 lines: the spec writes a skeleton first and adds function groups with Edits. One big Write dies on the output cap.
- An implementer that reports "blocked" or "hit the context line": never resume it with SendMessage (that reloads its whole context); write a narrower spec for a fresh call.

## Spec format

Complete enough that the implementer never chooses a name, a location or a design. Every delegation contains:

1. **Target files:** the exact path of every file to create, edit or delete, and the function names to grep for.
2. **Symbols:** exact names and full typed signatures for everything added or changed.
3. **Logic steps:** the implementation as an ordered, numbered list.
4. **Edge cases:** each one and exactly how to handle it.
5. **Do not touch:** files, symbols and behaviour that must stay unchanged, including foreign edits already in a target file (shared mode).
6. **Rules:** the invariants and `.claude/rules/` pitfalls this change must respect.
7. **Verification:** the commands from Verify, plus a `git grep` proving deleted symbols are gone when the spec deletes something.

## Verify

In worktree and cloud mode the Stop hook refuses to end a turn whose Godot changes are newer than the last clean run of what they need.

- Any `.gd`, `.tscn`, `.tres`, `.gdshader` or `project.godot` change: `py -3 tools/check.py` (import scan, a load of every script and resource, and a debugger pass that fails on any GDScript warning; about 15 s warm).
- Anything under `scripts/`, `scenes/`, `resources/` or `tools/smoke/`, or `project.godot`: also `py -3 tools/smoke.py` (about 40 s).
- The van's scenes (`scenes/van/`, `scenes/ui/run_hud.tscn`): also `py -3 tools/scene_dump.py`.
- Anything visible (models, materials, shaders, facades, lighting, HUD): `py -3 tools/smoke.py --shots <scratchpad>/shots`, then Read the PNGs yourself before reporting. At IDLE, in combat, at the elevator stop and at the rear-park stop it saves three views: what the player sees, the player turned to the rear doors, and a camera above the cab looking back over the van at the street, raiders or stop (UI hidden in the last two). On Windows it runs Godot on a separate hidden Win32 desktop (`tools/hidden_desktop.py`), so no window ever appears on, takes focus from, or alt-tabs the owner out of what they are doing (they play fullscreen games while sessions verify); Windows desktop only. Never launch a windowed Godot any other way.
- `--bless` only when a change is meant to alter the fingerprint or the van tree; say so in the report.
- Neither the smoke nor the shots drive panel UI that `speed` mode skips (act reveal, boon pick): review those by reading, and tell the owner in Try where to look.
- A failure is any output line containing `SCRIPT ERROR`, `Parse Error`, `ERROR:` or a GDScript warning; Godot's exit code alone is not reliable. Right after moving files, the first check can print stale `uid_cache` errors; run it again.

## Context budget

Quality drops as a context grows, long before the window is full. `.claude/hooks/context-watch.py` measures every context after every tool call and prints `CONTEXT WATCH` at 80% of its line and past it. Lines: main 140k, Explore and Plan 100k, reviewer 80k, implementer 60k; a subagent at 1.5 times its line has every further tool call denied.

- Main session past its line: finish only the current atomic step (an implementer already running may finish; start nothing new), verify, commit, then follow your mode file's "Context full" rule. The `handoff` skill has the handoff format and "Auto-continue": after the handoff, keep working; auto-compaction (set a little past the line, `CLAUDE_CODE_AUTO_COMPACT_WINDOW` in `.claude/settings.json`) summarizes the conversation mid-turn and the hook prints the handoff back in, so the owner types nothing. Never clear the session to continue: in the desktop app a clear stops its process. Use the skill too whenever a turn must end with work half done.
- `SUBAGENT CONTEXT ... over the line` means the spec or Explore prompt was too wide: next time name the file, function and line range, or split the task.
- A handoff printed at session start: restate the plan in two lines, continue from Next, never redo Done, delete the file once absorbed.

## Token budget

- Never read a whole file over 300 lines: `file-guard.py` refuses it and names the line count. Grep `-n` for the function name, then Read with `offset` and a `limit` of at most 300. Function names don't drift; line numbers do. `docs/PROJECT_MAP.md` lists every script's line count.
- `docs/PROJECT_MAP.md` is generated: grep it for inventories (scripts with summaries and line counts, signals, groups, trait keys, resources, balance values, debug commands). Never read it whole and never re-survey the repo.
- The van scene is four files: `scenes/van/van.tscn` (16 KB: rig, props, systems, the HUD's button connections), `van_shell.tscn` (46 KB: walls, floor, ceiling, doors, windows), `van_breach_points.tscn` and `scenes/ui/run_hud.tscn`. Grep for the node name and read about 40 lines around the hit.
- Never open `*.png`, `*.wav`, `*.ogg`, `*.import`, `.godot/` or `__pycache__/` in the repo (the guard refuses them); screenshots in your scratchpad are fine.
- Keep command output out of context: pipe it through `tail -n 30` (PowerShell: `Select-Object -Last 30`), or grep it for errors.

## Keeping the docs honest

After a structural change, re-run `py -3 tools/gen_context.py` (it reads committed balance values and skips `.claude/`, so the map is the same in every checkout). A new always-on invariant goes in the list above; a design note, deliberate choice or pitfall that only matters in one area goes in the matching `.claude/rules/` file (check its `paths:` still cover the scripts). Delete a table row when you delete its system.

## Commands

The tools find Godot themselves (`GODOT`, then the Windows user variable, then `godot` on PATH) and switch to the `_console` build, since the plain exe writes nothing to a pipe. Local tools run with `py -3`; the cloud container has only `python3`.

- **Headless check:** `py -3 tools/check.py`.
- **Smoke test:** `py -3 tools/smoke.py [--bless | --shots DIR]`. Plays a run like a player headless with `-- --smoke-sandbox` (saves and the meta profile never touch `user://`): NEW, IDLE, class panel, GO, `summon enemy`, firing, bench, a REST pick, two forks in `speed` mode with an elevator stop and a rear-park stop, a save round-trip. Fails on any error line, a non-zero exit, the 300 s timeout, or any difference between `tools/smoke/fingerprint.txt` and `fingerprint.baseline.txt`. The `[waves]` section pins `segment_wave_min` and `segment_wave_max` to 2 and 4 while it plans, so the owner's balance edits never move the fingerprint and a clean clone reproduces the baseline.
- **Scene dump:** `py -3 tools/scene_dump.py [--bless]`. Instantiates `van.tscn` headless and fails on any difference from `tools/scene_dump/van.baseline.txt`. Run it for any change to the van's scenes that should not alter the built tree.
- **Lint the tree:** `py -3 .claude/hooks/gd-lint.py --scan [paths]`.
- **PROJECT_MAP:** `py -3 tools/gen_context.py`.
- **Boons and pools:** `py -3 tools/generate_boons.py`; icons: `py -3 tools/generate_boon_icons.py`. Boon `.tres` files, pools and icons are generated: change the generator and re-run it (the file guard refuses hand edits).
- **Try and Commit** (`tools/try.py`) belong to the owner: print them in the report, never run them.
- Never launch the editor or a windowed game yourself, and never run anything that waits for input. The one exception is `tools/smoke.py --shots`, which runs on a hidden desktop the owner never sees and quits itself.

## Git

- Stage files by path. Never `git add -A` or `git add .`. `.claude/hooks/git-guard.py` refuses blanket git (`add -A`/`.`, `commit -a`, `stash`, `checkout --`, `restore`, `reset --hard`, `clean`, `rebase`, force push), any push except a cloud session's own branch, merges into `main`, branch deletion, worktree removal, `checkout`/`switch` in the main checkout, and staging a path that was already uncommitted when the session started. Don't work around it; if the owner wants one of those, they run it themselves.
- Where commits go depends on the mode file. One commit per task step; every task ends with a commit, unasked.
- Commit messages are one sentence saying what changed and why, like the existing history.

## Commands shown to the owner

They run in Windows PowerShell 5.1 from the app's Run button: fenced blocks tagged `bash`, one command per block, forward-slash absolute paths (`C:/Users/Traff/...`), never `&&`, `||`, `$(...)` or bash `if`. The Bash tool is fine for your own use.

## No scratch files in the repo

Logs, dumps, screenshots and notes go in the session's scratchpad, never the repo.
