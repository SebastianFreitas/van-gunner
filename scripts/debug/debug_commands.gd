extends Node

## Parses and runs debug console commands. Add new commands in _register_commands().

const _PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")
const _SoundCue := preload("res://scripts/audio/sound_cue.gd")

var _commands: Dictionary = {}


func _ready() -> void:
	if not DebugConfig.ENABLED:
		return
	_register_commands()


func get_completion_context(text: String, caret_col: int) -> Dictionary:
	var safe_caret := clampi(caret_col, 0, text.length())
	var before := text.substr(0, safe_caret)
	var token_start := before.rfind(" ") + 1
	if token_start < 0:
		token_start = 0
	var partial := before.substr(token_start)
	var parts := before.strip_edges(false).split(" ", false)
	var matches: Array[String] = []

	if parts.is_empty() or (parts.size() == 1 and not before.ends_with(" ")):
		matches = _filter_prefix(_command_names(), partial)
	elif parts.size() == 1 and before.ends_with(" "):
		match parts[0]:
			"give", "spawn":
				matches = _filter_prefix(ItemRegistry.list_ids(), "")
			"boonpool":
				matches = _filter_prefix(_boon_pool_names(), "")
			"summon":
				matches = _filter_prefix(["enemy"], "")
			"reardoor":
				matches = _filter_prefix(["open", "close", "toggle"], "")
			"sidedoor":
				matches = _filter_prefix(["open", "close", "toggle"], "")
			"list":
				matches = _filter_prefix(
					["boons", "items", "commands", "weapons", "cards", "stops", "sounds"], ""
				)
			"sound":
				matches = _filter_prefix(_sound_id_strings(), "")
			"card":
				matches = _filter_prefix(_card_id_strings(), "")
			"stop":
				matches = _filter_prefix(_stop_force_tokens(), "")
			"give_weapon":
				matches = _filter_prefix(WeaponCatalog.list_definition_ids(), "")
			_:
				matches = []
	elif parts[0] == "give" or parts[0] == "spawn":
		matches = _filter_prefix(ItemRegistry.list_ids(), partial)
	elif parts[0] == "give_weapon":
		matches = _filter_prefix(WeaponCatalog.list_definition_ids(), partial)
	elif parts[0] == "boonpool":
		matches = _filter_prefix(_boon_pool_names(), partial)
	elif parts[0] == "card":
		matches = _filter_prefix(_card_id_strings(), partial)
	elif parts[0] == "stop":
		if parts.size() >= 2 and SideStopRegistry.arrival_from_label(str(parts[1])) >= 0:
			matches = _filter_prefix(_stop_id_strings(), partial)
		else:
			matches = _filter_prefix(_stop_force_tokens(), partial)
	elif parts[0] == "summon":
		matches = _filter_prefix(["enemy"], partial)
	elif parts[0] == "reardoor":
		matches = _filter_prefix(["open", "close", "toggle"], partial)
	elif parts[0] == "sidedoor":
		matches = _filter_prefix(["open", "close", "toggle"], partial)
	elif parts[0] == "list":
		matches = _filter_prefix(
			["boons", "items", "commands", "weapons", "cards", "stops", "sounds"], partial
		)
	elif parts[0] == "sound":
		matches = _filter_prefix(_sound_id_strings(), partial)
	else:
		matches = []

	return {
		"token_start": token_start,
		"partial": partial,
		"matches": matches,
		"add_space": _should_add_space_after(parts, before.ends_with(" ")),
	}


func run(line: String) -> String:
	if not DebugConfig.ENABLED:
		return "Debug tools are disabled."
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return ""
	var parts := trimmed.split(" ", false)
	var cmd: String = parts[0].to_lower()
	var args: Array = parts.slice(1)
	if not _commands.has(cmd):
		return "Unknown command: %s  (try help)" % cmd
	return _commands[cmd].call(args)


