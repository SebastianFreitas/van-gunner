# PROJECT_MAP — van-gunner
> **Generated file. Do not hand-edit.** Regenerate with `py -3 tools/gen_context.py`.
> Design intent, invariants and gotchas live in `CLAUDE.md` (workflow, summary, always-on invariants) and `.claude/rules/` (per-area design notes and pitfalls, loaded by path).

## Project settings

- Name: `VanGunner`
- Main scene: `res://scenes/boot/boot.tscn`
- Engine features: `4.7, Forward Plus`
- Physics: Jolt · Renderer: Forward+ (d3d12 on Windows)

## Autoloads (singletons, always available)

| Name | Script |
|---|---|
| SceneRouter | `res://scripts/core/scene_router.gd` |
| SaveManager | `res://scripts/core/save_manager.gd` |
| GameSession | `res://scripts/core/game_session.gd` |
| GameBalance | `res://scripts/core/game_balance.gd` |
| MetaProgression | `res://scripts/core/meta_progression.gd` |
| AudioDirector | `res://scripts/audio/audio_director.gd` |
| LootCollector | `res://scripts/core/loot_collector.gd` |
| ProjectilePool | `res://scripts/combat/projectile_pool.gd` |
| CombatFeedback | `res://scripts/ui/combat_feedback.gd` |
| DebugCommands | `res://scripts/debug/debug_commands.gd` |

## Input actions

`move_forward`, `move_back`, `move_left`, `move_right`, `interact`, `jump`, `shoot`, `reload`, `pause`, `use_usable`, `use_slot_1`, `use_slot_2`, `use_slot_3`, `use_slot_4`, `debug_console`, `driver_boost`, `driver_slow`

## Node groups

Registered: `act_deck_controller`, `agile`, `boon_reward_controller`, `boss`, `breach_controller`, `breach_points`, `cabin_nav`, `dialogue_hud`, `encounter_director`, `enemy`, `gun_controller`, `gun_stats`, `head_hitbox`, `pickup`, `player`, `rear_doors`, `side_doors`, `side_windows`, `travel_controller`, `van_run`, `van_vitals`

Looked up: `act_deck_controller`, `agile`, `boon_reward_controller`, `breach_controller`, `breach_points`, `cabin_nav`, `dialogue_hud`, `encounter_director`, `enemy`, `facade_lights`, `gun_controller`, `gun_stats`, `head_hitbox`, `pickup`, `player`, `rear_doors`, `side_doors`, `side_windows`, `travel_controller`, `van_run`, `van_vitals`

## Signals and enums

**`scenes/corridor/corridor_segment.gd`**

- `enum Opening { NONE, SIDE_STREET, BAY }`

**`scripts/acts/act_card_definition.gd`**

- `enum Polarity { BLESSING = 0, DANGER = 1, }`

**`scripts/acts/act_deck_controller.gd`**

- `signal reveal_resolved`
- `signal boss_pick_resolved`

**`scripts/acts/boon_reward_controller.gd`**

- `signal rest_resolved`

**`scripts/classes/class_definition.gd`**

- `enum Family { BASIC, SHOTGUN, MACHINEGUN, SNIPER }`

**`scripts/combat/grenade.gd`**

- `signal exploded(world_position: Vector3)`

**`scripts/combat/gun_controller.gd`**

- `signal fired(hit: bool)`
- `signal shot`
- `signal ammo_changed(current: int, max_ammo: int)`
- `signal reloading_changed(is_reloading: bool)`

**`scripts/combat/gun_stats_controller.gd`**

- `signal stats_changed`

**`scripts/combat/projectile.gd`**

- `signal hit_target(target: Node)`
- `signal ricocheted(position: Vector3, normal: Vector3)`
- `signal despawned(was_hit: bool)`

**`scripts/combat/stat_modifier.gd`**

- `enum Mode { ADD, MULTIPLY, }`

**`scripts/core/game_session.gd`**

- `signal phase_changed(phase: RunPhase)`
- `signal van_health_changed(current: float, maximum: float)`
- `signal player_health_changed(current: float, maximum: float)`
- `signal route_chosen(direction: StringName, step: int)`
- `signal wave_changed(wave: int)`
- `signal room_changed(room: StringName)`
- `signal coins_changed(total: int)`
- `signal enemy_defeated(enemy: Node)`
- `signal session_loaded`
- `signal chill_mode_changed(enabled: bool)`
- `signal class_changed(class_id: StringName)`
- `enum RunPhase { IDLE, TRAVELLING, COMBAT, ROUTE_CHOICE, TURNING, GAME_OVER, REST, PARKING, STOP, ACT_REVEAL, BOSS_PICK, }`

**`scripts/core/loot_collector.gd`**

- `signal queue_changed`

**`scripts/core/meta_progression.gd`**

- `signal van_speed_changed(level: int, speed: float)`
- `signal rare_parts_changed(total: int)`
- `signal tree_changed`

**`scripts/enemies/biker_boss.gd`**

- `enum BikePhase { IDLE, CHARGE, WINDUP, PEEL, WEAVE, ENTERING, BENCH }`

**`scripts/enemies/breach_point.gd`**

- `signal breached`
- `signal health_changed(current: float, maximum: float)`
- `enum Kind { REAR_DOOR, SIDE_DOOR, WINDOW, SIDE_DOOR_WINDOW }`

**`scripts/enemies/cabin_nav.gd`**

- `enum Room { BACK, CABIN }`

**`scripts/enemies/window_raider.gd`**

- `signal attack_landed(amount: float)`
- `signal defeated`
- `signal assault_finished`
- `enum AssaultPhase { IDLE, APPROACH, BREACHING, ENTERING, ATTACKING_BENCH, ATTACKING_PLAYER }`

**`scripts/interactions/class_board.gd`**

- `signal opened`

**`scripts/interactions/crafting_table.gd`**

- `signal opened`

**`scripts/interactions/request_board.gd`**

- `signal opened`

**`scripts/items/item_definition.gd`**

- `enum ItemKind { MONEY = 0, BOON = 1, TOOL = 2, CONSUMABLE = 3, }`

**`scripts/items/item_usable_config.gd`**

- `enum RechargeMode { NONE, COOLDOWN, ON_KILL, }`

**`scripts/items/pickup.gd`**

- `enum _AnimState { SPIN, FACE }`

**`scripts/meta/skill_node_definition.gd`**

- `enum Branch { ORIGIN = 0, UP = 1, DOWN = 2, LEFT = 3, RIGHT = 4, }`

**`scripts/player/boon_traits.gd`**

- `signal traits_changed`

**`scripts/player/fps_player.gd`**

- `signal interaction_prompt_changed(text: String)`
- `signal shot_fired(hit: bool)`

**`scripts/player/usables_controller.gd`**

