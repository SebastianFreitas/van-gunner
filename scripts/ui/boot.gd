extends Control

@export var minimum_display_time := 0.75


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(minimum_display_time).timeout
	SceneRouter.go_to_main_menu()
