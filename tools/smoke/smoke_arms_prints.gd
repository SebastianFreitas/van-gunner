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
	var hands := DebugCommands.run("arms hands")
	for line in hands.split("\n"):
		driver.call(&"_log", line)
	if hands.contains("HANDS CHECK"):
		driver.call(&"_fail", hands)
	var reach := DebugCommands.run("arms reach-end")
	for line in reach.split("\n"):
		driver.call(&"_log", line)
	if reach.contains("BAD"):
		driver.call(&"_fail", reach)
	var ram := driver.get_tree().root.find_child("TopRam", true, false) as RearDoorDonorTopRam
	var built: Dictionary = ram.check_built() if ram != null else {"pin_err": INF, "outside": []}
	var pin_err: float = built["pin_err"]
	var lead_clear := RearDoorDonorTopRam.lead_clearance()
	driver.call(&"_log", "%s pin_err=%.4f lead_clearance=%.3f"
			% [RearDoorDonorTopRam.sweep(), pin_err, lead_clear])
	if not lead_clear > 0.0:
		driver.call(&"_fail", "top ram lead_clearance %.3f" % lead_clear)
	for outside: String in built["outside"]:
		driver.call(&"_log", "top ram outside: " + outside)
		driver.call(&"_fail", "top ram outside: " + outside)
	if not pin_err < 0.01:
		driver.call(&"_fail", "top ram pin_err %.4f" % pin_err)


## The framing check after the arm shots; ERR fails smoke.
func frame_check() -> void:
	var frame_line: String = DebugCommands.run("arms frame")
	driver.call(&"_log", frame_line)
	if frame_line.begins_with("FRAME ERR"):
		driver.call(&"_fail", frame_line)
