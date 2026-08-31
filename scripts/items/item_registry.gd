class_name ItemRegistry
extends RefCounted

## Resolves item definitions by id from the standard item directories.

const _SEARCH_DIRS: Array[String] = [
	"res://resources/items/boons/",
	"res://resources/items/",
]


static func load_by_id(item_id: String) -> ItemDefinition:
	for dir in _SEARCH_DIRS:
		var path: String = dir + item_id + ".tres"
		if ResourceLoader.exists(path):
			return load(path) as ItemDefinition
	return null


static func list_ids() -> Array[String]:
	var ids: Array[String] = []
	var seen: Dictionary = {}
	for dir_path in _SEARCH_DIRS:
		var dir := DirAccess.open(dir_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var item_id := file_name.get_basename()
				if not seen.has(item_id):
					seen[item_id] = true
					ids.append(item_id)
			file_name = dir.get_next()
	ids.sort()
	return ids


static func list_entries(kind_filter: int = -1, name_filter: String = "") -> Array[Dictionary]:
	var needle := name_filter.strip_edges().to_lower()
	var entries: Array[Dictionary] = []
	for item_id in list_ids():
		var item := load_by_id(item_id)
		if not item:
			continue
		if kind_filter >= 0 and item.kind != kind_filter:
			continue
		if not needle.is_empty():
			var id_text := String(item_id).to_lower()
			var display := item.display_name.to_lower()
			if not id_text.contains(needle) and not display.contains(needle):
				continue
		entries.append({
			"id": String(item_id),
			"name": item.display_name,
			"kind": ItemDefinition.ItemKind.keys()[item.kind],
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.id) < String(b.id)
	)
	return entries
