extends Node
## Headless van audit entry scene: collects every visible triangle of the van, checks
## it and writes a report. Mirrors tools/probe: the entry scene spawns a worker under
## the root because SceneRouter.go_to_van() frees the current scene.
## `--audit-passes=a,b` runs only those of closed, half, open, win_half, win_open, tail
## (default all), so tools/smoke.py can shard the run.

const AuditMesh := preload("res://tools/van_audit/van_audit_mesh.gd")
const AuditStates := preload("res://tools/van_audit/van_audit_states.gd")
const AuditOverlap := preload("res://tools/van_audit/van_audit_overlap.gd")
const AuditGaps := preload("res://tools/van_audit/van_audit_gaps.gd")
const AuditLeaks := preload("res://tools/van_audit/van_audit_leaks.gd")
const AuditFlicker := preload("res://tools/van_audit/van_audit_flicker.gd")
const AuditProbe := preload("res://tools/van_audit/van_audit_probe.gd")
const RIG_PATH := ^"TravelPath/VanFollow/VanRig"
const ALL_PASSES: PackedStringArray = ["closed", "half", "open", "win_half", "win_open", "tail"]

var rig: Node3D
var tris: RefCounted
var lines: PackedStringArray
var counts: Dictionary = {}

var _done := false


func _ready() -> void:
	if get_tree().current_scene == self:
		var worker: Node = (get_script() as GDScript).new()
		worker.name = "VanAuditWorker"
		get_tree().root.add_child.call_deferred(worker)
		return
	await _run()


func _run() -> void:
	get_tree().create_timer(500.0).timeout.connect(func() -> void:
		if not _done:
			_fail("watchdog timeout")
	)

	if not SaveSandbox.enabled:
		_fail("save sandbox is off; run with -- --smoke-sandbox")
		return

	SceneRouter.go_to_van()
	if not await _wait_for_van_ready():
		return

	for i in range(30):
		if _done:
			return
		await get_tree().process_frame

	rig = get_tree().current_scene.get_node(RIG_PATH) as Node3D
	if rig == null:
		_fail("could not find van rig at %s" % String(RIG_PATH))
		return

	var passes := _parse_passes()
	if _done:
		return
	var seed_arg := _user_arg("--van-seed=")
	if seed_arg != "":
		var look := get_tree().get_first_node_in_group(VanLook.GROUP) as VanLook
		if look == null:
			_fail("no VanLook for --van-seed")
			return
		look.reroll(int(seed_arg))
		print("AUDIT van seed %d" % int(seed_arg))
		for i in range(5):
			await get_tree().process_frame
		if _done:
			return
	if OS.get_cmdline_user_args().has("--plant-flicker"):
		_plant_flicker()

	_freeze_machines()
	collect()
	var probes: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe="):
			var halves := arg.trim_prefix("--probe=").split(":")
			if halves.size() == 2:
				var f := halves[0].split_floats(",")
				var d := halves[1].split_floats(",")
				if f.size() == 3 and d.size() == 3:
					probes.append({"from": Vector3(f[0], f[1], f[2]), "dir": Vector3(d[0], d[1], d[2])})
	if not probes.is_empty():
		AuditProbe.run(tris, probes)
		_done = true
		get_tree().quit(0)
		return
	if passes.has("tail"):
		check_height()

	var states := AuditStates.new(rig)
	var roots: Dictionary = states.moving_roots()
	var closed_boxes: Dictionary = _closed_boxes(roots)

	if passes.has("closed"):
		AuditFlicker.check_flicker(tris, self, "closed", {})
		AuditOverlap.check_clip(tris, self, "closed", roots)

	var door_roots: Dictionary = {}
	var front_roots: Dictionary = {}
	for label in roots.keys():
		if AuditStates.FRONT_WINDOWS.has(label):
			front_roots[label] = roots[label]
		else:
			door_roots[label] = roots[label]
	var state_names: PackedStringArray = ["half", "open", "win_half", "win_open"]
	var state_fractions: PackedFloat32Array = [0.5, 1.0, 0.5, 1.0]
	for i in range(state_names.size()):
		var pose_name: String = state_names[i]
		if not passes.has(pose_name):
			continue
		var front: bool = pose_name.begins_with("win_")
		states.pose(0.0)
		states.pose_front(0.0)
		if front:
			states.pose_front(state_fractions[i])
		else:
			states.pose(state_fractions[i])
		await get_tree().process_frame
		collect()
		var posed: Dictionary = front_roots if front else door_roots
		AuditFlicker.check_flicker(tris, self, pose_name, posed)
		AuditOverlap.check_clip(tris, self, pose_name, posed)
		if pose_name == "open" or pose_name == "win_open":
			var boxes: Dictionary = {}
			for label in posed.keys():
				boxes[label] = closed_boxes[label]
			AuditOverlap.check_openings(tris, self, posed, boxes)

	states.pose(0.0)
	states.pose_front(0.0)
	collect()
	if not passes.has("tail"):
		write_report()
		get_tree().quit(0)
		return

	var gaps := AuditGaps.new()
	var proxies := gaps.build_proxies(tris, rig)
	await get_tree().physics_frame
	await get_tree().physics_frame
	gaps.check_edges(tris, self)
	var profile := VanBodyProfile.from_interior(rig.get_node(^"Interior"))
	var leaks := AuditLeaks.new(gaps, rig)
	leaks.check_leaks_inside(tris, self, profile)
	leaks.check_leaks_outside(tris, self, closed_boxes)
	proxies.queue_free()

	write_report()
	get_tree().quit(0)


