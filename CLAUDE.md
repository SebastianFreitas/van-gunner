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
3. **Spec:** one per implementer call (format in `.claude/playbook.md`). A step with more than about three deliverables becomes several specs.
4. **Implement** with the `implementer` subagent.
5. **Verify:** the commands in Verify; look at the screenshots yourself for anything visible.
6. **Review:** over about 150 lines or more than three files, the `reviewer` subagent checks the diff against the spec and reports only gaps that break the spec, an invariant or a check; fix them with a follow-up spec.
7. **Commit** by path, as your mode says, with a message that describes the work (a squash takes the branch tip's message). In worktree mode run the mode's `try.py --commit` yourself once verified.
8. **Report:** end the turn with exactly this and nothing after it:
   1. **Name:** the feature in plain words, then the branch (and the PR in cloud).
   2. **How it looks:** for a visible change, one or two PNGs from `tools/smoke.py --shots`, sent with SendUserFile and never committed; otherwise one line saying why there is none.
   3. **Try:** one `bash` block, one command, from your mode file, plus one line saying what to do in the game to see the change as exact steps a new player can follow (name the class and where to pick it, which fork, or the exact debug console command; `H` opens the console); never "any class" or "any fork".
   4. **Commit:** which commit already landed on local `main` (worktree), or one `bash` block, one command, from your mode file (cloud; shared mode: the one line it gives).
   5. **Look at:** at most three bullets, plus anything left open.

If the owner replies with changes, do another round on the same branch and end with the same report.

## Active task

When the user points you at a file in `docs/tasks/`, that file is the task. Re-read it after every compaction (the SessionStart hook reminds you), work its steps in order, and tick its checklist as each step's commit lands. The task's last commit deletes the file.

Two pieces of work never share one context. A task step, like a plan phase, is one context: verify it, commit it, tick it, and stop with the report; the owner clears and prompts for the next step. Never continue into the next step because there is context left.

## Active plan

Big work runs as a plan: `.claude/plans/<name>.md` (from `TEMPLATE.md`), started with `/plan new <name>: <brief>` and driven by the owner-invoked `/plan` skill (`.claude/skills/plan/SKILL.md`). Never use the built-in plan mode (Shift+Tab) for this.

- **Several at once, one per checkout.** Every plan whose `Stage:` is planning, ready or running is active. The gitignored `.claude/plans/HERE` binds this checkout's plan (with no HERE, the only active plan). The SessionStart hook prints `PLAN: <name> · <stage>` for the bound plan and lists the others (never touch their files); `PLANS: ...` means none is bound here: `go <name>` binds and continues it.
- **Planning happens in the app:** an interview through `AskUserQuestion` until every choice execution will face is settled by a D. A bare "go" continues it.
- **Running is strictly one phase per fresh context** (owner's rule, 2026-09-26). A phase verifies, commits, writes its state file `.claude/plans/<name>.state.md` (first line `Status: phase-done|partial|blocked|plan-done`: architecture now, the phase done, the exact start of the next one), commits that, then hard-stops with the skill's exact "Phase complete" message. The next phase starts only from the owner's "Read .claude/plans/<name>.state.md and execute the next phase." (or "go") after `/clear`. Never chain phases, however small the next one is.
- **Phase questions** are asked only at a phase's start; anything seen, heard or felt, a balance number, a change outside Scope or a deletion is never decided alone (the skill's stop line).
- **Blocked:** a phase that needs the owner writes the questions into the state file with `Status: blocked` and stops. A "go" in the app on that checkout asks them, records the D's, unblocks and prints the command to continue; it never runs the phase itself.
- **Unattended:** `py -3 tools/autoplan.py <name>` (workflow-port phase 5) runs the phases from a terminal, one headless session each, in `.claude/worktrees/plan-<name>`. Inside such a session `AUTOPLAN=1` is set: read `.claude/skills/plan/unattended.md`, not the whole skill.

The same split applies outside plans: a prompt with two separable pieces of work gets the first finished, committed and reported, and the second named under "Look at".

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
| Van look (seeded war-rig dressing, machine looks, cables) | `scripts/van/look/` (`van_look.gd` owns the seed; `machine_parts.gd`, `machine_motion.gd`, `machine_damage.gd`; cables `van_cable_runs.gd` + `van_cable_router.gd`) |
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
| Claude Code workflow | `.claude/playbook.md` (specs, delegation, tool commands), `.claude/modes/`, `.claude/hooks/`, `.claude/agents/`, `.claude/skills/`, `.claude/settings.json`, `.claude/rules/tooling.md` |
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

Every code change goes to `implementer`, one task per call, one file per call unless the change genuinely spans files. It runs with `omitClaudeMd`: it sees only the spec and its agent file, which already carries the GDScript conventions, the scene-text rules and the verification commands. The spec adds the invariants and area pitfalls that apply. Read `.claude/playbook.md` before the first spec of a turn: parallel calls, `implementer-wt`, big new files, blocked implementers, the Spec format and the tool commands.

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

Quality drops as a context grows, long before the window is full. `.claude/hooks/context-watch.py` measures every context after every tool call and prints `CONTEXT WATCH` at 80% of its line and past it. Lines: main 120k (headless autoplan sessions too; its runner kills at 140k), Explore and Plan 100k, reviewer 80k, implementer 60k; a subagent at 1.5 times its line has every further tool call denied.

- Main session past its line: finish only the current atomic step (an implementer already running may finish; start nothing new), verify, commit, then follow your mode file's "Context full" rule. The `handoff` skill has the handoff format and "Auto-continue": after the handoff, keep working; auto-compaction (at 130k: 65% of the 200k `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` in `.claude/settings.json`) summarizes the conversation mid-turn and the hook prints the handoff back in, so the owner types nothing. Never clear the session yourself to continue mid-step: in the desktop app a clear stops its process. Use the skill too whenever a turn must end with work half done. A running plan never auto-continues across a phase: a phase that hits the line stops as `partial` in its state file, and between plan phases and task steps the turn hard-stops and the owner runs `/clear` (see Active task and Active plan).
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

The tool commands (check, smoke, scene dump, lint, map, generators, and the coming autoplan, probe and shots) are in `.claude/playbook.md`. `tools/try.py`: Try belongs to the owner (print it, never run it); worktree mode runs Commit itself once verified, cloud and shared print it. Never launch the editor or a windowed game yourself, and never run anything that waits for input; the one exception is `tools/smoke.py --shots`, which runs on a hidden desktop and quits itself.

## Git

- Stage files by path. Never `git add -A` or `git add .`. `.claude/hooks/git-guard.py` refuses blanket git (`add -A`/`.`, `commit -a`, `stash`, `checkout --`, `restore`, `reset --hard`, `clean`, `rebase`, force push), any push except a cloud session's own branch, merges into `main`, branch deletion, worktree removal, `checkout`/`switch` in the main checkout, and staging a path that was already uncommitted when the session started. Don't work around it; if the owner wants one of those, they run it themselves.
- Where commits go depends on the mode file. One commit per task step; every task ends with a commit, unasked.
- Commit messages are one sentence saying what changed and why, like the existing history.

## Commands shown to the owner

They run in Windows PowerShell 5.1 from the app's Run button: fenced blocks tagged `bash`, one command per block, forward-slash absolute paths (`C:/Users/Traff/...`), never `&&`, `||`, `$(...)` or bash `if`. The Bash tool is fine for your own use.

## No scratch files in the repo

Logs, dumps, screenshots and notes go in the session's scratchpad, never the repo.