- `signal slots_changed`
- `signal boons_changed`
- `signal item_acquired(item: ItemDefinition, charges: int, slot_index: int)`
- `signal usable_activated(item: ItemDefinition, success: bool)`

**`scripts/stops/side_stop_definition.gd`**

- `enum Arrival { REAR_PARK = 0, ELEVATOR = 1, }`

**`scripts/stops/warehouse_hide.gd`**

- `signal triggered`
- `enum Reveal { BURST, FALL, PEEL }`

**`scripts/stops/warehouse_laser.gd`**

- `signal sprung`

**`scripts/travel/travel_controller.gd`**

- `enum TurnState { NONE, APPROACHING, TURNING, PARKING, LEAVING_STOP, ELEVATING, }`

**`scripts/ui/act_reveal_panel.gd`**

- `signal reveal_finished`
- `signal boss_cards_picked(card_ids: Array)`
- `enum Mode { ACT_REVEAL, BOSS_PICK }`

**`scripts/ui/bench_screen.gd`**

- `signal closed`

**`scripts/ui/boon_choice_panel.gd`**

- `signal choice_made(item: ItemDefinition)`

**`scripts/ui/class_panel.gd`**

- `signal closed`

**`scripts/ui/debug_console.gd`**

- `signal opened`
- `signal closed`

**`scripts/ui/driver_shout_hud.gd`**

- `signal boost_pressed`
- `signal slow_pressed`

**`scripts/ui/pause_menu.gd`**

- `signal opened`
- `signal closed`
- `signal quit_to_menu_requested`
- `signal quit_game_requested`

**`scripts/ui/skill_tree_hud.gd`**

- `signal closed`

**`scripts/van/breakable_glass.gd`**

- `signal shattered`

**`scripts/van/rear_doors.gd`**

- `signal opened`
- `signal closed`
- `signal door_changed(side: StringName, is_open: bool)`
- `signal glass_shattered(side: StringName)`

**`scripts/van/side_doors.gd`**

- `signal opened`
- `signal closed`
- `signal door_changed(side: StringName, is_open: bool)`
- `signal passage_changed(side: StringName, is_passable: bool)`

**`scripts/van/side_windows.gd`**

- `signal opened`
- `signal closed`
- `signal window_changed(window_id: StringName, is_open: bool)`

**`scripts/van/van_bulkhead.gd`**

- `enum OpeningSide { LEFT, RIGHT }`

**`scripts/van/van_vital.gd`**

- `signal health_changed(current: float, maximum: float)`


## Script index

238 GDScript files, 34249 lines.

### `scenes/corridor/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `corridor_segment.gd` | — | 174 | A single corridor tile: road floor, wall collision, procedural facades on both sides, and the side-street / stop-bay openings that carve them. |
| `corridor_t_junction.gd` | — | 132 | Fills sidewalk corners where stem / branch / optional through-road meet the open junction slab. |
| `side_street_branch.gd` | — | 57 | A side-street branch tile; mirrors its children when attached on the right side. |

### `scripts/acts/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `act_card_combat.gd` | `ActCardCombat` | 148 | Dispatcher for active street cards — mirrors BoonCombat for act cards. |
| `act_card_definition.gd` | `ActCardDefinition` | 27 | Combat behavior lives in composable `effects`. |
| `act_card_effect.gd` | `ActCardEffect` | 45 | Base class for anything an active street card does while it is the road. |
| `act_card_effect_context.gd` | `ActCardEffectContext` | 39 | Shared bag for street-card effect hooks. |
| `act_card_registry.gd` | `ActCardRegistry` | 48 | Resolves act street-card definitions by id from resources/acts/cards/. |
| `act_deck_controller.gd` | `ActDeckController` | 150 | Owns act-start tarot reveals and the act-end boss pick. |
| `boon_reward_controller.gd` | `BoonRewardController` | 146 | During REST, grants a 3-choice boon for the street card committed at the last fork. |

### `scripts/acts/effects/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `enemy_health_mult_effect.gd` | `EnemyHealthMultEffect` | 20 | Scales raider max/current health on spawn (dangers that make fights longer). |
| `enemy_loot_bonus_effect.gd` | `EnemyLootBonusEffect` | 11 | Adds to the item drop chance roll on enemy death (0.1 = +10%). |
| `enemy_speed_mult_effect.gd` | `EnemySpeedMultEffect` | 18 | Scales raider world chase speed on spawn (1.15 = 15% faster). |
| `narrow_fork_effect.gd` | `NarrowForkEffect` | 12 | After this street, the next fork is a T — two face-up cards instead of three. |
| `temp_boon_trait_effect.gd` | `TempBoonTraitEffect` | 18 | While this street is active, grants a boon trait via BoonTraits street overlay. |
| `wave_count_mult_effect.gd` | `WaveCountMultEffect` | 19 | Bumps each wave's spawn count (danger roads). |

### `scripts/audio/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `audio_director.gd` | — | 368 | Central sound playback. |
| `sound_bank.gd` | `SoundBank` | 42 | Flat list of SoundCues, indexed by id once at load. |
| `sound_cue.gd` | `SoundCue` | 41 | One addressable sound. |

### `scripts/classes/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `class_catalog.gd` | `ClassCatalog` | 68 | Resolves player classes by id from resources/classes/. |
| `class_definition.gd` | `ClassDefinition` | 42 | One player class: a single gun with its base stats. |

### `scripts/combat/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `arm_cannon_mesh.gd` | `ArmCannonMesh` | 176 | Boxy Mega Man forearm cannons. |
| `bullet_trail.gd` | `BulletTrail` | 118 | Draws and fades the trail mesh a bullet leaves behind as it travels. |
| `bullet_visual.gd` | `BulletVisual` | 161 | Cosmetic bullet mesh + trail. |
| `damage_info.gd` | `DamageInfo` | 49 | One hit: a single damage number plus where it landed. |
| `damage_resolver.gd` | `DamageResolver` | 111 | Static helpers that apply bullet hits and explosions to damageable nodes, with headshot checks. |
| `explosion_fx.gd` | `ExplosionFx` | 304 | Pixel-art billboard blast. |
| `grenade.gd` | `Grenade` | 159 | Hand-integrated ballistics instead of a RigidBody3D. |
| `gun_controller.gd` | `GunController` | 322 | Hit/miss for the HUD once the first pellet resolves. |
| `gun_stats.gd` | `GunStats` | 46 | Defaults match game_balance.tres; GunStatsController still re-seeds from GameBalance. |
| `gun_stats_controller.gd` | `GunStatsController` | 153 | Rebuilds a gun's effective stats from its base stats, class and modifiers. |
| `gun_viewmodel.gd` | `GunViewmodel` | 222 | Viewmodel motion: quarter-roll per shot, tip-up accelerating spin on reload with a coast / settle finish so the mag change doesn't hard-cut. |
| `projectile.gd` | `Projectile` | 320 | A bullet: flies, ricochets off scenery and resolves damage on hit. |
| `projectile_pool.gd` | — | 82 | Reuses Projectile nodes to avoid instantiate/free churn during heavy fire. |
| `stat_modifier.gd` | `StatModifier` | 14 | A single additive or multiplicative modifier applied to a named gun stat. |
| `status_effect_controller.gd` | `StatusEffectController` | 128 | Poison stacks and the cold slow on one enemy. |

