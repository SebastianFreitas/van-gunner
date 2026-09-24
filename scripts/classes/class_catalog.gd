class_name ClassCatalog
extends RefCounted

## Resolves player classes by id from resources/classes/. Unknown ids fall back
## to Basic so an edited profile or save never leaves the player without a gun.

const DEFAULT_ID := &"basic"
const _SEARCH_DIR := "res://resources/classes/"


static func load_by_id(class_id: StringName) -> ClassDefinition:
	if class_id == &"":
		return null
	var path := _SEARCH_DIR + String(class_id) + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as ClassDefinition
	return null


## The class for an id, or Basic when the id is empty or unknown.
static func load_or_basic(class_id: StringName) -> ClassDefinition:
	var def := load_by_id(class_id)
	if def == null:
		def = load_by_id(DEFAULT_ID)
	return def


## The id itself when it names a class, otherwise Basic's.
static func resolve_id(class_id: StringName) -> StringName:
	if load_by_id(class_id) != null:
		return class_id
	return DEFAULT_ID


static func list_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var dir := DirAccess.open(_SEARCH_DIR)
	if not dir:
		push_warning("ClassCatalog: could not open %s." % _SEARCH_DIR)
		return ids
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var listed := file_name
			## Packed builds list foo.tres.remap; strip it before the .tres check.
			if listed.ends_with(".remap"):
				listed = listed.trim_suffix(".remap")
			if listed.ends_with(".tres"):
				ids.append(StringName(listed.get_basename()))
		file_name = dir.get_next()
	dir.list_dir_end()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	if ids.is_empty():
		push_warning("ClassCatalog: no classes found in %s." % _SEARCH_DIR)
	return ids


static func list_all() -> Array[ClassDefinition]:
	var defs: Array[ClassDefinition] = []
	for class_id in list_ids():
		var def := load_by_id(class_id)
		if def:
			defs.append(def)
	return defs