func _register_commands() -> void:
	_commands = {
		"help": _cmd_help,
		"chill": _cmd_chill,
		"unchill": _cmd_unchill,
		"speed": _cmd_speed,
		"unspeed": _cmd_unspeed,
		"summon": _cmd_summon,
		"give": _cmd_give,
		"spawn": _cmd_spawn,
		"coins": _cmd_coins,
		"heal": _cmd_heal,
		"phase": _cmd_phase,
		"boonpool": _cmd_boonpool,
		"list": _cmd_list,
		"card": _cmd_card,
		"stop": _cmd_stop,
		"boss": _cmd_boss,
		"reardoor": _cmd_reardoor,
		"sidedoor": _cmd_sidedoor,
		"give_weapon": _cmd_give_weapon,
		"give_random_weapon": _cmd_give_random_weapon,
		"force_a1": _cmd_force_a1,
		"sound": _cmd_sound,
	}


func _cmd_help(_args: Array) -> String:
	var names: Array[String] = []
	for key in _commands.keys():
		names.append(String(key))
	names.sort()
	return (
		"Commands: %s\n"
		+ "  chill          freeze van travel and stop new encounters\n"
		+ "  unchill        resume normal run flow\n"
		+ "  speed          debug turbo — fast travel, skips intro, compresses timers\n"
		+ "  unspeed        turn off debug turbo\n"
		+ "  summon enemy   spawn a raider that assaults an open breach slot\n"
		+ "  give <item_id> add item to player (e.g. give frag_grenade)\n"
		+ "  spawn <item_id> drop a pickup near the player\n"
		+ "  coins <n>      add coins\n"
		+ "  heal [amount]  heal the player\n"
		+ "  boonpool <pool> roll a boon from general/fire/poison/cold/physical\n"
		+ "  list boons [q]  browse boon ids (optional filter)\n"
		+ "  list items [q]  browse all item ids\n"
		+ "  list cards [q]  browse street card ids\n"
		+ "  list stops [q]  browse side-stop ids (shop, garage, mechanic, warehouse, …)\n"
		+ "  stop <id>       next fork offers that stop on every road\n"
		+ "  stop <arrival> <content>  compose e.g. stop elevator shop\n"
		+ "  card [id]       print / force-activate active street card(s)\n"
		+ "  boss            skip to act-end boss pick (current six streets)\n"
		+ "  phase          print current run phase\n"
		+ "  reardoor [open|close|toggle]  swing the van rear doors\n"
		+ "  sidedoor [open|close|toggle]  slide the van side doors\n"
		+ "  give_weapon <id> [level]  equip generated gun (e.g. give_weapon shotgun)\n"
		+ "  give_random_weapon [level]  equip a random generated gun\n"
		+ "  force_a1         drop a random A1 gun near the player\n"
		+ "  list weapons [q] browse weapon definition ids\n"
		+ "  list sounds [q] browse SoundCue ids\n"
		+ "  sound <cue>     play a cue (audition without a run)\n"
		+ "  Tab            autocomplete command or item id"
	) % ", ".join(names)


func _cmd_chill(_args: Array) -> String:
	GameSession.set_chill_mode(true)
	return "Chill mode ON — encounters paused, van keeps moving."


func _cmd_unchill(_args: Array) -> String:
	GameSession.set_chill_mode(false)
	return "Chill mode OFF — run resumes."


func _cmd_speed(_args: Array) -> String:
	var travel := _find_travel_controller()
	if not travel:
		return "TravelController not found — are you in the van scene?"
	travel.set_debug_speed_mode(true)
	var started := false
	if GameSession.phase == GameSession.RunPhase.IDLE:
		GameSession.begin_run()
		started = true
	var msg := (
		"Speed mode ON — %.1fx travel, timers compressed, intro skipped."
		% travel.debug_speed_multiplier
	)
	if started:
		msg += " Run auto-started."
	return msg


func _cmd_unspeed(_args: Array) -> String:
	var travel := _find_travel_controller()
	if not travel:
		return "TravelController not found — are you in the van scene?"
	travel.set_debug_speed_mode(false)
	return "Speed mode OFF — back to normal travel speed (%.1f u/s)." % travel.travel_speed


func _cmd_summon(args: Array) -> String:
	var kind: String = str(args[0]).to_lower() if not args.is_empty() else "enemy"
	if kind != "enemy":
		return "Usage: summon enemy"
	var director := _find_encounter_director()
	if not director:
		return "EncounterDirector not found — are you in the van scene?"
	return director.spawn_debug_raider()