### `scripts/core/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `game_balance.gd` | — | 188 | Runtime facade over the Inspector-editable GameBalanceData resource. |
| `game_balance_data.gd` | `GameBalanceData` | 149 | Inspector-editable balance sheet for encounter pacing and act scaling. |
| `game_session.gd` | — | 365 | Autoload: tracks run phase, van/player health, route and wave state for the current run. |
| `loot_collector.gd` | — | 226 | Hopper for street-kill loot. |
| `meta_progression.gd` | — | 345 | Autoload: persists van speed level, rare parts and the meta skill tree across runs. |
| `save_manager.gd` | — | 97 | Autoload: reads and writes save slot JSON files on disk. |
| `save_sandbox.gd` | `SaveSandbox` | 10 | Test switch: when on, SaveManager and MetaProgression never touch user://, and the game never captures the mouse (the `--shots` window runs off-screen at -1000… |
| `scene_router.gd` | — | 74 | Autoload: switches between the main menu and van scenes, preloading the van ahead of time. |
| `session_act_deck.gd` | — | 203 | Act deck logic for GameSession. |
| `session_save.gd` | — | 163 | Save serialization for GameSession. |
| `session_vitals.gd` | — | 177 | Vital bookkeeping for GameSession. |
| `skill_tree_registry.gd` | — | 94 | Resolves skill-tree nodes from resources/meta/tree/. |

### `scripts/debug/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `debug_act_commands.gd` | — | 77 | Debug console commands: act. |
| `debug_catalog.gd` | — | 231 | Debug console command catalog: the `list` command plus the formatting and id-listing helpers shared by other command groups and by DebugCommands.get_completion… |
| `debug_commands.gd` | — | 229 | Parses and runs debug console commands. |
| `debug_config.gd` | `DebugConfig` | 7 | Set true to ship the console in a release export. |
| `debug_facade_commands.gd` | — | 301 | Debug console commands for the street facades: force a district or set-piece, reseed the tiles in view, print stats and plans, and run the keep-out stress audi… |
| `debug_item_commands.gd` | — | 70 | Debug console commands: items. |
| `debug_meta_commands.gd` | — | 55 | Debug console commands: meta. |
| `debug_run_flow_commands.gd` | — | 54 | Debug console commands: run flow. |
| `debug_van_commands.gd` | — | 50 | Debug console commands: van. |

### `scripts/dialogue/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `dialogue_choice.gd` | `DialogueChoice` | 21 | One option in an NPC talk. |
| `npc_talk.gd` | `NpcTalk` | 116 | Look + E opens talk. |

### `scripts/enemies/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `biker_boss.gd` | `BikerBoss` | 310 | Wanjna: hit-and-run biker. |
| `breach_controller.gd` | `BreachController` | 277 | Assigns raid slots around the van and interior vital damage targets. |
| `breach_point.gd` | `BreachPoint` | 365 | Outside attack slot that must be breached (or opened) before mobs can enter. |
| `cabin_nav.gd` | `CabinNav` | 333 | Van-local waypoint graph + occupancy. |
| `cabin_nav_paths.gd` | — | 163 | A* pathfinding and slot geometry over CabinNav's waypoint graph. |
| `encounter_director.gd` | `EncounterDirector` | 319 | Drives the travel/combat/rest cycle and owns the external spawn API for a run. |
| `encounter_spawner.gd` | — | 110 | Spawns bosses/raiders for EncounterDirector and answers alive/approaching queries. |
| `enemy_definition.gd` | `EnemyDefinition` | 14 | Data-only description of a spawnable enemy type. |
| `enemy_spawn_pool.gd` | `EnemySpawnPool` | 48 | A weighted collection of enemies to roll spawns from. |
| `enemy_spawn_pool_entry.gd` | `EnemySpawnPoolEntry` | 8 | A single weighted slot inside an EnemySpawnPool. |
| `loot_drop_component.gd` | `LootDropComponent` | 62 | Drop-in component that gives any enemy a chance to drop loot on death. |
| `window_raider.gd` | `WindowRaider` | 523 | A raider enemy: approaches, breaches a window or door, then attacks the bench or player. |
| `window_raider_motion.gd` | — | 69 | Per-frame chase math for WindowRaider. |
| `window_raider_targeting.gd` | — | 112 | Target picking, cabin/breach queries and status math for WindowRaider. |

### `scripts/interactions/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `cab_door.gd` | — | 185 | Decorative cab-facing door at the front partition. |
| `class_board.gd` | — | 21 | Wall board where the run's class is picked. |
| `crafting_table.gd` | `CraftingTable` | 10 | Interactable crafting table in the van; E opens the bench screen. |
| `interactable.gd` | `Interactable` | 14 | Base class for world objects the player can interact with. |
| `loot_machine.gd` | `LootMachine` | 31 | Left-wall hopper. |
| `request_board.gd` | — | 9 | Interactable request board in the van; E opens the van schematic (skill tree HUD). |

### `scripts/items/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `boon_trait_keys.gd` | `BoonTraitKeys` | 62 | StringName keys for passive boon traits stored on BoonTraits. |
| `item_definition.gd` | `ItemDefinition` | 98 | Data-only description of a single item. |
| `item_describer.gd` | `ItemDescriber` | 183 | Turns item resources into readable lines for UI. |
| `item_effect.gd` | `ItemEffect` | 20 | Base class for anything an item/boon does when it is collected. |
| `item_pool_registry.gd` | `ItemPoolRegistry` | 101 | Loads loot pools by name. |
| `item_registry.gd` | `ItemRegistry` | 63 | Resolves item definitions by id from the standard item directories. |
| `item_usable_config.gd` | `ItemUsableConfig` | 24 | Runtime rules for tools and abilities held in the player's hotbar. |
| `loot_catch.gd` | `LootCatch` | 33 | One hopper / popup entry wrapping a dropped ItemDefinition. |
| `loot_pool.gd` | `LootPool` | 62 | A weighted collection of items to roll drops from. |
| `loot_pool_entry.gd` | `LootPoolEntry` | 8 | A single weighted slot inside a LootPool. |
| `pickup.gd` | `Pickup` | 285 | Walk into a floor pickup to use it. |

