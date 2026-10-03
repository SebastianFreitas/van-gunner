extends RefCounted
## Smoke check: a loper shot dead on the wall falls to the road, plays the wall death and stays.


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	# The earlier loper smokes leave lopers holding the windows; clear them so this one gets in.
	for node in tree.get_nodes_in_group(&"agile"):
		node.queue_free()
	await tree.create_timer(0.5).timeout
	var before: Array[int] = []
	for node in tree.get_nodes_in_group(&"agile"):
		before.append(node.get_instance_id())
	var reply: String = str(DebugCommands.run("summon loper"))
	var raider: WindowRaider = null
	for node in tree.get_nodes_in_group(&"agile"):
		if not before.has(node.get_instance_id()):
			raider = node as WindowRaider
	if not reply.begins_with("Summoned") or raider == null:
		driver._log("loper wall death: skipped (%s)" % reply)
		return
	var gripping := WindowRaider.AssaultPhase.GRIPPING
	var climbing := WindowRaider.AssaultPhase.CLIMBING
	var breaching := WindowRaider.AssaultPhase.BREACHING
	var seen: Array[String] = []
	var phase_at_kill := ""
	var hit := false
	var landed := false
	var frames_after := 0
	for _i in range(7200):
		await tree.physics_frame
		if not is_instance_valid(raider) or raider.is_queued_for_deletion():
			break
		var phase := raider.assault_phase
		var phase_name: String = WindowRaider.AssaultPhase.keys()[phase]
		if seen.is_empty() or seen[seen.size() - 1] != phase_name:
			seen.append(phase_name)
		if not hit:
			if phase == gripping or phase == climbing or phase == breaching:
				hit = true
				phase_at_kill = phase_name
				raider.take_damage(1e6)
			continue
		frames_after += 1
		if absf(raider.position.y - WindowRaider._WallScript.ROAD_ORIGIN_Y) <= 0.05:
			landed = true
			break
		if frames_after > 600:
			break
	if not hit:
		driver._log("loper wall death: skipped (never reached the wall: %s)" % " > ".join(seen))
		return
	await tree.create_timer(1.0).timeout
	var kept := is_instance_valid(raider) and not raider.is_queued_for_deletion()
	var clip := &""
	if kept:
		clip = raider._anim._clip
	driver._log("loper wall death: landed %s clip %s body_kept %s phase_at_kill %s" % [
		landed, clip, kept, phase_at_kill,
	])
	if not kept or not raider.is_defeated:
		driver._fail("wall-killed loper was not left on the road as a body")
	elif not landed:
		driver._fail("wall-killed loper never reached the road")
	elif clip != &"wall_death":
		driver._fail("wall-killed loper never played the wall_death clip")
