class_name WeaponCatalog
extends RefCounted

## Loads WeaponDefinition resources from resources/weapons/definitions/.

const DEFINITIONS_DIR := "res://resources/weapons/definitions/"

static var _cache: Dictionary = {}


static func load_definition(definition_id: StringName) -> WeaponDefinition:
	var key := String(definition_id)
	if _cache.has(key):
		return _cache[key] as WeaponDefinition
	var path := DEFINITIONS_DIR + key + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("WeaponCatalog: missing definition %s" % key)
		return null
	var def := load(path) as WeaponDefinition
	if def:
		_cache[key] = def
	return def


static func list_definition_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open(DEFINITIONS_DIR)
	if not dir:
		return ids
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			ids.append(file_name.get_basename())
		file_name = dir.get_next()
	ids.sort()
	return ids


static func all_definitions() -> Array[WeaponDefinition]:
	var result: Array[WeaponDefinition] = []
	for id in list_definition_ids():
		var def := load_definition(StringName(id))
		if def:
			result.append(def)
	return result


static func clear_cache() -> void:
	_cache.clear()
