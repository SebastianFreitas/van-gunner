extends RefCounted

## Debug console commands: items. Registered in DebugCommands._register_commands.

const _PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")

var host: Node  # the DebugCommands autoload (tree access and shared finders)


func _init(owner: Node) -> void:
	host = owner


func cmd_summon(args: Array) -> String:
	var kind: String = str(args[0]).to_lower() if not args.is_empty() else "enemy"
	if kind != "enemy":
		return "Usage: summon enemy"
	var director: EncounterDirector = host._find_encounter_director()
	if not director:
		return "EncounterDirector not found — are you in the van scene?"
	return director.spawn_debug_raider()


func cmd_give(args: Array) -> String:
	if args.is_empty():
		return "Usage: give <item_id>  (e.g. give chew_tobacco)"
	var item_id: String = str(args[0])
	var item := _load_item(item_id)
	if not item:
		return "Unknown item: %s" % item_id
	var player: Node3D = host._find_player()
	if not player:
		return "Player not found."
	item.collect(player)
	return "Gave %s." % item.display_name


func cmd_spawn(args: Array) -> String:
	if args.is_empty():
		return "Usage: spawn <item_id>"
	var item_id: String = str(args[0])
	var item := _load_item(item_id)
	if not item:
		return "Unknown item: %s" % item_id
	var player: Node3D = host._find_player()
	if not player:
		return "Player not found."
	var pickup := _PICKUP_SCENE.instantiate() as Pickup
	pickup.item = item
	player.get_parent().add_child(pickup)
	var forward := -player.global_transform.basis.z
	pickup.global_position = player.global_position + forward * 1.2 + Vector3(0.0, 0.5, 0.0)
	return "Spawned %s pickup." % item.display_name


func cmd_coins(args: Array) -> String:
	var amount: int = int(args[0]) if not args.is_empty() else 10
	GameSession.add_coins(amount)
	return "Added %d coins (total %d)." % [amount, GameSession.coins]


func cmd_heal(args: Array) -> String:
	var amount: float = float(args[0]) if not args.is_empty() else GameSession.get_max_player_health()
	GameSession.heal_player(amount)
	return "Player healed by %.0f." % amount


func _load_item(item_id: String) -> ItemDefinition:
	return ItemRegistry.load_by_id(item_id)
