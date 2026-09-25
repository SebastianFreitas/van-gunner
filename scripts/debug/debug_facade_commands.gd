extends RefCounted
## Debug console commands for the street facades: force a district or set-piece, reseed the
## tiles in view, print stats and plans, and run the keep-out stress audit.


const _FacadeRegistry := preload("res://scripts/travel/facades/facade_registry.gd")
const _FacadeSetPieces := preload("res://scripts/travel/facades/facade_set_pieces.gd")
const _FacadeAudit := preload("res://scripts/travel/facades/facade_audit.gd")
const _CorridorSegmentScene := preload("res://scenes/corridor/corridor_segment.tscn")

const OPENING_NONE := 0  # mirrors corridor_segment.gd's Opening enum
const OPENING_SIDE_STREET := 1
const OPENING_BAY := 2

const _MAX_STRESS_FAIL_LINES := 20

var host: Node  # the DebugCommands autoload (tree access and shared finders)


func _init(owner: Node) -> void:
	host = owner


## Sub-command names, for DebugCommands.get_completion_context.
func sub_commands() -> Array[String]:
	return ["help", "list", "district", "rare", "reseed", "stats", "dump", "check", "stress"]


func cmd_facade(args: Array) -> String:
	if args.is_empty() or String(args[0]) == "help":
		return _usage()
	var sub := String(args[0])
	var rest := args.slice(1)
	match sub:
		"list":
			return _cmd_list(rest)
		"district":
			return _cmd_district(rest)
		"rare":
			return _cmd_rare(rest)
		"reseed":
			return _cmd_reseed(rest)
		"stats":
			return _cmd_stats(rest)
		"dump":
			return _cmd_dump(rest)
		"check":
			return _cmd_check(rest)
		"stress":
			return _cmd_stress(rest)
		_:
			return "Unknown facade sub-command: %s  (try facade help)" % sub


func _usage() -> String:
	return (
		"facade list                     districts and set-pieces\n"
		+ "facade district <index|id|off>  force the neighborhood district\n"
		+ "facade rare <id|off>            force a set-piece to roll everywhere it's eligible\n"
		+ "facade reseed [n]                reroll every alive tile's facades\n"
		+ "facade stats                     tile / mesh / light / material counts\n"
		+ "facade dump [left|right]         nearest tile's plans and prop node names\n"
		+ "facade check                     mouth keep-out audit over every alive tile\n"
		+ "facade stress [seeds]            build + audit every district x piece x opening"
	)


func _cmd_list(_args: Array) -> String:
	var lines: Array[String] = ["Districts:"]
	for district: FacadeDistrict in _FacadeRegistry.districts():
		lines.append("  %d %s" % [district.index, district.id])
	lines.append("Set-pieces:")
	for piece: FacadeSetPiece in _FacadeRegistry.set_pieces():
		var row := "  %s  weight=%.2f districts=%s span=%s"
		lines.append(row % [piece.id, piece.weight, piece.districts, piece.span])
	return "\n".join(lines)


func _cmd_district(args: Array) -> String:
	var travel: TravelController = host._find_travel_controller()
	if travel == null:
		return "TravelController not found — are you in the van scene?"
	if args.is_empty():
		if travel.has_meta(&"debug_district"):
			var current := int(travel.get_meta(&"debug_district"))
			return "Debug district: %d  (facade district off to clear)" % current
		return "Debug district: off  (usage: facade district <index|id|off>)"
	var token := String(args[0])
	if token == "off":
		travel.remove_meta(&"debug_district")
		return "Debug district: off — neighborhoods pick normally again."
	var index := _district_index(token)
	if index < 0:
		return "Unknown district: %s  (try facade list)" % token
	travel.set_meta(&"debug_district", index)
	var id := _FacadeRegistry.district(index).id
	return "Debug district: %d %s — new tiles use it." % [index, id]


