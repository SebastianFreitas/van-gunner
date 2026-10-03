extends RefCounted

## Smoke step: the C-C halt, exit, climb-in and Shift resume round trip.

var driver: Node


func _init(owner: Node) -> void:
	driver = owner


## Slow, halt, step out the back (resume refused), climb back in, resume; leaves the van rolling.
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
		step = 4
		player.position = Vector3(0.0, -0.85, 6.5)
		await driver.get_tree().physics_frame
		await driver.get_tree().physics_frame
		ok = not van.request_driver_boost() and travel.is_halted()
	var climb := driver.get_tree().get_first_node_in_group(&"rear_climb") as RearClimb
	if ok:
		step = 5
		ok = climb != null and climb.get_interaction_prompt() != ""
	if ok:
		climb.interact(player)
		await driver.get_tree().physics_frame
		ok = player.position.y > -0.35 \
				and not player.test_move(player.global_transform, Vector3.ZERO)
	if ok:
		step = 6
		ok = van.request_driver_boost() and not travel.is_halted() and travel.travel_speed > 0.0 \
				and not containment.is_rear_exit_allowed()
	if not ok:
		driver._fail("halt round trip step %d" % step)
		return false
	driver._log("halt round trip ok")
	return true
