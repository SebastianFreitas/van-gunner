extends RefCounted

## Smoke step: the C-C halt, exit, climb-in and Shift resume round trip.

var driver: Node


func _init(owner: Node) -> void:
	driver = owner


## Slow, halt, walk out an open side door, step out the back (resume refused), climb back in, resume; leaves the van rolling.
func halt_round_trip() -> bool:
	var rolling := [GameSession.RunPhase.TRAVELLING, GameSession.RunPhase.COMBAT,
			GameSession.RunPhase.REST]
	var waited := 0
	while waited < 600 and not GameSession.phase in rolling:
		await driver.get_tree().process_frame
		waited += 1
	var van := driver.get_tree().get_first_node_in_group(&"van_run")
	var travel := driver.get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if van == null or travel == null:
		driver._fail("halt round trip step 1: no van_run or travel_controller")
		return false
	var player: FpsPlayer = van.get("player")
	var containment: VanPlayerContainment = van.get("player_containment")
	var base := travel.travel_speed
	var step := 2
	var ok := travel.try_slow() and travel.is_slowing() and travel.travel_speed < base
	if ok:
		step = 3
		ok = travel.try_halt() and travel.is_halted() and travel.travel_speed == 0.0 \
				and containment.is_rear_exit_allowed()
	if ok:
		step = 31
		var doors := driver.get_tree().get_first_node_in_group(&"side_doors")
		ok = doors != null
		if ok:
			var inside_pos := player.position
			doors.open_door(&"left")
			var door_waited := 0
			while door_waited < 180 and not doors.is_door_passable(&"left"):
				await driver.get_tree().physics_frame
				door_waited += 1
			# The leaf slides +Z when open, so take z from the closed position.
			var door_z: float = player.get_parent().to_local(
					doors.to_global(doors.get("_left_closed_pos"))).z
			player.position = Vector3(-(VanInteriorSize.BOTTOM_HALF - 1.99), 0.1, door_z)
			await driver.get_tree().physics_frame
			# 2.4 m out passes the containment wall at x -3.04 (-x is the left side).
			ok = not player.test_move(player.global_transform, Vector3(-2.4, 0.0, 0.0))
			# From the road outside the left bay, facing +x into the van.
			var road_x := VanInteriorSize.BOTTOM_HALF
			ok = ok and await _walk_in(
					player, Vector3(-(road_x + 0.61), -0.9, door_z), -PI * 0.5, "side")
			ok = ok and await _walk_in(
					player, Vector3(-(road_x + 3.61), -0.9, door_z), -PI * 0.5, "side", true)
			doors.close_door(&"left")
			player.position = inside_pos
			await driver.get_tree().physics_frame
	if ok:
		step = 4
		player.position = Vector3(0.0, -0.85, VanInteriorSize.REAR_Z + 1.8)
		await driver.get_tree().physics_frame
		await driver.get_tree().physics_frame
		ok = not van.request_driver_boost() and travel.is_halted()
	if ok:
		step = 5
		# The rear doors swing open in 0.9 s; their closed leaves would block the climb.
		var rear := driver.get_tree().get_first_node_in_group(&"rear_doors")
		rear.open()
		for _i in 75:
			await driver.get_tree().physics_frame
		# On the road behind the open rear, facing -z into the van.
		player.position = Vector3(0.0, -0.9, VanInteriorSize.REAR_Z + 1.2)
		player.rotation.y = 0.0
		await driver.get_tree().physics_frame
		await driver.get_tree().physics_frame
		# Outside, against the van, is not inside.
		ok = not van.request_driver_boost()
		var rear_z := VanInteriorSize.REAR_Z
		ok = ok and await _walk_in(player, Vector3(0.0, -0.9, rear_z + 2.3), 0.0, "rear")
		ok = ok and await _walk_in(player, Vector3(0.0, -0.9, rear_z + 3.3), 0.0, "rear", true)
		if not ok:
			driver._fail("halt round trip step 5: no climb in at the rear")
			return false
	if ok:
		step = 6
		ok = player.position.y > -0.35 \
				and not player.test_move(player.global_transform, Vector3.ZERO)
		if ok:
			driver._log("halt mantle: rise ok")
			ok = await _walk_floor(player)
	if ok:
		ok = van.request_driver_boost() and not travel.is_halted() and travel.travel_speed > 0.0 \
				and not containment.is_rear_exit_allowed()
	if not ok:
		driver._fail("halt round trip step %d" % step)
		return false
	driver._log("halt round trip ok")
	return true


