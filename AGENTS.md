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
parented to a `PathFollow3D`, and the world (corridor segments, junctions, shops)
is spawned ahead and culled behind. Enemies live in `EnemyContainer`, a child of the
van rig, so their positions are **van-local**. This is why chase speed is expressed
as *closing speed* (`mob_world_speed - live_van_speed`) rather than a plain velocity.

## 2. The run loop

`GameSession.RunPhase` is the single source of truth for what the game is doing.
Every system reacts to `phase_changed` rather than driving each other directly.

```
IDLE ──(player tells driver to start)──> TRAVELLING
TRAVELLING ──(act deck empty)──> ACT_REVEAL ──> ROUTE_CHOICE
ROUTE_CHOICE ──(pick left/right card)──> TURNING ──> TRAVELLING
TRAVELLING ──(EncounterDirector timer)──> COMBAT ──> REST
REST ──(boon pick for the committed street card)──> ROUTE_CHOICE
   ...six cards later...
REST ──> BOSS_PICK ──> TRAVELLING ──> COMBAT (boss) ──> REST ──> ACT_REVEAL (next act)
TRAVELLING ──(shop fork was taken)──> PARKING ──> SHOP ──> TRAVELLING
any ──(van health hits 0)──> GAME_OVER
```

### Acts and street cards

An **act** is a deck of 6 street cards: 3 BLESSING, 3 DANGER, drawn at a roadside
statue (`ACT_REVEAL`) and shown shuffled. At each fork the player sees the top two
cards face-up as the left/right options; taking one commits it and leaves the other
in the deck. A committed card:

- applies its `ActCardEffect`s to combat for that street (`ActCardCombat`)
- owes the player a 3-choice boon at the following `REST`
- if DANGER, bumps the next wave plan (`_apply_danger_bump`, ×1.35 + 1)

When the deck empties, the six cards come back **face-down** and the player picks
two (`BOSS_CARD_PICK_COUNT`) to bind to the act boss — both cards' effects stack on
that fight. Beat it and a new deck is drawn.

Shops are separate from cards: every fork currently offers a shop on one side
(`TravelController._prepare_shop_fork`), and taking that side gets you both the shop
*and* the card.

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
`class_name` cycle, and `GameSession.to_save_data()` reaches the weapon inventory
with an untyped `var inv = ...` for the same reason. Keep this pattern when you add
a system that two others need. The current registry is in `PROJECT_MAP.md`.

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
| a gun | `resources/weapons/definitions/` | `WeaponCatalog` |
| an enemy | `resources/enemies/` (+ spawn pool) | `GameBalance.pick_spawn_enemy` |
| a balance tweak | `resources/balance/game_balance.tres` | `GameBalance` facade |

New *behaviour* means a new small `Resource` subclass — `ItemEffect`,
`ActCardEffect`, or a `BoonBehavior` registered in `BoonBehaviorRegistry` — not a
branch inside an existing system.

### Combat stat pipeline

Order matters and is fixed:

```
GameBalance floor
  → WeaponDefinition identity (fire_rate_mult, mag, reload, pellets, element)
  → WeaponMod % increases          (WeaponStatsBuilder)
  → BoonTraits adds/mults          (GunStatsController._apply_traits)
  → temporary StatModifiers        (stims)
  → clamps
```

`BoonTraits` holds two layers: permanent boon traits, and a replaceable **street
overlay** set by the active act card(s). `set_street_overlay` replaces wholesale;
boss fights merge several cards' overlays before applying (`ActCardCombat`).

## 4. Hard invariants

Breaking these is how the game stops being fun, so they're worth stating flatly.

1. **No flat damage on weapons or weapon mods.** Guns define *feel*; boons define
   the damage curve. Damage always starts from `GameBalance.BASE_DAMAGE_PER_SHOT`.
2. **Max 4 mods per gun**, interior/exterior grades only, no duplicates of the same
   `grade + mod_id`.
3. **Shotgun pellets split damage**, they don't multiply it. An 8-pellet shotgun is
   coverage, not ×8 DPS.
4. **Elemental gun variants only set `damage_type`.** They never add a second damage
   channel — conversions and bonuses are boon territory.
5. **"Reload Speed %" lowers duration:** `seconds / (1 + pct/100)`. Never add the
   percentage onto the seconds field.
