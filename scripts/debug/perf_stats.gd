class_name PerfStats
extends RefCounted
## Frame times, named work spans and a hitch log, ticked by the PerfOverlay autoload and read by
## the overlay, the `perf` console command and tools/perf.

const RING_SIZE := 600
const HITCH_LOG_SIZE := 24

## Off by default so the begin/end/mark calls sprinkled in game code cost one bool test.
static var enabled := false
## A frame at least this long (ms) goes into the hitch log with its heaviest spans.
static var hitch_ms := 25.0

static var _ring := PackedFloat32Array()
static var _ring_pos := 0
static var _capture := PackedFloat32Array()
static var _capturing := false
## StringName to usec spent since the last tick, so a hitch can name its culprits.
static var _frame_spans: Dictionary = {}
## StringName to [count, total_usec, max_usec] over the whole session.
static var _totals: Dictionary = {}
static var _hitches: Array[Dictionary] = []
static var _hitch_count := 0
static var _last_usec := 0


## Start a timed span: pass the result to end(). Returns 0 (ignored by end) when disabled.
static func begin() -> int:
	if not enabled:
		return 0
	return Time.get_ticks_usec()


## Close a span opened with begin() and add it to this frame and to the session totals.
static func end(label: StringName, start_usec: int) -> void:
	if not enabled or start_usec == 0:
		return
	var usec := Time.get_ticks_usec() - start_usec
	_frame_spans[label] = int(_frame_spans.get(label, 0)) + usec
	var t: Array = _totals.get(label, [0, 0, 0])
	t[0] += 1
	t[1] += usec
	t[2] = maxi(int(t[2]), usec)
	_totals[label] = t


## Count an occurrence of `label` (a rebuild, a spawn) without timing it.
static func mark(label: StringName) -> void:
	if not enabled:
		return
	if not _frame_spans.has(label):
		_frame_spans[label] = 0
	var t: Array = _totals.get(label, [0, 0, 0])
	t[0] += 1
	_totals[label] = t


## Close the previous frame: record its length, log it if it was a hitch, clear the frame spans.
static func tick() -> void:
	if not enabled:
		return
	var now := Time.get_ticks_usec()
	if _last_usec == 0:
		_last_usec = now
		_frame_spans.clear()
		return
	var ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	if _ring.size() < RING_SIZE:
		_ring.append(ms)
	else:
		_ring[_ring_pos] = ms
		_ring_pos = (_ring_pos + 1) % RING_SIZE
	if _capturing:
		_capture.append(ms)
	if ms >= hitch_ms:
		_hitch_count += 1
		var labels: Array = _frame_spans.keys()
		labels.sort_custom(
			func(a: StringName, b: StringName) -> bool: return _frame_spans[a] > _frame_spans[b]
		)
		var parts := PackedStringArray()
		for label: StringName in labels.slice(0, 4):
			var usec: int = _frame_spans[label]
			if usec == 0:
				parts.append(String(label))
			else:
				parts.append("%s %.1f" % [label, usec / 1000.0])
		_hitches.append({"at_ms": Time.get_ticks_msec(), "ms": ms, "spans": ", ".join(parts)})
		if _hitches.size() > HITCH_LOG_SIZE:
			_hitches.remove_at(0)
	_frame_spans.clear()


## Drop every sample, span and hitch. Leaves `enabled` and `hitch_ms` alone.
static func reset() -> void:
	_ring.clear()
	_ring_pos = 0
	_capture.clear()
	_capturing = false
	_frame_spans.clear()
	_totals.clear()
	_hitches.clear()
	_hitch_count = 0
	_last_usec = 0


## Frame-time statistics of `ms` (milliseconds per frame); every key is 0 for an empty array.
static func summarize(ms: PackedFloat32Array) -> Dictionary:
	var n := ms.size()
	if n == 0:
		return {
			"frames": 0, "avg_ms": 0.0, "p50_ms": 0.0, "p95_ms": 0.0, "p99_ms": 0.0,
			"max_ms": 0.0, "fps_avg": 0.0, "fps_low1": 0.0,
		}
	var sorted: PackedFloat32Array = ms.duplicate()
	sorted.sort()
	var total := 0.0
	for v: float in sorted:
		total += v
	var avg := total / n
	var p99: float = sorted[mini(int(n * 0.99), n - 1)]
	return {
		"frames": n,
		"avg_ms": avg,
		"p50_ms": sorted[mini(int(n * 0.5), n - 1)],
		"p95_ms": sorted[mini(int(n * 0.95), n - 1)],
		"p99_ms": p99,
		"max_ms": sorted[n - 1],
		"fps_avg": 1000.0 / avg,
		"fps_low1": 1000.0 / p99,
	}


## Statistics of the last RING_SIZE frames.
static func recent() -> Dictionary:
	return summarize(_ring)


## Start a clean capture: a tool reads the whole run through capture_end().
static func capture_begin() -> void:
	reset()
	_capturing = true


## Stop the capture and return its statistics plus the hitch count.
static func capture_end() -> Dictionary:
	_capturing = false
	var out := summarize(_capture)
	out["hitches"] = _hitch_count
	return out


## One row per span label, heaviest total first.
static func span_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for label: StringName in _totals:
		var t: Array = _totals[label]
		var count: int = t[0]
		var total_ms: float = float(t[1]) / 1000.0
		rows.append({
			"label": String(label),
			"count": count,
			"total_ms": total_ms,
			"avg_ms": total_ms / maxf(count, 1.0),
			"max_ms": float(t[2]) / 1000.0,
		})
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a["total_ms"] > b["total_ms"]
	)
	return rows


## The hitch log, oldest first.
static func hitch_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.assign(_hitches)
	return rows


static func hitch_count() -> int:
	return _hitch_count


## Renderer and memory counters from the engine, as whole numbers.
static func render_counts() -> Dictionary:
	return {
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"video_mb": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		"static_mb": int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
	}
