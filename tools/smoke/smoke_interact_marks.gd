extends RefCounted

## Smoke step: the real player aims its crosshair at every van Interactable's mark and must focus it.

const _EYE_BACK := 1.2

var driver: Node


func _init(owner: Node) -> void:
	driver = owner


## Aims the real player at each mark with the openings closed, then open.
func run() -> bool:
	var tree := driver.get_tree()
	var van := tree.get_first_node_in_group(&"van_run") as Node3D
	var windows := tree.get_first_node_in_group(&"side_windows")
	var side_doors := tree.get_first_node_in_group(&"side_doors")
	var rear := tree.get_first_node_in_group(&"rear_doors")
	if van == null or windows == null or side_doors == null or rear == null:
		driver._fail("interact marks: van, windows or doors missing")
		return false
	var player := van.get("player") as FpsPlayer
	var feet_y := van.to_local(player.global_position).y
	var idle := 0
	var marks := 0
	for node in van.find_children("*", "InteractionMarker", true, false):
		var mk := node as InteractionMarker
		marks += 1
		if mk.modulate.is_equal_approx(InteractionMarker.IDLE_COLOR) and mk.scale.is_equal_approx(Vector3.ONE):
			idle += 1
		else:
			driver._log("interact mark not idle at start: %s %s" % [van.get_path_to(mk), mk.modulate])
	driver._log("interact marks idle at start: %d/%d" % [idle, marks])
	if idle != marks:
		driver._fail("interact marks: %d start bright" % (marks - idle))
		return false
	var hits := 0
	var total := 0
	for phase in ["closed", "windows+rear open", "side doors open"]:
		match phase:
			"closed":
				windows.close()
				side_doors.close()
				rear.close()
			"windows+rear open":
				windows.open()
				rear.open()
			"side doors open":
				windows.close()
				side_doors.open()
		for _i in 150:
			await tree.physics_frame
		for node in van.find_children("*", "Interactable", true, false):
			var result: String = await _check(van, player, feet_y, node as Interactable)
			if result == "skip":
				continue
			total += 1
			if result == "ok":
				hits += 1
			if result != "ok":
				driver._log("interact mark FAIL [%s] %s: %s" % [phase, van.get_path_to(node), result])
	windows.close()
	side_doors.close()
	driver._log("interact marks (real aim): %d/%d" % [hits, total])
	if hits != total:
		driver._fail("interact marks: %d unreachable" % (total - hits))
		return false
	return true


func _check(van: Node3D, player: FpsPlayer, feet_y: float, target: Interactable) -> String:
	var marker: InteractionMarker
	for child in target.get_children():
		if child is InteractionMarker:
			marker = child
	if marker == null or not marker.visible:
		return "skip"
	if target.collision_layer & 34 == 0:
		return "skip"
	var mark := marker.global_position
	# Stand on the walkway 0.8 to 1.2 m from the mark, toward the van's centre line.
	var local := van.to_local(mark)
	var back := Vector3(-local.x, 0.0, -local.z)
	back = back.normalized() if back.length() > 0.01 else Vector3.RIGHT
	var side := Vector3(-back.z, 0.0, back.x)
	var result := "miss (nothing)"
	for spot: Array in [[_EYE_BACK, 0.0], [0.8, 0.0], [_EYE_BACK, 0.7], [_EYE_BACK, -0.7]]:
		var offset: Vector3 = back * float(spot[0]) + side * float(spot[1])
		player.velocity = Vector3.ZERO
		player.global_position = van.to_global(Vector3(local.x, feet_y, local.z) + offset)
		await driver.get_tree().physics_frame
		await driver.get_tree().physics_frame
		# Turn the body and head so the crosshair points at the mark.
		var dir := mark - player.camera.global_position
		player.global_rotation.y = atan2(-dir.x, -dir.z)
		player.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())
		await driver.get_tree().physics_frame
		await driver.get_tree().physics_frame
		var focused := player.get("_current_interactable") as Interactable
		if focused == target:
			return "ok"
		var ray := player.interaction_ray
		var hit := "nothing"
		if ray.is_colliding():
			hit = str((ray.get_collider() as Node).get_path())
		var focus_name := str(focused.get_path()) if is_instance_valid(focused) else "none"
		result = "focused %s, ray hit %s" % [focus_name, hit]
	return result
