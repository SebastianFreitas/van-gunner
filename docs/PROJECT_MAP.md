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

Registered: `act_deck_controller`, `agile`, `boon_reward_controller`, `boss`, `breach_controller`, `breach_points`, `encounter_director`, `enemy`, `gun_controller`, `gun_stats`, `head_hitbox`, `pickup`, `player`, `rear_doors`, `side_doors`, `side_windows`, `travel_controller`, `van_run`, `weapon_pickup`, `weapon_replace_prompt`

Looked up: `act_deck_controller`, `agile`, `boon_reward_controller`, `breach_controller`, `breach_points`, `encounter_director`, `enemy`, `gun_controller`, `gun_stats`, `head_hitbox`, `pickup`, `player`, `rear_doors`, `side_doors`, `side_windows`, `travel_controller`, `van_run`, `weapon_replace_prompt`

## Signals and enums

**`scripts/combat/damage_type.gd`**

- `enum Type { NORMAL, EXPLOSIVE, POISON, FIRE, LIGHTNING, COLD, }`

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
- `signal route_chosen(direction: StringName, step: int)`
- `signal wave_changed(wave: int)`
- `signal room_changed(room: StringName)`
- `signal coins_changed(total: int)`
- `signal enemy_defeated(enemy: Node)`
- `signal session_loaded`
- `signal chill_mode_changed(enabled: bool)`
- `signal area_changed(area: ItemDefinition.BoonPool)`
- `enum RunPhase { IDLE, TRAVELLING, COMBAT, ROUTE_CHOICE, TURNING, GAME_OVER, REST, PARKING, STOP, ACT_REVEAL, BOSS_PICK, }`

**`scripts/core/meta_progression.gd`**

- `signal van_speed_changed(level: int, speed: float)`

**`scripts/interactions/crafting_table.gd`**

- `signal opened`

**`scripts/items/item_definition.gd`**

- `enum ItemKind { MONEY = 0, BOON = 1, TOOL = 2, CONSUMABLE = 3, }`
- `enum BoonPool { GENERAL, FIRE, POISON, COLD, PHYSICAL, }`

**`scripts/items/item_usable_config.gd`**

- `enum RechargeMode { NONE, COOLDOWN, ON_KILL, }`

**`scripts/items/pickup.gd`**

- `enum _AnimState { SPIN, FACE }`

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

**`scripts/run/side_windows.gd`**

- `signal opened`
- `signal closed`
- `signal window_changed(window_id: StringName, is_open: bool)`

**`scripts/run/travel_controller.gd`**

- `enum TurnState { NONE, APPROACHING, TURNING, PARKING, LEAVING_STOP, }`

**`scripts/run/van_bulkhead.gd`**

- `enum OpeningSide { LEFT, RIGHT }`

**`scripts/run/warehouse_hide.gd`**

- `signal triggered`
- `enum Reveal { BURST, FALL, PEEL }`

**`scripts/run/warehouse_laser.gd`**

- `signal sprung`

**`scripts/run/window_raider.gd`**

- `signal attack_landed(amount: float)`
- `signal defeated`
- `signal assault_finished`
- `enum AssaultPhase { IDLE, APPROACH, BREACHING, ENTERING, ATTACKING_BENCH }`

**`scripts/ui/act_reveal_panel.gd`**

- `signal reveal_finished`
- `signal boss_cards_picked(card_ids: Array)`
- `enum Mode { ACT_REVEAL, BOSS_PICK }`

**`scripts/ui/bench_screen.gd`**

- `signal closed`

**`scripts/ui/boon_choice_panel.gd`**

- `signal choice_made(item: ItemDefinition)`

**`scripts/ui/debug_console.gd`**

- `signal opened`
- `signal closed`

**`scripts/ui/driver_shout_hud.gd`**

- `signal boost_pressed`
- `signal slow_pressed`

**`scripts/ui/weapon_replace_prompt.gd`**

- `signal resolved(replaced: bool)`

**`scripts/weapons/weapon_definition.gd`**

- `enum Family { BASIC, SHOTGUN, MACHINEGUN, SNIPER }`
- `enum Tier { BASE, A1 }`
- `enum Element { NONE, FIRE, COLD, POISON }`

**`scripts/weapons/weapon_inventory.gd`**

- `signal loadout_changed`
- `signal active_weapon_changed(index: int, instance: WeaponInstance)`
- `signal weapon_pickup_rejected(reason: String)`
- `enum AddResult { STORED, REPLACED, REJECTED }`

**`scripts/weapons/weapon_mod.gd`**

- `enum Grade { INTERIOR, EXTERIOR }`
- `enum Operator { INCREASED }`


## Script index

149 GDScript files, 25165 lines.

