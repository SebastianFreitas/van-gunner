extends Node

## Parses and runs debug console commands. Add new commands in _register_commands().

const _DebugCatalog := preload("res://scripts/debug/debug_catalog.gd")
const _RunFlowCommands := preload("res://scripts/debug/debug_run_flow_commands.gd")
const _ItemCommands := preload("res://scripts/debug/debug_item_commands.gd")
const _ActCommands := preload("res://scripts/debug/debug_act_commands.gd")
const _VanCommands := preload("res://scripts/debug/debug_van_commands.gd")
const _MetaCommands := preload("res://scripts/debug/debug_meta_commands.gd")
const _FacadeCommands := preload("res://scripts/debug/debug_facade_commands.gd")

var _commands: Dictionary = {}

var _run_flow: RefCounted
var _items: RefCounted
var _acts: RefCounted
var _van: RefCounted
var _meta: RefCounted
var _catalog: RefCounted
var _facade: RefCounted


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
			"summon":
				matches = _filter_prefix(["enemy"], "")
			"reardoor":
				matches = _filter_prefix(["open", "close", "toggle"], "")
			"sidedoor":
				matches = _filter_prefix(["open", "close", "toggle"], "")
			"list":
				matches = _filter_prefix(
					["boons", "items", "commands", "classes", "cards", "stops", "sounds", "tree"], ""
				)
			"sound":
				matches = _filter_prefix(_DebugCatalog.sound_id_strings(), "")
			"card":
				matches = _filter_prefix(_DebugCatalog.card_id_strings(), "")
			"stop":
				matches = _filter_prefix(_DebugCatalog.stop_force_tokens(), "")
			"class":
				matches = _filter_prefix(_DebugCatalog.class_id_strings(), "")
			"facade":
				matches = _filter_prefix(_facade.sub_commands(), "")
			_:
				matches = []
	elif parts[0] == "give" or parts[0] == "spawn":
		matches = _filter_prefix(ItemRegistry.list_ids(), partial)
	elif parts[0] == "class":
		matches = _filter_prefix(_DebugCatalog.class_id_strings(), partial)
	elif parts[0] == "card":
		matches = _filter_prefix(_DebugCatalog.card_id_strings(), partial)
	elif parts[0] == "stop":
		if parts.size() >= 2 and SideStopRegistry.arrival_from_label(str(parts[1])) >= 0:
			matches = _filter_prefix(_DebugCatalog.stop_id_strings(), partial)
		else:
			matches = _filter_prefix(_DebugCatalog.stop_force_tokens(), partial)
	elif parts[0] == "summon":
		matches = _filter_prefix(["enemy"], partial)
	elif parts[0] == "reardoor":
		matches = _filter_prefix(["open", "close", "toggle"], partial)
	elif parts[0] == "sidedoor":
		matches = _filter_prefix(["open", "close", "toggle"], partial)
	elif parts[0] == "list":
		matches = _filter_prefix(
			["boons", "items", "commands", "weapons", "cards", "stops", "sounds", "tree"], partial
		)
	elif parts[0] == "sound":
		matches = _filter_prefix(_DebugCatalog.sound_id_strings(), partial)
	elif parts[0] == "facade":
		matches = _filter_prefix(_facade.sub_commands(), partial)
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
	_run_flow = _RunFlowCommands.new(self)
	_items = _ItemCommands.new(self)
	_acts = _ActCommands.new(self)
	_van = _VanCommands.new(self)
	_meta = _MetaCommands.new(self)
	_catalog = _DebugCatalog.new(self)
	_facade = _FacadeCommands.new(self)
	_commands = {
		"help": _cmd_help,
		"chill": _run_flow.cmd_chill,
		"unchill": _run_flow.cmd_unchill,
		"speed": _run_flow.cmd_speed,
		"unspeed": _run_flow.cmd_unspeed,
		"summon": _items.cmd_summon,
		"give": _items.cmd_give,
		"spawn": _items.cmd_spawn,
		"coins": _items.cmd_coins,
		"heal": _items.cmd_heal,
		"phase": _run_flow.cmd_phase,
		"list": _catalog.cmd_list,
		"card": _acts.cmd_card,
		"stop": _acts.cmd_stop,
		"boss": _acts.cmd_boss,
		"reardoor": _van.cmd_reardoor,
		"sidedoor": _van.cmd_sidedoor,
		"class": _meta.cmd_class,
		"sound": _meta.cmd_sound,
		"parts": _meta.cmd_parts,
		"tree_reset": _meta.cmd_tree_reset,
		"facade": _facade.cmd_facade,
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
		+ "  class [id]      print the class, or equip one in any phase (e.g. class sniper)\n"
		+ "  list classes [q] browse class ids\n"
		+ "  list sounds [q] browse SoundCue ids\n"
		+ "  list tree [q]   browse skill-tree node ids\n"
		+ "  sound <cue>     play a cue (audition without a run)\n"
		+ "  parts [n]       add Rare Parts (meta schematic currency)\n"
		+ "  tree_reset      wipe the schematic back to origin (keeps parts)\n"
		+ "  facade [sub]    street facade debug (try facade help)\n"
		+ "  Tab            autocomplete command or item id"
	) % ", ".join(names)


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