func _cmd_give(args: Array) -> String:
	if args.is_empty():
		return "Usage: give <item_id>  (e.g. give chew_tobacco)"
	var item_id: String = str(args[0])
	var item := _load_item(item_id)
	if not item:
		return "Unknown item: %s" % item_id
	var player := _find_player()
	if not player:
		return "Player not found."
	item.collect(player)
	return "Gave %s." % item.display_name


func _cmd_spawn(args: Array) -> String:
	if args.is_empty():
		return "Usage: spawn <item_id>"
	var item_id: String = str(args[0])
	var item := _load_item(item_id)
	if not item:
		return "Unknown item: %s" % item_id
	var player := _find_player()
	if not player:
		return "Player not found."
	var pickup := _PICKUP_SCENE.instantiate() as Pickup
	pickup.item = item
	player.get_parent().add_child(pickup)
	var forward := -player.global_transform.basis.z
	pickup.global_position = player.global_position + forward * 1.2 + Vector3(0.0, 0.5, 0.0)
	return "Spawned %s pickup." % item.display_name


func _cmd_coins(args: Array) -> String:
	var amount: int = int(args[0]) if not args.is_empty() else 10
	GameSession.add_coins(amount)
	return "Added %d coins (total %d)." % [amount, GameSession.coins]


func _cmd_heal(args: Array) -> String:
	var amount: float = float(args[0]) if not args.is_empty() else GameSession.get_max_player_health()
	GameSession.heal_player(amount)
	return "Player healed by %.0f." % amount


func _cmd_boonpool(args: Array) -> String:
	if args.is_empty():
		return "Usage: boonpool <general|fire|poison|cold|physical>"
	var pool_name: String = str(args[0]).to_lower()
	var pool := ItemDefinition.BoonPool.GENERAL
	match pool_name:
		"general":
			pool = ItemDefinition.BoonPool.GENERAL
		"fire":
			pool = ItemDefinition.BoonPool.FIRE
		"poison":
			pool = ItemDefinition.BoonPool.POISON
		"cold":
			pool = ItemDefinition.BoonPool.COLD
		"physical":
			pool = ItemDefinition.BoonPool.PHYSICAL
		_:
			return "Unknown pool: %s" % pool_name
	var item := ItemPoolRegistry.pick_from_boon_pool(pool)
	if not item:
		return "Pool is empty."
	var player := _find_player()
	if not player:
		return "Player not found."
	item.collect(player)
	return "Rolled %s from %s pool." % [item.display_name, pool_name]


func _cmd_give_weapon(args: Array) -> String:
	if args.is_empty():
		return "Usage: give_weapon <definition_id> [level]"
	var def_id := StringName(str(args[0]))
	if WeaponCatalog.load_definition(def_id) == null:
		return "Unknown weapon: %s  (try list weapons)" % def_id
	var level: int = int(args[1]) if args.size() > 1 else maxi(GameSession.route_step, 1)
	var force_mods := 0 if def_id == &"basic" else -1
	var inst := WeaponGenerator.create_weapon(level, def_id, force_mods)
	return _deliver_weapon(inst)


func _cmd_give_random_weapon(args: Array) -> String:
	var level: int = int(args[0]) if not args.is_empty() else maxi(GameSession.route_step, 1)
	var inst := WeaponGenerator.create_weapon(level)
	return _deliver_weapon(inst)


func _deliver_weapon(inst: WeaponInstance) -> String:
	var player := _find_player()
	if not player:
		return "Player not found."
	var inventory := player.get_node_or_null("WeaponInventory") as WeaponInventory
	if inventory == null:
		player.set_meta(&"debug_pending_weapon", inst)
		return "Generated %s (uid %d, %d mods) — inventory not ready; stashed on player meta." % [
			inst.display_name(), inst.uid, inst.mods.size()
		]
	var result := inventory.try_add(inst)
	if result == WeaponInventory.AddResult.STORED:
		return "Equipped %s (%d mods)." % [inst.display_name(), inst.mods.size()]
	var old := inventory.replace_slot(inventory.active_index, inst)
	var note := ""
	if old:
		note = " Replaced %s." % old.display_name()
	return "Equipped %s (%d mods).%s" % [inst.display_name(), inst.mods.size(), note]


