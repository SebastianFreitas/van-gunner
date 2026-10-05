extends Node

## Performance benchmark entry scene (tools/perf.py). Spawns the runner under the root because
## SceneRouter.go_to_van() frees the current scene.

const _PerfRunner := preload("res://tools/perf/perf_runner.gd")


func _ready() -> void:
	var runner := _PerfRunner.new()
	runner.name = "PerfRunner"
	get_tree().root.add_child.call_deferred(runner)
