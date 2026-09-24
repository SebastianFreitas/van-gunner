extends RefCounted

## Debug console commands: van. Registered in DebugCommands._register_commands.

var host: Node  # the DebugCommands autoload (tree access and shared finders)


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
