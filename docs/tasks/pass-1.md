# Pass 1: classes, one damage number, bullet boons

This is the active task. Work the steps at the bottom in order and tick each box when its commit lands. Delete this file in the final commit.

## Ground rules

- AGENTS.md describes the game and its code rules. This task changes some of them. Where this file and AGENTS.md disagree, this file wins; step 5 updates AGENTS.md to match.
- Change only what is listed here. Don't rebalance, rename or tidy anything else: the owner retunes numbers himself, and pass 2 does the structural refactor.
- Every step leaves the headless check clean and ends with its own commit.
- The owner playtests after the whole pass. Don't stop between steps to ask for a playtest.

## Decisions

### Classes

1. Four classes replace the weapon system: Basic, Machinegun, Shotgun, Sniper. A class is one gun with base stats. No weapon mods, drops, slots, swapping or crafting.
2. New resource `ClassDefinition` in `scripts/classes/class_definition.gd` with `id`, `display_name`, `description`, `family`, `damage_mult`, `fire_rate_mult`, `pellets_per_shot`, `pellet_spread_degrees`, `bullet_speed`, `bullet_size`, `max_bounces`, `base_mag_size`, `base_reload_seconds`. The `Family` enum moves here from `WeaponDefinition` with the same members in the same order, so `ArmCannonMesh.build` keeps building its four meshes. Never name a variable `class`; it is a GDScript keyword.
3. `resources/classes/basic.tres`, `machinegun.tres`, `shotgun.tres`, `sniper.tres`. Copy every number from the matching base file in `resources/weapons/definitions/` (not the `_a1` or elemental variants). `damage_mult`: Basic 1.0, Machinegun 0.42, Shotgun 3.11, Sniper 2.47. At today's base damage of 1.5 that is 0.63, 4.66 per full spread and 3.70, which gives all four the Basic's sustained DPS including reloads. Descriptions: "Balanced and reliable.", "High fire rate, large magazine.", "Wide pellet spray.", "Slow, long reach, ricochet-friendly."
4. A class catalog lists classes by scanning `resources/classes/`, stripping `.remap` the way `ActCardRegistry.list_ids()` does.
5. Gun stat pipeline: `GameBalance` floor, then the class (`damage_per_shot = BASE_DAMAGE_PER_SHOT * damage_mult`, `fire_rate = BASE_FIRE_RATE * fire_rate_mult`, the rest copied), then `BoonTraits` adds and mults (the existing `_apply_traits`), then temporary `StatModifier`s, then clamps. Shotgun pellets still split damage.
6. The equipped class persists across runs as `MetaProgression.equipped_class_id` in `meta_progression.json`, default `&"basic"`. Do not bump `MetaProgression.SAVE_VERSION`: `load_profile()` resets the van schematic on a version mismatch. Read the new field with a default, like the volume fields. A missing or unknown id means Basic.
7. The run's class is `GameSession.class_id`: copied from `MetaProgression` in `start_new()`, saved in the run save, restored on CONTINUE. An unknown id means Basic.
8. Class board: a new wall prop in the centre room (z from -4.6 to +1.0), same pattern as `RequestBoard`: a scene in `scenes/van/`, a script extending `Interactable` that emits `opened`, wired in `van.gd` next to `request_board`. Mount it flush on a wall, clear of walkways, the bulkhead doorway and the other props. Prompt in IDLE: "Change class (<name>)". In every other phase: "Class: <name>", and interacting does nothing.
9. Class panel: a HUD overlay with four cards showing name, description, damage per shot (per full spread for the Shotgun), shots per second, magazine and reload seconds, with the equipped class highlighted. Clicking a card equips it; E or Esc closes the panel. It follows the overlay rules in AGENTS §6: counted in `has_modal_free_cursor()` and `_is_interactive_hud()`, closed through `refresh_mouse_mode()`, takes Esc before the pause menu does, and closes itself if the phase leaves IDLE.
10. Equipping a class sets `MetaProgression.equipped_class_id` and saves the profile, sets `GameSession.class_id` and saves the run, rebuilds gun stats, refills the magazine and swaps the viewmodel mesh.

### Weapon system removal

