# PROJECT_MAP — van-gunner
> **Generated file. Do not hand-edit.** Regenerate with `python3 tools/gen_context.py`.
> Design intent, invariants and gotchas live in `AGENTS.md`, which *is* hand-written.

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

Looked up: `act_deck_controller`, `agile`, `boon_reward_controller`, `breach_controller`, `breach_points`, `cabin_nav`, `dialogue_hud`, `encounter_director`, `enemy`, `gun_controller`, `gun_stats`, `head_hitbox`, `pickup`, `player`, `rear_doors`, `side_doors`, `side_windows`, `travel_controller`, `van_run`, `van_vitals`

## Signals and enums

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

**`scripts/run/act_card_definition.gd`**

- `enum Polarity { BLESSING = 0, DANGER = 1, }`

**`scripts/run/act_deck_controller.gd`**

- `signal reveal_resolved`
- `signal boss_pick_resolved`

**`scripts/run/biker_boss.gd`**

- `enum BikePhase { IDLE, CHARGE, WINDUP, PEEL, WEAVE, ENTERING, BENCH }`

**`scripts/run/boon_reward_controller.gd`**

- `signal rest_resolved`

**`scripts/run/breach_point.gd`**

- `signal breached`
- `signal health_changed(current: float, maximum: float)`
- `enum Kind { REAR_DOOR, SIDE_DOOR, WINDOW, SIDE_DOOR_WINDOW }`

**`scripts/run/breakable_glass.gd`**

- `signal shattered`

**`scripts/run/cabin_nav.gd`**

- `enum Room { BACK, CABIN }`

**`scripts/run/rear_doors.gd`**

- `signal opened`
- `signal closed`
- `signal door_changed(side: StringName, is_open: bool)`
- `signal glass_shattered(side: StringName)`

**`scripts/run/side_doors.gd`**

- `signal opened`
- `signal closed`
- `signal door_changed(side: StringName, is_open: bool)`
- `signal passage_changed(side: StringName, is_passable: bool)`

**`scripts/run/side_stop_definition.gd`**

- `enum Arrival { REAR_PARK = 0, ELEVATOR = 1, }`

**`scripts/run/side_windows.gd`**

- `signal opened`
- `signal closed`
- `signal window_changed(window_id: StringName, is_open: bool)`

**`scripts/run/travel_controller.gd`**

- `enum TurnState { NONE, APPROACHING, TURNING, PARKING, LEAVING_STOP, ELEVATING, }`

**`scripts/run/van_bulkhead.gd`**

- `enum OpeningSide { LEFT, RIGHT }`

**`scripts/run/van_vital.gd`**

- `signal health_changed(current: float, maximum: float)`

**`scripts/run/warehouse_hide.gd`**

- `signal triggered`
- `enum Reveal { BURST, FALL, PEEL }`

**`scripts/run/warehouse_laser.gd`**

- `signal sprung`

**`scripts/run/window_raider.gd`**

- `signal attack_landed(amount: float)`
- `signal defeated`
- `signal assault_finished`
- `enum AssaultPhase { IDLE, APPROACH, BREACHING, ENTERING, ATTACKING_BENCH, ATTACKING_PLAYER }`

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


## Script index

159 GDScript files, 27202 lines.

### `scenes/corridor/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `corridor_segment.gd` | — | 171 | Open a wall gap for a side-stop bay without showing the cosmetic side street. |
| `corridor_t_junction.gd` | — | 64 | Fills sidewalk corners where stem / branch / optional through-road meet the |
| `side_street_branch.gd` | — | 19 |  |

### `scripts/audio/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `audio_director.gd` | — | 368 | Central sound playback. Gameplay code says *what happened* (`&"gun_fire"`), |
| `sound_bank.gd` | `SoundBank` | 42 | Flat list of SoundCues, indexed by id once at load. |
| `sound_cue.gd` | `SoundCue` | 41 | One addressable sound. Adding audio should mean adding a .tres, never a |

### `scripts/classes/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `class_catalog.gd` | `ClassCatalog` | 68 | Resolves player classes by id from resources/classes/. Unknown ids fall back |
| `class_definition.gd` | `ClassDefinition` | 42 | One player class: a single gun with its base stats. Identity only — damage |

