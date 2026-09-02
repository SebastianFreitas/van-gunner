extends Node

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const VAN := "res://scenes/van/van.tscn"

var _transitioning := false
var _van_packed: PackedScene
var _van_preload_started := false
var _shutting_down := false


func go_to_main_menu() -> void:
	GameSession.set_chill_mode(false)
	_change_scene(MAIN_MENU)
	preload_van()


func preload_van() -> void:
	if _van_packed != null or _van_preload_started:
		return
	_van_preload_started = true
	var error := ResourceLoader.load_threaded_request(VAN)
	if error != OK:
		push_error("Could not start threaded load for %s (error %s)." % [VAN, error])
		_van_preload_started = false


func is_van_ready() -> bool:
	return _resolve_van_packed() != null


func go_to_van() -> void:
	if _transitioning:
		return
	_transitioning = true
	var packed := await _await_van_packed()
	var error := OK
	if packed != null:
		error = get_tree().change_scene_to_packed(packed)
	else:
		error = get_tree().change_scene_to_file(VAN)
	if error != OK:
		push_error("Could not load scene %s (error %s)." % [VAN, error])
	_transitioning = false


func _await_van_packed() -> PackedScene:
	preload_van()
	while not _shutting_down:
		var packed := _resolve_van_packed()
		if packed != null:
			return packed
		if not _van_preload_started:
			return null
		var status := ResourceLoader.load_threaded_get_status(VAN)
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Threaded load failed for %s." % VAN)
			_van_preload_started = false
			return null
		await get_tree().process_frame
	return null


func _resolve_van_packed() -> PackedScene:
	if _van_packed != null:
		return _van_packed
	if not _van_preload_started:
		return null
	var status := ResourceLoader.load_threaded_get_status(VAN)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	_van_packed = ResourceLoader.load_threaded_get(VAN) as PackedScene
	return _van_packed


func _change_scene(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Could not load scene %s (error %s)." % [path, error])
	_transitioning = false


func _exit_tree() -> void:
	_shutting_down = true
	_transitioning = false
	_van_preload_started = false
	_van_packed = null
	ProjectilePool.shutdown()