## Pass names from `--audit-passes=`; all of them when absent. Fails on an unknown name.
func _parse_passes() -> PackedStringArray:
	var arg := _user_arg("--audit-passes=")
	if arg == "":
		return ALL_PASSES
	var out := PackedStringArray()
	for pass_name in arg.split(","):
		if not ALL_PASSES.has(pass_name):
			_fail("unknown audit pass '%s'" % pass_name)
			return out
		out.append(pass_name)
	return out


## Stops every MachineMotion and restores its parts to their rest pose; animated fan, flywheel
## and needle poses made FLICKER rows vary from run to run.
## Value after `prefix` in the user args, or "" when the arg is absent.
func _user_arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


## A known failure so `tools/smoke.py --plant-flicker` can prove strict mode fails: two
## identical boxes, so every face pair is coplanar.
func _plant_flicker() -> void:
	for box_name in ["AuditPlantA", "AuditPlantB"]:
		var box := MeshInstance3D.new()
		box.name = box_name
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.3, 0.3, 0.3)
		box.mesh = mesh
		rig.add_child(box)
		box.position = Vector3(0.0, 1.6, 0.0)
	print("AUDIT planted flicker at (0, 1.6, 0)")


func _freeze_machines() -> void:
	for node: Node in get_tree().current_scene.find_children("*", "MachineMotion", true, false):
		node.set_process(false)
		var entries: Array = node.get(&"_entries")
		for e: Dictionary in entries:
			var target := e.get(&"target") as Node3D
			if target == null or not is_instance_valid(target) or not e.has(&"rest"):
				continue
			match e.get(&"kind"):
				&"spin":
					target.basis = e[&"rest"]
				&"pump":
					target.position = e[&"rest"]
				&"wobble":
					target.rotation = e[&"rest"]


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
	_fail("timed out waiting for the van scene")
	return false


func add_finding(section: String, text: String) -> void:
	lines.append("%s %s" % [section, text])
	counts[section] = int(counts.get(section, 0)) + 1


func collect() -> void:
	var started := Time.get_ticks_msec()
	tris = AuditMesh.new()
	tris.collect(rig)
	var elapsed := Time.get_ticks_msec() - started
	print("AUDIT collected %d triangles from %d meshes in %d ms" % [
		tris.count(), tris.nodes.size(), elapsed,
	])


