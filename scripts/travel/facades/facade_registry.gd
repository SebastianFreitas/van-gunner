extends RefCounted
## Loads the facade data folders once: districts (sorted by index) and, from step 8 on,
## set-pieces. Scans with DirAccess like SideStopRegistry so adding a .tres is enough.


const DISTRICTS_DIR := "res://resources/facades/districts/"

static var _districts: Array[FacadeDistrict] = []
static var _loaded := false


static func districts() -> Array[FacadeDistrict]:
	if _loaded:
		return _districts
	_loaded = true
	_districts = _scan_districts()
	if _districts.is_empty():
		push_warning("FacadeRegistry: no districts in %s, using defaults" % DISTRICTS_DIR)
		_districts = [FacadeDistrict.new()]
	return _districts


static func district(index: int) -> FacadeDistrict:
	var all := districts()
	return all[clampi(index, 0, all.size() - 1)]


static func district_count() -> int:
	return districts().size()


## Clears the cache; the debug console will use this later to hot-reload districts.
static func reset() -> void:
	_districts = []
	_loaded = false


static func _scan_districts() -> Array[FacadeDistrict]:
	var found: Array[FacadeDistrict] = []
	var dir := DirAccess.open(DISTRICTS_DIR)
	if not dir:
		push_warning("FacadeRegistry: could not open %s." % DISTRICTS_DIR)
		return found
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var listed := file_name
			if listed.ends_with(".remap"):
				listed = listed.trim_suffix(".remap")
			if listed.ends_with(".tres"):
				var res := load(DISTRICTS_DIR + listed)
				if res is FacadeDistrict:
					found.append(res)
		file_name = dir.get_next()
	found.sort_custom(func(a: FacadeDistrict, b: FacadeDistrict) -> bool:
		return a.index < b.index
	)
	return found
