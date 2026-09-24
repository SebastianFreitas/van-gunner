# AGENTS.md — van-gunner

Context for anyone (human or LLM) picking up this codebase cold.

**Two documents, on purpose:**

- **This file** is hand-written and holds things a script cannot infer: what the
  game is, why systems are shaped the way they are, and the rules you must not
  break. It goes stale slowly because it describes *intent*, not counts.
- **`docs/PROJECT_MAP.md`** is generated (`python3 tools/gen_context.py`) and holds
  everything that changes constantly: file lists, autoloads, signals, groups,
  balance numbers, resource inventories, debug commands. **Never hand-edit it.**
  If an LLM asks "what boons exist" or "what's the current fire rate", the answer
  is in there, freshly regenerated.

If you find yourself wanting to write a number or a list into this
file, it belongs in the generated one instead.

---

## 1. What the game is

A first-person roguelite played **entirely inside a moving van**. The player walks
around the van's interior on foot and shoots raiders who chase the van down a
street and try to breach it — through the rear doors, the side cargo doors, or the
side windows. The van drives itself; the player never steers. Progress is made by
choosing which street to turn onto at forks.

Nothing about the van moves in world space in the way you'd expect: the van rig is
parented to a `PathFollow3D`, and the world (corridor segments, junctions, side stops)
is spawned ahead and culled behind. Enemies live in `EnemyContainer`, a child of the
van rig, so their positions are **van-local**. This is why chase speed is expressed
as *closing speed* (`mob_world_speed - live_van_speed`) rather than a plain velocity.

## 2. The run loop

`GameSession.RunPhase` is the single source of truth for what the game is doing.
Every system reacts to `phase_changed` rather than driving each other directly.

```
IDLE ──(Shift GO / yell let's go)──> TRAVELLING
TRAVELLING ──(act deck empty)──> ACT_REVEAL ──> ROUTE_CHOICE
ROUTE_CHOICE ──(pick a street card)──> TURNING ──> TRAVELLING
  └── PARKING ──> STOP ──> TRAVELLING  (every street has a side stop)
TRAVELLING ──(EncounterDirector timer)──> COMBAT ──> REST
REST ──(boon pick for the committed street card)──> ROUTE_CHOICE
 ...six cards later...
REST ──> BOSS_PICK ──> TRAVELLING ──> COMBAT (boss) ──> REST ──> ACT_REVEAL (next act)
any ──(van hull or player HP hits 0)──> GAME_OVER
```

### Acts and street cards

An **act** is a deck of 6 street cards: 3 BLESSING, 3 DANGER, drawn at a roadside
statue (`ACT_REVEAL`) and shown shuffled. At each fork the player sees the top
cards face-up (three at a 4-way, two at a T); taking one commits it and leaves
the others in the deck. A committed card:

- applies its `ActCardEffect`s to combat for that street (`ActCardCombat`)
- owes the player a 3-choice boon at the following `REST`
- if DANGER, bumps the next wave plan (`_apply_danger_bump`, ×1.35 + 1)

When the deck empties, the six cards come back **face-down** and the player picks
two (`BOSS_CARD_PICK_COUNT`) to bind to the act boss — both cards' effects stack on
that fight. Beat it and a new deck is drawn.

**Side stops** are separate from street-card effects. Every offered road at a
fork gets a stop (shop, garage, … from `resources/side_stops/`) — blessing
and DANGER alike, including straight. The card is just that street's combat
modifier. Taking a road commits the card *and* visits that stop. While docked
(`STOP`) the rear doors stay open so you can walk the room.

How the van arrives is data on the stop, not a new travel system: a stop is
`arrival(content)`. `Arrival.REAR_PARK` reverse-parks into the shared vestibule;
`Arrival.ELEVATOR` halts on the road and drops a pad to the same vestibule and
roll-up door. Content scenes mount just behind the door (no dock markers). Swap
`arrival` on the `.tres` (and optionally `spawn_weight`) to put any interior on
the lift — debug `stop elevator shop` composes the same pairing without a new file.

Default forks are 4-ways (left / straight / right). T-junctions are used when
fewer than three cards remain in the act deck, or when **No Through Road** was
the previous street — that DANGER card sets `GameSession.pending_narrow_fork`
so the next choice drops from 3 to 2.

### Determinism

Act deck shuffles are seeded from `hash([run_seed, run_act, channel])`, so a reload
mid-act rebuilds the same deck. Wave composition and side-street placement use
unseeded `randf()`/`randi()` — deliberately, so replays aren't identical.

