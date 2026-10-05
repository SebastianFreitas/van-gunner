extends Node

## Performance benchmark driver (tools/perf.py): opens the van, idles, cruises, rushes and fights
## on the real renderer while PerfStats records, and prints one `PERF key=value` line per number.
## Runs only with -- --smoke-sandbox so no save is touched.

const _WATCHDOG_SECONDS := 260.0
const _OPEN_SPAN_WAIT_S := 5.0
const _ROUTE_WAIT_S := 20.0
const _STOP_WAIT_S := 60.0
const _IDLE_SETTLE_S := 2.0
const _IDLE_SECONDS := 5.0
const _RUSH_SECONDS := 12.0
const _COMBAT_SECONDS := 8.0
const _STALL_MS := 2000
const _HITCH_LINES := 10

var _cruise_seconds := 30.0


func _ready() -> void:
	var watchdog := get_tree().create_timer(_WATCHDOG_SECONDS)
	watchdog.timeout.connect(_fail.bind("watchdog timeout"))
	var vsync := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-seconds="):
			_cruise_seconds = float(arg.trim_prefix("--perf-seconds="))
		elif arg == "--perf-vsync":
			vsync = true
	if not vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	PerfStats.reset()
	PerfStats.enabled = true
	_run()


func _run() -> void:
	# Opened by hand without the sandbox, this run would start against the real saves.
	if not SaveSandbox.enabled:
		_fail("save sandbox is off; run through tools/perf.py")
		return
	print("PERF open.engine_to_runner_ms=%d" % Time.get_ticks_msec())
	var t0 := Time.get_ticks_msec()
	GameSession.start_new(1)
	SceneRouter.go_to_van()
	if not await _wait_for_van_ready():
		return
	print("PERF open.van_ready_ms=%d" % (Time.get_ticks_msec() - t0))
	var built := await _wait_until(_has_span.bind("arms_build"), _OPEN_SPAN_WAIT_S)
	await _frames(1)
	print("PERF open.arms_ms=%d" % ((Time.get_ticks_msec() - t0) if built else -1))
	_print_spans("open")

	await _seconds(_IDLE_SETTLE_S)
	PerfStats.capture_begin()
	var start := Time.get_ticks_msec()
	await _seconds(_IDLE_SECONDS)
	_print_section("idle", start, "time")

	DebugCommands.run("speed")
	DebugCommands.run("chill")
	if not await _reach_open_street():
		return
	DebugCommands.run("unspeed")

	await _drive_section("cruise", _cruise_seconds)
	DebugCommands.run("speed")
	await _drive_section("rush", _RUSH_SECONDS)
	await _combat_section()

	print("PERF: done")
	get_tree().quit()


## Tiles do not spawn at a fork, so the benchmark takes the first fork and leaves its stop before
## measuring: the cruise then drives an open street.
func _reach_open_street() -> bool:
	if not await _wait_phase(GameSession.RunPhase.ROUTE_CHOICE, _ROUTE_WAIT_S):
		_fail("no ROUTE_CHOICE after the run began")
		return false
	var dirs := GameSession.get_route_directions()
	if dirs.is_empty():
		_fail("the fork offered no direction")
		return false
	GameSession.choose_route(dirs[0])
	if not await _wait_phase(GameSession.RunPhase.STOP, _STOP_WAIT_S):
		_fail("the van did not reach a stop")
		return false
	await _frames(10)
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	if travel == null or not travel.has_method(&"leave_stop"):
		_fail("no travel controller")
		return false
	travel.call(&"leave_stop")
	if not await _wait_phase(GameSession.RunPhase.TRAVELLING, _STOP_WAIT_S):
		_fail("the van did not leave the stop")
		return false
	await _frames(5)
	return true


func _wait_phase(target: GameSession.RunPhase, timeout_s: float) -> bool:
	return await _wait_until(func() -> bool: return GameSession.phase == target, timeout_s)


