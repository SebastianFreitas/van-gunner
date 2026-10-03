extends RefCounted
## Smoke check: summons a window loper and watches its assault phases; fails only when it never climbs.

const _STOP_PHASES: Array[String] = ["BREACHING", "ENTERING", "ATTACKING_BENCH", "ATTACKING_PLAYER"]


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	var before: Array[int] = []
	for node in tree.get_nodes_in_group(&"agile"):
		before.append(node.get_instance_id())
	var reply: String = str(DebugCommands.run("summon loper"))
	var raider: WindowRaider = null
	for node in tree.get_nodes_in_group(&"agile"):
		if not before.has(node.get_instance_id()):
			raider = node as WindowRaider
	if not reply.begins_with("Summoned") or raider == null:
		driver._log("loper wall climb: skipped (%s)" % reply)
		return
	var seen: Array[String] = []
	var killed := false
	var last := Vector3.ZERO
	var grip := Vector3.ZERO
	var gripped := false
	for _i in range(1800):
		await tree.physics_frame
		if not is_instance_valid(raider) or raider.is_queued_for_deletion():
			killed = true
			break
		last = raider.position
		var phase_name: String = WindowRaider.AssaultPhase.keys()[raider.assault_phase]
		if seen.is_empty() or seen[seen.size() - 1] != phase_name:
			seen.append(phase_name)
		if phase_name == "CLIMBING" and not gripped:
			gripped = true
			grip = last
		if _STOP_PHASES.has(phase_name):
			break
	driver._log("loper wall climb: %s x=%.2f y=%.2f z=%.2f grip x=%.2f y=%.2f" % [
		" > ".join(seen), absf(last.x), last.y, last.z, absf(grip.x), grip.y])
	if not seen.has("CLIMBING"):
		if killed:
			driver._log("loper wall climb: skipped (killed)")
			return
		driver._fail("loper never reached CLIMBING (phases: %s)" % " > ".join(seen))
