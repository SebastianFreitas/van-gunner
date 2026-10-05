extends RefCounted

## Console command for the perf overlay: modes, the hitch log, span totals.

const _MODE_NAMES: Array[String] = ["off", "fps", "full"]
const _OFF_TEXT := "Perf stats are off: press F3 or run perf full."

var host: Node  # the DebugCommands autoload (tree access and shared finders)


func _init(owner: Node) -> void:
	host = owner


func cmd_perf(args: Array) -> String:
	var overlay: Node = host.get_tree().get_first_node_in_group(&"perf_overlay")
	if overlay == null or not overlay.has_method(&"set_mode"):
		return "No perf overlay."
	var sub := "" if args.is_empty() else str(args[0]).to_lower()
	match sub:
		"":
			overlay.cycle_mode()
			return "Perf overlay: %s" % _MODE_NAMES[overlay.get_mode()]
		"off", "fps", "full":
			overlay.set_mode(_MODE_NAMES.find(sub))
			return "Perf overlay: %s" % _MODE_NAMES[overlay.get_mode()]
		"log":
			if not PerfStats.enabled:
				return _OFF_TEXT
			var lines: Array[String] = [
				"%d hitches over %d ms" % [PerfStats.hitch_count(), int(PerfStats.hitch_ms)]
			]
			var rows := PerfStats.hitch_rows()
			for i in range(rows.size() - 1, -1, -1):
				var age := float(Time.get_ticks_msec() - int(rows[i]["at_ms"])) / 1000.0
				lines.append("  %.1f s ago  %.1f ms  %s" % [age, rows[i]["ms"], rows[i]["spans"]])
			return "\n".join(lines)
		"spans":
			if not PerfStats.enabled:
				return _OFF_TEXT
			var span_rows := PerfStats.span_rows()
			if span_rows.is_empty():
				return "No spans recorded."
			var lines: Array[String] = ["label  count  avg ms  max ms  total ms"]
			for row in span_rows:
				lines.append("%s  %d  %.2f  %.2f  %.1f" % [
					row["label"], row["count"], row["avg_ms"], row["max_ms"], row["total_ms"],
				])
			return "\n".join(lines)
		"reset":
			PerfStats.reset()
			return "Perf stats cleared."
		"hitch":
			if args.size() > 1 and str(args[1]).is_valid_float():
				PerfStats.hitch_ms = clampf(str(args[1]).to_float(), 5.0, 500.0)
			return "Hitch threshold: %d ms" % int(PerfStats.hitch_ms)
	return host.usage_line("perf")
