extends RefCounted
## `wcam`: look through the van's window cameras (`VanWindowCams`), or hand back the player camera.

const USAGE := "wcam list | <name> [out: outside, looking at the window] | off"

var _host: Node


func _init(host: Node) -> void:
	_host = host


func cmd_wcam(args: Array) -> String:
	var cams := _cams()
	if cams == null:
		return "wcam: no window cameras"
	var names: PackedStringArray = cams.names()
	var list := "window cameras: " + ", ".join(names)
	if args.is_empty() or str(args[0]) == "list":
		return list
	var arg := str(args[0])
	if arg == "off":
		var player := _host.get_tree().get_first_node_in_group(&"player")
		var cam: Camera3D = player.get(&"camera") if player != null else null
		if cam == null:
			return "wcam: no player camera"
		cam.make_current()
		return "wcam off"
	if not names.has(arg):
		return list
	var outward := args.size() > 1 and str(args[1]) == "out"
	cams.aim(arg, outward)
	cams.camera(arg).make_current()
	return "wcam %s%s" % [arg, " out" if outward else ""]


func _cams() -> VanWindowCams:
	var rig := VanAnchors.rig(_host.get_tree())
	if rig == null:
		return null
	for child in rig.get_children():
		if child is VanWindowCams:
			return child
	return null
