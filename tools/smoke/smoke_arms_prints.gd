extends RefCounted

## Smoke step: print-only arm checks (IK bars, touch) and the reach-end check that fails smoke on BAD.

var driver: Node


func _init(owner: Node) -> void:
	driver = owner


## The IK bars and touch lines never enter the fingerprint and never fail smoke; reach-end does.
func run() -> void:
	for sub: String in ["ik", "touch"]:
		var lines := DebugCommands.run("arms " + sub).split("\n")
		for line in lines.slice(maxi(lines.size() - 3, 0)):
			driver.call(&"_log", "arms %s: %s" % [sub, line])
	var reach := DebugCommands.run("arms reach-end")
	for line in reach.split("\n"):
		driver.call(&"_log", line)
	if reach.contains("BAD"):
		driver.call(&"_fail", reach)


## The framing check after the arm shots; ERR fails smoke.
func frame_check() -> void:
	var frame_line: String = DebugCommands.run("arms frame")
	driver.call(&"_log", frame_line)
	if frame_line.begins_with("FRAME ERR"):
		driver.call(&"_fail", frame_line)
