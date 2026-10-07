extends RefCounted
## Smoke helper: writes the kit golden and runs the kit rules on a ready van.

const SEEDS: Array[int] = [1337, 7, 42]


static func write_golden() -> void:
	var path := ProjectSettings.globalize_path("res://tools/smoke/van_kit_golden.current.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	var lines := PackedStringArray()
	for s in SEEDS:
		_rebuild_for(s)
		lines.append_array(VanKitGolden.lines([s] as Array[int]))
	file.store_string("\n".join(lines) + "\n")
	file.close()
	run_rules()
	_rebuild_for(SEEDS[0])


## Runs the kit rules check on each seed; break lines carry the seed and fail smoke.py.
static func run_rules() -> void:
	var van: Node = Engine.get_main_loop().root.get_tree().get_first_node_in_group(&"van_run")
	var rig: Node3D = van.get_node_or_null(^"TravelPath/VanFollow/VanRig") if van != null else null
	if rig == null:
		print("VAN KIT RULE BREAK: no van rig for the keep-out")
		return
	for s in SEEDS:
		_rebuild_for(s)
		var donors := VanDonors.roll_seed(s)
		var lines := VanKitRules.check(VanKit.place(s), donors, VanKitKeepOut.build(rig, donors))
		for i in lines.size():
			if i == 0:
				print("SMOKE: " + lines[i].replace("van kit rules:", "van kit rules seed %d:" % s))
			elif lines[i].begins_with("VAN KIT RULE BREAK: "):
				print(lines[i].replace("BREAK: ", "BREAK: seed %d " % s))
			elif s == SEEDS[0] or not lines[i].begins_with("paint "):
				print("SMOKE: " + lines[i])


## Rebuilds the van look for a seed so the cables and router, and so the keep-out, follow it.
static func _rebuild_for(seed_value: int) -> void:
	var look: VanLook = Engine.get_main_loop().root.get_tree().get_first_node_in_group(
		VanLook.GROUP) as VanLook
	if look != null:
		var t0 := Time.get_ticks_usec()
		look.rebuild(seed_value)
		print("SMOKE: INFO: van_look rebuild %.1f ms seed %d" % [
			float(Time.get_ticks_usec() - t0) / 1000.0, seed_value])