func _cmd_rare(args: Array) -> String:
	if args.is_empty():
		if _FacadeSetPieces.forced_id != &"":
			return "Forced rare: %s  (facade rare off to clear)" % _FacadeSetPieces.forced_id
		return "Forced rare: off  (usage: facade rare <id|off>)"
	var token := String(args[0])
	if token == "off":
		_FacadeSetPieces.forced_id = &""
		return "Forced rare: off."
	var id := StringName(token)
	if _FacadeRegistry.set_piece(id) == null:
		var ids: Array[String] = []
		for piece: FacadeSetPiece in _FacadeRegistry.set_pieces():
			ids.append(String(piece.id))
		return "Unknown set-piece: %s  (ids: %s)" % [token, ", ".join(ids)]
	_FacadeSetPieces.forced_id = id
	return "Forced rare: %s — new tiles roll it whenever it's eligible." % id


func _cmd_reseed(args: Array) -> String:
	var travel: TravelController = host._find_travel_controller()
	if travel == null:
		return "TravelController not found — are you in the van scene?"
	var base_n: int = int(args[0]) if not args.is_empty() else randi()
	var count := 0
	var child_index := 0
	for tile in travel.corridor_root.get_children():
		if not (tile.has_method(&"configure") and tile.has_method(&"apply_side_streets")):
			child_index += 1
			continue
		var left_opening: int = tile.opening_of(&"left")
		var right_opening: int = tile.opening_of(&"right")
		if left_opening == OPENING_BAY or right_opening == OPENING_BAY:
			child_index += 1  # keep BAY sides untouched: skip the whole tile
			continue
		tile.configure(base_n + child_index, tile.district(), hash([base_n, &"nb"]), true)
		tile.apply_side_streets(
			left_opening == OPENING_SIDE_STREET, right_opening == OPENING_SIDE_STREET
		)
		count += 1
		child_index += 1
	return "reseeded %d tiles" % count


func _cmd_stats(_args: Array) -> String:
	var travel: TravelController = host._find_travel_controller()
	if travel == null:
		return "TravelController not found — are you in the van scene?"
	var tiles := 0
	var meshes := 0
	var shader_materials: Dictionary = {}
	for tile in travel.corridor_root.get_children():
		if not (tile.has_method(&"configure") and tile.has_method(&"apply_side_streets")):
			continue
		tiles += 1
		var facades := (tile as Node3D).get_node_or_null("Facades")
		if facades == null:
			continue
		for mesh: MeshInstance3D in facades.find_children("*", "MeshInstance3D", true, false):
			meshes += 1
			if mesh.material_override is ShaderMaterial and String(mesh.name).begins_with("Body"):
				shader_materials[mesh.material_override] = true
	var lights := host.get_tree().get_nodes_in_group(&"facade_lights").size()
	var nearest := _nearest_tile(travel)
	var describe: String = nearest.describe_facades() if nearest else "no tile near the van"
	return "tiles=%d meshes=%d lights=%d shader_materials=%d\n%s" % [
		tiles, meshes, lights, shader_materials.size(), describe
	]


## corridor_segment exposes no per-plan accessor, so this lists built node names, not raw plans.
func _cmd_dump(args: Array) -> String:
	var travel: TravelController = host._find_travel_controller()
	if travel == null:
		return "TravelController not found — are you in the van scene?"
	var nearest := _nearest_tile(travel)
	if nearest == null:
		return "No corridor tile near the van."
	var sides: Array[StringName] = [&"left", &"right"]
	if not args.is_empty():
		var token := String(args[0]).to_lower()
		if token == "left" or token == "right":
			sides = [StringName(token)]
	var lines: Array[String] = [nearest.describe_facades()]
	for side: StringName in sides:
		var root: Node3D = nearest.facade_root(side)
		var names: Array[String] = []
		for node in (root.get_children() if root else []):
			names.append(String(node.name))
		lines.append("%s props: %s" % [side, ", ".join(names)])
	return "\n".join(lines)


func _cmd_check(_args: Array) -> String:
	var travel: TravelController = host._find_travel_controller()
	if travel == null:
		return "TravelController not found — are you in the van scene?"
	var counts := {&"bays": 0, &"checked": 0}
	var violations: Array[String] = []
	for tile in travel.corridor_root.get_children():
		if not (tile is Node3D) or not tile.has_method(&"opening_of"):
			continue
		violations.append_array(_FacadeAudit.tile_mouth_violations(tile as Node3D, counts))
	if violations.is_empty():
		return "OK mouth clear (%d nodes)" % int(counts.get(&"checked", 0))
	return "\n".join(violations)


