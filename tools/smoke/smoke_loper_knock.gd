extends RefCounted
## Smoke check: a loper shot out of its jump falls, tumbles and runs back to jump again.

const _Seeds := preload("res://tools/smoke/smoke_seeds.gd")


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	var before: Array[int] = []
	for node in tree.get_nodes_in_group(&"agile"):
		before.append(node.get_instance_id())
	var reply: String = _Seeds.summon("loper", 1)
	var raider: WindowRaider = null
	for node in tree.get_nodes_in_group(&"agile"):
		if not before.has(node.get_instance_id()):
			raider = node as WindowRaider
	if not reply.begins_with("Summoned") or raider == null:
		driver._log("loper knock: skipped (%s)" % reply)
		return
	var jumping := WindowRaider.AssaultPhase.JUMPING
	var knocked := WindowRaider.AssaultPhase.KNOCKED
	var seen: Array[String] = []
	var hit := false
	var saw_knock := false
	var landed := false
	var tumbled := false
	var recovered := false
	var killed := false
	var frames_after := 0
	for _i in range(3600):
		await tree.physics_frame
		if not is_instance_valid(raider) or raider.is_queued_for_deletion():
			killed = true
			break
		var phase := raider.assault_phase
		var phase_name: String = WindowRaider.AssaultPhase.keys()[phase]
		if seen.is_empty() or seen[seen.size() - 1] != phase_name:
			seen.append(phase_name)
		if not hit:
			if phase == jumping:
				hit = true
				raider.take_damage(1.0)
			continue
		frames_after += 1
		if phase == knocked:
			saw_knock = true
			if absf(raider.position.y - WindowRaider._WallScript.ROAD_ORIGIN_Y) <= 0.05:
				landed = true
		if raider._anim._clip == &"tumble":
			tumbled = true
		if saw_knock and phase != knocked and (
			phase == WindowRaider.AssaultPhase.APPROACH or phase == jumping
		):
			recovered = true
			break
		if frames_after > 600:
			break
	driver._log("loper knock: %s" % " > ".join(seen))
	if killed or not hit:
		driver._log("loper knock: skipped (%s)" % ("killed" if killed else "never jumped"))
		return
	if not saw_knock:
		driver._fail("loper was not KNOCKED by a hit in the air (phases: %s)" % " > ".join(seen))
	elif not landed:
		driver._fail("knocked loper never reached the road")
	elif not tumbled:
		driver._fail("knocked loper never played the tumble clip")
	elif not recovered:
		driver._fail("knocked loper never ran back to jump (phases: %s)" % " > ".join(seen))