### `scripts/combat/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `arm_cannon_mesh.gd` | `ArmCannonMesh` | 176 | Boxy Mega Man forearm cannons. Rear face stays at REAR_Z so length grows |
| `bullet_trail.gd` | `BulletTrail` | 117 | The one trail colour now that bullets carry no damage type. |
| `bullet_visual.gd` | `BulletVisual` | 161 | Cosmetic bullet mesh + trail. Starts at the gun muzzle and flies on a frozen |
| `damage_info.gd` | `DamageInfo` | 49 | One hit: a single damage number plus where it landed. There are no damage |
| `damage_resolver.gd` | `DamageResolver` | 110 | Splash is a share of the hit that caused it, with distance falloff. It is |
| `explosion_fx.gd` | `ExplosionFx` | 304 | Pixel-art billboard blast. The ring's outer edge is the same sphere |
| `grenade.gd` | `Grenade` | 159 | Hand-integrated ballistics instead of a RigidBody3D. |
| `gun_controller.gd` | `GunController` | 322 | Hit/miss for the HUD once the first pellet resolves. Not a muzzle event. |
| `gun_stats.gd` | `GunStats` | 46 | Defaults match game_balance.tres; GunStatsController still re-seeds from GameBalance. |
| `gun_stats_controller.gd` | `GunStatsController` | 152 | GameBalance floor, then the class identity. Boons and stims come after, in |
| `gun_viewmodel.gd` | `GunViewmodel` | 222 | Viewmodel motion: quarter-roll per shot, tip-up accelerating spin on reload |
| `projectile.gd` | `Projectile` | 319 | Distance the bullet is pushed off a surface after a bounce so the next sweep |
| `projectile_pool.gd` | — | 82 | Reuses Projectile nodes to avoid instantiate/free churn during heavy fire. |
| `stat_modifier.gd` | `StatModifier` | 13 |  |
| `status_effect_controller.gd` | `StatusEffectController` | 128 | Poison stacks and the cold slow on one enemy. There is no burn and no freeze: |

### `scripts/core/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `game_balance.gd` | — | 188 | Runtime facade over the Inspector-editable GameBalanceData resource. |
| `game_balance_data.gd` | `GameBalanceData` | 149 | Inspector-editable balance sheet for encounter pacing and act scaling. |
| `game_session.gd` | — | 812 | Interior machines that sum to van death HP. Equal share of van_max_health. |
| `loot_collector.gd` | — | 226 | Hopper for street-kill loot. Floor drops stay walkable; REST vacuums |
| `meta_progression.gd` | — | 344 | Preload-as-type: this autoload cannot name SkillNodeDefinition / the tree |
| `save_manager.gd` | — | 96 |  |
| `save_sandbox.gd` | `SaveSandbox` | 8 | Test switch: when on, SaveManager and MetaProgression never touch user://. |
| `scene_router.gd` | — | 73 | Sync load on the main thread. Threaded load of van.tscn fails cold with a |
| `skill_tree_registry.gd` | — | 94 | Resolves skill-tree nodes from resources/meta/tree/. Not an autoload and |

### `scripts/debug/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `debug_commands.gd` | — | 673 | Parses and runs debug console commands. Add new commands in _register_commands(). |
| `debug_config.gd` | `DebugConfig` | 7 | Set true to ship the console in a release export. Default follows the build. |

### `scripts/dialogue/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `dialogue_choice.gd` | `DialogueChoice` | 21 | One option in an NPC talk. Built in code; the HUD just renders it. |
| `npc_talk.gd` | `NpcTalk` | 116 | Look + E opens talk. Hover + click picks; E or walking off closes. |

### `scripts/enemies/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `enemy_definition.gd` | `EnemyDefinition` | 14 | Data-only description of a spawnable enemy type. |
| `enemy_spawn_pool.gd` | `EnemySpawnPool` | 48 | A weighted collection of enemies to roll spawns from. |
| `enemy_spawn_pool_entry.gd` | `EnemySpawnPoolEntry` | 8 | A single weighted slot inside an EnemySpawnPool. |

### `scripts/interactions/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `cab_door.gd` | — | 185 | Decorative cab-facing door at the front partition. |
| `class_board.gd` | — | 21 | Wall board where the run's class is picked. Only IDLE lets it change; for the |
| `crafting_table.gd` | `CraftingTable` | 9 |  |
| `interactable.gd` | `Interactable` | 13 |  |
| `loot_machine.gd` | `LootMachine` | 31 | Left-wall hopper. Street-kill loot queues here; E on the cabinet ejects one item. |
| `request_board.gd` | — | 8 |  |

