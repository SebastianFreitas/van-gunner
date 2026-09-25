extends RefCounted
## Loads the facade data folders once: districts (sorted by index) and set-pieces (sorted by
## id). Scans with DirAccess like SideStopRegistry so adding a .tres is enough.


const DISTRICTS_DIR := "res://resources/facades/districts/"
const SET_PIECES_DIR := "res://resources/facades/set_pieces/"

static var _districts: Array[FacadeDistrict] = []
static var _loaded := false
static var _set_pieces: Array[FacadeSetPiece] = []
static var _set_pieces_loaded := false


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


static func set_pieces() -> Array[FacadeSetPiece]:
	if _set_pieces_loaded:
		return _set_pieces
	_set_pieces_loaded = true
	_set_pieces = _scan_set_pieces()
	return _set_pieces


static func set_piece(id: StringName) -> FacadeSetPiece:
	for piece: FacadeSetPiece in set_pieces():
		if piece.id == id:
			return piece
	return null


## Clears the cache; the debug console will use this later to hot-reload districts / set-pieces.
static func reset() -> void:
	_districts = []
	_loaded = false
	_set_pieces = []
	_set_pieces_loaded = false


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


static func _scan_set_pieces() -> Array[FacadeSetPiece]:
	var found: Array[FacadeSetPiece] = []
	var dir := DirAccess.open(SET_PIECES_DIR)
	if not dir:
		push_warning("FacadeRegistry: could not open %s." % SET_PIECES_DIR)
		return found
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var listed := file_name
			if listed.ends_with(".remap"):
				listed = listed.trim_suffix(".remap")
			if listed.ends_with(".tres"):
				var res := load(SET_PIECES_DIR + listed)
				if res is FacadeSetPiece:
					found.append(res)
		file_name = dir.get_next()
	found.sort_custom(func(a: FacadeSetPiece, b: FacadeSetPiece) -> bool:
		return String(a.id) < String(b.id)
	)
	return found