### `scenes/corridor/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `corridor_segment.gd` | — | 161 | Open a wall gap for a side-stop bay without showing the cosmetic side street. |
| `corridor_t_junction.gd` | — | 64 | Fills sidewalk corners where stem / branch / optional through-road meet the |
| `side_street_branch.gd` | — | 19 |  |

### `scripts/audio/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `audio_director.gd` | — | 379 | Central sound playback. Gameplay code says *what happened* (`&"gun_fire"`), |
| `sound_bank.gd` | `SoundBank` | 42 | Flat list of SoundCues, indexed by id once at load. |
| `sound_cue.gd` | `SoundCue` | 41 | One addressable sound. Adding audio should mean adding a .tres, never a |

### `scripts/combat/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `arm_cannon_mesh.gd` | `ArmCannonMesh` | 176 | Boxy Mega Man forearm cannons. Rear face stays at REAR_Z so length grows |
| `bullet_trail.gd` | `BulletTrail` | 136 | When set, points are stored in this node's local space (usually VanRig) so the |
| `bullet_visual.gd` | `BulletVisual` | 161 | Cosmetic bullet mesh + trail. Starts at the gun muzzle and flies on a frozen |
| `damage_info.gd` | `DamageInfo` | 79 | Extra headshot multiplier from weapon Critical Damage % mods (1.0 = none). |
| `damage_resolver.gd` | `DamageResolver` | 135 |  |
| `damage_type.gd` | `DamageType` | 12 |  |
| `grenade.gd` | `Grenade` | 201 | Hand-integrated ballistics instead of a RigidBody3D. |
| `gun_controller.gd` | `GunController` | 404 | Hit/miss for the HUD once the first pellet resolves. Not a muzzle event. |
| `gun_stats.gd` | `GunStats` | 61 | Defaults match game_balance.tres; GunStatsController still re-seeds from GameBalance. |
| `gun_stats_controller.gd` | `GunStatsController` | 136 | Balance floor + definition identity + weapon mods, then boons/temp mods. |
| `gun_viewmodel.gd` | `GunViewmodel` | 222 | Viewmodel motion: quarter-roll per shot, tip-up accelerating spin on reload |
| `projectile.gd` | `Projectile` | 380 | Distance the bullet is pushed off a surface after a bounce so the next sweep |
| `projectile_pool.gd` | — | 82 | Reuses Projectile nodes to avoid instantiate/free churn during heavy fire. |
| `stat_modifier.gd` | `StatModifier` | 13 |  |
| `status_effect_controller.gd` | `StatusEffectController` | 220 |  |

### `scripts/core/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `game_balance.gd` | — | 287 | Runtime facade over the Inspector-editable GameBalanceData resource. |
| `game_balance_data.gd` | `GameBalanceData` | 146 | Inspector-editable balance sheet for encounter pacing and act scaling. |
| `game_session.gd` | — | 638 | How many face-down streets the player commits to the act boss. Array-backed |
| `loot_collector.gd` | — | 88 | Teleports shot/swept pickups onto the van's center table. Gold is converted |
| `meta_progression.gd` | — | 131 | FUTURE — persistent street-card back marks (meta, all runs): |
| `save_manager.gd` | — | 100 |  |
| `scene_router.gd` | — | 68 | Sync load on the main thread. Threaded load of van.tscn fails cold with a |

### `scripts/debug/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `debug_commands.gd` | — | 637 | Parses and runs debug console commands. Add new commands in _register_commands(). |
| `debug_config.gd` | `DebugConfig` | 7 | Set true to ship the console in a release export. Default follows the build. |

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
| `crafting_table.gd` | `CraftingTable` | 15 |  |
| `interactable.gd` | `Interactable` | 13 |  |

### `scripts/items/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `boon_trait_keys.gd` | `BoonTraitKeys` | 133 | StringName keys for passive boon traits stored on BoonTraits. |
| `item_definition.gd` | `ItemDefinition` | 105 | Data-only description of a single item. |
| `item_describer.gd` | `ItemDescriber` | 190 | Turns item resources into readable lines for UI. Effects only carry raw |
| `item_effect.gd` | `ItemEffect` | 15 | Base class for anything an item/boon does when it is collected. |
| `item_pool_registry.gd` | `ItemPoolRegistry` | 154 | Loads loot pools by name. Pools are plain LootPool .tres files. |
| `item_registry.gd` | `ItemRegistry` | 63 | Resolves item definitions by id from the standard item directories. |
| `item_usable_config.gd` | `ItemUsableConfig` | 24 | Runtime rules for tools and abilities held in the player's hotbar. |
| `loot_pool.gd` | `LootPool` | 62 | A weighted collection of items to roll drops from. |
| `loot_pool_entry.gd` | `LootPoolEntry` | 8 | A single weighted slot inside a LootPool. |
| `pickup.gd` | `Pickup` | 307 | Shoot a pickup to send it to the van's center table. Walk into it (on the |

