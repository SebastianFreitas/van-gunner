extends RefCounted

## Debug console commands: run flow. Registered in DebugCommands._register_commands.

var host: Node  # the DebugCommands autoload (tree access and shared finders)


func _init(owner: Node) -> void:
	host = owner


func cmd_chill(_args: Array) -> String:
	GameSession.set_chill_mode(true)
	return "Chill mode ON — encounters paused, van keeps moving."


func cmd_unchill(_args: Array) -> String:
	GameSession.set_chill_mode(false)
	return "Chill mode OFF — run resumes."


func cmd_speed(_args: Array) -> String:
	var travel: TravelController = host._find_travel_controller()
	if not travel:
		return "TravelController not found — are you in the van scene?"
	travel.set_debug_speed_mode(true)
	var started := false
	if GameSession.phase == GameSession.RunPhase.IDLE:
		GameSession.begin_run()
		started = true
	var msg := (
		"Speed mode ON — %.1fx travel, timers compressed, intro skipped."
		% travel.debug_speed_multiplier
	)
	if started:
		msg += " Run auto-started."
	return msg


func cmd_unspeed(_args: Array) -> String:
	var travel: TravelController = host._find_travel_controller()
	if not travel:
		return "TravelController not found — are you in the van scene?"
	travel.set_debug_speed_mode(false)
	return "Speed mode OFF — back to normal travel speed (%.1f u/s)." % travel.travel_speed


func cmd_phase(_args: Array) -> String:
	var phase_name: String = GameSession.RunPhase.keys()[GameSession.phase]
	return (
		"phase=%s  chill=%s  wave=%d  route_step=%d"
		% [phase_name, GameSession.chill_mode, GameSession.wave_count, GameSession.route_step]
	)