## 3. Architecture, and why it looks like this

### Autoloads carry state; scenes carry behaviour

Autoloads are plain `extends Node` with **no `class_name`**. That is intentional:
several of them reference types that reference them back, and a `class_name` on an
autoload creates a parse cycle in Godot. Same reason `GameBalance` does
`const _GameBalanceData := preload(...)` instead of using the global class name.

### Groups are the service locator

Cross-system lookups go through `get_tree().get_first_node_in_group(&"...")` plus
`has_method(&"...")` duck typing, not typed references. `TravelController` and
`ActDeckController` talk to each other this way specifically to avoid a
`class_name` cycle, and `van.gd` keeps the class panel and the schematic HUD
untyped for the same reason. Keep this pattern when you add a system that two
others need. The current registry is in `PROJECT_MAP.md`.

### Async sequences are guarded by a counter

`TravelController` and `EncounterDirector` run long `await` chains. Both hold a
`_sequence_id: int`; every new sequence increments it and captures the value, then
after each `await` checks `if id != _sequence_id: return`. This is how a chill-mode
toggle, a phase change, or a scene teardown cancels an in-flight coroutine. **Any
new `await` chain in those files needs the same guard** or you'll get two directors
running waves at once.

### Data lives in `.tres`, code reads it

Adding content should almost never mean writing code:

| To add… | Create a `.tres` in… | Read by |
|---|---|---|
| a boon or item | `resources/items/` (+ pool entry) | `ItemPoolRegistry`, `ItemRegistry` |
| a street card | `resources/acts/cards/` | `ActCardRegistry` (scans the folder) |
| a side stop | `resources/side_stops/` (+ content scene, `arrival`) | `SideStopRegistry` (scans the folder) |
| a class | `resources/classes/` | `ClassCatalog` (scans the folder) |
| an enemy | `resources/enemies/` (+ spawn pool) | `GameBalance.pick_spawn_enemy` |
| a sound | `resources/audio/sound_bank.tres` (SoundCue) | `AudioDirector` |
| a balance tweak | `resources/balance/game_balance.tres` | `GameBalance` facade |

New *behaviour* means a new small `Resource` subclass — `ItemEffect`,
`ActCardEffect`, or a `BoonBehavior` registered in `BoonBehaviorRegistry` — not a
branch inside an existing system.

### Combat stat pipeline

Order matters and is fixed:

```
GameBalance floor (BASE_DAMAGE_PER_SHOT, BASE_FIRE_RATE)
  → ClassDefinition identity   (damage_mult, fire_rate_mult, mag, reload, pellets, spread, speed, size, bounces)
  → BoonTraits adds/mults      (GunStatsController._apply_traits: boons and street cards)
  → temporary StatModifiers    (stims)
  → clamps
```

`BoonTraits` holds two layers: permanent boon traits, and a replaceable **street
overlay** set by the active act card(s). `set_street_overlay` replaces wholesale;
boss fights merge several cards' overlays before applying (`ActCardCombat`).
A bullet leaves the gun with the resulting `damage_per_shot` and is never scaled
again; Explosive, Poison and Cold Rounds spend shares of that hit through their
`BoonBehavior` handlers on the post-hit hook.

## 4. Hard invariants

Breaking these is how the game stops being fun, so they're worth stating flatly.

1. **One damage number, no damage types.** A bullet's damage is
   `GameBalance.BASE_DAMAGE_PER_SHOT * ClassDefinition.damage_mult`. Boons and street
   cards scale it through the `gun_damage_per_shot` trait, applied once in
   `GunStatsController`. Blasts and poison are shares of the hit that caused them
   and are never scaled again.
2. Retired.
3. **Shotgun pellets split damage**, they don't multiply it. An 8-pellet shotgun is
   coverage, not ×8 DPS.
4. **Fire, poison and cold are bullet boons, not damage types.** Explosive, Poison
   and Cold Rounds each have one `BoonBehavior` handler. Secondary damage (blast
   splash, poison ticks) never triggers them; a blast does apply poison and cold.
   Explosive bullets detonate on first contact and do not ricochet.
5. **"Reload Speed %" lowers duration:** `seconds / (1 + pct/100)`. Never add the
   percentage onto the seconds field.
6. **One gun per class.** The class is picked at the class board in IDLE and locked
   for the rest of the run. Keys 1-4 are tool slots; Q is bound but unused.