## Walks the halted van's floor with real input: rear floor, up the doorway stairs onto the mid
## slab, down into the step well, and back. Feet y is position.y; no leg may mantle.
func _walk_floor(player: FpsPlayer) -> bool:
	var tree := driver.get_tree()
	var mantles := [0]
	var on_mantle := func() -> void: mantles[0] += 1
	player.mantle_started.connect(on_mantle)
	player.position = Vector3(-2.6, -0.9, 3.0)
	player.velocity = Vector3.ZERO
	await tree.physics_frame
	await tree.physics_frame
	var legs := [["stairs up", Vector2(-2.6, 0.3)], ["well", Vector2(-2.9, -3.0)],
			["slab back", Vector2(-2.6, 0.3)], ["stairs down", Vector2(-2.6, 3.0)]]
	var slab_max := -10.0
	var well_y := 10.0
	var ok := true
	for leg: Array in legs:
		var label: String = leg[0]
		var target: Vector2 = leg[1]
		var arrived := false
		Input.action_press(&"move_forward")
		for _i in 360:
			var d := target - Vector2(player.position.x, player.position.z)
			if d.length() < 0.2:
				arrived = true
				break
			player.rotation.y = atan2(-d.x, -d.y)
			await tree.physics_frame
			if label == "stairs up" or label == "slab back":
				slab_max = maxf(slab_max, player.position.y)
		Input.action_release(&"move_forward")
		for _i in 15:
			await tree.physics_frame
		var feet := player.position.y
		if label == "well":
			well_y = feet
		if not arrived:
			driver._fail("walk floor %s: timeout at %s" % [label, player.position])
			ok = false
		elif label == "stairs up" and feet < 0.28 or label == "well" and feet > 0.02 \
				or label == "stairs down" and feet > 0.02:
			driver._fail("walk floor %s: feet y %.3f at %s" % [label, feet, player.position])
			ok = false
		if not ok:
			break
	player.mantle_started.disconnect(on_mantle)
	if ok and mantles[0] != 0:
		driver._fail("walk floor: %d mantles" % mantles[0])
		ok = false
	if ok and slab_max < 0.28:
		driver._fail("walk floor: slab max y %.3f" % slab_max)
		ok = false
	driver._log("walk floor: slab max y %.3f, well y %.3f, mantles %d" % [slab_max, well_y, mantles[0]])
	return ok


## Puts the player outside at `from` (VanRig-local) facing `yaw`, walks forward with real input,
## sends a jump key press and expects the player to end inside the van.
## With `run_up` it taps jump (3 frames) while still walking, before reaching the opening.
func _walk_in(player: FpsPlayer, from: Vector3, yaw: float, label: String,
		run_up := false) -> bool:
	var tree := driver.get_tree()
	# The act reveal is a modal that blocks jumping until a player dismisses it.
	var van := tree.get_first_node_in_group(&"van_run")
	var reveal := van.get("_act_reveal") as Control
	if reveal != null and reveal.visible:
		reveal.call(&"dismiss")
		await tree.process_frame
	player.position = from
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	await tree.physics_frame
	await tree.physics_frame
	Input.action_press(&"move_forward")
	var last := player.position
	var still := 0
	for i in 240:
		await tree.physics_frame
		if run_up:
			# The reveal can present again mid-walk; it would swallow the jump.
			if reveal != null and reveal.visible:
				reveal.call(&"dismiss")
			# Tap while still more than 1 m from the opening (rear ramp end, side door bay).
			if (label == "rear" and player.position.z < VanInteriorSize.REAR_Z + 2.1) \
					or (label != "rear" and player.position.x > -3.92):
				break
			continue
		still = still + 1 if player.position.distance_to(last) < 0.001 else 0
		last = player.position
		if still >= 10:
			break
	var ev := InputEventAction.new()
	ev.action = &"jump"
	ev.pressed = true
	Input.parse_input_event(ev)
	# A run-up tap is released after 3 frames; the walk-in press after 1.
	for _i in 3 if run_up else 1:
		await tree.physics_frame
	var rel := InputEventAction.new()
	rel.action = &"jump"
	rel.pressed = false
	Input.parse_input_event(rel)
	for _i in 90:
		await tree.physics_frame
	Input.action_release(&"move_forward")
	var inside: bool = player.position.y > -0.35
	if label == "rear":
		inside = inside and player.position.z < 4.68
	else:
		inside = inside and player.position.x > -3.04
	var tag := "%s run-up" % label if run_up else label
	driver._log("halt mantle %s: %s at %s" % [tag, "ok" if inside else "FAILED", player.position])
	return inside
