extends Control

@export var minimum_display_time := 0.75


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	## Defer van preload one frame so global class registration finishes.
	## Early threaded load of van.tscn can fail with a cryptic parse error.
	call_deferred("_start_van_preload")
	await get_tree().create_timer(minimum_display_time).timeout
	SceneRouter.go_to_main_menu()


func _start_van_preload() -> void:
	SceneRouter.preload_van()