### `scripts/items/effects/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `boon_trait_effect.gd` | `BoonTraitEffect` | 25 | Registers a passive boon trait on the player's BoonTraits node. |
| `composite_effect.gd` | `CompositeEffect` | 13 | Runs multiple child effects when a boon is collected. |
| `full_heal_effect.gd` | `FullHealEffect` | 9 | Heals the van to full hull health. |
| `grant_coin_effect.gd` | `GrantCoinEffect` | 10 | Grants a random amount of coins to the session. |
| `gun_stat_modifier_effect.gd` | `GunStatModifierEffect` | 22 | Permanently changes gun stats for the rest of the run via BoonTraits. |
| `heal_effect.gd` | `HealEffect` | 11 | Heals the van by a percentage of its maximum health. |
| `max_health_effect.gd` | `MaxHealthEffect` | 11 | Permanently increases the van's maximum hull health for the run. |
| `repair_window_bars_effect.gd` | `RepairWindowBarsEffect` | 14 | Instantly restores all window bars to full HP. |
| `throw_grenade_effect.gd` | `ThrowGrenadeEffect` | 32 | Throws an explosive grenade from the player's view direction. |
| `timed_stat_modifier_effect.gd` | `TimedStatModifierEffect` | 28 | Applies temporary gun stat modifiers, then removes them after a duration. |

### `scripts/player/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `boon_behavior.gd` | `BoonBehavior` | 75 | Base class for boon combat behaviors. |
| `boon_behavior_context.gd` | `BoonBehaviorContext` | 30 | Shared payload passed to boon behavior handlers during combat events. |
| `boon_behavior_handlers.gd` | — | 193 | Concrete boon behavior handlers. Each inner class maps one trait to combat logic. |
| `boon_behavior_registry.gd` | `BoonBehaviorRegistry` | 185 | Dispatches combat events to registered boon behavior handlers. |
| `boon_combat.gd` | `BoonCombat` | 293 | Thin dispatcher for boon combat logic. All behavior lives in BoonBehaviorRegistry handlers. |
| `boon_stat_handlers.gd` | — | 202 | Stat-based boon behavior handlers (add/mult traits, no flags required). |
| `boon_traits.gd` | `BoonTraits` | 75 | Stores passive boon modifiers that combat systems query at runtime. |
| `fps_player.gd` | `FpsPlayer` | 251 | Modal / menu UI owns the cursor — don't steal it back into FPS look. |
| `usable_state.gd` | `UsableState` | 26 |  |
| `usables_controller.gd` | `UsablesController` | 166 |  |

