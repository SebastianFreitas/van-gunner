extends RefCounted

## Modal overlays: bench, skill tree, class panel, debug console, pause menu, mouse passthrough.

var van: Node3D  # untyped owner; van.gd has no class_name (cycle rule), so fields are read dynamically


func _init(owner: Node3D) -> void:
	van = owner


func build_debug_console() -> void:
	if DebugConfig.ENABLED:
		## load() not preload() — compile-time preload of the console scene
		## hard-fails van.gd (and boot's van preload) if the console graph breaks.
		var console_scene := load("res://scenes/ui/debug_console.tscn") as PackedScene
		if console_scene:
			van._debug_console = console_scene.instantiate()
			van.get_node("HUD").add_child(van._debug_console)
			van._debug_console.opened.connect(on_debug_console_opened)
			van._debug_console.closed.connect(on_debug_console_closed)
		else:
			push_warning("Van: could not load debug_console.tscn")


func build_panels() -> void:
	van._act_reveal = van._ActRevealPanel.new()
	van.get_node("HUD").add_child(van._act_reveal)
	van._act_deck = van._ActDeckController.new()
	van.add_child(van._act_deck)
	van._act_deck.bind(van._act_reveal)
	van._boon_choice = van._BoonChoicePanel.new()
	van.get_node("HUD").add_child(van._boon_choice)
	van._boon_choice.bind(van.player)
	van._boon_rewards = van._BoonRewardController.new()
	van.add_child(van._boon_rewards)
	van._boon_rewards.bind(van.player, van._boon_choice)
	van._dialogue_hud = van._DialogueHud.new()
	van.get_node("HUD").add_child(van._dialogue_hud)
	van._class_panel = van._ClassPanel.new()
	van.get_node("HUD").add_child(van._class_panel)
	van._class_panel.closed.connect(on_class_panel_closed)


func has_modal_free_cursor() -> bool:
	if van.pause_menu and van.pause_menu.visible:
		return true
	if van._driver_talk_open:
		return true
	if van.bench_screen and van.bench_screen.visible:
		return true
	if van.skill_tree_hud and van.skill_tree_hud.visible:
		return true
	if van._debug_console and van._debug_console.visible:
		return true
	if van._dialogue_hud and van._dialogue_hud.visible:
		return true
	if van._act_reveal and van._act_reveal.visible:
		return true
	if van._boon_choice and van._boon_choice.visible:
		return true
	if van.route_panel and van.route_panel.visible:
		return true
	if van.game_over_panel and van.game_over_panel.visible:
		return true
	if van._class_panel and van._class_panel.visible:
		return true
	return false


func bind_pause_menu() -> void:
	if van.pause_menu == null:
		return
	van.pause_menu.opened.connect(on_pause_opened)
	van.pause_menu.closed.connect(on_pause_closed)
	van.pause_menu.quit_to_menu_requested.connect(van.leave_to_main_menu)
	van.pause_menu.quit_game_requested.connect(van.quit_game)
	## Stay above dynamically added HUD overlays (reveal, boon pick, talk).
	van.get_node("HUD").move_child(van.pause_menu, -1)


func try_open_pause() -> bool:
	if van.pause_menu == null or van.pause_menu.visible:
		return false
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return false
	## Overlays that already eat Esc (close themselves). Don't stack pause on top.
	if van.bench_screen and van.bench_screen.visible:
		return false
	if van.skill_tree_hud and van.skill_tree_hud.visible:
		return false
	if van._debug_console and van._debug_console.visible:
		return false
	if van._class_panel and van._class_panel.visible:
		return false
	van.get_node("HUD").move_child(van.pause_menu, -1)
	van.pause_menu.open()
	return true


func on_pause_opened() -> void:
	van.refresh_mouse_mode()
	if van.pause_menu:
		van.pause_menu.resume_button.grab_focus()


func on_pause_closed() -> void:
	van.refresh_mouse_mode()


func is_interactive_hud(node: Node) -> bool:
	return (
		node == van.route_panel
		or node == van.driver_talk_panel
		or node == van.driver_shout_hud
		or node == van.game_over_panel
		or node == van.pause_menu
		or node == van.bench_screen
		or node == van.skill_tree_hud
		or node == van._debug_console
		or node == van._dialogue_hud
		or node == van._act_reveal
		or node == van._boon_choice
		or node == van._class_panel
	)


## Combat HUD must not eat clicks — that uncaptures the mouse in Godot.
func make_combat_hud_mouse_passthrough(node: Node) -> void:
	if node == null:
		return
	if is_interactive_hud(node):
		return
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		make_combat_hud_mouse_passthrough(child)


func open_bench() -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	if van._driver_talk_open:
		van.close_driver_talk()
	if van.skill_tree_hud and van.skill_tree_hud.visible:
		van.skill_tree_hud.close()
	if van._class_panel and van._class_panel.visible:
		van._class_panel.close()
	van.bench_screen.open()
	van.refresh_mouse_mode()


func on_bench_closed() -> void:
	van.refresh_mouse_mode()


func open_skill_tree() -> void:
	if van._driver_talk_open:
		van.close_driver_talk()
	if van.bench_screen.visible:
		van.bench_screen.close()
	if van._class_panel and van._class_panel.visible:
		van._class_panel.close()
	van.skill_tree_hud.open()
	van.refresh_mouse_mode()


func on_skill_tree_closed() -> void:
	van.refresh_mouse_mode()


func open_class_panel() -> void:
	if GameSession.phase != GameSession.RunPhase.IDLE:
		return
	if van._driver_talk_open:
		van.close_driver_talk()
	if van.bench_screen.visible:
		van.bench_screen.close()
	if van.skill_tree_hud and van.skill_tree_hud.visible:
		van.skill_tree_hud.close()
	van._class_panel.open()
	van.refresh_mouse_mode()


func on_class_panel_closed() -> void:
	van.refresh_mouse_mode()


func on_debug_console_opened() -> void:
	if van.bench_screen.visible:
		van.bench_screen.close()
	if van.skill_tree_hud and van.skill_tree_hud.visible:
		van.skill_tree_hud.close()
	if van._class_panel and van._class_panel.visible:
		van._class_panel.close()
	if van._driver_talk_open:
		van.close_driver_talk()
	van.refresh_mouse_mode()


func on_debug_console_closed() -> void:
	van.refresh_mouse_mode()


func close_blocked_overlays(next_phase: GameSession.RunPhase) -> bool:
	var bench_blocked := next_phase in [
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.ROUTE_CHOICE,
		GameSession.RunPhase.GAME_OVER,
		GameSession.RunPhase.PARKING,
		GameSession.RunPhase.ACT_REVEAL,
		GameSession.RunPhase.BOSS_PICK,
	]
	if van._act_reveal and van._act_reveal.visible:
		bench_blocked = true
	if van._boon_choice and van._boon_choice.visible:
		bench_blocked = true
	if van._driver_talk_open:
		bench_blocked = true
	if van.bench_screen.visible:
		# close() re-applies the mouse mode through on_bench_closed.
		if bench_blocked:
			van.bench_screen.close()
		return true
	if van.skill_tree_hud and van.skill_tree_hud.visible:
		if next_phase in [
			GameSession.RunPhase.ROUTE_CHOICE,
			GameSession.RunPhase.ACT_REVEAL,
			GameSession.RunPhase.BOSS_PICK,
		]:
			van.skill_tree_hud.close()
		return true
	if van._class_panel and van._class_panel.visible:
		if next_phase != GameSession.RunPhase.IDLE:
			van._class_panel.close()
		return true
	return false