func _cmd_force_a1(_args: Array) -> String:
	var player := _find_player()
	if not player:
		return "Player not found."
	var ids: Array[StringName] = [
		&"basic_a1", &"shotgun_a1", &"machinegun_a1", &"sniper_a1",
		&"basic_a1_fd", &"shotgun_a1_cd", &"machinegun_a1_pd", &"sniper_a1_fd",
	]
	var def_id: StringName = ids[randi() % ids.size()]
	var level := maxi(GameSession.route_step, 1)
	var inst := WeaponGenerator.create_weapon(level, def_id, -1)
	var container: Node = player.get_parent()
	WeaponPickup.spawn_at(
		inst,
		player.global_position + (-player.global_transform.basis.z) * 1.4 + Vector3(0, 0.5, 0),
		container
	)
	return "Dropped %s (%d mods) nearby." % [inst.display_name(), inst.mods.size()]


func _cmd_list(args: Array) -> String:
	if args.is_empty():
		return "Usage: list boons|items|commands|weapons|cards|stops|sounds [filter]"
	var kind: String = str(args[0]).to_lower()
	var filter_text := " ".join(args.slice(1))
	match kind:
		"commands":
			var lines: PackedStringArray = PackedStringArray()
			lines.append(_cmd_help([]))
			return "\n".join(lines)
		"boons":
			return _format_item_list(
				ItemRegistry.list_entries(ItemDefinition.ItemKind.BOON, filter_text),
				"boons",
				filter_text
			)
		"items":
			return _format_item_list(ItemRegistry.list_entries(-1, filter_text), "items", filter_text)
		"weapons":
			return _format_weapon_list(filter_text)
		"cards":
			return _format_card_list(filter_text)
		"stops":
			return _format_stop_list(filter_text)
		"sounds":
			return _format_sound_list(filter_text)
		_:
			return (
				"Unknown list target: %s  (try boons, items, commands, weapons, cards, stops, sounds)"
				% kind
			)


func _cmd_card(args: Array) -> String:
	if args.is_empty():
		var cards := GameSession.get_active_modifier_cards()
		if cards.is_empty():
			return "No active street cards."
		var lines: PackedStringArray = PackedStringArray()
		for card in cards:
			lines.append("%s (%s) — %s" % [
				card.id,
				card.polarity_label(),
				card.description.strip_edges(),
			])
		return "active (%d):\n%s" % [cards.size(), "\n".join(lines)]
	var card_id := StringName(str(args[0]))
	var card := ActCardRegistry.load_by_id(card_id)
	if card == null:
		return "Unknown card: %s" % card_id
	ActCardCombat.clear()
	GameSession.boss_modifier_card_ids.clear()
	GameSession.active_street_card_id = card_id
	GameSession.pending_danger = card.is_danger()
	ActCardCombat.activate(card)
	return "Forced street card: %s (%s)" % [card.display_name, card.polarity_label()]


func _cmd_stop(args: Array) -> String:
	if args.is_empty():
		return "Usage: stop <id> | stop <arrival> <content>  (see list stops)"
	var stop: SideStopDefinition
	if args.size() >= 2:
		var arrival := SideStopRegistry.arrival_from_label(str(args[0]))
		if arrival < 0:
			return "Unknown arrival '%s' — use rear_park or elevator." % str(args[0])
		var content_id := StringName(str(args[1]))
		stop = SideStopRegistry.compose(content_id, arrival as SideStopDefinition.Arrival)
		if stop == null:
			return "Unknown content stop: %s" % content_id
	else:
		var stop_id := StringName(str(args[0]))
		stop = SideStopRegistry.load_by_id(stop_id)
		if stop == null or stop.scene == null:
			return "Unknown stop: %s" % stop_id
	var travel := _find_travel_controller()
	if travel == null:
		return "TravelController not found — are you in the van scene?"
	if travel.has_method(&"force_stop_def"):
		if not travel.force_stop_def(stop):
			return "Could not queue stop: %s" % String(stop.id)
	elif travel.has_method(&"force_next_stop"):
		if not travel.force_next_stop(stop.id):
			return "Could not queue stop: %s" % String(stop.id)
	else:
		return "TravelController not found — are you in the van scene?"
	return "Next fork: %s [%s] on every road." % [stop.fork_label(), stop.arrival_label()]