### `scripts/items/effects/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `boon_trait_effect.gd` | `BoonTraitEffect` | 25 | Registers a passive boon trait on the player's BoonTraits node. |
| `composite_effect.gd` | `CompositeEffect` | 13 | Runs multiple child effects when a boon is collected. |
| `full_heal_effect.gd` | `FullHealEffect` | 9 | Heals the player to full health. |
| `grant_coin_effect.gd` | `GrantCoinEffect` | 10 | Grants a random amount of coins to the session. |
| `gun_stat_modifier_effect.gd` | `GunStatModifierEffect` | 22 | Permanently changes gun stats for the rest of the run via BoonTraits. |
| `heal_effect.gd` | `HealEffect` | 11 | Heals the player by a percentage of their maximum health. |
| `max_health_effect.gd` | `MaxHealthEffect` | 11 | Permanently increases the van's maximum hull health for the run. |
| `repair_window_bars_effect.gd` | `RepairWindowBarsEffect` | 70 | Look-at weld: restore `repair_amount` on a machine, door, or window. |
| `throw_grenade_effect.gd` | `ThrowGrenadeEffect` | 32 | Throws a fire grenade from the player's view direction. |
| `timed_stat_modifier_effect.gd` | `TimedStatModifierEffect` | 28 | Applies temporary gun stat modifiers, then removes them after a duration. |

### `scripts/meta/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `skill_node_definition.gd` | `SkillNodeDefinition` | 47 | One cell on the van schematic. |
| `skill_node_effect.gd` | `SkillNodeEffect` | 21 | One gameplay hook on a meta skill-tree node. |

### `scripts/meta/effects/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `van_speed_level_effect.gd` | `VanSpeedLevelEffect` | 19 | Feeds the existing MetaProgression.van_speed_level curve. |
| `vital_max_health_effect.gd` | `VitalMaxHealthEffect` | 40 | Raises interior-machine max HP. |

### `scripts/player/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `boon_behavior.gd` | `BoonBehavior` | 66 | Base class for boon combat behaviors. |
| `boon_behavior_context.gd` | `BoonBehaviorContext` | 25 | Shared payload passed to boon behavior handlers during combat events. |
| `boon_behavior_handlers.gd` | — | 79 | Concrete boon behavior handlers. |
| `boon_behavior_registry.gd` | `BoonBehaviorRegistry` | 142 | Dispatches combat events to registered boon behavior handlers. |
| `boon_combat.gd` | `BoonCombat` | 216 | Thin dispatcher for boon combat logic. |
| `boon_traits.gd` | `BoonTraits` | 75 | Stores passive boon modifiers that combat systems query at runtime. |
| `fps_player.gd` | `FpsPlayer` | 275 | The first-person player controller: movement, interaction and shooting input. |
| `usable_state.gd` | `UsableState` | 27 | Runtime state for one equipped usable item: charges and cooldown remaining. |
| `usables_controller.gd` | `UsablesController` | 166 | Owns the player's usable item slots and boon inventory for the run. |

### `scripts/stops/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `block_glyphs.gd` | `BlockGlyphs` | 172 | Stamped 5 x 7 block-letter font shared by shop flyers and street signs: glyph bit rows, text drawing into an Image, and label textures for signs. |
| `garage_lounge.gd` | — | 185 | Sparse garage furniture — sofa and a TV in one corner, empty floor otherwise. |
| `mechanic_talk.gd` | `MechanicTalk` | 133 | Mechanic bay keeper. |
| `mechanic_workshop.gd` | — | 308 | Open auto-repair bay — workbench, hoist, tires. |
| `shop_booth_flyers.gd` | — | 289 | Randomly placed sticker/flyer stickers on the shop booth face, plus their pixel-art textures. |
| `shop_booth_frame.gd` | — | 219 | Counter deck, pillars, wall panels and window/transaction openings for the shop booth. |
| `shop_booth_materials.gd` | — | 77 | Material factories for the shop counter booth — each call returns a fresh instance. |
| `shop_booth_trim.gd` | — | 231 | Armor plating, viewing grill, window brow, lamp visuals and shop sign for the shop booth. |
| `shop_counter_booth.gd` | — | 164 | Fortified metal shop counter — armored face, cash slot, eye-level grilled window. |
| `shop_hatch_net.gd` | — | 125 | Cargo-net screen on the shop hatch — thin diamond mesh, not solid bars. |
| `shop_offer.gd` | `ShopOffer` | 108 | A single priced item sitting on the shop counter. |
| `shop_stock.gd` | — | 30 | Rolls 3 unique items from the shop pool and places them on the counter. |
| `side_stop_definition.gd` | `SideStopDefinition` | 67 | A roadside stop on a fork road. |
| `side_stop_registry.gd` | `SideStopRegistry` | 113 | Resolves side-stop definitions by id from resources/side_stops/. |
| `stop_elevator.gd` | `StopElevator` | 355 | On-road lift that drops the van to the shared stop vestibule. |
| `stop_vestibule.gd` | `StopVestibule` | 287 | Shared mouth for every roadside stop. |
| `warehouse_chest.gd` | `WarehouseChest` | 60 | Table-top crate. |
| `warehouse_director.gd` | `WarehouseDirector` | 176 | Picks one hide layout per visit. |
| `warehouse_dummy.gd` | `WarehouseDummy` | 114 | Standing shootable raider for warehouse hides. |
| `warehouse_hide.gd` | `WarehouseHide` | 149 | One ambush pocket. |
| `warehouse_interior.gd` | — | 243 | Flared warehouse bay: shell, wrapped dressing, table + chest, one hide layout. |
| `warehouse_laser.gd` | `WarehouseLaser` | 72 | Waist-high trip across the aisle. |
| `warehouse_look.gd` | `WarehouseLook` | 143 | Shared palette / mesh helpers for the warehouse bay and its hide layouts. |

### `scripts/travel/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `road_floor.gd` | `RoadFloor` | 365 | Reusable corridor road slab: carriageway + raised sidewalks + curb/gutter details. |
| `road_floor_details.gd` | — | 232 | Street furniture/detail builders for RoadFloor: expansion joints, drains, manholes and sidewalk dressing. |
| `road_floor_materials.gd` | — | 35 | Static material factories for RoadFloor: procedural street shaders plus a generic StandardMaterial3D helper, shared by the core and the detail builders. |
| `travel_controller.gd` | `TravelController` | 607 | Drives the van's travel state machine: approach, turn, park and leave each stop. |
| `travel_routes.gd` | — | 264 | Owns the travel-path curve building for turns, stop parking and leaving a stop. |
| `travel_stops.gd` | — | 203 | Owns the stop fork, side-stop placement, elevator pad ride and stop-state cleanup. |
| `travel_world.gd` | — | 268 | Owns corridor tile spawning/pruning, side streets, neighborhood variants and act statues. |