11. Delete `scripts/weapons/` (every script with its `.gd.uid`), `resources/weapons/`, `scenes/items/weapon_pickup.tscn`, `scenes/shop/weapon_shop_offer.tscn`, `scripts/run/weapon_shop_offer.gd`, `scripts/ui/weapon_replace_prompt.gd` and `scripts/ui/weapon_slots_hud.gd` with their nodes in `van.tscn`, the `WeaponInventory` node in `player.tscn`, the weapon paths in `LootCatch`, `LootCollector` and `LootDropComponent`, `GameSession.pending_weapons_save` and the `"weapons"` save key, the `weapon_*` exports in `GameBalanceData` with their `GameBalance` getters, and weapon swapping in `fps_player.gd` (scroll wheel and Q). Q stays bound in `project.godot` with nothing reading it.
12. The shop's last counter slot (`shop_stock.gd`) gets a normal `shop` pool item like the other slots.
13. The bench keeps its Overview page and loses its Weapons tab. Its "Damage type" row becomes a "Class" row. The `CraftingTable` node stays exactly as it is: it holds a `VanVital` that counts toward van hull.

### One damage number

14. Delete `DamageType` and every use of it. `DamageInfo` keeps `amount`, `source`, `is_headshot`, `hit_position` and `explosion_radius`, and renames `is_dot_tick` to `is_secondary` (true for blast splash and poison ticks). Channels, per-type percentages, dominant-type logic, `GunStats.damage_type` and the `*_damage_increased_pct` fields go.
15. A headshot multiplies the hit by 2.0. The lightning 2.5 and the crit-mod bonus go.
16. Every damage bonus is applied exactly once, where the damage starts. Bullets: the `gun_damage_per_shot` trait in `GunStatsController`. Frag Grenade: its blast damage (30) times `traits.get_mult(BoonTraitKeys.GUN_DAMAGE_PER_SHOT)` at detonation, no flat adds, and grenades never carry bullet boons. Blasts and poison are shares of the hit that caused them and are never scaled again.

### The three bullet boons

Each is a boon whose effect is a `BoonTraitEffect` with an add value, plus one `BoonBehavior` handler registered in `BoonBehaviorRegistry`. The add value is the tunable share, so the owner tunes it in the boon's `.tres`.

17. Explosive Rounds: id and trait `explosive_rounds`, value 0.5. On a bullet's first contact with an enemy or scenery, the enemy it touched (if any) takes the full hit, then a blast at the contact point deals `hit * 0.5` to every enemy within the bullet's `explosion_radius` (1.8 today) with the existing distance falloff. The enemy hit directly is inside the blast and takes both. The bullet detonates on first contact and does not ricochet, which is today's rule for explosive shots. Blast damage is secondary. `ExplosionFx` is unchanged.
18. Poison Rounds: `poison_rounds`, value 1.0. Each bullet hit on an enemy adds a poison stack worth `hit * 1.0`, dealt over the poison duration in ticks (today 2.0 s in 0.5 s ticks). Stacks run side by side, as `apply_poison_stack` does today. Ticks are secondary.
19. Cold Rounds: `cold_rounds`, value 0.45. Each bullet hit on an enemy slows its movement and attacks by 45% for the cold duration (today 2.5 s). A new hit refreshes the duration; slows don't stack past the strongest, as `apply_cold` does today. No freeze.
20. A blast applies the owner's Poison Rounds and Cold Rounds to every enemy it damages; the poison is based on the damage that enemy took from the blast. Secondary damage never triggers Explosive Rounds, and poison ticks trigger nothing.
21. The shared numbers move to `GameBalanceData` exports with today's values: `poison_duration` 2.0, `poison_tick_interval` 0.5, `cold_slow_duration` 2.5. Add them to `game_balance_data.gd` with those defaults only; don't write them into `game_balance.tres`.
22. Shotgun pellets are separate bullets. Each pellet applies the boons from its own share of the damage, so an Explosive shotgun spread makes up to eight small blasts. That is intended.
23. Descriptions: "Bullets explode on impact.", "Bullets poison enemies.", "Bullets slow enemies."

### Boons and items

