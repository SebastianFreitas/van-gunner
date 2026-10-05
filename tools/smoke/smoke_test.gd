extends Node

## Headless smoke test entry scene. Spawns the driver under the root because
## SceneRouter.go_to_van() frees the current scene.

const _SmokeDriver := preload("res://tools/smoke/smoke_driver.gd")


func _ready() -> void:
	# Console lines from `smoke.py --pre`, run before the van scene and its first street exist.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--smoke-pre="):
			var line := arg.trim_prefix("--smoke-pre=")
			print("SMOKE PRE: %s -> %s" % [line, DebugCommands.run(line)])
	var driver := _SmokeDriver.new()
	driver.name = "SmokeDriver"
	get_tree().root.add_child.call_deferred(driver)
