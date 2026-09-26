extends RefCounted

## Debug console commands: van. Registered in DebugCommands._register_commands.

var host: Node  # the DebugCommands autoload (tree access and shared finders)
var _ghost_return_position := Vector3.ZERO


func _init(owner: Node) -> void:
	host = owner


func cmd_reardoor(args: Array) -> String:
	var doors := host.get_tree().get_first_node_in_group(&"rear_doors")
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


func cmd_sidedoor(args: Array) -> String:
	var doors := host.get_tree().get_first_node_in_group(&"side_doors")
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


func cmd_ghost(args: Array) -> String:
	var player: Node3D = host._find_player()
	if player == null:
		return "no player"
	var action: String = str(args[0]).to_lower() if not args.is_empty() else ""
	var turn_on: bool
	match action:
		"on":
			turn_on = true
		"off":
			turn_on = false
		_:
			turn_on = not bool(player.get("ghost"))
	if turn_on:
		_ghost_return_position = player.position
		player.call(&"set_ghost", true)
		return "ghost on: fly with WASD + mouse, walls off. 'ghost' again to land back."
	player.call(&"set_ghost", false)
	player.position = _ghost_return_position
	return "ghost off"


func cmd_van(args: Array) -> String:
	var look: VanLook = host.get_tree().get_first_node_in_group(VanLook.GROUP) as VanLook
	if look == null:
		return "Van look not found."
	if args.is_empty() or args[0] == "seed":
		return "Van seed: %d%s" % [look.van_seed, " (rerolled)" if look.is_overridden() else ""]
	if args[0] == "reroll":
		var s: int
		if args.size() < 2:
			s = randi()
		elif str(args[1]).is_valid_int():
			s = int(args[1])
		else:
			s = hash(str(args[1]))
		look.reroll(s)
		return "Van rerolled: seed %d." % s
	return "Usage: van [seed|reroll [seed]]"
