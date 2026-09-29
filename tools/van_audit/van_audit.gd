extends Node
## Headless van audit entry scene: collects every visible triangle of the van, checks
## it and writes a report. Mirrors tools/probe: the entry scene spawns a worker under
## the root because SceneRouter.go_to_van() frees the current scene.

const AuditMesh := preload("res://tools/van_audit/van_audit_mesh.gd")
const AuditStates := preload("res://tools/van_audit/van_audit_states.gd")
const AuditOverlap := preload("res://tools/van_audit/van_audit_overlap.gd")
const AuditGaps := preload("res://tools/van_audit/van_audit_gaps.gd")
const AuditFlicker := preload("res://tools/van_audit/van_audit_flicker.gd")
const RIG_PATH := ^"TravelPath/VanFollow/VanRig"

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

	collect()
	check_height()

	var states := AuditStates.new(rig)
	var roots: Dictionary = states.moving_roots()
	var closed_boxes: Dictionary = _closed_boxes(roots)

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

	var gaps := AuditGaps.new()
	var proxies := gaps.build_proxies(tris, rig)
	await get_tree().physics_frame
	await get_tree().physics_frame
	gaps.check_edges(tris, self)
	var profile := VanBodyProfile.from_interior(rig.get_node(^"Interior"))
	gaps.check_leaks_inside(tris, self, profile)
	gaps.check_leaks_outside(tris, self)
	proxies.queue_free()

	write_report()
	get_tree().quit(0)


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
	body.append("")

	for section in counts.keys():
		for line in lines:
			if line.begins_with("%s " % section):
				body.append(line)

	var section_names: Array[String] = []
	for section in counts.keys():
		section_names.append(String(section))
	section_names.sort()
	var summary_parts: PackedStringArray = []
	for section in section_names:
		summary_parts.append("%s=%d" % [section, counts[section]])
	var summary: String = " ".join(summary_parts)

	body.append("")
	body.append("AUDIT SUMMARY " + summary)

	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(body) + "\n")
	f.close()

	print("AUDIT SUMMARY " + summary)
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