## Every district x set-piece (plus "none") x opening case x seed, built in isolation and freed.
func _cmd_stress(args: Array) -> String:
	var seeds := 2
	if not args.is_empty() and String(args[0]).is_valid_int():
		seeds = maxi(1, int(args[0]))
	var previous_forced := _FacadeSetPieces.forced_id
	var stress_host := Node3D.new()
	stress_host.name = "FacadeStressHost"
	# Visible: a hidden parent makes is_visible_in_tree() false everywhere, a vacuous pass.
	stress_host.position = Vector3(0.0, -500.0, 0.0)
	host.add_child(stress_host)
	var ids: Array[StringName] = [&""]
	for piece: FacadeSetPiece in _FacadeRegistry.set_pieces():
		ids.append(piece.id)
	var opening_cases: Array = [
		[OPENING_NONE, OPENING_NONE], [OPENING_BAY, OPENING_NONE], [OPENING_NONE, OPENING_BAY]
	]
	var builds := 0
	var fail_lines: Array[String] = []
	for district_idx in _FacadeRegistry.district_count():
		for id: StringName in ids:
			for opening_case: Array in opening_cases:
				for seed_value in seeds:
					builds += 1
					var line := _stress_build(
						stress_host, district_idx, id, opening_case, seed_value
					)
					if not line.is_empty():
						fail_lines.append(line)
	host.remove_child(stress_host)
	stress_host.free()
	_FacadeSetPieces.forced_id = previous_forced
	if fail_lines.is_empty():
		return "OK stress: %d builds, 0 violations" % builds
	if fail_lines.size() > _MAX_STRESS_FAIL_LINES:
		var shown := fail_lines.slice(0, _MAX_STRESS_FAIL_LINES)
		shown.append("... and %d more" % (fail_lines.size() - _MAX_STRESS_FAIL_LINES))
		return "\n".join(shown)
	return "\n".join(fail_lines)


## One build: configure, open_bay if the case has one, both audits, free. FAIL line or "".
func _stress_build(
	stress_host: Node3D, district_idx: int, id: StringName, opening_case: Array, seed_value: int
) -> String:
	_FacadeSetPieces.forced_id = id
	var tile := _CorridorSegmentScene.instantiate() as Node3D
	stress_host.add_child(tile)
	tile.configure(seed_value, district_idx, hash([seed_value]), id != &"")
	tile.apply_side_streets(false, false)
	var bay_side := &""
	if opening_case[0] == OPENING_BAY:
		bay_side = &"left"
	elif opening_case[1] == OPENING_BAY:
		bay_side = &"right"
	if bay_side != &"":
		tile.open_bay(bay_side)
	var mouth_counts := {&"bays": 0, &"checked": 0}
	var violations: Array[String] = _FacadeAudit.tile_mouth_violations(tile, mouth_counts)
	var lane_counts := {&"checked": 0}
	violations.append_array(_FacadeAudit.tile_lane_violations(tile, lane_counts))
	if int(lane_counts.get(&"checked", 0)) == 0:
		violations.append("lane audit checked zero nodes")
	stress_host.remove_child(tile)
	tile.free()
	if violations.is_empty():
		return ""
	return "FAIL district=%d rare=%s openings=%s seed=%d: %s" % [
		district_idx, "none" if id == &"" else String(id), opening_case, seed_value, violations[0]
	]


func _nearest_tile(travel: TravelController) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := INF
	for tile in travel.corridor_root.get_children():
		if not tile.has_meta(&"route_progress"):
			continue
		var dist := absf(float(tile.get_meta(&"route_progress")) - travel.van_follow.progress)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = tile as Node3D
	return nearest


func _district_index(token: String) -> int:
	if token.is_valid_int():
		var index := int(token)
		return index if index >= 0 and index < _FacadeRegistry.district_count() else -1
	for district: FacadeDistrict in _FacadeRegistry.districts():
		if String(district.id) == token:
			return district.index
	return -1