### `scripts/travel/facades/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `corridor_facades.gd` | — | 249 | Owns a corridor tile's two facade sides: their openings, plans and built nodes. |
| `facade_audit.gd` | — | 122 | Shared keep-out audits for a corridor tile's built facades: the bay-mouth clearance check (nothing built in front of a stop-bay opening) and the raider-lane cl… |
| `facade_body.gd` | — | 261 | Builds one building's body: SurfaceTool quads with UV in metres (u along the facade, v up), end returns, a roof plate, the stop-bay header / flank cut, and the… |
| `facade_district.gd` | `FacadeDistrict` | 55 | One neighborhood look: skin presets, height range, ground-floor kinds, window state ratios and prop chances. |
| `facade_fixtures.gd` | — | 107 | Wall lamp fixtures and their SpotLight3D pools for one facade side: district colour, dead lamps, the world-wide light cap, and the layer-1 cull mask that keeps… |
| `facade_keep_out.gd` | — | 163 | Keep-out volumes for one facade side: the gate every facade placer passes an AABB through, so nothing ever stands in the raider lane, hangs over the road below… |
| `facade_materials.gd` | — | 315 | Static material factories for the facade system: a ShaderMaterial per building from a parameter dictionary, cached StandardMaterial3D props by key, and named s… |
| `facade_mesh_kit.gd` | — | 121 | Box-and-quad helpers shared by every facade prop builder: gated boxes into a SurfaceTool, committing an ArrayMesh node, and single BoxMesh nodes for props that… |
| `facade_overheads.gd` | — | 146 | Cross-street industrial dressing (pipe bridges, catwalks, ribs) built under Facades/Overhead when both sides are plain; it never reaches below 9 m over the roa… |
| `facade_plan.gd` | — | 191 | Plans one facade side: splits the 20 m tile edge into buildings and gives each a skin preset, height, floors, ground kind and setback. |
| `facade_props_ground.gd` | — | 329 | Ground-floor props for one building (storefront frames, awnings, roll-up lintels, loading docks, arcade pilasters, stoops, sidewalk furniture). |
| `facade_props_upper.gd` | — | 354 | Upper-facade props for one building: trim (parapet cap, cornice, string-course ledges, downspout), AC units, a fire escape, balconies, roof clutter and wall pi… |
| `facade_registry.gd` | — | 104 | Loads the facade data folders once: districts (sorted by index) and set-pieces (sorted by id). |
| `facade_set_piece.gd` | `FacadeSetPiece` | 46 | One rare street set-piece: eligibility data plus the hooks a subclass overrides. |
| `facade_set_pieces.gd` | — | 84 | Rolls which rare set-piece (if any) a tile gets and on which side, and drives the piece's hooks from corridor_facades. |
| `facade_signs.gd` | — | 285 | Street signage for one building: a backlit box sign over a storefront, a neon strip, a perpendicular blade sign, a cloth banner, or a torn poster on a boarded… |
| `facade_spans.gd` | — | 50 | Facade spans for walls that are not corridor tile sides (junction stems, branches, the T far wall, side-street flanks): a host node maps the tile body builder'… |

### `scripts/travel/facades/set_pieces/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `antenna_farm.gd` | — | 88 | A cluster of roof masts of random height, two tilted dish plates and a beacon light atop the tallest mast. |
| `blown_out_shop.gd` | — | 110 | A storefront gutted by fire: a charred black-out panel behind the first unit's glass, rubble kicked out onto the sidewalk, and police tape strung across the do… |
| `burning_tenement.gd` | — | 122 | A tenement mid-fire: flickering, broken upper windows (soot is shader-only, nothing to build), a few glowing flame slabs behind the glass, and one warm light a… |
| `chapel.gd` | — | 129 | A stone chapel front: a stained-glass rose window over the arcade, and a bell tower standing on the roof with a clock face and a pointed cap. |
| `cinema_marquee.gd` | — | 151 | A cinema marquee bolted onto a storefront: a lit canopy slab with chasing bulb strips on its three outer faces, a backlit title panel, a vertical CINEMA blade,… |
| `collapsed_block.gd` | — | 125 | A building torn open partway up: the shader discards everything above a noisy collapse edge, and rubble, standing rebar and two ragged slab stubs sell the wrec… |
| `crane_site.gd` | — | 135 | A tower crane grafted onto a bare industrial frame: a green safety net over the low floors, a lattice mast standing on the roof, a jib and counter-jib, a hangi… |
| `gas_canopy.gd` | — | 148 | A gas station canopy grafted onto a low storefront: a lit slab on two posts over the pumps, a price pole and one warm light underneath. |
| `glass_crown.gd` | — | 100 | A commercial tower stretched to its full height, capped with a glowing crown band and a red beacon on a roof mast. |
| `laundry_balconies.gd` | — | 138 | A tenement plastered in balconies: full window-grid coverage (not the rare few an ordinary building rolls), each one strung with hanging laundry. |
| `mural.gd` | — | 131 | A blank wall (windows switched off) painted with a generated mural: solid shapes plus one giant glyph word from the district's sign list. |
| `neon_blade.gd` | — | 59 | A giant neon blade bolted flat across the widest eligible face: the same two-face box builder facade_signs.gd uses for an ordinary blade, just bigger, brighter… |
| `overgrown_ruin.gd` | — | 116 | A building half-swallowed by growth: the shader crops it at a collapse edge, ivy hangs from the sills below that line, and a couple of saplings have taken root… |
| `parking_deck.gd` | — | 121 | A bare-frame parking structure: open waist bands at every deck level, fluorescent strip lighting under most slabs, and a hazard stripe marking the ramp entranc… |
| `pedestrian_bridge.gd` | — | 55 | An enclosed pedestrian bridge crossing the street: a floor and roof well above the lane, two glazed side walls, and end portals closing the gap against the fac… |
| `pipe_bridge.gd` | — | 49 | Three rusty pipes slung across the street on a shared industrial gantry: valve wheels on the middle pipe, hanger straps dropping onto the top one. |
| `power_outage.gd` | — | 13 | No geometry: kills every window's lights on the tile. |
| `radio_mast.gd` | — | 121 | A lattice radio mast on a low roof: three legs and cross rings every 2.5 m, two guy lines anchoring it to the roof, and a beacon at the top. |
| `rooftop_billboard.gd` | — | 108 | A lit billboard panel on two posts atop the shortest eligible roof, with flood lights at its base; the panel's text face reuses facade_signs.gd's two-surface b… |
| `scaffolded.gd` | — | 116 | A construction scaffold over the lower floors: two rows of standards joined by ledgers and transoms, a work plank on each level, and a green safety net over th… |
| `searchlight.gd` | — | 92 | A rooftop searchlight sweeping a tilted cone over the street: a pedestal and housing on the roof, with a beam mesh spun by scripts/travel/facades/set_pieces/se… |
| `searchlight_pivot.gd` | — | 15 | Spins a searchlight beam around its own tilted Y axis, sweeping a cone over the street. |
| `water_tower.gd` | — | 96 | A rooftop water tower: four legs, a wood tank, a conical lid and a ladder on the road side. |

