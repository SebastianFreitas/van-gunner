extends Node

## Headless smoke test entry scene. Spawns the driver under the root because
## SceneRouter.go_to_van() frees the current scene.

const _SmokeDriver := preload("res://tools/smoke/smoke_driver.gd")


func _ready() -> void:
	var driver := _SmokeDriver.new()
	driver.name = "SmokeDriver"
	get_tree().root.add_child.call_deferred(driver)