7. **Gold buys at shops and the mechanic.** Rare Parts (`MetaProgression.rare_parts`)
   are a second wallet for the van schematic only: boss drops, 3 per run max. Never
   spend gold on schematic nodes.
8. **Van speed is tree-written.** `van_speed_level` still feeds the chase formula
   (`closing = mob_world_speed - live_van_speed`). Only allocated schematic nodes
   change it; pending requests wait until the next run (or apply in `IDLE`).
   Do not buy speed with gold at the bench.
9. **Do not add a hitscan gun.** Combat is projectile-only; the old `HitscanWeapon`
   script is gone.
10. **Run save version lives only on `SaveManager.SAVE_VERSION`.**
    `GameSession.to_save_data()` must read that constant. Mismatched slot files are
    rejected with a warning that names both versions — never fail silently.
    The main menu must not treat a rejected file as a new run (use NEW to overwrite).
11. **`is_elite` is explicit.** Agile (window climbing, green tint) does not imply
    elite loot. Set elite on the raider export, or via `mark_as_boss()` /
    `EncounterDirector._spawn_boss`.
12. **Player HP and van hull are both fail conditions.** Either bar at 0 is
    `GAME_OVER`. Van hull is the **sum of interior vitals** (bench, hopper, fuse
    box, cab relay), not door/window smash HP. Heal consumables restore player
    HP only; the weld kit (look-at, +50) repairs a machine, door, or window.
    Max-HP boons still raise van hull (split across the vitals).

## 5. Code conventions

- Godot 4.7, GDScript, **tabs** for indent, LF line endings, ~100 col soft limit.
- Two blank lines between top-level functions (gdformat house style).
- Typed everything: `var x := 0.0`, `func f(a: int) -> void:`.
- `StringName` literals with `&"..."` for ids, groups, signals, action names.
- `##` doc comments on classes and on any non-obvious field.
- Comments explain **why**, not what. There are a lot of "don't do X, it breaks Y"
  notes in this codebase (mouse capture timing, threaded scene loads, park curve
  handles). Read them before touching that code, and add one when you fix
  something subtle.
- `class_name` on anything reusable, except autoloads (see above).

## 6. Known pitfalls

Each of these has already cost someone real debugging time:

- **Mouse capture.** Godot ignores `MOUSE_MODE_CAPTURED` on the same frame as a GUI
  click. `van.gd` works around it with `_capture_mouse_after_ui_click()` and a
  `_mouse_capture_gen` counter. New overlays must call `refresh_mouse_mode()` on
  close rather than setting the mode themselves, and register in
  `has_modal_free_cursor()`. Don't `gui_release_focus()` while the debug console
  is open — that unfocuses the LineEdit so you have to click it to type.
- **Pause menu.** Esc opens it and sets `get_tree().paused`. The overlay is
  `PROCESS_MODE_ALWAYS` so Resume still works. `SceneRouter` unpauses on every
  scene change — if you skip that, the main menu loads frozen. Don't open pause
  on `GAME_OVER` (those buttons are pausable). Bench / schematic / class panel /
  console still eat Esc first and close themselves.
- **HUD eating clicks.** Any non-interactive HUD control must be
  `MOUSE_FILTER_IGNORE`, otherwise clicking through it uncaptures the mouse.
  `_make_combat_hud_mouse_passthrough()` handles this — add genuinely interactive
  panels to `_is_interactive_hud()`.
- **Threaded loading of `van.tscn` fails.** `SceneRouter.preload_van()` deliberately
  uses a synchronous `ResourceLoader.load`; the threaded path dies on the floor
  shader sub-resource. Don't "optimise" it back.
- **`debug_console.tscn` is `load()`ed, not `preload()`ed** in `van.gd`, so a broken
  console scene doesn't hard-fail the whole van scene at compile time. The
  schematic HUD is instanced in `van.tscn` but also not preloaded into `van.gd`
  for the same reason.
- **`DebugConfig.ENABLED`** is a `static var` initialised from
  `OS.has_feature("debug")`. Editor and debug exports get the console (`H`);
  release exports do not. Set `DebugConfig.FORCE_ENABLED` to `true` to ship the
  console in a release build.
- **`ActCardRegistry` scans `res://resources/acts/cards/` with `DirAccess`.** Packed
  listings may use `foo.tres.remap`; `list_ids()` strips `.remap` before the
  `.tres` check. An empty list `push_warning`s rather than failing quietly.
