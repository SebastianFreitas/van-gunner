class_name SideStopRegistry
extends RefCounted

## Resolves side-stop definitions by id from resources/side_stops/.

const _SEARCH_DIR := "res://resources/side_stops/"


static func load_by_id(stop_id: StringName) -> SideStopDefinition:
	if stop_id == &"":
		return null
	match String(stop_id).to_lower().replace(" ", "_"):
		"rare_vendor", "undercroft", "undershop", "vault":
			stop_id = &"rare_shop"
	var path := _SEARCH_DIR + String(stop_id) + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as SideStopDefinition
	return null


static func list_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var dir := DirAccess.open(_SEARCH_DIR)
	if not dir:
		push_warning("SideStopRegistry: could not open %s." % _SEARCH_DIR)
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
		push_warning("SideStopRegistry: no side stops found in %s." % _SEARCH_DIR)
	return ids


## Parse "rear_park" / "elevator" (and a few aliases). Returns -1 if unknown.
static func arrival_from_label(text: String) -> int:
	var key := text.strip_edges().to_lower().replace(" ", "").replace("_", "")
	match key:
		"rearpark", "normalrearpark", "bay":
			return SideStopDefinition.Arrival.REAR_PARK
		"elevator", "undergroundelevator", "underground":
			return SideStopDefinition.Arrival.ELEVATOR
	return -1


## Pair any content stop with an arrival without writing a new .tres.
static func compose(
	content_id: StringName, arrival: SideStopDefinition.Arrival
) -> SideStopDefinition:
	var stop := load_by_id(content_id)
	if stop == null or stop.scene == null:
		return null
	var copy := stop.duplicate() as SideStopDefinition
	if copy == null:
		return null
	copy.arrival = arrival
	if arrival != stop.arrival:
		copy.parking_toast = ""
		copy.leaving_toast = ""
	return copy


static func pick(
	rng: RandomNumberGenerator,
	except_ids: Array[StringName] = []
) -> SideStopDefinition:
	var ids := list_ids()
	if ids.is_empty():
		return null
	var pool: Array[StringName] = []
	for stop_id in ids:
		if except_ids.is_empty() or stop_id not in except_ids:
			pool.append(stop_id)
	if pool.is_empty():
		pool = ids.duplicate()
	return load_by_id(_pick_weighted_id(rng, pool))


static func _pick_weighted_id(
	rng: RandomNumberGenerator,
	pool: Array[StringName]
) -> StringName:
	if pool.is_empty():
		return &""
	var weights: Array[float] = []
	var total := 0.0
	for stop_id in pool:
		var stop := load_by_id(stop_id)
		var weight := 0.0
		if stop and stop.scene != null:
			weight = maxf(stop.spawn_weight, 0.0)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return pool[rng.randi() % pool.size()]
	var roll := rng.randf() * total
	var cursor := 0.0
	for index in pool.size():
		cursor += weights[index]
		if roll <= cursor:
			return pool[index]
	return pool[pool.size() - 1]