24. Kept with their current values unless item 25 says otherwise: Field Stimpack, Road Lighter, Weld Kit, Coins, Lucky Chip, Frag Grenade, Adrenaline Stim, Thick Skin, Iron Constitution, Titan's Heart, Second Wind, Hair Trigger, Ricochet Rounds, Rubber Casings, Cascading Rounds, Chew Tobacco, Brawler's Bulk.
25. Chew Tobacco becomes +1 damage (was +2 physical); Brawler's Bulk becomes +10 max health and +1 damage (was +10 physical). Both as a `gun_damage_per_shot` ADD through `GunStatModifierEffect`. Descriptions: "Permanent grit. +1 damage for the rest of the run." and "Gain 10 Max Health and +1 damage". Cascading Rounds keeps +15% per bounce on the single damage number.
26. New in the boon pool at weight 5 each: Explosive Rounds, Poison Rounds, Cold Rounds. Plus Double Damage (item 30).
27. Delete the other 37 boons (every fire, poison, cold and physical boon) with their icons and `.import` files, the fire, poison, cold and physical pools, `ItemDefinition.BoonPool` and the `boon_pool` field, every trait key and `BoonBehavior` handler that only deleted boons used, and the fire DoT and freeze code in `StatusEffectController`. Keep the `BoonBehavior` hook methods and the registry dispatchers even where no handler uses them yet; future boons plug into them.
28. `general_boon_pool.tres` is the only boon pool, and the `van` alias keeps pointing at it. Rest offers draw from it at weight 1.0 and from `rest_tools` at 0.35 (today's opening-rest weights without the elemental pools).
29. New `ItemDefinition.repeatable`, default false, true on Thick Skin, Iron Constitution, Titan's Heart and Second Wind. Repeatable boons can be offered and taken again; every other boon stays one per run. One helper builds the "already owned" exclusion list, skipping repeatable boons, for the rest reward, the warehouse chest and the mechanic. The same card never appears twice in one offer, and the boons HUD lists a repeatable boon once.
30. Double Damage: id `double_damage`, `gun_damage_per_shot` MULTIPLY 2.0, description "Deal 2x damage.", one per run. It lives only in a new `resources/items/pools/warehouse_rare_boon_pool.tres`. Only the warehouse chest's bonus pick reads that pool: with chance `GameBalance.WAREHOUSE_RARE_BOON_CHANCE` (new export `warehouse_rare_boon_chance`, default 0.05) one of its three cards is Double Damage, unless the player owns it. It never appears at rests, the mechanic or shops.

### Street cards and areas

31. Brass Road becomes "+25% damage while this street is active": a `TempBoonTraitEffect` on `gun_damage_per_shot` with multiply 1.25, the same pattern as Hairpin. Delete `FlatDamageBonusEffect`; Brass Road was its only user.
32. Delete Cold Road and Icebox with their card art and `.import` files. Four blessings remain and an act needs three.
33. Remove the area system: `current_area`, `area_changed`, the three `_*_AREA_CYCLE` tables, `_resolve_area_for_fork`, `get_rest_area`, `get_area_flavor_name`, `_area_from_save`, the `"current_area"` save key, and the area label passed to the act reveal and boss pick panels.

### Visuals

34. No colour coding by effect: damage numbers use the normal colour (the headshot colour stays), the enemy hit flash uses today's default flash colour, and bullet trails use today's default trail colour. `ExplosionFx` is unchanged.

### Saves

35. `SaveManager.SAVE_VERSION` goes from 5 to 6. Older slots show CAN'T CONTINUE through the existing path.

### Debug console

36. Remove `give_weapon`, `give_random_weapon`, `force_a1`, `boonpool` and `list weapons`. Add `class <id>`, which equips a class in any phase for testing, and `list classes`. Update `help`.

### Tools and docs

37. `tools/generate_boons.py` owns every boon `.tres` and every boon pool: make its list exactly the kept and new boons with the values above, and have it write only `general_boon_pool.tres` and `warehouse_rare_boon_pool.tres`. It stops writing a `boon_pool` line. Boon files that already have a `uid://` in their header keep it. Delete boon files the generator no longer lists.
38. `tools/generate_boon_icons.py`: glyphs for the four new boons, glyphs of deleted boons removed, every boon on the general style.
39. `tools/gen_context.py`: drop the weapon definitions section and the `boon_pool` column, add a classes table, then regenerate `docs/PROJECT_MAP.md`.
40. AGENTS.md: rewrite the stat pipeline in §3; replace the §4 items below and keep the numbering; replace the first §7 bullet with "Wave counts in `game_balance.tres` are test values the owner changes freely. The working tree may hold an uncommitted edit to them."; update the §8 rows (guns become classes, damage types become bullet boons, bench crafting becomes the bench overview); remove the reference to `docs/WEAPON_SYSTEM_VAN_GUNNER.md` and delete that file.

New §4 items:

1. **One damage number, no damage types.** A bullet's damage is `GameBalance.BASE_DAMAGE_PER_SHOT * ClassDefinition.damage_mult`. Boons and street cards scale it through the `gun_damage_per_shot` trait, applied once in `GunStatsController`. Blasts and poison are shares of the hit that caused them and are never scaled again.
2. Retired.
4. **Fire, poison and cold are bullet boons, not damage types.** Explosive, Poison and Cold Rounds each have one `BoonBehavior` handler. Secondary damage (blast splash, poison ticks) never triggers them; a blast does apply poison and cold. Explosive bullets detonate on first contact and do not ricochet.
6. **One gun per class.** The class is picked at the class board in IDLE and locked for the rest of the run. Keys 1-4 are tool slots; Q is bound but unused.
7. **Gold buys at shops and the mechanic.** Rare Parts (`MetaProgression.rare_parts`) are a second wallet for the van schematic only: boss drops, 3 per run max. Never spend gold on schematic nodes.

## Do not touch

- `resources/balance/game_balance.tres` holds an uncommitted test edit: don't revert it, edit it or commit it. Same for the untracked `export_presets.cfg`.
- The four van vitals (bench, hopper, fuse box, cab relay) and the van hull rules in AGENTS §4 item 12.
- `ArmCannonMesh` and its four meshes.
- `GameBalance.get_act` versus `GameSession.run_act` (AGENTS §7).
- The run save doesn't store boons or tools, so CONTINUE drops them. Known gap; leave it.
- Travel, stops, doors, windows, the schematic and audio: nothing here needs them. In raider and vital scripts, touch only damage handling.

## Steps

- [x] 0. Baseline. Commit the untracked `CLAUDE.md`, `.claude/agents/` and this file as they are. Then prove the headless check: add `tools/_probe.gd` with `class_name ProbeCheck` and a deliberate syntax error, run the check from CLAUDE.md, and confirm it reports the error. Delete the probe and any `.uid` Godot created for it. If the check misses the error, find a command that catches it and write it into CLAUDE.md before continuing. Run the check on the untouched tree and write down any errors it already reports; those are the baseline, not regressions.
- [x] 1. Classes replace weapons: items 1-13 and 35, plus the weapon and class parts of 36.
- [ ] 2. Old boons out: items 24, 25, 27, 31, 32 and 33, and `boonpool` from 36. Update both generators for the removals and re-run them.
- [ ] 3. One damage number: items 14, 15, 16 and 34.
- [ ] 4. Bullet boons and the new pools: items 17-23, 26, 28, 29 and 30. Update both generators and re-run them, then run the headless check so Godot imports the new icons, and commit each new `.svg` with its `.svg.import`.
- [ ] 5. `gen_context.py` and PROJECT_MAP (39), then AGENTS.md (40).
- [ ] 6. Final sweep. `git grep` finds nothing for `DamageType`, `damage_type`, `WeaponInventory`, `WeaponInstance`, `WeaponDefinition`, `WeaponMod`, `WeaponCatalog`, `current_area`, `BoonPool`, `boon_pool`, `phys_damage_bonus`, `is_dot_tick`, `try_apply_freeze`, `freeze_chance`, `fire_damage`, `cold_damage` or `poison_damage`. The headless check shows nothing beyond the step-0 baseline. Delete this file in the final commit.

## Final report to the owner

1. Files added and deleted, one line per area.
2. Where the class board is, and its node path so it can be moved in the editor.
3. This playtest list, unchanged:
   - New run: the board in the centre room says "Change class (Basic)". Pick each class and fire at the rear: the arm cannon, magazine and fire rate change.
   - Yell GO: the board shows the class and does nothing on E.
   - Quit to the menu and CONTINUE: same class. A slot saved before this pass shows CAN'T CONTINUE.
   - Console `give explosive_rounds`: bullets explode on impact and don't ricochet. `give poison_rounds`: hit raiders keep taking damage for 2 s. `give cold_rounds`: hit raiders move and attack slower.
   - With all three: a blast poisons and slows every raider in it.
   - `give double_damage`: damage numbers double, and so does the Frag Grenade blast.
   - Take Brass Road: damage x1.25 on that street only.
   - After owning all three bullet boons, rests still offer three cards.
   - The shop's last slot is a normal item, the mechanic's random van boon works, and the bench opens with the Class row.