### `scripts/items/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `boon_trait_keys.gd` | `BoonTraitKeys` | 62 | StringName keys for passive boon traits stored on BoonTraits. |
| `item_definition.gd` | `ItemDefinition` | 98 | Data-only description of a single item. |
| `item_describer.gd` | `ItemDescriber` | 183 | Turns item resources into readable lines for UI. Effects only carry raw |
| `item_effect.gd` | `ItemEffect` | 20 | Base class for anything an item/boon does when it is collected. |
| `item_pool_registry.gd` | `ItemPoolRegistry` | 101 | Loads loot pools by name. Pools are plain LootPool .tres files. |
| `item_registry.gd` | `ItemRegistry` | 63 | Resolves item definitions by id from the standard item directories. |
| `item_usable_config.gd` | `ItemUsableConfig` | 24 | Runtime rules for tools and abilities held in the player's hotbar. |
| `loot_catch.gd` | `LootCatch` | 33 | One hopper / popup entry wrapping a dropped ItemDefinition. |
| `loot_pool.gd` | `LootPool` | 62 | A weighted collection of items to roll drops from. |
| `loot_pool_entry.gd` | `LootPoolEntry` | 8 | A single weighted slot inside a LootPool. |
| `pickup.gd` | `Pickup` | 285 | Walk into a floor pickup to use it. Idle pickups bob, spin, and gently |

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
| `skill_node_definition.gd` | `SkillNodeDefinition` | 47 | One cell on the van schematic. Gameplay lives in `effects`; layout is grid |
| `skill_node_effect.gd` | `SkillNodeEffect` | 21 | One gameplay hook on a meta skill-tree node. Nodes hold an Array of these — |

### `scripts/meta/effects/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `van_speed_level_effect.gd` | `VanSpeedLevelEffect` | 19 | Feeds the existing MetaProgression.van_speed_level curve. Do not invent a |
| `vital_max_health_effect.gd` | `VitalMaxHealthEffect` | 40 | Raises interior-machine max HP. Empty vital_id applies `amount` to each of |

### `scripts/player/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `boon_behavior.gd` | `BoonBehavior` | 66 | Base class for boon combat behaviors. |
| `boon_behavior_context.gd` | `BoonBehaviorContext` | 25 | Shared payload passed to boon behavior handlers during combat events. |
| `boon_behavior_handlers.gd` | — | 79 | Concrete boon behavior handlers. Each inner class maps one trait to combat logic. |
| `boon_behavior_registry.gd` | `BoonBehaviorRegistry` | 142 | Dispatches combat events to registered boon behavior handlers. |
| `boon_combat.gd` | `BoonCombat` | 216 | Thin dispatcher for boon combat logic. All behavior lives in BoonBehaviorRegistry handlers. |
| `boon_traits.gd` | `BoonTraits` | 75 | Stores passive boon modifiers that combat systems query at runtime. |
| `fps_player.gd` | `FpsPlayer` | 272 | The equipped class; applied on ready and again whenever GameSession changes it. |
| `usable_state.gd` | `UsableState` | 26 |  |
| `usables_controller.gd` | `UsablesController` | 165 | Ids of the player's boons that cannot be taken again. Every offer (rest |

