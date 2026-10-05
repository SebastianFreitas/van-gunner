extends CanvasLayer
## F3 performance readout (off, FPS only, full stats with the hitch log); ticks PerfStats each frame.

const GROUP := &"perf_overlay"
const REFRESH_SECONDS := 0.25
## Top of the readout: under the HUD's ammo bar (ends y 224) and its RELOADING line (ends y 251).
const TOP_Y := 256.0
## Row caps keep the full block at 15 lines (286 px, ending y 542), above the driver shout buttons
## that start at y 552 on the 720 px base height. `perf log` and `perf spans` print the full lists.
const MAX_HITCH_ROWS := 3
const MAX_SPAN_ROWS := 7

enum Mode { OFF, FPS, FULL }

var _mode: int = Mode.OFF
var _label: Label
var _since_refresh := 0.0


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_label = Label.new()
	# Under the HUD's top-left block (health, phase, ammo).
	_label.position = Vector2(28, TOP_Y)
	# A clickable HUD control would uncapture the mouse.
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override(&"font_size", 14)
	_label.add_theme_color_override(&"font_color", Color(0.62, 0.66, 0.64))
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 4)
	# 19 px rows: the row caps above count on it.
	_label.add_theme_constant_override(&"line_spacing", -1)
	add_child(_label)
	visible = false


func _process(delta: float) -> void:
	# A tool may enable PerfStats with the overlay off; the frame clock must still tick.
	if PerfStats.enabled:
		PerfStats.tick()
	if _mode == Mode.OFF:
		return
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		_since_refresh = 0.0
		_label.text = stats_text(_mode == Mode.FULL)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"perf_overlay"):
		cycle_mode()
		get_viewport().set_input_as_handled()


func get_mode() -> int:
	return _mode


func set_mode(mode: int) -> void:
	var next := clampi(mode, Mode.OFF, Mode.FULL)
	if next == Mode.OFF:
		PerfStats.enabled = false
	elif _mode == Mode.OFF:
		PerfStats.reset()
		PerfStats.enabled = true
	_mode = next
	visible = next != Mode.OFF
	_since_refresh = 0.0
	_label.text = stats_text(next == Mode.FULL) if next != Mode.OFF else ""


func cycle_mode() -> void:
	set_mode((_mode + 1) % 3)


## The readout text: one line for FPS mode, the full block (counters, hitches, spans) otherwise.
func stats_text(full: bool) -> String:
	var r := PerfStats.recent()
	# Just switched on: the ring is empty and zeros would read as a dead counter.
	var warming := int(r["frames"]) == 0
	if not full:
		if warming:
			return "measuring..."
		return "%d fps  %.1f ms" % [r["fps_avg"], r["avg_ms"]]
	var c := PerfStats.render_counts()
	var lines := PackedStringArray()
	if warming:
		lines.append("measuring...")
	else:
		lines.append("%d fps  %.1f ms avg  %.1f worst  1%% low %d" % [
			r["fps_avg"], r["avg_ms"], r["max_ms"], r["fps_low1"]])
	lines.append("draws %d  prims %d  objects %d  nodes %d" % [
		c["draws"], c["prims"], c["objects"], c["nodes"]])
	lines.append("process %.1f ms  physics %.1f ms  video %d MB  static %d MB" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		c["video_mb"], c["static_mb"]])
	lines.append("hitches over %d ms: %d" % [PerfStats.hitch_ms, PerfStats.hitch_count()])
	var hitches := PerfStats.hitch_rows()
	var now_ms := Time.get_ticks_msec()
	for i in mini(hitches.size(), MAX_HITCH_ROWS):
		var h: Dictionary = hitches[hitches.size() - 1 - i]
		var ago := float(now_ms - int(h["at_ms"])) / 1000.0
		lines.append("  %.1f s ago  %.1f ms  %s" % [ago, h["ms"], h["spans"]])
	lines.append("spans (count  avg ms  max ms)")
	var rows := PerfStats.span_rows()
	for i in mini(rows.size(), MAX_SPAN_ROWS):
		var row: Dictionary = rows[i]
		lines.append("  %s  %d  %.1f  %.1f" % [
			row["label"], row["count"], row["avg_ms"], row["max_ms"]])
	return "\n".join(lines)
