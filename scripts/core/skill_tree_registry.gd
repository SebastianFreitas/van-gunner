extends RefCounted

## Resolves skill-tree nodes from resources/meta/tree/. Not an autoload and
## no class_name: autoloads / van.gd preload this script instead (same reason
## GameBalance preloads GameBalanceData). Packed listings may use
## foo.tres.remap; strip that before the .tres check.

const _SkillNodeDefinition := preload("res://scripts/meta/skill_node_definition.gd")

const SEARCH_DIR := "res://resources/meta/tree/"
const ORIGIN_ID: StringName = &"origin"
const MAX_NODE_COUNT := 50
const MAX_ALLOCATED := 25

static var _by_id: Dictionary = {}
static var _ids: Array[StringName] = []
static var _scanned := false


static func get_definition(node_id: StringName) -> _SkillNodeDefinition:
	_ensure_scan()
	if node_id == &"":
		return null
	if _by_id.has(node_id):
		return _by_id[node_id] as _SkillNodeDefinition
	return null


static func list_ids() -> Array[StringName]:
	_ensure_scan()
	return _ids.duplicate()


static func list_definitions() -> Array[_SkillNodeDefinition]:
	_ensure_scan()
	var nodes: Array[_SkillNodeDefinition] = []
	for node_id in _ids:
		var node := get_definition(node_id)
		if node:
			nodes.append(node)
	return nodes


static func get_children_of(parent_id: StringName) -> Array[_SkillNodeDefinition]:
	var children: Array[_SkillNodeDefinition] = []
	for node in list_definitions():
		if node.parent_id == parent_id:
			children.append(node)
	return children


static func _ensure_scan() -> void:
	if _scanned:
		return
	_scanned = true
	_scan()


static func _scan() -> void:
	_by_id.clear()
	_ids.clear()
	var dir := DirAccess.open(SEARCH_DIR)
	if not dir:
		push_warning("SkillTreeRegistry: could not open %s." % SEARCH_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var listed := file_name
			if listed.ends_with(".remap"):
				listed = listed.trim_suffix(".remap")
			if listed.ends_with(".tres"):
				var node_id := StringName(listed.get_basename())
				var path := SEARCH_DIR + listed
				if ResourceLoader.exists(path):
					var node := load(path) as _SkillNodeDefinition
					if node:
						if node.id == &"":
							node.id = node_id
						_by_id[node.id] = node
						_ids.append(node.id)
		file_name = dir.get_next()
	_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	if _ids.is_empty():
		push_warning("SkillTreeRegistry: no nodes found in %s." % SEARCH_DIR)
	elif _ids.size() > MAX_NODE_COUNT:
		push_warning(
			"SkillTreeRegistry: %d nodes in %s (cap is %d)."
			% [_ids.size(), SEARCH_DIR, MAX_NODE_COUNT]
		)