### `scripts/ui/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `act_reveal_cards.gd` | — | 303 | Builds the reveal chrome (backdrop, title, card row) and the per-card visuals for ActRevealPanel: card backs, flipped faces and the continue button's stylebox. |
| `act_reveal_panel.gd` | `ActRevealPanel` | 306 | Act-start overlay: flips street cards (name + modifiers) and waits. |
| `bench_items_grid.gd` | — | 204 | Builds the boons/tools item grid cells and their hover tooltips for BenchScreen. |
| `bench_screen.gd` | `BenchScreen` | 247 | Bench overlay: stats + gold spending on the left, boons and tools on the right. |
| `boon_choice_panel.gd` | `BoonChoicePanel` | 160 | REST-break overlay: pick one of several offered boons. |
| `boot.gd` | — | 18 | Boot splash screen; preloads the van scene before handing off to the main menu. |
| `class_panel.gd` | — | 193 | Class picker overlay: one card per class, click to equip. |
| `combat_feedback.gd` | — | 36 | Spawns floating damage numbers over hit targets in a dedicated canvas layer. |
| `damage_number.gd` | `DamageNumber` | 38 | A floating label showing one damage hit, styled differently for headshots. |
| `debug_console.gd` | `DebugConsole` | 259 | In-game debug terminal. |
| `dialogue_hud.gd` | `DialogueHud` | 270 | Hover-to-highlight NPC talk, Slay-the-Spire style. |
| `driver_shout_hud.gd` | `DriverShoutHud` | 109 | Always-on GO / EASY shouts. |
| `enemy_health_bar.gd` | `EnemyHealthBar` | 60 | A billboard health bar shown above an enemy while it is damaged. |
| `item_hud.gd` | — | 88 | Hotbar for tools and a row of collected boon icons. |
| `main_menu.gd` | — | 128 | The main menu screen: save slot selection, settings panel and starting a run. |
| `pause_menu.gd` | `PauseMenu` | 93 | Esc overlay. |
| `skill_tree_hud.gd` | — | 338 | Van schematic overlay. |
| `skill_tree_nodes.gd` | — | 167 | Builds skill tree node buttons and branch labels, tracks each node's unlock/allocation state and fills the hover tooltip's text. |
| `usable_slot.gd` | — | 43 | One usable-item slot in the HUD: icon, charge count and cooldown bar. |
| `van_health_bar.gd` | `VanHealthBar` | 77 | Single hull line: left half = interior vitals (death HP), right half = doors. |

### `scripts/van/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `breakable_glass.gd` | — | 121 | Breakable window pane (rear doors or side openings). |
| `broken_iron_cross.gd` | `BrokenIronCross` | 278 | Blown-out iron + after a window breach. |
| `front_partition.gd` | — | 101 | Front cargo partition: wall panels flanking the decorative cab door. |
| `iron_cross.gd` | `IronCross` | 355 | Welded iron + on a window pane. |
| `rear_door_interact.gd` | — | 23 | Layer-2-only hit target on a rear door leaf. |
| `rear_doors.gd` | — | 400 | Truck-style rear double doors. |
| `room_zone.gd` | `RoomZone` | 15 | Marks a van interior zone; tells GameSession which room the player is in. |
| `side_door_interact.gd` | — | 23 | Layer-2-only hit target on a side door leaf. |
| `side_door_leaf.gd` | — | 285 | Builds the side door leaf meshes (body, trim, frames, latch) onto SideDoors nodes. |
| `side_doors.gd` | — | 292 | Sliding cargo-style side doors. |
| `side_window_interact.gd` | — | 23 | Layer-2 hit target on a side window sash. |
| `side_windows.gd` | — | 334 | Side cargo windows — top-hinged sashes that tip vertically outward. |
| `van.gd` | — | 398 | Van root script: wires up the van's HUD, overlays, act deck and route choices. |
| `van_bulkhead.gd` | `VanBulkhead` | 202 | Mid/rear cargo bulkhead: metal frame + diagonal mesh, side doorway. |
| `van_bulkhead_mesh.gd` | — | 225 | Builds the bulkhead's frame posts, headers, panels and diagonal mesh netting. |
| `van_ceiling.gd` | `VanCeiling` | 380 | Barrel-vault interior ceiling with headliner and cargo dressing. |
| `van_driver_talk.gd` | — | 158 | The driver-talk panel: open/close, option refresh, and boost/slow shout handling. |
| `van_floor.gd` | `VanFloor` | 340 | Worn cargo-van floor with ribbed decking plus flat floor dressing (mats, paper, tape). |
| `van_hud.gd` | — | 183 | Combat HUD readouts: ammo, health, waves, prompts, item toasts, stop toasts. |
| `van_hull_mesh.gd` | `VanHullMesh` | 400 | XY end-cap slabs that follow VanSideWall's bow and VanCeiling's barrel vault. |
| `van_lighting.gd` | `VanLighting` | 50 | Marks van interior meshes as render layer 2 so DoorSpill (cull mask layer 1) lights the corridor through openings without washing the cabin. |
| `van_overlays.gd` | — | 238 | Modal overlays: bench, skill tree, class panel, debug console, pause menu, mouse passthrough. |
| `van_player_containment.gd` | `VanPlayerContainment` | 77 | Invisible shell that keeps the player inside the van. |
| `van_route_choice.gd` | — | 287 | Builds and refreshes the ROUTE_CHOICE panel: card art, stop labels, highlight state. |
| `van_side_wall.gd` | `VanSideWall` | 378 | Curved cargo-van side liners: wider at the floor, bowed out at the waist, tapering in toward the roof — with punched openings for windows / side doors. |
| `van_side_wall_panel.gd` | — | 389 | This wall's own side panel mesh: openings, reveals, returns, and the cut queries that decide which cells are punched for the side doors and windows. |
| `van_side_wall_shell.gd` | — | 401 | Generic curved-shell / pane / frame-ring mesh builders for VanSideWall: the low-level lofting onto the cargo profile, shared by side walls, doors and windows. |
| `van_vital.gd` | `VanVital` | 91 | One interior machine whose HP is a slice of van death hull. |

### `tools/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `check_scripts.gd` | — | 45 | Headless load check. |

### `tools/scene_dump/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `scene_dump.gd` | — | 148 | Headless dump of an instantiated scene's nodes, properties, resources and connections for diffing. |

