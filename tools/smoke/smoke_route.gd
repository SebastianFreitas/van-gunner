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

	await driver._frames(10)
	travel.leave_stop()

	if not await driver._wait_phase(GameSession.RunPhase.TRAVELLING, 60.0):
		driver._fail(
			"timed out waiting for TRAVELLING (left %s stop), phase=%s" % [label, driver._phase_name()]
		)
		return false
	driver._log("phase %s" % driver._phase_name())
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
