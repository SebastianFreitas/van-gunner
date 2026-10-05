extends RefCounted

## Runs queued tile build steps a few per frame, so a new street tile never lands in one frame.

## Milliseconds of steps run per frame before the rest wait; one step always runs.
const BUDGET_MS := 3.0

## `[tile, step]` pairs, in the order they were added.
var _jobs: Array = []
## Rendered frame of the last `step()`: `_physics_process` can tick several times per frame.
var _last_step_frame := -1


func add(tile: Node, steps: Array[Callable]) -> void:
	for step_call in steps:
		_jobs.append([tile, step_call])


func is_empty() -> bool:
	return _jobs.is_empty()


## Runs steps until BUDGET_MS is spent. At most once per rendered frame.
func step() -> void:
	var frame := Engine.get_process_frames()
	if frame == _last_step_frame:
		return
	_last_step_frame = frame
	var started := Time.get_ticks_usec()
	var budget_usec := int(BUDGET_MS * 1000.0)
	while not _jobs.is_empty():
		_run_next()
		if Time.get_ticks_usec() - started >= budget_usec:
			return


## Runs everything left, now.
func flush() -> void:
	while not _jobs.is_empty():
		_run_next()


func _run_next() -> void:
	var job: Array = _jobs.pop_front()
	var tile: Node = job[0] if is_instance_valid(job[0]) else null
	if tile == null or tile.is_queued_for_deletion():
		return
	var step_call: Callable = job[1]
	var perf_t := PerfStats.begin()
	step_call.call()
	PerfStats.end(&"tile_step", perf_t)
