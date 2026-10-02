extends RefCounted
## Debug console commands: facade render stats (`facade faces`, `facade perf`), reached from debug_facade_commands.gd.


const _USAGE := "usage: facade faces | facade perf [frames]"
const _MAX_FAMILY_LINES := 20


static func run(rest: PackedStringArray) -> String:
	if rest.is_empty():
		return _USAGE
	match String(rest[0]):
		"faces":
			var root := Engine.get_main_loop() as SceneTree
			var debug_commands: Node = root.root.get_node_or_null("DebugCommands")
			if debug_commands == null or not debug_commands.has_method(&"_find_travel_controller"):
				return "facade faces: no travel controller"
			return faces(debug_commands._find_travel_controller())
		"perf":
			# A static console command can't await frames, so it reads the current monitors.
			if DisplayServer.get_name() == "headless":
				return "facade perf: headless, no renderer"
			return render_line("console")
		_:
			return _USAGE


static func faces(travel: Node) -> String:
	if travel == null or travel.get("corridor_root") == null:
		return "facade faces: no travel controller"
	var families: Dictionary = {}
	var tiles := 0
	var meshes := 0
	var tris := 0
	for tile in travel.corridor_root.get_children():
		if not tile.has_method(&"configure"):
			continue
		tiles += 1
		for node in tile.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			if mesh == null:
				continue
			var count: int = int(mesh.get_faces().size() / 3.0)
			var family := _family(String(node.name))
			var entry: Dictionary = families.get(family, {"meshes": 0, "tris": 0})
			entry["meshes"] = int(entry["meshes"]) + 1
			entry["tris"] = int(entry["tris"]) + count
			families[family] = entry
			meshes += 1
			tris += count
	var names: Array = families.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return int(families[a]["tris"]) > int(families[b]["tris"]))
	var lines: Array[String] = ["facade faces: tiles=%d meshes=%d tris=%d" % [tiles, meshes, tris]]
	for family: String in names.slice(0, _MAX_FAMILY_LINES):
		var entry: Dictionary = families[family]
		lines.append("  %-20s meshes=%4d tris=%7d" % [family, entry["meshes"], entry["tris"]])
	return "\n".join(lines)


static func render_line(label: String) -> String:
	return "RENDER %s: draws=%d prims=%d objects=%d process_ms=%.2f" % [
		label,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
	]

## Strips a "Body<digits>" or "Ruin<digits>" prefix and trailing digits, so
## "Body3ClutterBrick" and "Ruin1Rubble" group with their siblings.
static func _family(node_name: String) -> String:
	var prefix := ""
	for candidate in ["Body", "Ruin"]:
		if node_name.begins_with(candidate):
			prefix = candidate
	var start := prefix.length()
	while start < node_name.length() and node_name[start] >= "0" and node_name[start] <= "9":
		start += 1
	var family := node_name.substr(start)
	if family.is_empty():
		return prefix if not prefix.is_empty() else node_name
	var end := family.length()
	while end > 1 and family[end - 1] >= "0" and family[end - 1] <= "9":
		end -= 1
	return family.substr(0, end)