func _cmd_boss(_args: Array) -> String:
	var deck := get_tree().get_first_node_in_group(&"act_deck_controller")
	GameSession.debug_prepare_boss_pick()
	if deck and deck.has_method(&"begin_boss_pick_if_needed"):
		deck.begin_boss_pick_if_needed()
		return "Boss pick started — six streets, pick two."
	GameSession.commit_boss_picks([])
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
	return "Boss pick skipped UI; stacked fallback cards and queued the fight."


func _format_card_list(filter_text: String) -> String:
	var needle := filter_text.strip_edges().to_lower()
	var lines: PackedStringArray = PackedStringArray()
	var count := 0
	for card_id in ActCardRegistry.list_ids():
		var card := ActCardRegistry.load_by_id(card_id)
		if card == null:
			continue
		var hay := ("%s %s %s" % [card.id, card.display_name, card.description]).to_lower()
		if not needle.is_empty() and not hay.contains(needle):
			continue
		lines.append(
			"  %s  —  [%s] %s — %s"
			% [card.id, card.polarity_label(), card.display_name, card.description.strip_edges()]
		)
		count += 1
	if count == 0:
		if filter_text.is_empty():
			return "No street cards found."
		return "No street cards match '%s'." % filter_text
	var header := "%d street cards" % count
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	return header + ":\n" + "\n".join(lines)


func _format_stop_list(filter_text: String) -> String:
	var needle := filter_text.strip_edges().to_lower()
	var lines: PackedStringArray = PackedStringArray()
	var count := 0
	for stop_id in SideStopRegistry.list_ids():
		var stop := SideStopRegistry.load_by_id(stop_id)
		if stop == null:
			continue
		var hay := ("%s %s %s" % [stop.id, stop.display_name, stop.short_label]).to_lower()
		if not needle.is_empty() and not hay.contains(needle):
			continue
		lines.append(
			"  %s  —  %s [%s, w=%.2f]"
			% [stop.id, stop.fork_label(), stop.arrival_label(), stop.spawn_weight]
		)
		count += 1
	if count == 0:
		if filter_text.is_empty():
			return "No side stops found."
		return "No side stops match '%s'." % filter_text
	var header := "%d side stops" % count
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	return header + ":\n" + "\n".join(lines)


func _stop_id_strings() -> Array[String]:
	var out: Array[String] = []
	for stop_id in SideStopRegistry.list_ids():
		out.append(String(stop_id))
	return out


func _stop_force_tokens() -> Array[String]:
	var out: Array[String] = ["rear_park", "elevator"]
	out.append_array(_stop_id_strings())
	return out


func _card_id_strings() -> Array[String]:
	var out: Array[String] = []
	for card_id in ActCardRegistry.list_ids():
		out.append(String(card_id))
	return out


func _format_weapon_list(filter_text: String) -> String:
	var needle := filter_text.strip_edges().to_lower()
	var lines: PackedStringArray = PackedStringArray()
	var count := 0
	for id in WeaponCatalog.list_definition_ids():
		if not needle.is_empty() and not id.to_lower().contains(needle):
			continue
		var def := WeaponCatalog.load_definition(StringName(id))
		var weapon_name := def.display_name if def else id
		lines.append("  %s  —  %s" % [id, weapon_name])
		count += 1
	if count == 0:
		if filter_text.is_empty():
			return "No weapons found."
		return "No weapons match '%s'." % filter_text
	var header := "%d weapons" % count
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	return header + ":\n" + "\n".join(lines)


func _cmd_sound(args: Array) -> String:
	if args.is_empty():
		return "Usage: sound <cue_id>  (try list sounds)"
	var cue_id := StringName(str(args[0]))
	if AudioDirector.bank == null or not AudioDirector.bank.has_cue(cue_id):
		return "Unknown cue: %s  (try list sounds)" % cue_id
	var cue := AudioDirector.bank.get_cue(cue_id) as _SoundCue
	if cue == null or cue.stream == null:
		return "Cue %s has no stream yet — drop a .wav / .ogg on the SoundCue." % cue_id
	# Always the non-positional path so you can hear it from the console.
	AudioDirector.play(cue_id)
	return "Playing %s." % cue_id