### `scripts/run/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `act_card_combat.gd` | `ActCardCombat` | 148 | Dispatcher for active street cards — mirrors BoonCombat for act cards. |
| `act_card_definition.gd` | `ActCardDefinition` | 27 | Combat behavior lives in composable `effects`. Boss fights activate an Array of |
| `act_card_effect.gd` | `ActCardEffect` | 45 | Base class for anything an active street card does while it is the road. |
| `act_card_effect_context.gd` | `ActCardEffectContext` | 39 | Shared bag for street-card effect hooks. Effects mutate fields; ActCardCombat |
| `act_card_registry.gd` | `ActCardRegistry` | 48 | Resolves act street-card definitions by id from resources/acts/cards/. |
| `act_deck_controller.gd` | `ActDeckController` | 150 | Owns act-start tarot reveals and the act-end boss pick. |
| `biker_boss.gd` | `BikerBoss` | 310 | Wanjna: hit-and-run biker. Fast charge, slow axe on a door, peel and weave. |
| `boon_reward_controller.gd` | `BoonRewardController` | 146 | During REST, grants a 3-choice boon for the street card committed at the last fork. |
| `breach_controller.gd` | `BreachController` | 277 | Assigns raid slots around the van and interior vital damage targets. |
| `breach_point.gd` | `BreachPoint` | 365 | Outside attack slot that must be breached (or opened) before mobs can enter. |
| `breakable_glass.gd` | — | 121 | Breakable window pane (rear doors or side openings). Surrounding metal stays. |
| `broken_iron_cross.gd` | `BrokenIronCross` | 278 | Blown-out iron + after a window breach. Same local frame as IronCross: |
| `cabin_nav.gd` | `CabinNav` | 477 | Van-local waypoint graph + occupancy. Raiders stay Node3D; this is how they |
| `encounter_director.gd` | `EncounterDirector` | 411 | Soft cap: after this, surviving raiders of the current wave retreat. |
| `front_partition.gd` | — | 101 | Front cargo partition: wall panels flanking the decorative cab door. |
| `garage_lounge.gd` | — | 185 | Sparse garage furniture — sofa and a TV in one corner, empty floor otherwise. |
| `iron_cross.gd` | `IronCross` | 355 | Welded iron + on a window pane. Local XY is the glass face; +Z is outward. |
| `loot_drop_component.gd` | `LootDropComponent` | 62 | Drop-in component that gives any enemy a chance to drop loot on death. |
| `mechanic_talk.gd` | `MechanicTalk` | 133 | Mechanic bay keeper. Three buys: full van patch, a van-pool boon, a weld kit. |
| `mechanic_workshop.gd` | — | 308 | Open auto-repair bay — workbench, hoist, tires. No shop counter. |
| `rear_door_interact.gd` | — | 23 | Layer-2-only hit target on a rear door leaf. Toggles that leaf only. |
| `rear_doors.gd` | — | 400 | Truck-style rear double doors. |
| `road_floor.gd` | `RoadFloor` | 609 | Reusable corridor road slab: carriageway + raised sidewalks + curb/gutter |
| `room_zone.gd` | `RoomZone` | 14 |  |
| `shop_counter_booth.gd` | — | 1013 | Fortified metal shop counter — armored face, cash slot, eye-level grilled window. |
| `shop_hatch_net.gd` | — | 125 | Cargo-net screen on the shop hatch — thin diamond mesh, not solid bars. |
| `shop_offer.gd` | `ShopOffer` | 108 | A single priced item sitting on the shop counter. Look + E to buy with gold. |
| `shop_stock.gd` | — | 30 | Rolls 3 unique items from the shop pool and places them on the counter. |
| `side_door_interact.gd` | — | 23 | Layer-2-only hit target on a side door leaf. Toggles that leaf only. |
| `side_doors.gd` | — | 558 | Sliding cargo-style side doors. |
| `side_stop_definition.gd` | `SideStopDefinition` | 67 | A roadside stop on a fork road. Every offered street gets one, regardless |
| `side_stop_registry.gd` | `SideStopRegistry` | 113 | Resolves side-stop definitions by id from resources/side_stops/. |
| `side_window_interact.gd` | — | 23 | Layer-2 hit target on a side window sash. Toggles that sash only. |
| `side_windows.gd` | — | 334 | Side cargo windows — top-hinged sashes that tip vertically outward. |
| `stop_elevator.gd` | `StopElevator` | 355 | On-road lift that drops the van to the shared stop vestibule. Content |
| `stop_vestibule.gd` | `StopVestibule` | 287 | Shared mouth for every roadside stop. Content (shop, garage, mechanic, |
| `travel_controller.gd` | `TravelController` | 1283 | Empty corridor tiles required between side-street openings (avoids a thin |
| `van.gd` | — | 1163 | Preload so van.tscn can type the bar without a class_name parse cycle. |
| `van_bulkhead.gd` | `VanBulkhead` | 410 | Mid/rear cargo bulkhead: metal frame + diagonal mesh, side doorway. |
| `van_ceiling.gd` | `VanCeiling` | 380 | Barrel-vault interior ceiling with headliner and cargo dressing. |
| `van_floor.gd` | `VanFloor` | 340 | Worn cargo-van floor with ribbed decking plus flat floor dressing (mats, paper, tape). |
| `van_hull_mesh.gd` | `VanHullMesh` | 400 | XY end-cap slabs that follow VanSideWall's bow and VanCeiling's barrel vault. |
| `van_lighting.gd` | `VanLighting` | 49 | Marks van interior meshes as render layer 2 so DoorSpill (cull mask layer 1) |
| `van_player_containment.gd` | `VanPlayerContainment` | 77 | Invisible shell that keeps the player inside the van. Uses a dedicated physics |
| `van_side_wall.gd` | `VanSideWall` | 1058 | Curved cargo-van side liners: wider at the floor, bowed out at the waist, |
| `van_vital.gd` | `VanVital` | 91 | One interior machine whose HP is a slice of van death hull. |
| `warehouse_chest.gd` | `WarehouseChest` | 60 | Table-top crate. E opens a bonus 3-choice boon, then springs leftover hides. |
| `warehouse_director.gd` | `WarehouseDirector` | 176 | Picks one hide layout per visit. Early triggers (shoot / walk / laser) or |
| `warehouse_dummy.gd` | `WarehouseDummy` | 114 | Standing shootable raider for warehouse hides. Not in `&"enemy"` — street |
| `warehouse_hide.gd` | `WarehouseHide` | 149 | One ambush pocket. `trigger()` is idempotent — shooting, walking a volume, |
| `warehouse_interior.gd` | — | 243 | Flared warehouse bay: shell, wrapped dressing, table + chest, one hide layout. |
| `warehouse_laser.gd` | `WarehouseLaser` | 72 | Waist-high trip across the aisle. Jump over to stay quiet; walking through |
| `warehouse_look.gd` | `WarehouseLook` | 143 | Shared palette / mesh helpers for the warehouse bay and its hide layouts. |
| `window_raider.gd` | `WindowRaider` | 667 | Agile raiders can climb window bars; door mobs only smash doors. |

### `scripts/run/effects/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `enemy_health_mult_effect.gd` | `EnemyHealthMultEffect` | 20 | Scales raider max/current health on spawn (dangers that make fights longer). |
| `enemy_loot_bonus_effect.gd` | `EnemyLootBonusEffect` | 11 | Adds to the item drop chance roll on enemy death (0.1 = +10%). |
| `enemy_speed_mult_effect.gd` | `EnemySpeedMultEffect` | 18 | Scales raider world chase speed on spawn (1.15 = 15% faster). |
| `narrow_fork_effect.gd` | `NarrowForkEffect` | 12 | After this street, the next fork is a T — two face-up cards instead of three. |
| `temp_boon_trait_effect.gd` | `TempBoonTraitEffect` | 18 | While this street is active, grants a boon trait via BoonTraits street overlay. |
| `wave_count_mult_effect.gd` | `WaveCountMultEffect` | 19 | Bumps each wave's spawn count (danger roads). Multiplies then optionally adds. |

### `scripts/ui/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `act_reveal_panel.gd` | `ActRevealPanel` | 580 | Act-start overlay: flips street cards (name + modifiers) and waits. |
| `bench_screen.gd` | `BenchScreen` | 434 | Bench overlay: stats + gold spending on the left, boons and tools on the right. |
| `boon_choice_panel.gd` | `BoonChoicePanel` | 160 | REST-break overlay: pick one of several offered boons. |
| `boot.gd` | — | 17 | Defer van preload one frame so global class registration finishes. |
| `class_panel.gd` | — | 193 | Class picker overlay: one card per class, click to equip. The class board |
| `combat_feedback.gd` | — | 35 |  |
| `damage_number.gd` | `DamageNumber` | 37 |  |
| `debug_console.gd` | `DebugConsole` | 259 | In-game debug terminal. H to open, Esc to close. |
| `dialogue_hud.gd` | `DialogueHud` | 270 | Hover-to-highlight NPC talk, Slay-the-Spire style. Click picks; E walks away. |
| `driver_shout_hud.gd` | `DriverShoutHud` | 109 | Always-on GO / EASY shouts. van.gd plays shout_start / shout_turbo / shout_slow / shout_resume. |
| `enemy_health_bar.gd` | `EnemyHealthBar` | 59 |  |
| `item_hud.gd` | — | 88 | Hotbar for tools and a row of collected boon icons. |
| `main_menu.gd` | — | 127 | Rejected files (old version, corrupt JSON) used to look like NEW RUN |
| `pause_menu.gd` | `PauseMenu` | 93 | Esc overlay. PROCESS_MODE_ALWAYS so Resume/Esc still work while the tree is paused. |
| `skill_tree_hud.gd` | — | 487 | Van schematic overlay. Hover/click nodes; pending requests ghost until the |
| `usable_slot.gd` | — | 42 |  |
| `van_health_bar.gd` | `VanHealthBar` | 77 | Single hull line: left half = interior vitals (death HP), right half = doors. |

### `tools/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `check_scripts.gd` | — | 45 | Headless load check. Loads every script, scene, resource and shader under res:// |

### `tools/smoke/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `smoke_driver.gd` | — | 354 | Drives a full headless playthrough of one van run to prove the game boots, |
| `smoke_test.gd` | — | 13 | Headless smoke test entry scene. Spawns the driver under the root because |

## Scenes

| Scene | Nodes | Root type |
|---|---|---|
| `scenes/boot/boot.tscn` | 3 | Control |
| `scenes/combat/projectile.tscn` | 4 | Area3D |
| `scenes/corridor/act_statue.tscn` | 4 | Node3D |
| `scenes/corridor/corridor_crossroads.tscn` | 37 | Node3D |
| `scenes/corridor/corridor_segment.tscn` | 84 | Node3D |
| `scenes/corridor/corridor_t_junction.tscn` | 31 | Node3D |
| `scenes/corridor/garage_bay.tscn` | 14 | Node3D |
| `scenes/corridor/mechanic_bay.tscn` | 19 | Node3D |
| `scenes/corridor/road_floor.tscn` | 1 | Node3D |
| `scenes/corridor/shop_bay.tscn` | 23 | Node3D |
| `scenes/corridor/side_street_branch.tscn` | 10 | Node3D |
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
| `scenes/ui/skill_tree_hud.tscn` | 19 | Control |
| `scenes/ui/usable_slot.tscn` | 6 | PanelContainer |
| `scenes/van/broken_iron_cross.tscn` | 1 | Node3D |
| `scenes/van/class_board.tscn` | 4 | StaticBody3D |
| `scenes/van/iron_cross.tscn` | 1 | Node3D |
| `scenes/van/loot_machine.tscn` | 9 | StaticBody3D |
| `scenes/van/request_board.tscn` | 4 | StaticBody3D |
| `scenes/van/van.tscn` | 312 | Node3D |
| `scenes/van/van_bulkhead.tscn` | 1 | StaticBody3D |
| `scenes/van/van_ceiling.tscn` | 1 | Node3D |
| `scenes/van/van_floor.tscn` | 1 | Node3D |
| `scenes/van/van_side_wall.tscn` | 1 | Node3D |
| `scenes/van/van_vital_dummy.tscn` | 5 | StaticBody3D |
| `tools/smoke/smoke_test.tscn` | 1 | Node |

## Shaders

`scenes/corridor/asphalt_surface.gdshader`, `scenes/corridor/industrial_surface.gdshader`, `scenes/corridor/sidewalk_surface.gdshader`, `scenes/van/van_ceiling.gdshader`, `scenes/van/van_floor.gdshader`, `scenes/van/van_floor_mat.gdshader`, `scenes/van/van_floor_paper.gdshader`, `scenes/van/van_viga.gdshader`, `scenes/van/van_wall.gdshader`

## Balance sheet (`resources/balance/game_balance.tres`)

**Overridden in the .tres:**

| Field | Value |
|---|---|
| `base_damage_per_shot` | `1.5` |
| `base_fire_rate` | `1.75` |
| `segment_wave_min` | `2` |
| `segment_wave_max` | `4` |
| `act_wave_base_count` | `PackedInt32Array(2, 2, 2)` |
| `act_wave_growth_per_step` | `PackedInt32Array(1, 1, 1)` |
| `act_last_wave_extra` | `PackedInt32Array(2, 2, 3)` |
| `act_breather_chance` | `PackedFloat32Array(0.15, 0.3, 0.35)` |
| `act_engagement_seconds` | `PackedFloat32Array(10, 8, 6)` |
| `act_expected_upgrade_fraction` | `PackedFloat32Array(0.333333, 0.666667, 1)` |
| `segment_spawn_pool` | `ExtResource("2")` |
| `act_target_van_speed` | `PackedFloat32Array(8, 9, 10)` |

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
| `mob_interior_speed` | `1.6` |
| `van_speed_max_level` | `4` |
| `van_speed_upgrade_base_cost` | `50` |
| `mechanic_full_repair_cost` | `45` |
| `mechanic_van_boon_cost` | `40` |
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

`help`, `chill`, `unchill`, `speed`, `unspeed`, `summon`, `give`, `spawn`, `coins`, `heal`, `phase`, `list`, `card`, `stop`, `boss`, `reardoor`, `sidedoor`, `class`, `sound`, `parts`, `tree_reset`
