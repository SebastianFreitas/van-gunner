extends RefCounted

## Drives the fork/side-stop portion of the smoke run (route.gd -> route
## choice -> stop -> back to travelling). Split out of smoke_driver.gd; the
## driver node it wraps outlives the helper for the whole run, so it's safe
## to hold onto and await through.

var driver: Node


func _init(owner: Node) -> void:
	driver = owner


func fork_pass() -> bool:
	var travel := driver.get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel == null:
		driver._fail("no travel_controller node found")
		return false

	driver._log(DebugCommands.run("speed"))

	var stress := DebugCommands.run("facade stress 1")
	driver._log(stress)
	if not stress.begins_with("OK"):
		driver._fail("facade stress: " + stress)
		return false

	if not await drive_side_stop(travel, "stop elevator shop", "elevator"):
		return false
	if not await drive_side_stop(travel, "stop garage", "rear-park"):
		return false

	driver._log(DebugCommands.run("unspeed"))
	driver._log(DebugCommands.run("chill"))
	await driver._frames(5)
	return true


## Forces the given stop onto the next fork, drives through the fork, docks,
## and leaves it again. `label` is only for log/fail messages.
func drive_side_stop(travel: TravelController, stop_command: String, label: String) -> bool:
	driver._log(DebugCommands.run(stop_command))
	if not await force_route_choice(travel, 60.0):
		driver._fail(
			"timed out waiting for ROUTE_CHOICE (%s fork), phase=%s" % [label, driver._phase_name()]
		)
		return false
	driver._log("phase %s" % driver._phase_name())

	var dirs := GameSession.get_route_directions()
	driver._log("route_directions=%s" % [dirs])
	var direction: StringName = dirs[0]
	if direction == driver._last_route_direction and dirs.size() > 1:
		direction = dirs[1]
	driver._last_route_direction = direction
	GameSession.choose_route(direction)

	if not await driver._wait_phase(GameSession.RunPhase.STOP, 60.0):
		driver._fail("timed out waiting for STOP (%s docked), phase=%s" % [label, driver._phase_name()])
		return false
	driver._log("phase %s" % driver._phase_name())

	if label == "rear-park" and not _assert_bay_mouth_clear(travel):
		return false

	await driver._frames(10)
	travel.leave_stop()

	if not await driver._wait_phase(GameSession.RunPhase.TRAVELLING, 60.0):
		driver._fail(
			"timed out waiting for TRAVELLING (left %s stop), phase=%s" % [label, driver._phase_name()]
		)
		return false
	driver._log("phase %s" % driver._phase_name())
	return true


## Confirms nothing built at a docked bay's facade covers the mouth the van reverse-parked
## through (facade_audit.tile_mouth_violations mirrors facade_keep_out.gd's own bay boxes
## against every visible, non-freed mesh built there).
func _assert_bay_mouth_clear(travel: TravelController) -> bool:
	var facade_audit: GDScript = load("res://scripts/travel/facades/facade_audit.gd")
	var counts := {&"bays": 0, &"checked": 0}
	var violations: Array[String] = []
	for piece in travel.corridor_root.get_children():
		if not piece.has_method(&"opening_of"):
			continue
		violations.append_array(facade_audit.tile_mouth_violations(piece, counts))
	if not violations.is_empty():
		driver._fail(violations[0])
		return false
	var bays: int = int(counts.get(&"bays", 0))
	var checked: int = int(counts.get(&"checked", 0))
	if bays == 0:
		driver._fail("no corridor tile has an open bay at the rear-park stop")
		return false
	if checked == 0:
		driver._fail("the bay side built no facade nodes")
		return false
	driver._log("bay mouth clear: %d bay side(s), %d facade nodes checked" % [bays, checked])
	return true


## Mirrors EncounterDirector._run_segment()'s post-combat REST -> ROUTE_CHOICE tail
## (scripts/enemies/encounter_director.gd ~149-169). Chill mode is kept on for the
## whole fork/stop drive so the director's own encounter loop never runs between
## forks here, so nothing else would ever end a forced REST; the driver forces the
## same REST phase and replays the same act-deck calls the director makes once a
## rest break resolves, instead of waiting on a sequence nothing ever starts.
func force_route_choice(travel: TravelController, timeout_s: float) -> bool:
	GameSession.set_phase(GameSession.RunPhase.REST)
	await mirror_rest_break_wait(travel)

	var act_deck := driver.get_tree().get_first_node_in_group(&"act_deck_controller") as ActDeckController
	if GameSession.phase == GameSession.RunPhase.REST and GameSession.needs_boss_pick():
		if act_deck and act_deck.has_method(&"begin_boss_pick_if_needed"):
			act_deck.begin_boss_pick_if_needed()
			if act_deck.has_method(&"wait_for_boss_pick_resolution"):
				await act_deck.wait_for_boss_pick_resolution()
		elif GameSession.needs_boss_pick():
			GameSession.commit_boss_picks([])
	if GameSession.phase in [
		GameSession.RunPhase.REST,
		GameSession.RunPhase.ACT_REVEAL,
		GameSession.RunPhase.BOSS_PICK,
	] and GameSession.needs_act_reveal():
		if act_deck and act_deck.has_method(&"begin_reveal_if_needed"):
			act_deck.begin_reveal_if_needed()
			if act_deck.has_method(&"wait_for_reveal_resolution"):
				await act_deck.wait_for_reveal_resolution()
		elif GameSession.needs_act_reveal():
			GameSession.begin_new_act_deck()
	if GameSession.phase in [
		GameSession.RunPhase.REST,
		GameSession.RunPhase.ACT_REVEAL,
		GameSession.RunPhase.BOSS_PICK,
	]:
		GameSession.set_phase(GameSession.RunPhase.ROUTE_CHOICE)
	return await driver._wait_phase(GameSession.RunPhase.ROUTE_CHOICE, timeout_s)


## Mirrors EncounterDirector._wait_for_rest_break(): the boon resolves instantly
## under debug speed mode, but the director still sits out the rest duration itself.
func mirror_rest_break_wait(travel: TravelController) -> void:
	var director := driver.get_tree().get_first_node_in_group(&"encounter_director") as EncounterDirector
	var rest_duration := 20.0
	if director:
		rest_duration = director.rest_duration
	var seconds := rest_duration
	if travel and travel.has_method(&"scale_debug_wait"):
		seconds = travel.scale_debug_wait(rest_duration)
	var rewards := driver.get_tree().get_first_node_in_group(&"boon_reward_controller")
	if rewards and rewards.has_method(&"wait_for_rest_resolution"):
		await rewards.wait_for_rest_resolution()
	await driver.get_tree().create_timer(seconds).timeout