6. **Exactly 2 weapon slots**, swapped with scroll or Q. Never bind swapping to 1–4;
   those are tool slots.
7. **Crafting spends `GameSession.coins`.** There is no second currency.
8. **Do not add a hitscan gun.** Combat is projectile-only; the old `HitscanWeapon`
   script is gone.
9. **Run save version lives only on `SaveManager.SAVE_VERSION`.**
   `GameSession.to_save_data()` must read that constant. Mismatched slot files are
   rejected with a warning that names both versions — never fail silently.
   The main menu must not treat a rejected file as a new run (use NEW to overwrite).
10. **`is_elite` is explicit.** Agile (window climbing, green tint) does not imply
    elite loot. Set elite on the raider export, or via `mark_as_boss()` /
    `EncounterDirector._spawn_boss`.

The long-form reasoning behind all of this is in
`docs/WEAPON_SYSTEM_VAN_GUNNER.md`, which is still an accurate description of the
implemented system.

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
  `has_modal_free_cursor()`.
- **HUD eating clicks.** Any non-interactive HUD control must be
  `MOUSE_FILTER_IGNORE`, otherwise clicking through it uncaptures the mouse.
  `_make_combat_hud_mouse_passthrough()` handles this — add genuinely interactive
  panels to `_is_interactive_hud()`.
- **Threaded loading of `van.tscn` fails.** `SceneRouter.preload_van()` deliberately
  uses a synchronous `ResourceLoader.load`; the threaded path dies on the floor
  shader sub-resource. Don't "optimise" it back.
- **`debug_console.tscn` is `load()`ed, not `preload()`ed** in `van.gd`, so a broken
  console scene doesn't hard-fail the whole van scene at compile time.
- **`DebugConfig.ENABLED`** is a `static var` initialised from
  `OS.has_feature("debug")`. Editor and debug exports get the console (`H`);
  release exports do not. Set `DebugConfig.FORCE_ENABLED` to `true` to ship the
  console in a release build.
- **`ActCardRegistry` scans `res://resources/acts/cards/` with `DirAccess`.** Packed
  listings may use `foo.tres.remap`; `list_ids()` strips `.remap` before the
  `.tres` check. An empty list `push_warning`s rather than failing quietly.
- **Rejected saves used to look like NEW RUN.** `load_slot_data()` returns `{}` for
  version mismatches and corrupt JSON, which made `get_slot_summary()` report
  `exists: false`. Clicking the slot then called `start_new`. Incompatible files
  now show CAN'T CONTINUE and CONTINUE does not overwrite them.

## 7. Deliberate choices — do not change these without asking

These look like bugs. They are not. The project owner set them on purpose.

- **`segment_wave_min` / `segment_wave_max` are both `1`** in
  `resources/balance/game_balance.tres`. The script default is 4–9. This is a
  deliberate testing value that makes every street a single 2-enemy wave so the
  run loop can be exercised quickly. A side effect is that
  `act_wave_growth_per_step` and `act_last_wave_extra` never execute, because a
  one-entry plan only ever hits the `is_first` branch of
  `GameBalance.build_segment_wave_plan`. Leave all three alone.

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
| Change road, turns, shop parking, statues | `scripts/run/travel_controller.gd` |
| Change act deck / boss pick logic | `game_session.gd` + `scripts/run/act_deck_controller.gd` |
| Change the reveal / boss-pick UI | `scripts/ui/act_reveal_panel.gd` |
| Add a boon | new `.tres` in `resources/items/boons/` + pool + maybe a `BoonBehavior` |
| Add a street card | new `.tres` in `resources/acts/cards/` + maybe an `ActCardEffect` |
| Touch guns | `scripts/weapons/` + `scripts/combat/gun_*.gd` |
| Touch the van shell / doors / windows | `scripts/run/van_*.gd`, `side_*.gd`, `rear_doors.gd` |
| Bench / crafting UI | `scripts/ui/bench_screen.gd` |
| Bench screenshot tool | `tools/bench_preview.tscn` |
| Shop | `scripts/run/shop_*.gd` |

## 9. Running and debugging

- Open the project in Godot 4.7; main scene is `scenes/boot/boot.tscn`.
- In-game console: **H**. `help` lists commands; `list commands|boons|items|weapons|cards`
  enumerates content. Full command list is in `PROJECT_MAP.md`.
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