- **`SkillTreeRegistry` scans `res://resources/meta/tree/` the same way.** Callers
  preload the script (it is not an autoload and has no `class_name`). Pending
  node buys must not emit `van_speed_changed` or the chase window jumps mid-street.
  Fuse box / cab relay vitals need explicit `vital_id` on the `van.tscn` instances
  — the dummy scene leaves the id empty so both become `&"van_vital"`.
- **`SideStopRegistry` scans `res://resources/side_stops/` the same way.** Arrival
  hosts (`stop_vestibule.tscn` / `stop_elevator.tscn`) expose `DockPoint` and
  `ExitPoint`. Content scenes start just inside the roll-up (`ContentMount` at
  the door, +X inward) and must not include those markers. `DockPoint.x` is
  negative so the rear bumper sits in the vestibule, not inside the door.
- **Stop attach ignores leftover tiles after a curve swap.** Left/right turns
  replace `travel_path.curve` and reset progress to 0. Old corridor tiles keep
  their `route_progress` numbers, so a naive "first tile ahead" pick can parent
  the garage to the street you just left — van reverse-parks on the new road
  with the building on its side. `TravelController` stamps `_route_gen` and only
  attaches to tiles that still sit on the live curve.
- **Elevator stops ride `PathFollow3D.v_offset`.** The van stays on the road
  curve; the pad is a sibling in the corridor, not a new parent. Don't reparent
  `VanRig` onto the platform. Open the shaft (hide *collision* as well as the
  mesh) as the ride starts — a street-height `StaticBody` will hold the player
  at grade while the van drops. Keep the pad below the van deck and inside the
  shaft so it does not z-fight the interior floor. Vestibule yaw is `-PI/2`
  so shop `+X` faces van rear (`+Z`); `+PI/2` puts the door at the nose and
  walking out the back falls into the shaft. Don't place the shop slab under
  the van deck (origin needs to sit aft of the rear doors).
- **Dialogue hover.** Talk frees the cursor (`has_modal_free_cursor`) so options
  highlight on hover and click to pick. E still walks away. Keys 1–4 still route
  to `DialogueHud.try_choose` first so a leftover weld kit does not fire mid-talk.
- **Rejected saves used to look like NEW RUN.** `load_slot_data()` returns `{}` for
  version mismatches and corrupt JSON, which made `get_slot_summary()` report
  `exists: false`. Clicking the slot then called `start_new`. Incompatible files
  now show CAN'T CONTINUE and CONTINUE does not overwrite them.
- **Positional audio is van-local.** Enemies and projectiles live under `VanRig`,
  so a 3D sound left at a world position pans to the rear within a second.
  `AudioDirector.play_at()` reparents the pooled player into the emitter's space.
  Don't parent an `AudioStreamPlayer3D` to an enemy or a pooled projectile — both
  die (or recycle) before the tail finishes. Don't call `play()` from
  `gun_controller`; emit `shot` and let the autoload map it to a `SoundCue`.
  The `Interior` bus sends to SFX and has no FX yet — that's the van-shell
  low-pass / short-reverb slot. Import SFX as `.wav` (no decode latency) and
  music as `.ogg` with the loop flag.
- **Van raiders use a waypoint graph, not a navmesh.** They are `Node3D`s under
  `EnemyContainer` on a `PathFollow3D`. `NavigationAgent3D` / `CharacterBody3D`
  on that parent slides and fights the van-local lerp. Indoor paths go through
  `CabinNav` (bulkhead doorway, occupancy slots). Warehouse buildings are
  world-static — bake a `NavigationRegion3D` there later, not on the van.
- **A rear door and its window pane are two BreachPoints.** Door goons and
  agile climbers use separate pools, but the Outside markers sit ~15cm apart.
  Occupancy is clustered on the opening (`BreachPoint._shares_opening`); CabinNav
  never occupies outside holes. Do not split that cluster or a mixed pack stacks.

## 7. Deliberate choices — do not change these without asking

These look like bugs. They are not. The project owner set them on purpose.

- **Wave counts in `game_balance.tres` are test values the owner changes freely.**
  The working tree may hold an uncommitted edit to them.

- **`GameBalance.get_act(route_step)` and `GameSession.run_act` disagree.**
  `get_act` is the old three-step pacing model (act 3 from route step 3 onward);
  `run_act` is the current deck-based act counter (one act = six cards = six route
  steps). Every balance curve — mob world speed, engagement seconds, expected van
  upgrade fraction, wave sizing — still reads the old one, so difficulty stops
  scaling early in act 1. **This is a known open design question, not an oversight.**
  The owner is redesigning how acts drive pacing. Do not unify these two models,
  do not rewire `get_act` to take `run_act`, and do not add a compatibility shim.
  Raise it and wait.

