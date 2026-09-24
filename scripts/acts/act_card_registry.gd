class_name ActCardRegistry
extends RefCounted

## Resolves act street-card definitions by id from resources/acts/cards/.

const _SEARCH_DIR := "res://resources/acts/cards/"


static func load_by_id(card_id: StringName) -> ActCardDefinition:
	if card_id == &"":
		return null
	var path := _SEARCH_DIR + String(card_id) + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as ActCardDefinition
	return null


static func list_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var dir := DirAccess.open(_SEARCH_DIR)
	if not dir:
		push_warning("ActCardRegistry: could not open %s." % _SEARCH_DIR)
		return ids
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var listed := file_name
			if listed.ends_with(".remap"):
				listed = listed.trim_suffix(".remap")
			if listed.ends_with(".tres"):
				ids.append(StringName(listed.get_basename()))
		file_name = dir.get_next()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	if ids.is_empty():
		push_warning("ActCardRegistry: no street cards found in %s." % _SEARCH_DIR)
	return ids


static func list_by_polarity(polarity: ActCardDefinition.Polarity) -> Array[ActCardDefinition]:
	var cards: Array[ActCardDefinition] = []
	for card_id in list_ids():
		var card := load_by_id(card_id)
		if card and card.polarity == polarity:
			cards.append(card)
	return cards