func _format_sound_list(filter_text: String) -> String:
	var needle := filter_text.strip_edges().to_lower()
	var lines: PackedStringArray = PackedStringArray()
	var count := 0
	for cue_id in _sound_id_strings():
		if not needle.is_empty() and not cue_id.to_lower().contains(needle):
			continue
		var cue := AudioDirector.bank.get_cue(StringName(cue_id)) as _SoundCue
		var stream_note := "ready" if cue and cue.stream else "no stream"
		var where := "3D" if cue and cue.positional else "2D"
		var interval: float = cue.min_interval if cue else 0.0
		lines.append("  %s  —  %s %s  min=%.3f" % [cue_id, where, stream_note, interval])
		count += 1
	if count == 0:
		if filter_text.is_empty():
			return "No sounds found."
		return "No sounds match '%s'." % filter_text
	var header := "%d sounds" % count
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	return header + ":\n" + "\n".join(lines)


func _sound_id_strings() -> Array[String]:
	var out: Array[String] = []
	if AudioDirector.bank == null:
		return out
	for cue_id in AudioDirector.bank.list_ids():
		out.append(String(cue_id))
	return out


func _cmd_phase(_args: Array) -> String:
	var phase_name: String = GameSession.RunPhase.keys()[GameSession.phase]
	return (
		"phase=%s  chill=%s  wave=%d  route_step=%d"
		% [phase_name, GameSession.chill_mode, GameSession.wave_count, GameSession.route_step]
	)


func _cmd_reardoor(args: Array) -> String:
	var doors := get_tree().get_first_node_in_group(&"rear_doors")
	if doors == null or not doors.has_method("toggle"):
		return "Rear doors not found."
	var action: String = str(args[0]).to_lower() if not args.is_empty() else "toggle"
	match action:
		"open":
			doors.open()
			return "Rear doors opening."
		"close":
			doors.close()
			return "Rear doors closing."
		"toggle":
			var was_open: bool = doors.is_open()
			doors.toggle()
			return "Rear doors %s." % ("closing" if was_open else "opening")
		_:
			return "Usage: reardoor [open|close|toggle]"


func _cmd_sidedoor(args: Array) -> String:
	var doors := get_tree().get_first_node_in_group(&"side_doors")
	if doors == null or not doors.has_method("toggle"):
		return "Side doors not found."
	var action: String = str(args[0]).to_lower() if not args.is_empty() else "toggle"
	match action:
		"open":
			doors.open()
			return "Side doors opening."
		"close":
			doors.close()
			return "Side doors closing."
		"toggle":
			var was_open: bool = doors.is_open()
			doors.toggle()
			return "Side doors %s." % ("closing" if was_open else "opening")
		_:
			return "Usage: sidedoor [open|close|toggle]"


func _load_item(item_id: String) -> ItemDefinition:
	return ItemRegistry.load_by_id(item_id)


func _find_player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _find_encounter_director() -> EncounterDirector:
	return get_tree().get_first_node_in_group(&"encounter_director") as EncounterDirector


func _find_travel_controller() -> TravelController:
	return get_tree().get_first_node_in_group(&"travel_controller") as TravelController


func _command_names() -> Array[String]:
	var names: Array[String] = []
	for key in _commands.keys():
		names.append(String(key))
	names.sort()
	return names


func _boon_pool_names() -> Array[String]:
	return ["general", "fire", "poison", "cold", "physical"]


func _filter_prefix(options: Array, partial: String) -> Array[String]:
	var needle := partial.to_lower()
	var matches: Array[String] = []
	for option in options:
		var value := String(option)
		if needle.is_empty() or value.to_lower().begins_with(needle):
			matches.append(value)
	return matches


func _should_add_space_after(parts: Array, _ends_with_space: bool) -> bool:
	if parts.is_empty():
		return true
	if parts.size() == 1:
		return true
	if parts[0] == "list" and parts.size() == 2:
		return true
	return false


func _format_item_list(entries: Array[Dictionary], label: String, filter_text: String) -> String:
	if entries.is_empty():
		if filter_text.is_empty():
			return "No %s found." % label
		return "No %s match '%s'." % [label, filter_text]
	var lines: PackedStringArray = PackedStringArray()
	var header := "%d %s" % [entries.size(), label]
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	lines.append(header + ":")
	for entry in entries:
		lines.append("  %s  —  %s" % [entry.id, entry.name])
	return "\n".join(lines)
