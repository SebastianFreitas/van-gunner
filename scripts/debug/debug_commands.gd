extends Node

## Parses and runs debug console commands. Add new commands in _register_commands().

const _DebugCatalog := preload("res://scripts/debug/debug_catalog.gd")
const _RunFlowCommands := preload("res://scripts/debug/debug_run_flow_commands.gd")
const _ItemCommands := preload("res://scripts/debug/debug_item_commands.gd")
const _ActCommands := preload("res://scripts/debug/debug_act_commands.gd")
const _VanCommands := preload("res://scripts/debug/debug_van_commands.gd")
const _MetaCommands := preload("res://scripts/debug/debug_meta_commands.gd")
const _FacadeCommands := preload("res://scripts/debug/debug_facade_commands.gd")
const _ArmsCommands := preload("res://scripts/debug/debug_arms_commands.gd")
const _PerfCommands := preload("res://scripts/debug/debug_perf_commands.gd")
const _Completion := preload("res://scripts/debug/debug_completion.gd")

var _commands: Dictionary = {}

var _run_flow: RefCounted
var _items: RefCounted
var _acts: RefCounted
var _van: RefCounted
var _meta: RefCounted
var _catalog: RefCounted
var _facade: RefCounted
var _arms: RefCounted
var _perf: RefCounted
var _completion: RefCounted


func _ready() -> void:
	if not DebugConfig.ENABLED:
		return
	_register_commands()


## Tab completion state for the console; see debug_completion.gd for the returned keys.
func get_completion_context(text: String, caret_col: int) -> Dictionary:
	return _completion.context(text, caret_col)


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
	_arms = _ArmsCommands.new(self)
	_perf = _PerfCommands.new(self)
	_completion = _Completion.new(self)
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
		"ghost": _van.cmd_ghost,
		"torch": _van.cmd_torch,
		"floodlight": _van.cmd_floodlight,
		"gaplight": _van.cmd_gaplight,
		"bars": _van.cmd_bars,
		"van": _van.cmd_van,
		"class": _meta.cmd_class,
		"sound": _meta.cmd_sound,
		"parts": _meta.cmd_parts,
		"tree_reset": _meta.cmd_tree_reset,
		"facade": _facade.cmd_facade,
		"walk_wreck": _facade.cmd_walk_wreck,
		"arms": _arms.cmd_arms,
		"perf": _perf.cmd_perf,
	}


func _cmd_help(args: Array) -> String:
	var usage := _usage_lines()
	if not args.is_empty():
		var wanted := str(args[0]).to_lower()
		if not _commands.has(wanted):
			return "unknown command %s; try help" % wanted
		return _usage_text(wanted, usage)
	var lines: Array[String] = ["Commands: %s" % ", ".join(_command_names())]
	for key in _commands.keys():
		lines.append(_usage_text(String(key), usage))
	lines.append("  Tab            autocomplete, then fill current values (arms)")
	return "\n".join(lines)


## One command's usage line (the first line of its text), or "".
func usage_line(cmd: String) -> String:
	var text: String = _usage_lines().get(cmd, "")
	return text.split("\n")[0].strip_edges()


func _usage_text(cmd: String, usage: Dictionary) -> String:
	assert(usage.has(cmd), "debug command %s has no usage line" % cmd)
	if not usage.has(cmd):
		return "  %s  (no description)" % cmd
	var text: String = usage[cmd]
	if cmd == "arms":
		text = _arms.usage()
	return "  " + text.replace("\n", "\n  ")


## Command name -> one-line usage (several lines when it has sub-forms).
func _usage_lines() -> Dictionary:
	return {
		"help": "help [cmd]  list commands, or show one command's usage",
		"chill": "chill          pause encounters; the van keeps moving",
		"unchill": "unchill        resume normal run flow",
		"speed": "speed          debug turbo: fast travel, skips intro, compresses timers",
		"unspeed": "unspeed        turn off debug turbo",
		"summon": "summon <enemy|loper>  raider assaults a breach slot, or a loper climbs the wall",
		"give": "give <item_id> add item to player (e.g. give frag_grenade)",
		"spawn": "spawn <item_id> drop a pickup near the player",
		"coins": "coins <n>      add coins",
		"heal": "heal [amount]  heal the player",
		"phase": "phase          print current run phase",
		"list": "list <kind> [q]  browse ids: boons, items, commands, classes, cards, stops, "
				+ "sounds, tree (optional filter)",
		"card": "card [id]       print / force-activate active street card(s)",
		"stop": "stop <id>       next fork offers that stop on every road\n"
				+ "stop <arrival> <content>  compose e.g. stop elevator shop",
		"boss": "boss            skip to act-end boss pick (current six streets)",
		"reardoor": "reardoor [open|close|toggle]  swing the van rear doors",
		"sidedoor": "sidedoor [open|close|toggle]  slide the van side doors",
		"ghost": "ghost [on|off]  fly through the van walls to look at it from outside",
		"torch": "torch [on|off]  head lamp on your camera (inspection light, rides with ghost)",
		"floodlight": "floodlight [on|off]  work lights at the van's four corners",
		"gaplight": "gaplight [on|out|off]  paints everything that is not van magenta "
				+ "(on: seen from the cabin, out: seen from the street)",
		"bars": "bars <0|1|2|break|fix>  window bars: damage stage, break, or restore (looks only)",
		"van": "van seed        print the van look seed\n"
				+ "van reroll [s]  rebuild the van look from a new (or given) seed",
		"class": "class [id]      print the class, or equip one in any phase (e.g. class sniper)",
		"sound": "sound <cue>     play a cue (audition without a run)",
		"parts": "parts [n]       add Rare Parts (meta schematic currency)",
		"tree_reset": "tree_reset      wipe the schematic back to origin (keeps parts)",
		"facade": "facade [sub]    street facade debug (try facade help)",
		"walk_wreck": "walk_wreck [share]  obliterated sidewalk share (default 0.30), rebuilds the street",
		"arms": "arms <sub> [args]  first-person arms debug (current values shown)",
		"perf": "perf [off|fps|full|log|spans|reset|hitch <ms>]  F3 perf overlay, hitch log, "
				+ "span totals",
	}


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
