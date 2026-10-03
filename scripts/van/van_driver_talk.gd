extends RefCounted

## The driver-talk panel: open/close, option refresh, and boost/slow shout handling.

const _VanHalt := preload("res://scripts/van/van_halt.gd")

var van: Node3D  # untyped owner; van.gd has no class_name (cycle rule), so fields are read dynamically
var halt: _VanHalt


func _init(owner: Node3D) -> void:
	van = owner
	halt = _VanHalt.new(owner)


func open() -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	if GameSession.phase == GameSession.RunPhase.ROUTE_CHOICE:
		return
	if GameSession.phase == GameSession.RunPhase.STOP:
		return
	if GameSession.phase == GameSession.RunPhase.PARKING:
		return
	if GameSession.phase == GameSession.RunPhase.ACT_REVEAL:
		return
	if GameSession.phase == GameSession.RunPhase.BOSS_PICK:
		return
	if van._act_reveal and van._act_reveal.visible:
		return
	if van.bench_screen.visible:
		van.bench_screen.close()
	if van.skill_tree_hud and van.skill_tree_hud.visible:
		van.skill_tree_hud.close()
	van._driver_talk_open = true
	refresh_options()
	van.driver_talk_panel.show()
	van.refresh_mouse_mode()
	van.set_process(true)


func close() -> void:
	if not van._driver_talk_open and not van.driver_talk_panel.visible:
		return
	van._driver_talk_open = false
	van.driver_talk_panel.hide()
	van.set_process(false)
	van.refresh_mouse_mode()


func refresh_options() -> void:
	var idle := GameSession.phase == GameSession.RunPhase.IDLE
	van.start_run_button.visible = idle
	van.accelerate_button.visible = not idle
	van.slow_button.visible = not idle
	if idle:
		van.driver_talk_hint.text = "Yell let's go when you're ready."
		van.start_run_button.disabled = false
		van.start_run_button.text = "LET'S GO"
		return

	var travel := van.get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel == null:
		van.driver_talk_hint.text = "Yell at the driver — speed up or ease off."
		van.accelerate_button.disabled = true
		van.accelerate_button.text = "ACCELERATE"
		van.slow_button.disabled = true
		van.slow_button.text = "EASY"
		return

	var halted := travel.is_halted()
	var slowing := travel.is_slowing()
	if halted:
		van.driver_talk_hint.text = "Engine's off - walk out the back, or shout to go."
	elif slowing:
		van.driver_talk_hint.text = "Holding back - shout when you want speed."
	elif travel.is_boosting():
		van.driver_talk_hint.text = "Hold on — flooring it."
	elif not travel.can_boost():
		van.driver_talk_hint.text = "Engine's hot — give it a moment."
	else:
		van.driver_talk_hint.text = "Yell at the driver — speed up or ease off."

	if travel.is_boosting():
		van.accelerate_button.disabled = true
		van.accelerate_button.text = "FLOORING IT"
	elif halted or slowing:
		van.accelerate_button.disabled = false
		van.accelerate_button.text = "LET'S GO"
	elif not travel.can_boost():
		var wait := ceili(travel.get_boost_cooldown_remaining())
		van.accelerate_button.disabled = true
		van.accelerate_button.text = "WAIT %ds" % wait
	else:
		van.accelerate_button.disabled = false
		van.accelerate_button.text = "ACCELERATE"

	if halted:
		van.slow_button.disabled = true
		van.slow_button.text = "STOPPED"
	elif slowing:
		van.slow_button.disabled = not travel.can_halt()
		van.slow_button.text = "STOP"
	else:
		van.slow_button.disabled = false
		van.slow_button.text = "EASY"


## Shift, cab-door ACCELERATE, and the HUD GO button share TravelController boost cooldown.
## In IDLE the same yell starts the run — no boost cooldown until you're actually travelling.
func request_boost() -> bool:
	if GameSession.phase == GameSession.RunPhase.IDLE:
		GameSession.begin_run()
		refresh_options()
		close()
		AudioDirector.play(&"shout_start")
		van._show_message("LET'S GO")
		return true
	if not halt.is_player_inside():
		van._show_message("GET BACK IN THE VAN")
		return false
	var travel := van.get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel != null and (travel.is_slowing() or travel.is_halted()):
		if not travel.try_resume_speed():
			refresh_options()
			return false
		refresh_options()
		AudioDirector.play(&"shout_resume")
		van._show_message("LET'S GO")
		return true
	if travel == null or not travel.try_boost():
		refresh_options()
		return false
	refresh_options()
	AudioDirector.play(&"shout_turbo")
	van._show_message("GO GO GO — DRIVER FLOORS IT")
	return true


## C / HUD: ease off, then stop; a stopped van only answers to Shift.
func request_slow_or_go() -> bool:
	if not halt.is_player_inside():
		van._show_message("GET BACK IN THE VAN")
		return false
	var travel := van.get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel == null:
		refresh_options()
		return false
	if travel.is_halted():
		van._show_message("STOPPED - SHIFT TO GO")
		return false
	if travel.is_slowing():
		if not travel.try_halt():
			van._show_message("CAN'T STOP HERE")
			return false
		refresh_options()
		AudioDirector.play(&"shout_slow")
		van._show_message("STOP THE VAN")
		return true
	if not travel.try_slow():
		refresh_options()
		return false
	refresh_options()
	AudioDirector.play(&"shout_slow")
	van._show_message("EASY — SLOW IT DOWN")
	return true


## Outside the van Shift and C are not shouts: van.gd leaves them unhandled,
## so a later dash and crouch can take them.
func shout_keys_blocked() -> bool:
	if not halt.is_player_inside() and GameSession.phase != GameSession.RunPhase.IDLE:
		return true
	if van.pause_menu and van.pause_menu.visible:
		return true
	if van._debug_console and van._debug_console.visible:
		return true
	if van._dialogue_hud and van._dialogue_hud.visible:
		return true
	if van.bench_screen and van.bench_screen.visible:
		return true
	if van.skill_tree_hud and van.skill_tree_hud.visible:
		return true
	if van._act_reveal and van._act_reveal.visible:
		return true
	if van._boon_choice and van._boon_choice.visible:
		return true
	if van.game_over_panel and van.game_over_panel.visible:
		return true
	if van._class_panel and van._class_panel.visible:
		return true
	return false
