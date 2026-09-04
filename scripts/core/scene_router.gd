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
	call_deferred("preload_van")


func preload_van() -> void:
	if _van_packed != null or _van_preload_started:
		return
	_van_preload_started = true
	## Sync load on the main thread. Threaded load of van.tscn fails cold with a
	## cryptic parse error at the floor shader sub_resource (Godot worker-thread
	## script/shader graph issue); sync load is reliable.
	var packed := ResourceLoader.load(VAN) as PackedScene
	if packed == null:
		push_error("Could not load %s." % VAN)
		_van_preload_started = false
		return
	_van_packed = packed


func is_van_ready() -> bool:
	return _van_packed != null


func go_to_van() -> void:
	if _transitioning:
		return
	_transitioning = true
	preload_van()
	var error := OK
	if _van_packed != null:
		error = get_tree().change_scene_to_packed(_van_packed)
	else:
		error = get_tree().change_scene_to_file(VAN)
	if error != OK:
		push_error("Could not load scene %s (error %s)." % [VAN, error])
	_transitioning = false


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