func check_height() -> void:
	var started := Time.get_ticks_msec()
	var profile := VanBodyProfile.from_interior(rig.get_node(^"Interior"))
	var crown: float = profile.outer_roof_y_at(0.0)

	var rear_z := -INF
	for t in range(tris.count()):
		if not tris.path_of(t).begins_with("Interior/Shell"):
			continue
		rear_z = maxf(rear_z, maxf(tris.a[t].z, maxf(tris.b[t].z, tris.c[t].z)))

	var max_y_by_node: Dictionary = {}
	var min_z_by_node: Dictionary = {}
	var max_z_by_node: Dictionary = {}
	var rear_vertex_by_node: Dictionary = {}
	for t in range(tris.count()):
		var idx: int = tris.owner_idx[t]
		for p in [tris.a[t], tris.b[t], tris.c[t]]:
			max_y_by_node[idx] = maxf(float(max_y_by_node.get(idx, -INF)), p.y)
			min_z_by_node[idx] = minf(float(min_z_by_node.get(idx, INF)), p.z)
			max_z_by_node[idx] = maxf(float(max_z_by_node.get(idx, -INF)), p.z)
			if p.y > crown + VanRoof.RACK_CLEAR_M + 0.02 and p.z > rear_z - VanRoof.REAR_ZONE_M:
				rear_vertex_by_node[idx] = maxf(float(rear_vertex_by_node.get(idx, -INF)), p.z)

	var over_idx: Array[int] = []
	for idx in max_y_by_node.keys():
		if String(tris.paths[idx]).get_file().begins_with("Antenna"):
			continue
		if float(max_y_by_node[idx]) > crown + VanRoof.ROOF_CAP_M + 0.02:
			over_idx.append(idx)
	over_idx.sort_custom(func(x: int, y: int) -> bool:
		return float(max_y_by_node[x]) > float(max_y_by_node[y])
	)

	for idx in over_idx:
		var top: float = max_y_by_node[idx]
		add_finding("HEIGHT", "%s top=%.3f over=%.3f z=%.3f..%.3f" % [
			tris.paths[idx], top, top - crown, min_z_by_node[idx], max_z_by_node[idx],
		])

	var rear_idx: Array[int] = []
	for idx in rear_vertex_by_node.keys():
		rear_idx.append(idx)
	rear_idx.sort_custom(func(x: int, y: int) -> bool:
		return float(max_y_by_node[x]) > float(max_y_by_node[y])
	)
	for idx in rear_idx:
		add_finding("REAR_ROOF", "%s top=%.3f z=%.3f" % [
			tris.paths[idx], max_y_by_node[idx], rear_vertex_by_node[idx],
		])

	var elapsed := Time.get_ticks_msec() - started
	print("AUDIT height crown=%.3f cap=%.3f rear_z=%.3f (%d ms)" % [
		crown, crown + VanRoof.ROOF_CAP_M, rear_z, elapsed,
	])


## Each moving root's closed-state triangle AABB (the opening it leaves behind), from the
## current collection.
func _closed_boxes(roots: Dictionary) -> Dictionary:
	var boxes: Dictionary = {}
	for label in roots.keys():
		var root: Node = roots[label]
		var box := AABB()
		var started := false
		for t in range(tris.count()):
			var node: Node = tris.nodes[tris.owner_idx[t]]
			if node != root and not root.is_ancestor_of(node):
				continue
			var tb: AABB = tris.tri_aabb(t)
			box = tb if not started else box.merge(tb)
			started = true
		boxes[label] = box
	return boxes


func write_report() -> void:
	var out_path := _out_path()
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())

	var look: VanLook = get_tree().get_first_node_in_group(VanLook.GROUP) as VanLook
	var seed_value: int = look.van_seed if look != null else 0

	var body: PackedStringArray = []
	body.append("VAN AUDIT REPORT")
	body.append("seed=%d" % seed_value)
	body.append("triangles=%d" % tris.count())

	var section_names: Array[String] = []
	for section in counts.keys():
		section_names.append(String(section))
	section_names.sort()
	var fail_parts: PackedStringArray = []
	var minor_parts: PackedStringArray = []
	var exempt_parts: PackedStringArray = []
	var fail_sections: Array[String] = []
	var info_sections: Array[String] = []
	for section in section_names:
		var part := "%s=%d" % [section, counts[section]]
		if section.ends_with("_MINOR"):
			minor_parts.append(part)
			info_sections.append(section)
		elif section.ends_with("_EXEMPT"):
			exempt_parts.append(part)
			info_sections.append(section)
		else:
			fail_parts.append(part)
			fail_sections.append(section)
	var summary: String = " ".join(fail_parts)
	var info: String = " ".join(minor_parts + exempt_parts)
	body.append("COUNTS " + summary)
	body.append("MINOR " + (" ".join(minor_parts) if not minor_parts.is_empty() else "none"))
	body.append("EXEMPT " + (" ".join(exempt_parts) if not exempt_parts.is_empty() else "none"))
	body.append("")

	for group: Array[String] in [fail_sections, info_sections]:
		for section in group:
			for line in lines:
				if line.begins_with("%s " % section):
					body.append(line)

	body.append("")
	body.append("AUDIT SUMMARY " + summary)
	body.append("AUDIT INFO " + info)

	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(body) + "\n")
	f.close()

	print("AUDIT SUMMARY " + summary)
	print("AUDIT INFO " + info)
	print("AUDIT DONE")


func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-out="):
			return arg.substr("--audit-out=".length())
	return "res://.godot/van_audit/report.txt"


func _fail(msg: String) -> void:
	if _done:
		return
	_done = true
	push_error("AUDIT: %s" % msg)
	get_tree().quit(1)
