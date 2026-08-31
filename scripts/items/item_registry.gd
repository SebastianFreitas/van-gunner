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
