extends RefCounted

## Smoke step: the C-C halt, exit, climb-in and Shift resume round trip.

## The rear end moved back by this much when the back compartment grew (it was z 4.70).
const REAR_SHIFT := VanInteriorSize.REAR_Z - 4.70

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
			player.position = Vector3(-1.4, 0.1, door_z)
			await driver.get_tree().physics_frame
			# 2.4 m out passes the containment wall at x -3.04 (-x is the left side).
			ok = not player.test_move(player.global_transform, Vector3(-2.4, 0.0, 0.0))
			# From the road outside the left bay, facing +x into the van.
			ok = ok and await _walk_in(player, Vector3(-4.0, -0.9, door_z), -PI * 0.5, "side")
			ok = ok and await _walk_in(
					player, Vector3(-7.0, -0.9, door_z), -PI * 0.5, "side", true)
			doors.close_door(&"left")
			player.position = inside_pos
			await driver.get_tree().physics_frame
	if ok:
		step = 4
		player.position = Vector3(0.0, -0.85, 6.5 + REAR_SHIFT)
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
		player.position = Vector3(0.0, -0.9, 5.9 + REAR_SHIFT)
		player.rotation.y = 0.0
		await driver.get_tree().physics_frame
		await driver.get_tree().physics_frame
		# Outside, against the van, is not inside.
		ok = not van.request_driver_boost()
		ok = ok and await _walk_in(player, Vector3(0.0, -0.9, 7.0 + REAR_SHIFT), 0.0, "rear")
		ok = ok and await _walk_in(player, Vector3(0.0, -0.9, 8.0 + REAR_SHIFT), 0.0, "rear", true)
		if not ok:
			driver._fail("halt round trip step 5: no climb in at the rear")
			return false
	if ok:
		step = 6
		ok = player.position.y > -0.35 \
				and not player.test_move(player.global_transform, Vector3.ZERO)
		if ok:
			driver._log("halt mantle: rise ok")
	if ok:
		ok = van.request_driver_boost() and not travel.is_halted() and travel.travel_speed > 0.0 \
				and not containment.is_rear_exit_allowed()
	if not ok:
		driver._fail("halt round trip step %d" % step)
		return false
	driver._log("halt round trip ok")
	return true


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
			if (label == "rear" and player.position.z < 6.8 + REAR_SHIFT) \
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
