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
			player.position = Vector3(-1.4, 0.1, door_z)
			await driver.get_tree().physics_frame
			# 2.4 m out passes the containment wall at x -3.04 (-x is the left side).
			ok = not player.test_move(player.global_transform, Vector3(-2.4, 0.0, 0.0))
			doors.close_door(&"left")
			player.position = inside_pos
			await driver.get_tree().physics_frame
	if ok:
		step = 4
		player.position = Vector3(0.0, -0.85, 6.5)
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
		player.position = Vector3(0.0, -0.9, 5.9)
		player.rotation.y = 0.0
		await driver.get_tree().physics_frame
		await driver.get_tree().physics_frame
		# Outside, against the van, is not inside.
		ok = not van.request_driver_boost()
		ok = ok and player.try_mantle()
		if not ok:
			driver._fail("halt round trip step 5: mantle did not start")
			return false
		var mantle_waited := 0
		while mantle_waited < 90 and player.is_mantling():
			await driver.get_tree().physics_frame
			mantle_waited += 1
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
