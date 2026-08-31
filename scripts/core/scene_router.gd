extends Node

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const VAN := "res://scenes/van/van.tscn"

var _transitioning := false


func go_to_main_menu() -> void:
	GameSession.set_chill_mode(false)
	_change_scene(MAIN_MENU)


func go_to_van() -> void:
	_change_scene(VAN)


func _change_scene(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Could not load scene %s (error %s)." % [path, error])
	_transitioning = false