## Records `seconds` of driving, or less when the run leaves the street phases for 2 s.
func _drive_section(section: String, seconds: float) -> void:
	PerfStats.capture_begin()
	var start := Time.get_ticks_msec()
	var stalled_since := -1
	var ended_by := "time"
	while float(Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await get_tree().process_frame
		if _is_driving():
			stalled_since = -1
		elif stalled_since < 0:
			stalled_since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - stalled_since >= _STALL_MS:
			ended_by = _phase_name()
			break
	_print_section(section, start, ended_by)


## Four raiders at normal speed while the gun fires every frame.
func _combat_section() -> void:
	DebugCommands.run("unspeed")
	DebugCommands.run("unchill")
	for _i in range(4):
		DebugCommands.run("summon enemy")
	PerfStats.capture_begin()
	var start := Time.get_ticks_msec()
	var ended_by := "time"
	while float(Time.get_ticks_msec() - start) / 1000.0 < _COMBAT_SECONDS:
		await get_tree().process_frame
		if GameSession.phase == GameSession.RunPhase.GAME_OVER:
			ended_by = _phase_name()
			break
		var gun := get_tree().get_first_node_in_group(&"gun_controller")
		if gun != null and gun.has_method(&"try_fire"):
			gun.call(&"try_fire")
	_print_section("combat", start, ended_by)


func _is_driving() -> bool:
	return GameSession.phase in [
		GameSession.RunPhase.TRAVELLING,
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.ROUTE_CHOICE,
		GameSession.RunPhase.TURNING,
	]


func _phase_name() -> String:
	var names: Array = GameSession.RunPhase.keys()
	return String(names[GameSession.phase])


func _has_span(label: String) -> bool:
	for row in PerfStats.span_rows():
		if row["label"] == label:
			return true
	return false


## Closes the capture and prints the section's frame statistics, render counts, spans and hitches.
func _print_section(section: String, start_msec: int, ended_by: String) -> void:
	var stats := PerfStats.capture_end()
	var seconds := float(Time.get_ticks_msec() - start_msec) / 1000.0
	print("PERF %s.seconds=%.2f" % [section, seconds])
	print("PERF %s.ended_by=%s" % [section, ended_by])
	print("PERF %s.frames=%d" % [section, stats["frames"]])
	print("PERF %s.fps_avg=%.2f" % [section, stats["fps_avg"]])
	print("PERF %s.fps_low1=%.2f" % [section, stats["fps_low1"]])
	print("PERF %s.ms_p50=%.3f" % [section, stats["p50_ms"]])
	print("PERF %s.ms_p95=%.3f" % [section, stats["p95_ms"]])
	print("PERF %s.ms_p99=%.3f" % [section, stats["p99_ms"]])
	print("PERF %s.ms_max=%.3f" % [section, stats["max_ms"]])
	print("PERF %s.hitches=%d" % [section, stats["hitches"]])
	var counts := PerfStats.render_counts()
	for key: String in counts:
		print("PERF %s.%s=%d" % [section, key, counts[key]])
	_print_spans(section)
	var hitches := PerfStats.hitch_rows()
	hitches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["ms"] > b["ms"])
	for row in hitches.slice(0, _HITCH_LINES):
		print("PERF hitch %s %.1f ms: %s" % [section, row["ms"], row["spans"]])


func _print_spans(prefix: String) -> void:
	for row in PerfStats.span_rows():
		var base := "PERF %s.span.%s" % [prefix, row["label"]]
		print("%s.count=%d" % [base, row["count"]])
		print("%s.avg_ms=%.3f" % [base, row["avg_ms"]])
		print("%s.max_ms=%.3f" % [base, row["max_ms"]])
		print("%s.total_ms=%.3f" % [base, row["total_ms"]])


func _wait_for_van_ready() -> bool:
	var elapsed := 0.0
	while elapsed < 30.0:
		if (
			get_tree().get_first_node_in_group(&"van_run")
			and get_tree().get_first_node_in_group(&"gun_stats")
			and get_tree().get_first_node_in_group(&"player")
		):
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_fail("timed out waiting for the van scene to be ready")
	return false


func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_s:
		if cond.call():
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return false


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _fail(msg: String) -> void:
	push_error("perf: " + msg)
	get_tree().quit(1)
