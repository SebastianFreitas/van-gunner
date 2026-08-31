extends Node

## Parses and runs debug console commands. Add new commands in _register_commands().

const _PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")

var _commands: Dictionary = {}


func _ready() -> void:
	if not DebugConfig.ENABLED:
		return
	_register_commands()


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
		"summon": _cmd_summon,
		"give": _cmd_give,
		"spawn": _cmd_spawn,
		"coins": _cmd_coins,
		"heal": _cmd_heal,
		"phase": _cmd_phase,
		"boonpool": _cmd_boonpool,
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
		+ "  summon enemy   spawn a raider at the rear window\n"
		+ "  give <item_id> add item to player (e.g. give frag_grenade)\n"
		+ "  spawn <item_id> drop a pickup near the player\n"
		+ "  coins <n>      add coins\n"
		+ "  heal [amount]  heal the van\n"
		+ "  boonpool <pool> roll a boon from general/fire/poison/cold/physical\n"
		+ "  phase          print current run phase"
	) % ", ".join(names)


func _cmd_chill(_args: Array) -> String:
	GameSession.set_chill_mode(true)
	return "Chill mode ON — van frozen, encounters paused."


func _cmd_unchill(_args: Array) -> String:
	GameSession.set_chill_mode(false)
	return "Chill mode OFF — run resumes."


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


func _cmd_phase(_args: Array) -> String:
	var phase_name: String = GameSession.RunPhase.keys()[GameSession.phase]
	return (
		"phase=%s  chill=%s  wave=%d  route_step=%d"
		% [phase_name, GameSession.chill_mode, GameSession.wave_count, GameSession.route_step]
	)


func _load_item(item_id: String) -> ItemDefinition:
	return ItemRegistry.load_by_id(item_id)


func _find_player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _find_encounter_director() -> EncounterDirector:
	return get_tree().get_first_node_in_group(&"encounter_director") as EncounterDirector