## 8. Where to start for common tasks

| Task | Entry point |
|---|---|
| Change run pacing / phases | `scripts/core/game_session.gd` |
| Change wave sizes, enemy speed, spawn geometry | `resources/balance/game_balance.tres` |
| Change how encounters are sequenced | `scripts/run/encounter_director.gd` |
| Van raider pathing / occupancy | `scripts/run/cabin_nav.gd` + `window_raider.gd` |
| Act boss (Wanjna the biker) | `scripts/run/biker_boss.gd` + `_spawn_boss` in `encounter_director.gd` |
| Change road, turns, side-stop parking, statues | `scripts/run/travel_controller.gd` |
| Change act deck / boss pick logic | `game_session.gd` + `scripts/run/act_deck_controller.gd` |
| Change the reveal / boss-pick UI | `scripts/ui/act_reveal_panel.gd` |
| Add a boon | new `.tres` in `resources/items/boons/` + pool + maybe a `BoonBehavior` |
| Add a street card | new `.tres` in `resources/acts/cards/` + maybe an `ActCardEffect` |
| Add a side stop | new `.tres` in `resources/side_stops/` + a content scene; set `arrival` to `REAR_PARK` or `ELEVATOR` |
| Touch classes / the gun | `scripts/classes/` + `resources/classes/` + `scripts/combat/gun_*.gd` |
| Class board / class panel | `scripts/interactions/class_board.gd` + `scripts/ui/class_panel.gd` + `GameSession.equip_class` |
| Bullet boons (explosive / poison / cold) | `scripts/player/boon_behavior_handlers.gd`, `scripts/combat/damage_resolver.gd`, `status_effect_controller.gd`, `explosion_fx.gd` |
| Add a sound | new `SoundCue` in `resources/audio/sound_bank.tres` — gameplay already emits |
| Touch the van shell / doors / windows | `scripts/run/van_*.gd`, `side_*.gd`, `rear_doors.gd` |
| Van hull / interior vitals | `scripts/run/van_vital.gd` + HUD `scripts/ui/van_health_bar.gd` |
| Weld kit (look-at repair) | `scripts/items/effects/repair_window_bars_effect.gd` |
| Yell at the driver (Shift GO / C EASY) | `travel_controller.gd` boost/slow + `scripts/ui/driver_shout_hud.gd` |
| Bench overview | `scripts/ui/bench_screen.gd` |
| Van schematic / skill tree | `scripts/ui/skill_tree_hud.gd` + `scripts/core/meta_progression.gd` + `resources/meta/tree/` |
| Loot hopper / death popups | `scripts/core/loot_collector.gd` + `scripts/interactions/loot_machine.gd` |
| Shop counter / stock | `scripts/run/shop_*.gd` |
| NPC talk (hover + click) | `scripts/dialogue/npc_talk.gd` + `scripts/ui/dialogue_hud.gd` |
| Pause menu (Esc) | `scripts/ui/pause_menu.gd` — settings, return to menu, quit |

## 9. Running and debugging

- Open the project in Godot 4.7; main scene is `scenes/boot/boot.tscn`.
- In-game console: **H**. `help` lists commands; `list commands|boons|items|classes|cards|stops|sounds|tree`
  enumerates content. `stop <id>` forces that side stop on the next fork (use
  `stop rare_shop` or `stop elevator shop` to test the elevator). `sound <cue>` auditions a cue.
  `class <id>` equips a class in any phase.
  `parts [n]` grants Rare Parts; `tree_reset` wipes the schematic back to origin.
- `speed` enables a debug fast-forward that also auto-resolves reveals and boon
  picks — useful for reaching late acts quickly, but it *skips* the panels, so don't
  use it to test UI.
- `chill` / `unchill` pauses and resumes encounters without leaving the run.
- Saves are JSON at `user://save_slot_N.json`; meta progression at
  `user://meta_progression.json`.

## 10. Keeping this file honest

When you change something structural, the fix is usually one of:

1. Re-run `python3 tools/gen_context.py` (covers ~80% of drift automatically).
2. Add a line to §4 if you introduced a new invariant, or to §7 if you made a
   deliberate choice that will look wrong to the next reader.
3. Add a line to §6 if you spent more than an hour on a subtle bug.

If you delete a system, delete its row in §8. Everything else takes care of itself.
