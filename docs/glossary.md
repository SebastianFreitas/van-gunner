# Glossary

Owner's words → code names. Add a line when the owner uses a word the code does not.

- loper: WindowRaider, scripts/enemies/window_raider.gd (+ _motion/_anim/_look/_targeting); the hunched door beast, scenes/enemies/window_raider.tscn, door_raider.png
- door goon / door raider: the loper at a rear-door BreachPoint; resources/enemies/door_raider.tres (breach_point.gd)
- crawler / window climber: the agile WindowRaider at a window; agile_raider.png, resources/enemies/agile_raider.tres, window_raider_look.gd fit_crawler
- Wanjna: BikerBoss, scripts/enemies/biker_boss.gd, resources/enemies/biker_boss.tres, scenes/enemies/wanjna.png (extends WindowRaider)
- window bars / bars / chains: IronCross, scripts/van/iron_cross.gd (+ _build/_geo; chains and padlock in iron_cross_build.gd)
- broken bars: BrokenIronCross, scripts/van/broken_iron_cross.gd (after a window breach)
- bar kit: item resources/items/window_bar_kit.tres, effect scripts/items/effects/repair_window_bars_effect.gd
- rear door look: scripts/van/look/van_rear_door_hardware.gd, scenes/van/van_rear_door.gdshader
- street card: ActCardDefinition, scripts/acts/act_card_*.gd, resources/acts/cards/*.tres (BLESSING or DANGER, 6 per act)
- act deck / act: ActDeckController, scripts/acts/act_deck_controller.gd, session_act_deck.gd, GameSession.run_act
- statue / act statue: roadside act reveal stop, scenes/corridor/act_statue.tscn, ACT_REVEAL phase, begin_act_statue_stop in act_deck_controller.gd
- boon pick / rest: REST phase, scripts/acts/boon_reward_controller.gd (3-choice boon)
- schematic / skill tree: SkillTreeRegistry, scripts/core/skill_tree_registry.gd, scripts/meta/, resources/meta/tree/, skill_tree_hud.gd
- request board: scripts/interactions/request_board.gd (E opens the schematic HUD)
- class board: scripts/interactions/class_board.gd (pick the class in IDLE)
- loot machine: LootMachine, scripts/interactions/loot_machine.gd (left-wall hopper for street-kill loot)
- stims / tools / hotbar: ItemUsableConfig, scripts/items/item_usable_config.gd, scripts/player/usables_controller.gd, resources/items/adrenaline_stim.tres
- chill (mode): GameSession.chill_mode, debug commands chill / unchill (freezes encounters)
- shop lift / elevator stop: StopElevator, scripts/stops/stop_elevator.gd, scenes/corridor/stop_elevator.tscn
- stop mouth / vestibule: scripts/stops/stop_vestibule.gd (shared entrance of every roadside stop)
- garage / lounge: resources/side_stops/garage.tres, scripts/stops/garage_lounge.gd, scenes/corridor/garage_bay.tscn
- mechanic: resources/side_stops/mechanic.tres, scripts/stops/mechanic_workshop.gd, mechanic_talk.gd
- warehouse: resources/side_stops/warehouse.tres, scripts/stops/warehouse_*.gd (chest, laser, dummy, director)
- buildings / street buildings: facades, scripts/travel/facades/corridor_facades.gd, facade_*.gd, FacadeDistrict
- ruin / ruin tier: facade_ruin.gd (INTACT, WORN, BROKEN, GUTTED), facade_ruin_*.gd
- gaps / yards between buildings: scripts/travel/facades/facade_infill.gd (+ _wall/_extra)
- rares / set pieces: FacadeSetPiece, facade_set_piece.gd, facade_set_pieces.gd
- graffiti / posters: scripts/travel/facades/facade_street_art.gd, street_art/
- sidewalk wreck / broken paving: scripts/travel/road_floor_wreck_map.gd (+ road_floor_wreck*.gd), facade_wreck.gd
- hands / arms / sausages: scripts/player/arms/ (arm_bulk.gd for hand and finger taper), arms_builder.gd
- war-rig: the van's look, .claude/rules/van-shell-and-hud.md "Van look"; scripts/van/look/