### `tools/smoke/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `smoke_driver.gd` | — | 364 | Drives a full headless playthrough of one van run to prove the game boots, the class/boon/rest UI flows work end to end, and the balance numbers stay determini… |
| `smoke_fingerprint.gd` | — | 106 | Static helpers that build the smoke driver's fingerprint lines (class stats, pools, act deck, waves, rest offer) and write them to user://. |
| `smoke_route.gd` | — | 158 | Drives the fork/side-stop portion of the smoke run (route.gd -> route choice -> stop -> back to travelling). |
| `smoke_shots.gd` | — | 74 | Screenshots for tools/smoke.py --shots. |
| `smoke_test.gd` | — | 13 | Headless smoke test entry scene. |

## Scenes

| Scene | Nodes | Root type |
|---|---|---|
| `scenes/boot/boot.tscn` | 3 | Control |
| `scenes/combat/projectile.tscn` | 4 | Area3D |
| `scenes/corridor/act_statue.tscn` | 4 | Node3D |
| `scenes/corridor/corridor_crossroads.tscn` | 21 | Node3D |
| `scenes/corridor/corridor_segment.tscn` | 11 | Node3D |
| `scenes/corridor/corridor_t_junction.tscn` | 17 | Node3D |
| `scenes/corridor/garage_bay.tscn` | 14 | Node3D |
| `scenes/corridor/mechanic_bay.tscn` | 19 | Node3D |
| `scenes/corridor/road_floor.tscn` | 1 | Node3D |
| `scenes/corridor/shop_bay.tscn` | 23 | Node3D |
| `scenes/corridor/side_street_branch.tscn` | 2 | Node3D |
| `scenes/corridor/stop_elevator.tscn` | 1 | Node3D |
| `scenes/corridor/stop_vestibule.tscn` | 4 | Node3D |
| `scenes/corridor/warehouse_bay.tscn` | 1 | Node3D |
| `scenes/enemies/biker_boss.tscn` | 2 |  |
| `scenes/enemies/window_raider.tscn` | 9 | Node3D |
| `scenes/items/pickup.tscn` | 3 | Area3D |
| `scenes/player/player.tscn` | 13 | CharacterBody3D |
| `scenes/shop/shop_offer.tscn` | 3 | StaticBody3D |
| `scenes/ui/bench_screen.tscn` | 24 | Control |
| `scenes/ui/damage_number.tscn` | 1 | Label |
| `scenes/ui/debug_console.tscn` | 8 | Control |
| `scenes/ui/driver_shout_hud.tscn` | 9 | Control |
| `scenes/ui/item_hud.tscn` | 7 | Control |
| `scenes/ui/main_menu.tscn` | 25 | Control |
| `scenes/ui/pause_menu.tscn` | 22 | Control |
| `scenes/ui/run_hud.tscn` | 43 | CanvasLayer |
| `scenes/ui/skill_tree_hud.tscn` | 19 | Control |
| `scenes/ui/usable_slot.tscn` | 6 | PanelContainer |
| `scenes/van/broken_iron_cross.tscn` | 1 | Node3D |
| `scenes/van/class_board.tscn` | 4 | StaticBody3D |
| `scenes/van/iron_cross.tscn` | 1 | Node3D |
| `scenes/van/loot_machine.tscn` | 9 | StaticBody3D |
| `scenes/van/request_board.tscn` | 4 | StaticBody3D |
| `scenes/van/van.tscn` | 56 | Node3D |
| `scenes/van/van_breach_points.tscn` | 32 | Node3D |
| `scenes/van/van_bulkhead.tscn` | 1 | StaticBody3D |
| `scenes/van/van_ceiling.tscn` | 1 | Node3D |
| `scenes/van/van_floor.tscn` | 1 | Node3D |
| `scenes/van/van_shell.tscn` | 184 | StaticBody3D |
| `scenes/van/van_side_wall.tscn` | 1 | Node3D |
| `scenes/van/van_vital_dummy.tscn` | 5 | StaticBody3D |
| `tools/scene_dump/scene_dump.tscn` | 1 | Node |
| `tools/smoke/smoke_test.tscn` | 1 | Node |

## Shaders

`scenes/corridor/asphalt_surface.gdshader`, `scenes/corridor/facade_marquee.gdshader`, `scenes/corridor/facade_sign.gdshader`, `scenes/corridor/facade_surface.gdshader`, `scenes/corridor/industrial_surface.gdshader`, `scenes/corridor/sidewalk_surface.gdshader`, `scenes/van/van_ceiling.gdshader`, `scenes/van/van_floor.gdshader`, `scenes/van/van_floor_mat.gdshader`, `scenes/van/van_floor_paper.gdshader`, `scenes/van/van_viga.gdshader`, `scenes/van/van_wall.gdshader`

## Balance sheet (`resources/balance/game_balance.tres`)

**Overridden in the .tres:**

| Field | Value |
|---|---|
| `base_damage_per_shot` | `1.5` |
| `base_fire_rate` | `1.75` |
| `segment_wave_min` | `1` |
| `segment_wave_max` | `1` |
| `act_wave_base_count` | `PackedInt32Array(2, 2, 2)` |
| `act_wave_growth_per_step` | `PackedInt32Array(1, 1, 1)` |
| `act_last_wave_extra` | `PackedInt32Array(2, 2, 3)` |
| `act_breather_chance` | `PackedFloat32Array(0.15, 0.3, 0.35)` |
| `act_engagement_seconds` | `PackedFloat32Array(10, 8, 6)` |
| `act_expected_upgrade_fraction` | `PackedFloat32Array(0.333333, 0.666667, 1)` |
| `segment_spawn_pool` | `ExtResource("2")` |
| `mob_interior_speed` | `1.6` |
| `act_target_van_speed` | `PackedFloat32Array(8, 9, 10)` |
| `mechanic_full_repair_cost` | `45` |
| `mechanic_van_boon_cost` | `40` |

**Still on script defaults (`game_balance_data.gd`):**

| Field | Default |
|---|---|
| `base_van_speed` | `8.0` |
| `spawn_distance` | `47.2` |
| `spawn_half_width` | `7.5` |
| `spawn_z_jitter` | `1.0` |
| `spawn_z_depth_min` | `-3.0` |
| `spawn_z_depth_max` | `3.0` |
| `spawn_delay_min` | `0.5` |
| `spawn_delay_max` | `2.0` |
| `inter_wave_delay` | `10.0` |
| `rear_door_breach_hp` | `96.0` |
| `window_breach_hp` | `50.0` |
| `rear_window_glass_hp` | `1.0` |
| `van_speed_max_level` | `4` |
| `van_speed_upgrade_base_cost` | `50` |
| `poison_duration` | `2.0` |
| `poison_tick_interval` | `0.5` |
| `cold_slow_duration` | `2.5` |
| `warehouse_rare_boon_chance` | `0.05` |

