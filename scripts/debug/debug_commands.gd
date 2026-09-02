extends Node

## Parses and runs debug console commands. Add new commands in _register_commands().

const _PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")

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
				matches = _filter_prefix(["boons", "items", "commands"], "")
			_:
				matches = []
	elif parts[0] == "give" or parts[0] == "spawn":
		matches = _filter_prefix(ItemRegistry.list_ids(), partial)
	elif parts[0] == "boonpool":
		matches = _filter_prefix(_boon_pool_names(), partial)
	elif parts[0] == "summon":
		matches = _filter_prefix(["enemy"], partial)
	elif parts[0] == "reardoor":
		matches = _filter_prefix(["open", "close", "toggle"], partial)
	elif parts[0] == "sidedoor":
		matches = _filter_prefix(["open", "close", "toggle"], partial)
	elif parts[0] == "list":
		matches = _filter_prefix(["boons", "items", "commands"], partial)
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
		"reardoor": _cmd_reardoor,
		"sidedoor": _cmd_sidedoor,
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
		+ "  heal [amount]  heal the van\n"
		+ "  boonpool <pool> roll a boon from general/fire/poison/cold/physical\n"
		+ "  list boons [q]  browse boon ids (optional filter)\n"
		+ "  list items [q]  browse all item ids\n"
		+ "  phase          print current run phase\n"
		+ "  reardoor [open|close|toggle]  swing the van rear doors\n"
		+ "  sidedoor [open|close|toggle]  slide the van side doors\n"
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
	var amount: float = float(args[0]) if not args.is_empty() else GameSession.get_max_van_health()
	GameSession.heal_van(amount)
	return "Van healed by %.0f." % amount


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


func _cmd_list(args: Array) -> String:
	if args.is_empty():
		return "Usage: list boons|items|commands [filter]"
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
		_:
			return "Unknown list target: %s  (try boons, items, commands)" % kind


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