### `scripts/run/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `act_card_combat.gd` | `ActCardCombat` | 148 | Dispatcher for active street cards — mirrors BoonCombat for act cards. |
| `act_card_definition.gd` | `ActCardDefinition` | 34 | Combat behavior lives in composable `effects`. Boss fights activate an Array of |
| `act_card_effect.gd` | `ActCardEffect` | 45 | Base class for anything an active street card does while it is the road. |
| `act_card_effect_context.gd` | `ActCardEffectContext` | 39 | Shared bag for street-card effect hooks. Effects mutate fields; ActCardCombat |
| `act_card_registry.gd` | `ActCardRegistry` | 48 | Resolves act street-card definitions by id from resources/acts/cards/. |
| `act_deck_controller.gd` | `ActDeckController` | 176 | Owns act-start tarot reveals and the act-end boss pick. |
| `biker_boss.gd` | `BikerBoss` | 308 | Wanjna: hit-and-run biker. Fast charge, slow axe on a door, peel and weave. |
| `boon_reward_controller.gd` | `BoonRewardController` | 141 | During REST, grants a 3-choice boon for the street card committed at the last fork. |
| `breach_controller.gd` | `BreachController` | 255 | Assigns raid slots around the van and exposes the bench damage target. |
| `breach_point.gd` | `BreachPoint` | 284 | Outside attack slot that must be breached (or opened) before mobs can enter. |
| `breakable_glass.gd` | — | 121 | Breakable window pane (rear doors or side openings). Surrounding metal stays. |
| `broken_iron_cross.gd` | `BrokenIronCross` | 278 | Blown-out iron + after a window breach. Same local frame as IronCross: |
| `encounter_director.gd` | `EncounterDirector` | 418 | Soft cap: after this, surviving raiders of the current wave retreat. |
| `front_partition.gd` | — | 101 | Front cargo partition: wall panels flanking the decorative cab door. |
| `garage_lounge.gd` | — | 185 | Sparse garage furniture — sofa and a TV in one corner, empty floor otherwise. |
| `iron_cross.gd` | `IronCross` | 355 | Welded iron + on a window pane. Local XY is the glass face; +Z is outward. |
| `loot_drop_component.gd` | `LootDropComponent` | 114 | Drop-in component that gives any enemy a chance to drop loot on death. |
| `mechanic_workshop.gd` | — | 309 | Open auto-repair bay — workbench, hoist, tires. No shop counter. |
| `rear_door_interact.gd` | — | 23 | Layer-2-only hit target on a rear door leaf. Toggles that leaf only. |
| `rear_doors.gd` | — | 402 | Truck-style rear double doors. |
| `road_floor.gd` | `RoadFloor` | 592 | Reusable corridor road slab: carriageway + raised sidewalks + curb/gutter |
| `room_zone.gd` | `RoomZone` | 14 |  |
| `shop_counter_booth.gd` | — | 1013 | Fortified metal shop counter — armored face, cash slot, eye-level grilled window. |
| `shop_hatch_net.gd` | — | 125 | Cargo-net screen on the shop hatch — thin diamond mesh, not solid bars. |
| `shop_offer.gd` | `ShopOffer` | 108 | A single priced item sitting on the shop counter. Look + E to buy with gold. |
| `shop_stock.gd` | — | 45 | Rolls 3 unique items from the shop pool and places them on the counter. |
| `side_door_interact.gd` | — | 23 | Layer-2-only hit target on a side door leaf. Toggles that leaf only. |
| `side_doors.gd` | — | 551 | Sliding cargo-style side doors. |
| `side_stop_definition.gd` | `SideStopDefinition` | 42 | A roadside building on a fork road. Every offered street gets one, regardless |
| `side_stop_registry.gd` | `SideStopRegistry` | 56 | Resolves side-stop definitions by id from resources/side_stops/. |
| `side_window_interact.gd` | — | 23 | Layer-2 hit target on a side window sash. Toggles that sash only. |
| `side_windows.gd` | — | 334 | Side cargo windows — top-hinged sashes that tip vertically outward. |
| `stop_vestibule.gd` | `StopVestibule` | 188 | Shared mouth for every roadside stop. Content (shop, garage, mechanic, |
| `travel_controller.gd` | `TravelController` | 1080 | Empty corridor tiles required between side-street openings (avoids a thin |
| `van.gd` | — | 1002 | load() not preload() — compile-time preload of the console scene |
| `van_bulkhead.gd` | `VanBulkhead` | 410 | Mid/rear cargo bulkhead: metal frame + diagonal mesh, side doorway. |
| `van_ceiling.gd` | `VanCeiling` | 380 | Barrel-vault interior ceiling with headliner and cargo dressing. |
| `van_floor.gd` | `VanFloor` | 340 | Worn cargo-van floor with ribbed decking plus flat floor dressing (mats, paper, tape). |
| `van_hull_mesh.gd` | `VanHullMesh` | 400 | XY end-cap slabs that follow VanSideWall's bow and VanCeiling's barrel vault. |
| `van_lighting.gd` | `VanLighting` | 50 | Marks van interior meshes as render layer 2 so DoorSpill (cull mask layer 1) |
| `van_player_containment.gd` | `VanPlayerContainment` | 77 | Invisible shell that keeps the player inside the van. Uses a dedicated physics |
| `van_side_wall.gd` | `VanSideWall` | 1111 | Curved cargo-van side liners: wider at the floor, bowed out at the waist, |
| `warehouse_chest.gd` | `WarehouseChest` | 60 | Table-top crate. E opens a bonus 3-choice boon, then springs leftover hides. |
| `warehouse_director.gd` | `WarehouseDirector` | 176 | Picks one hide layout per visit. Early triggers (shoot / walk / laser) or |
| `warehouse_dummy.gd` | `WarehouseDummy` | 108 | Standing shootable raider for warehouse hides. Not in `&"enemy"` — street |
| `warehouse_hide.gd` | `WarehouseHide` | 149 | One ambush pocket. `trigger()` is idempotent — shooting, walking a volume, |
| `warehouse_interior.gd` | — | 306 | Flared warehouse bay: shell, wrapped dressing, table + chest, one hide layout. |
| `warehouse_laser.gd` | `WarehouseLaser` | 72 | Waist-high trip across the aisle. Jump over to stay quiet; walking through |
| `warehouse_look.gd` | `WarehouseLook` | 144 | Shared palette / mesh helpers for the warehouse bay and its hide layouts. |
| `weapon_shop_offer.gd` | `WeaponShopOffer` | 87 | Shop counter offer that sells a generated WeaponInstance for gold. |
| `window_raider.gd` | `WindowRaider` | 385 | Agile raiders can climb window bars; door mobs only smash doors. |

### `scripts/run/effects/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `enemy_health_mult_effect.gd` | `EnemyHealthMultEffect` | 20 | Scales raider max/current health on spawn (dangers that make fights longer). |
| `enemy_loot_bonus_effect.gd` | `EnemyLootBonusEffect` | 11 | Adds to the item drop chance roll on enemy death (0.1 = +10%). |
| `enemy_speed_mult_effect.gd` | `EnemySpeedMultEffect` | 18 | Scales raider world chase speed on spawn (1.15 = 15% faster). |
| `flat_damage_bonus_effect.gd` | `FlatDamageBonusEffect` | 16 | Adds flat damage to outgoing hits of a given damage type while the card is active. |
| `narrow_fork_effect.gd` | `NarrowForkEffect` | 12 | After this street, the next fork is a T — two face-up cards instead of three. |
| `temp_boon_trait_effect.gd` | `TempBoonTraitEffect` | 18 | While this street is active, grants a boon trait via BoonTraits street overlay. |
| `wave_count_mult_effect.gd` | `WaveCountMultEffect` | 19 | Bumps each wave's spawn count (danger roads). Multiplies then optionally adds. |

### `scripts/ui/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `act_reveal_panel.gd` | `ActRevealPanel` | 581 | Act-start overlay: flips street cards (name + modifiers) and waits. |
| `bench_screen.gd` | `BenchScreen` | 770 | Bench overlay: stats + gold spending on the left, boons and tools on the right. |
| `boon_choice_panel.gd` | `BoonChoicePanel` | 160 | REST-break overlay: pick one of several offered boons. |
| `boot.gd` | — | 17 | Defer van preload one frame so global class registration finishes. |
| `combat_feedback.gd` | — | 40 |  |
| `damage_number.gd` | `DamageNumber` | 54 |  |
| `debug_console.gd` | `DebugConsole` | 220 | In-game debug terminal. H to open, Esc to close. |
| `driver_shout_hud.gd` | `DriverShoutHud` | 109 | Always-on GO / EASY shouts. van.gd plays shout_start / shout_turbo / shout_slow / shout_resume. |
| `enemy_health_bar.gd` | `EnemyHealthBar` | 59 |  |
| `item_hud.gd` | — | 86 | Hotbar for tools and a row of collected boon icons. |
| `main_menu.gd` | — | 127 | Rejected files (old version, corrupt JSON) used to look like NEW RUN |
| `usable_slot.gd` | — | 42 |  |
| `weapon_replace_prompt.gd` | `WeaponReplacePrompt` | 144 | Full inventory: pick a slot to replace, or Esc to cancel (gun stays in world). |
| `weapon_slots_hud.gd` | `WeaponSlotsHud` | 59 | Two weapon slots near ammo — highlight active, dashed empty. |

### `scripts/weapons/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `weapon_catalog.gd` | `WeaponCatalog` | 51 | Loads WeaponDefinition resources from resources/weapons/definitions/. |
| `weapon_definition.gd` | `WeaponDefinition` | 53 | Static gun archetype. Identity only — no flat damage (see WEAPON_SYSTEM_VAN_GUNNER.md). |
| `weapon_generator.gd` | `WeaponGenerator` | 118 | Pure create/roll API for generated guns. No flat damage mods. |
| `weapon_instance.gd` | `WeaponInstance` | 117 | Runtime generated gun: definition + mods + per-weapon ammo/reload state. |
| `weapon_inventory.gd` | `WeaponInventory` | 237 | Exactly 2 weapon slots. Active gun drives GunStatsController + GunController. |
| `weapon_mod.gd` | `WeaponMod` | 53 | One rolled gun mod. INCREASED % only — no flats (C1). |
| `weapon_mod_catalog.gd` | `WeaponModCatalog` | 170 | Interior/exterior mod pools + roll weights. No SPECIAL grade. No flat damage. |
| `weapon_pickup.gd` | `WeaponPickup` | 129 | World gun loot — shoot to stash, walk to collect into WeaponInventory. |
| `weapon_pricing.gd` | `WeaponPricing` | 41 | Gold prices for shop weapon offers (mega-expensive vs typical boons). |
| `weapon_stats_builder.gd` | `WeaponStatsBuilder` | 85 | Builds seed GunStats from balance + weapon definition + weapon mods (no flats). |

### `tools/`

| File | class_name | LOC | Summary |
|---|---|---|---|
| `bench_preview.gd` | — | 53 |  |

## Scenes

| Scene | Nodes | Root type |
|---|---|---|
| `VanModel.tscn` | 6 | Node3D |
| `scenes/boot/boot.tscn` | 3 | Control |
| `scenes/combat/projectile.tscn` | 4 | Area3D |
| `scenes/corridor/act_statue.tscn` | 4 | Node3D |
| `scenes/corridor/corridor_crossroads.tscn` | 37 | Node3D |
| `scenes/corridor/corridor_segment.tscn` | 84 | Node3D |
| `scenes/corridor/corridor_t_junction.tscn` | 31 | Node3D |
| `scenes/corridor/garage_bay.tscn` | 22 | Node3D |
| `scenes/corridor/mechanic_bay.tscn` | 25 | Node3D |
| `scenes/corridor/road_floor.tscn` | 1 | Node3D |
| `scenes/corridor/shop_bay.tscn` | 31 | Node3D |
| `scenes/corridor/side_street_branch.tscn` | 10 | Node3D |
| `scenes/corridor/stop_vestibule.tscn` | 4 | Node3D |
| `scenes/corridor/warehouse_bay.tscn` | 1 | Node3D |
| `scenes/enemies/biker_boss.tscn` | 2 |  |
| `scenes/enemies/window_raider.tscn` | 9 | Node3D |
| `scenes/items/pickup.tscn` | 3 | Area3D |
| `scenes/items/weapon_pickup.tscn` | 3 | Area3D |
| `scenes/player/player.tscn` | 14 | CharacterBody3D |
| `scenes/shop/shop_offer.tscn` | 3 | StaticBody3D |
| `scenes/shop/weapon_shop_offer.tscn` | 3 | StaticBody3D |
| `scenes/ui/bench_screen.tscn` | 24 | Control |
| `scenes/ui/damage_number.tscn` | 1 | Label |
| `scenes/ui/debug_console.tscn` | 8 | Control |
| `scenes/ui/driver_shout_hud.tscn` | 9 | Control |
| `scenes/ui/item_hud.tscn` | 7 | Control |
| `scenes/ui/main_menu.tscn` | 25 | Control |
| `scenes/ui/usable_slot.tscn` | 6 | PanelContainer |
| `scenes/van/broken_iron_cross.tscn` | 1 | Node3D |
| `scenes/van/iron_cross.tscn` | 1 | Node3D |
| `scenes/van/van.tscn` | 294 | Node3D |
| `scenes/van/vanSave.tscn` | 93 | Node3D |
| `scenes/van/van_bulkhead.tscn` | 1 | StaticBody3D |
| `scenes/van/van_ceiling.tscn` | 1 | Node3D |
| `scenes/van/van_floor.tscn` | 1 | Node3D |
| `scenes/van/van_side_wall.tscn` | 1 | Node3D |
| `tools/bench_preview.tscn` | 1 | Node |

## Shaders

`scenes/corridor/asphalt_surface.gdshader`, `scenes/corridor/industrial_surface.gdshader`, `scenes/corridor/sidewalk_surface.gdshader`, `scenes/van/van_ceiling.gdshader`, `scenes/van/van_floor.gdshader`, `scenes/van/van_floor_mat.gdshader`, `scenes/van/van_floor_paper.gdshader`, `scenes/van/van_viga.gdshader`, `scenes/van/van_wall.gdshader`

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
| `window_breach_hp` | `32.0` |
| `rear_window_glass_hp` | `1.0` |
| `mob_interior_speed` | `4.5` |
| `van_speed_max_level` | `4` |
| `van_speed_upgrade_base_cost` | `50` |
| `weapon_drop_chance_base` | `1` |
| `weapon_drop_chance_elite_bonus` | `10` |
| `weapon_craft_cost_mult` | `1.0` |
| `weapon_shop_price_mult` | `1.0` |
| `weapon_max_mods` | `4` |

## Weapon definitions

| id | name | fire_rate_mult | pellets | mag | reload_s | tickets |
|---|---|---|---|---|---|---|
| basic | Basic | 1.0 | 1 | 8 | 3 | 400 |
| basic_a1 | Basic A1 | 0.85 | 1 | 10 | 2.4 | 25 |
| basic_a1_cd | Basic A1 Cold | 0.85 | 1 | 10 | 2.4 | 55 |
| basic_a1_fd | Basic A1 Fire | 0.85 | 1 | 10 | 2.4 | 55 |
| basic_a1_pd | Basic A1 Poison | 0.85 | 1 | 10 | 2.4 | 55 |
| machinegun | Machinegun | 2.2 | 1 | 30 | 4.2 | 250 |
| machinegun_a1 | Machinegun A1 | 1.9 | 1 | 40 | 3.4 | 25 |
| machinegun_a1_cd | Machinegun A1 Cold | 1.9 | 1 | 40 | 3.4 | 55 |
| machinegun_a1_fd | Machinegun A1 Fire | 1.9 | 1 | 40 | 3.4 | 55 |
| machinegun_a1_pd | Machinegun A1 Poison | 1.9 | 1 | 40 | 3.4 | 55 |
| shotgun | Shotgun | 0.55 | 8 | 2 | 3.8 | 250 |
| shotgun_a1 | Shotgun A1 | 0.65 | 10 | 4 | 3 | 25 |
| shotgun_a1_cd | Shotgun A1 Cold | 0.65 | 10 | 4 | 3 | 55 |
| shotgun_a1_fd | Shotgun A1 Fire | 0.65 | 10 | 4 | 3 | 55 |
| shotgun_a1_pd | Shotgun A1 Poison | 0.65 | 10 | 4 | 3 | 55 |
| sniper | Sniper | 0.35 | 1 | 5 | 3.5 | 250 |
| sniper_a1 | Sniper A1 | 0.45 | 1 | 6 | 2.8 | 25 |
| sniper_a1_cd | Sniper A1 Cold | 0.45 | 1 | 6 | 2.8 | 55 |
| sniper_a1_fd | Sniper A1 Fire | 0.45 | 1 | 6 | 2.8 | 55 |
| sniper_a1_pd | Sniper A1 Poison | 0.45 | 1 | 6 | 2.8 | 55 |

## Act street cards

| id | name | polarity | description |
|---|---|---|---|
| brass_road | Brass Road | 0 | +10 physical damage dealt against enemies |
| cold_road | Cold Road | 0 | +10 cold damage dealt against enemies |
| empty_pockets | Empty Pockets | 1 | -25% item drops |
| hairpin | Hairpin | 0 | +100% fire rate while this street is active |
| hasty_pack | Hasty Pack | 1 | Enemies move 15% faster. +10% item drops. |
| icebox | Icebox | 0 | +3% chance cold damage freezes the enemy |
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
| shop | Shop Stop | SHOP |
| warehouse | Warehouse | WAREHOUSE |

## Enemies

| id | name | agile |
|---|---|---|
| agile_raider | Window Raider | true |
| biker_boss | Wanjna | false |
| door_raider | Door Raider | false |

## Boons

| id | name | pool | description |
|---|---|---|---|
| added_cold_projectile | Twin Frost | 3 | Shoot an additional cold projectile |
| chance_freeze_1 | Frost Touch | 3 | +1% chance cold damage freezes the enemy |
| chance_freeze_2 | Deep Freeze | 3 | +2% chance cold damage freezes the enemy |
| chew_tobacco | Chew Tobacco |  | Permanent grit. +2 physical damage for the rest of the run. |
| cold_shatter | Ice Burst | 3 | Enemies that die from cold damage shatter into cold projectiles |
| cold_shattering_ricochet | Shattering Ricochet | 3 | Ricochets shatter into extra cold projectiles |
| delayed_fire | Delayed Detonation | 1 | Delayed Explosion |
| double_fire | Focused Inferno | 1 | Fire explodes in 90% smaller area — fire damage doubled |
| double_phys_cold | Icebreaker | 4 | All physical damage against frozen enemies is doubled |
| extra_poison_to_fire | Toxic Fuel | 1 | Gain 25% of poison damage as fire damage |
| fire_death | Funeral Pyre | 1 | Enemies explode on death into a fire explosion |
| fire_greed | Pyromaniac's Bargain | 1 | Lose 20 max hp — Deal +10 fire damage |
| fire_to_phys_100 | Ashen Brass | 4 | Convert 100% of fire damage into physical damage |
| fire_to_phys_50 | Smoldering Brass | 4 | Convert 50% of fire damage into physical damage |
| frozen_damage | Shatter Strike | 3 | Deal 50% more damage against frozen targets |
| increased_fire_area | Blast Radius I | 1 | Fire damage explodes in a 20% larger area |
| increased_fire_area_2 | Blast Radius II | 1 | Fire damage explodes in a 50% larger area |
| increased_fire_area_3 | Blast Radius III | 1 | Fire damage explodes in a 100% larger area |
| instant_poison | Instant Toxin | 2 | Deal all poison damage instantly — deal half poison damage |
| longer_freeze | Permafrost | 3 | Freeze condition lasts one second longer |
| max_hp_1 | Thick Skin | 0 | Gain 10 Max Health |
| max_hp_2 | Iron Constitution | 0 | Gain 20 Max Health |
| max_hp_3 | Titan's Heart | 0 | Gain 60 Max Health |
| max_hp_heal | Second Wind | 0 | Gain 40 Max Health and heal fully |
| max_hp_phys | Brawler's Bulk | 0 | Gain 10 Max Health and 10 physical damage |
| more_frozen_loot | Frozen Fortune | 3 | Enemies killed while chilled or frozen drop extra loot |
| more_phys_10 | Heavy Rounds I | 4 | Gain +10 physical damage |
| more_phys_25 | Heavy Rounds II | 4 | Gain +25 physical damage |
| more_phys_50 | Heavy Rounds III | 4 | Gain +50 physical damage |
| phys_to_cold_crit | Cryo Crit | 3 | Physical damage converted to cold on critical hits |
| poison_duration | Lingering Venom | 2 | Poison lasts 5 more seconds |
| poison_explosions | Toxic Shrapnel | 2 | Fire explosions also deal poison damage |
| poison_follow | Seeking Venom | 2 | Ricochets bounce into close poisoned enemies |
| poisoned_chill | Toxic Chill | 3 | Poisoned enemies are more affected by chill |
| poisoned_cold | Cryo-Venom | 2 | Chilled enemies take 30% more poison damage |
| pull_fire | Vacuum Blast | 1 | Fire explosions pull instead of pushing |
| push_force_fire | Concussive Blast | 1 | Fire explosions gain more push back force |
| reduced_speed_more_phys | Slugs | 4 | 50% reduced bullet speed — gain +50 physical damage |
| ricochet_explosive | Incendiary Ricochet | 1 | Fire damage does not destroy the bullet on impact |
| ricochet_rounds | Ricochet Rounds |  | Hardened slugs that skip off steel. Bullets bounce 2 extra times. |
| ricochet_stack | Cascading Rounds | 0 | Ricochets get increasingly stronger |
| rubber_casings | Rubber Casings |  | Springy casings. One extra bounce, and ricochets keep far more speed. |
| shoot_speed | Hair Trigger | 0 | Gain 100% shot speed |
| triple_crit_phys | Deadeye | 4 | Critical hits deal 3× physical damage |
| twice_fast_poison | Accelerant Toxin | 2 | Poison deals damage twice as fast |
| vampiric_poison | Leeching Toxin | 2 | Enemies who die from poison have +5% chance to drop healing packs |
| weaker_poison | Neurotoxin | 2 | Poisoned enemies deal 25% less damage |

## Items (non-boon)

| id | name | kind | shop_price |
|---|---|---|---|
| adrenaline_stim | Adrenaline Stim | 2 | 25 |
| coin_item | Coins |  |  |
| frag_grenade | Frag Grenade | 2 | 18 |
| heal_potion | Field Stimpack | 3 | 10 |
| lucky_chip | Lucky Chip |  |  |
| road_lighter | Road Lighter | 3 | 6 |
| window_bar_kit | Window Bar Kit | 2 | 20 |

## Loot pools

`cold_boon_pool`, `fire_boon_pool`, `general_boon_pool`, `goon_pool`, `physical_boon_pool`, `poison_boon_pool`, `rest_tools_pool`, `shop_pool`

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
| `FIRE_DAMAGE_BONUS` | `fire_damage_bonus` |
| `FIRE_AREA_MULT` | `fire_area_mult` |
| `FIRE_DAMAGE_MULT` | `fire_damage_mult` |
| `RICOCHET_EXPLOSIVE` | `ricochet_explosive` |
| `DELAYED_FIRE` | `delayed_fire` |
| `FIRE_PUSH_MULT` | `fire_push_mult` |
| `FIRE_PULL` | `fire_pull` |
| `EXTRA_POISON_TO_FIRE` | `extra_poison_to_fire` |
| `FIRE_DEATH` | `fire_death` |
| `POISON_TICK_SPEED_MULT` | `poison_tick_speed_mult` |
| `POISON_DURATION_BONUS` | `poison_duration_bonus` |
| `POISON_FOLLOW` | `poison_follow` |
| `POISONED_ENEMY_DAMAGE_REDUCTION` | `poisoned_enemy_damage_reduction` |
| `POISONED_COLD_BONUS` | `poisoned_cold_bonus` |
| `VAMPIRIC_POISON_CHANCE` | `vampiric_poison_chance` |
| `INSTANT_POISON` | `instant_poison` |
| `POISON_EXPLOSIONS` | `poison_explosions` |
| `FREEZE_CHANCE` | `freeze_chance` |
| `FREEZE_DURATION_BONUS` | `freeze_duration_bonus` |
| `PHYS_TO_COLD_ON_CRIT` | `phys_to_cold_on_crit` |
| `FROZEN_DAMAGE_MULT` | `frozen_damage_mult` |
| `COLD_PROJECTILE_COUNT` | `cold_projectile_count` |
| `COLD_SHATTERING_RICOCHET` | `cold_shattering_ricochet` |
| `COLD_SHATTER` | `cold_shatter` |
| `POISONED_CHILL_BONUS` | `poisoned_chill_bonus` |
| `PHYS_DAMAGE_BONUS` | `phys_damage_bonus` |
| `DOUBLE_PHYS_COLD` | `double_phys_cold` |
| `TRIPLE_CRIT_PHYS` | `triple_crit_phys` |
| `FIRE_TO_PHYS_RATIO` | `fire_to_phys_ratio` |
| `RICOCHET_STACK_POWER` | `ricochet_stack_power` |
| `FROZEN_LOOT_BONUS` | `frozen_loot_bonus` |
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

`help`, `chill`, `unchill`, `speed`, `unspeed`, `summon`, `give`, `spawn`, `coins`, `heal`, `phase`, `boonpool`, `list`, `card`, `boss`, `reardoor`, `sidedoor`, `give_weapon`, `give_random_weapon`, `force_a1`, `sound`