## Classes (`resources/classes/`)

| id | name | damage_mult | fire_rate_mult | pellets | mag | reload_s |
|---|---|---|---|---|---|---|
| basic | Basic | 1.0 | 1.0 | 1 | 8 | 3.0 |
| machinegun | Machinegun | 0.42 | 2.2 | 1 | 30 | 4.2 |
| shotgun | Shotgun | 3.11 | 0.55 | 8 | 2 | 3.8 |
| sniper | Sniper | 2.47 | 0.35 | 1 | 5 | 3.5 |

## Act street cards

| id | name | polarity | description |
|---|---|---|---|
| brass_road | Brass Road | 0 | +25% damage while this street is active |
| empty_pockets | Empty Pockets | 1 | -25% item drops |
| hairpin | Hairpin | 0 | +100% fire rate while this street is active |
| hasty_pack | Hasty Pack | 1 | Enemies move 15% faster. +10% item drops. |
| no_through | No Through Road | 1 | Next fork is a T — two streets instead of three |
| salvage_lane | Salvage Lane | 0 | +15% item drops |
| slag_barrels | Slag Barrels | 1 | Fire rate x0.75 while this street is active |
| swarm | Swarm | 1 | 50% more raiders per wave, plus one |
| thick_hides | Thick Hides | 1 | Raiders have 40% more health |
| thin_file | Thin File | 0 | Half as many raiders per wave (min 1) |

## Side stops

| id | name | short_label |
|---|---|---|
| garage | Garage | GARAGE |
| mechanic | Mechanic | MECHANIC |
| rare_shop | Undercroft | VAULT |
| shop | Shop Stop | SHOP |
| warehouse | Warehouse | WAREHOUSE |

## Enemies

| id | name | agile |
|---|---|---|
| agile_raider | Window Raider | true |
| biker_boss | Wanjna | false |
| door_raider | Door Raider | false |

## Boons

| id | name | repeatable | description |
|---|---|---|---|
| chew_tobacco | Chew Tobacco |  | Permanent grit. +1 damage for the rest of the run. |
| cold_rounds | Cold Rounds |  | Bullets slow enemies. |
| double_damage | Double Damage |  | Deal 2x damage. |
| explosive_rounds | Explosive Rounds |  | Bullets explode on impact. |
| max_hp_1 | Thick Skin | true | Gain 10 Max Health |
| max_hp_2 | Iron Constitution | true | Gain 20 Max Health |
| max_hp_3 | Titan's Heart | true | Gain 60 Max Health |
| max_hp_heal | Second Wind | true | Gain 40 Max Health and heal fully |
| max_hp_phys | Brawler's Bulk |  | Gain 10 Max Health and +1 damage |
| poison_rounds | Poison Rounds |  | Bullets poison enemies. |
| ricochet_rounds | Ricochet Rounds |  | Hardened slugs that skip off steel. Bullets bounce 2 extra times. |
| ricochet_stack | Cascading Rounds |  | Ricochets get increasingly stronger |
| rubber_casings | Rubber Casings |  | Springy casings. One extra bounce, and ricochets keep far more speed. |
| shoot_speed | Hair Trigger |  | Gain 100% shot speed |

## Items (non-boon)

| id | name | kind | shop_price |
|---|---|---|---|
| adrenaline_stim | Adrenaline Stim | 2 | 25 |
| coin_item | Coins |  |  |
| frag_grenade | Frag Grenade | 2 | 18 |
| heal_potion | Field Stimpack | 3 | 10 |
| lucky_chip | Lucky Chip |  |  |
| road_lighter | Road Lighter | 3 | 6 |
| window_bar_kit | Weld Kit | 2 | 20 |

## Loot pools

`general_boon_pool`, `goon_pool`, `rest_tools_pool`, `shop_pool`, `warehouse_rare_boon_pool`

## Sound cues (`resources/audio/sound_bank.tres`)

| id | bus | positional | min_interval | max_voices |
|---|---|---|---|---|
| gun_fire | SFX | false | 0.04 | 4 |
| gun_reload | SFX | false | 0.15 | 2 |
| bullet_impact | SFX | true | 0.04 | 3 |
| bullet_ricochet | SFX | true | 0.04 | 2 |
| breach | SFX | true | 0.08 | 4 |
| glass_shatter | SFX | true | 0.05 | 4 |
| window_open | Interior | true | 0.05 | 4 |
| window_close | Interior | true | 0.05 | 4 |
| usable | SFX | false | 0.05 | 2 |
| coin | SFX | false | 0.04 | 4 |
| enemy_down | SFX | true | 0.05 | 4 |
| stinger_combat | SFX | false | 0.0 | 4 |
| stinger_rest | SFX | false | 0.0 | 4 |
| stinger_reveal | SFX | false | 0.0 | 4 |
| stinger_game_over | SFX | false | 0.0 | 4 |
| shout_start | SFX | false | 0.2 | 1 |
| shout_slow | SFX | false | 0.2 | 1 |
| shout_resume | SFX | false | 0.2 | 1 |
| shout_turbo | SFX | false | 0.2 | 1 |

## Boon trait keys

| Constant | StringName |
|---|---|
| `RICOCHET_STACK_POWER` | `ricochet_stack_power` |
| `EXPLOSIVE_ROUNDS` | `explosive_rounds` |
| `POISON_ROUNDS` | `poison_rounds` |
| `COLD_ROUNDS` | `cold_rounds` |
| `GUN_FIRE_RATE` | `gun_fire_rate` |
| `GUN_DAMAGE_PER_SHOT` | `gun_damage_per_shot` |
| `GUN_BULLET_SPEED` | `gun_bullet_speed` |
| `GUN_BULLET_WEIGHT` | `gun_bullet_weight` |
| `GUN_BULLET_SIZE` | `gun_bullet_size` |
| `GUN_RELOAD_SPEED` | `gun_reload_speed` |
| `GUN_MAG_SIZE` | `gun_mag_size` |
| `GUN_AIM_RANGE` | `gun_aim_range` |
| `GUN_EXPLOSION_RADIUS` | `gun_explosion_radius` |
| `GUN_MAX_BOUNCES` | `gun_max_bounces` |
| `GUN_BOUNCE_SPEED_RETENTION` | `gun_bounce_speed_retention` |
| `GUN_BOUNCE_DAMAGE_RETENTION` | `gun_bounce_damage_retention` |

## Debug console commands

`help`, `chill`, `unchill`, `speed`, `unspeed`, `summon`, `give`, `spawn`, `coins`, `heal`, `phase`, `list`, `card`, `stop`, `boss`, `reardoor`, `sidedoor`, `class`, `sound`, `parts`, `tree_reset`, `facade`
