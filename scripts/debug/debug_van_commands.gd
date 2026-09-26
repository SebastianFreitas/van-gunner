extends RefCounted

## Debug console commands: van. Registered in DebugCommands._register_commands.

var host: Node  # the DebugCommands autoload (tree access and shared finders)
var _ghost_return_position := Vector3.ZERO

## Debug inspection lights (torch, floodlight): render layers 1 (street, hull) and
## 2 (van interior), so they light everything the player can fly to.
const DEBUG_LIGHT_MASK := 3
const TORCH_COLOR := Color(1.0, 0.93, 0.8)
const TORCH_ENERGY := 6.0
const TORCH_RANGE_M := 40.0
const TORCH_ANGLE_DEG := 35.0
## Rig-local work-light spots: outside the hull (x +/-2.6, z +/-4.7) at every corner.
const FLOOD_CORNERS: Array[Vector3] = [
	Vector3(9.0, 7.0, -13.0), Vector3(-9.0, 7.0, -13.0),
	Vector3(9.0, 7.0, 13.0), Vector3(-9.0, 7.0, 13.0),
]
const FLOOD_ENERGY := 2.5
const FLOOD_RANGE_M := 35.0


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


func cmd_torch(args: Array) -> String:
	var player: Node3D = host._find_player()
	if player == null:
		return "no player"
	var camera := player.get("camera") as Node3D
	if camera == null:
		return "no player camera"
	var torch := camera.get_node_or_null(^"DebugTorch") as SpotLight3D
	if torch == null:
		torch = SpotLight3D.new()
		torch.name = &"DebugTorch"
		torch.light_color = TORCH_COLOR
		torch.light_energy = TORCH_ENERGY
		torch.spot_range = TORCH_RANGE_M
		torch.spot_angle = TORCH_ANGLE_DEG
		torch.shadow_enabled = true
		# Layers 1 (street, hull) and 2 (van interior); set before add_child, never after.
		torch.light_cull_mask = DEBUG_LIGHT_MASK
		torch.visible = false
		camera.add_child(torch)
	var on := _toggle_target(args, torch.visible)
	torch.visible = on
	return "torch %s" % ("on: a head lamp follows your look (works in ghost)" if on else "off")


func cmd_floodlight(args: Array) -> String:
	var van := host.get_tree().get_first_node_in_group(&"van_run")
	var rig := van.get_node_or_null(^"TravelPath/VanFollow/VanRig") if van != null else null
	if rig == null:
		return "no van rig"
	var flood := rig.get_node_or_null(^"DebugFloodlights") as Node3D
	if flood == null:
		flood = Node3D.new()
		flood.name = &"DebugFloodlights"
		flood.visible = false
		for corner in FLOOD_CORNERS:
			var lamp := OmniLight3D.new()
			lamp.position = corner
			lamp.light_energy = FLOOD_ENERGY
			lamp.omni_range = FLOOD_RANGE_M
			lamp.shadow_enabled = false
			lamp.light_cull_mask = DEBUG_LIGHT_MASK
			flood.add_child(lamp)
		rig.add_child(flood)
	var on := _toggle_target(args, flood.visible)
	flood.visible = on
	return "floodlight %s" % ("on: work lights at the van's four corners" if on else "off")


## Resolves "on" / "off" / bare toggle against the current state.
func _toggle_target(args: Array, current: bool) -> bool:
	var action: String = str(args[0]).to_lower() if not args.is_empty() else ""
	match action:
		"on":
			return true
		"off":
			return false
		_:
			return not current


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
