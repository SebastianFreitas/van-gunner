extends Node3D

const _ActRevealPanel := preload("res://scripts/ui/act_reveal_panel.gd")
const _ActDeckController := preload("res://scripts/acts/act_deck_controller.gd")
const _BoonChoicePanel := preload("res://scripts/ui/boon_choice_panel.gd")
const _BoonRewardController := preload("res://scripts/acts/boon_reward_controller.gd")
const _DialogueHud := preload("res://scripts/ui/dialogue_hud.gd")
const _ClassPanel := preload("res://scripts/ui/class_panel.gd")
## Preload so van.tscn can type the bar without a class_name parse cycle.
const _VanHealthBar := preload("res://scripts/ui/van_health_bar.gd")
const _VanRouteChoice := preload("res://scripts/van/van_route_choice.gd")
const _VanHud := preload("res://scripts/van/van_hud.gd")
const _VanDriverTalk := preload("res://scripts/van/van_driver_talk.gd")
const _VanOverlays := preload("res://scripts/van/van_overlays.gd")

@onready var player: FpsPlayer = $TravelPath/VanFollow/VanRig/Player
@onready var weapon: GunController = $TravelPath/VanFollow/VanRig/Player/Head/Camera3D/Weapon
@onready var usables: UsablesController = $TravelPath/VanFollow/VanRig/Player/Usables
@onready var player_containment: VanPlayerContainment = (
	$TravelPath/VanFollow/VanRig/Interior/PlayerContainment
)
@onready var item_hud: Control = $HUD/ItemHUD
@onready var prompt_label: Label = %InteractionPrompt
@onready var phase_label: Label = %PhaseLabel
@onready var wave_label: Label = %WaveLabel
@onready var health_bar: _VanHealthBar = %VanHealth
@onready var health_label: Label = %HealthLabel
@onready var player_health_bar: ProgressBar = %PlayerHealth
@onready var player_health_label: Label = %PlayerHealthLabel
@onready var hit_flash: ColorRect = %HitFlash
@onready var message_label: Label = %MessageLabel
@onready var crosshair: Label = %Crosshair
@onready var ammo_label: Label = %AmmoLabel
@onready var ammo_bar: ProgressBar = %AmmoBar
@onready var reload_label: Label = %ReloadLabel
@onready var route_panel: Control = %RouteChoice
@onready var driver_talk_panel: Control = %DriverTalk
@onready var driver_talk_hint: Label = %DriverTalkHint
@onready var start_run_button: Button = %StartRun
@onready var accelerate_button: Button = %Accelerate
@onready var slow_button: Button = %SlowDown
@onready var driver_shout_hud: DriverShoutHud = %DriverShoutHud
@onready var rest_toast: Label = %RestToast
@onready var game_over_panel: Control = %GameOver
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var bench_screen: BenchScreen = %BenchScreen
## Untyped on purpose — do not preload the schematic HUD into this file
## (same reason debug_console is load()ed: a HUD parse error must not
## hard-fail van.tscn).
@onready var skill_tree_hud = %SkillTreeHud
@onready var crafting_table: CraftingTable = (
	$TravelPath/VanFollow/VanRig/Interior/Props/CraftingTable
)
@onready var request_board = (
	$TravelPath/VanFollow/VanRig/Interior/Props/RequestBoard
)
@onready var class_board = (
	$TravelPath/VanFollow/VanRig/Interior/Props/ClassBoard
)

var _debug_console: Control
var _act_reveal: Control
var _act_deck: Node
var _boon_choice: Control
var _boon_rewards: Node
var _dialogue_hud: Control
var _driver_talk_open := false
var _class_panel: Control
var _ammo_reload_tween: Tween
var _mouse_capture_gen := 0
var _route_highlight: StringName = &"left"
var _left_route_btn: Button
var _straight_route_btn: Button
var _right_route_btn: Button
var _last_player_hp := -1.0
var _route_ui: _VanRouteChoice
var _hud: _VanHud
var _driver_talk: _VanDriverTalk
var _overlays: _VanOverlays


func _ready() -> void:
	_route_ui = _VanRouteChoice.new(self)
	_hud = _VanHud.new(self)
	_driver_talk = _VanDriverTalk.new(self)
	_overlays = _VanOverlays.new(self)
	_overlays.build_debug_console()
	add_to_group(&"van_run")
	AudioDirector.bind_run()
	player.interaction_prompt_changed.connect(_hud.on_prompt_changed)
	player.shot_fired.connect(_on_shot_fired)
	weapon.ammo_changed.connect(_hud.on_ammo_changed)
	weapon.reloading_changed.connect(_hud.on_reloading_changed)
	crafting_table.opened.connect(_overlays.open_bench)
	bench_screen.closed.connect(_overlays.on_bench_closed)
	bench_screen.bind(player, usables, player.gun_stats, weapon)
	request_board.opened.connect(_overlays.open_skill_tree)
	skill_tree_hud.closed.connect(_overlays.on_skill_tree_closed)
	class_board.opened.connect(_overlays.open_class_panel)
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.van_health_changed.connect(_hud.on_health_changed)
	GameSession.player_health_changed.connect(_hud.on_player_health_changed)
	GameSession.wave_changed.connect(_hud.on_wave_changed)
	GameSession.room_changed.connect(_hud.on_room_changed)
	_hud.on_health_changed(GameSession.van_health, GameSession.get_max_van_health())
	_hud.on_player_health_changed(GameSession.player_health, GameSession.get_max_player_health())
	_hud.on_wave_changed(GameSession.wave_count)
	_on_phase_changed(GameSession.phase)
	_hud.on_ammo_changed(weapon.get_current_ammo(), weapon.get_mag_size())
	item_hud.bind(usables)
	usables.item_acquired.connect(_hud.on_item_acquired)
	usables.usable_activated.connect(_hud.on_usable_activated)
	## Re-apply street card overlay after load (player exists now).
	ActCardCombat.activate_active_card()
	_overlays.build_panels()
	driver_talk_panel.hide()
	_driver_talk.refresh_options()
	if driver_shout_hud:
		driver_shout_hud.boost_pressed.connect(_on_hud_boost_pressed)
		driver_shout_hud.slow_pressed.connect(_on_hud_slow_pressed)
	_route_ui.bind_buttons()
	_overlays.bind_pause_menu()
	_overlays.make_combat_hud_mouse_passthrough($HUD)
	set_process(false)


func _exit_tree() -> void:
	AudioDirector.unbind_run()
	## Don't leave the next scene (main menu) frozen if this run is torn down paused.
	var tree := get_tree()
	if tree and tree.paused:
		tree.paused = false


func _process(_delta: float) -> void:
	if not _driver_talk_open:
		set_process(false)
		return
	_driver_talk.refresh_options()


func _on_shot_fired(hit: bool) -> void:
	crosshair.modulate = Color("#e7c45b") if hit else Color("#d86a4d")
	await get_tree().create_timer(0.09).timeout
	crosshair.modulate = Color.WHITE


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	phase_label.text = "%s  ·  %s ROOM" % [
		GameSession.RunPhase.keys()[next_phase].replace("_", " "),
		String(GameSession.current_room).to_upper(),
	]
	_hud.on_wave_changed(GameSession.wave_count)
	route_panel.visible = next_phase == GameSession.RunPhase.ROUTE_CHOICE
	if next_phase == GameSession.RunPhase.ROUTE_CHOICE:
		_route_highlight = &"left"
		_route_ui.refresh_labels()
	game_over_panel.visible = next_phase == GameSession.RunPhase.GAME_OVER
	if next_phase == GameSession.RunPhase.GAME_OVER and pause_menu and pause_menu.visible:
		## Game-over buttons are PAUSABLE; leaving the tree paused bricks RETURN TO MENU.
		pause_menu.close()
	if next_phase == GameSession.RunPhase.GAME_OVER or next_phase == GameSession.RunPhase.ROUTE_CHOICE:
		close_driver_talk()
	else:
		_driver_talk.refresh_options()

	_hud.show_phase_toast(next_phase)

	if _overlays.close_blocked_overlays(next_phase):
		return
	_apply_phase_mouse_mode(next_phase)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if _overlays.try_open_pause():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"driver_boost") and not _driver_talk.shout_keys_blocked():
		request_driver_boost()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"driver_slow") and not _driver_talk.shout_keys_blocked():
		request_driver_slow_or_go()
		get_viewport().set_input_as_handled()
		return
	if GameSession.phase != GameSession.RunPhase.ROUTE_CHOICE:
		return
	if not route_panel or not route_panel.visible:
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"move_left"):
		_set_route_highlight(&"left")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"move_right"):
		_set_route_highlight(&"right")
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed(&"ui_up")
		or event.is_action_pressed(&"move_forward")
	) and not GameSession.uses_t_junction():
		_set_route_highlight(&"straight")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		GameSession.choose_route(_route_highlight)
		get_viewport().set_input_as_handled()


func _set_route_highlight(direction: StringName) -> void:
	if direction not in GameSession.get_route_directions():
		return
	_route_highlight = direction
	_route_ui.sync_highlight()


## Re-apply the correct mouse mode for the current phase / open overlays.
## Overlays should call this on close instead of hardcoding CAPTURED.
func refresh_mouse_mode() -> void:
	_apply_phase_mouse_mode(GameSession.phase)


func wants_free_cursor(phase: GameSession.RunPhase = GameSession.phase) -> bool:
	if has_modal_free_cursor():
		return true
	return phase in [
		GameSession.RunPhase.ROUTE_CHOICE,
		GameSession.RunPhase.GAME_OVER,
	]


## True only when a clickable overlay owns the cursor (blocks Esc FPS look).
func has_modal_free_cursor() -> bool:
	return _overlays.has_modal_free_cursor()


func _apply_phase_mouse_mode(phase: GameSession.RunPhase) -> void:
	var viewport := get_viewport()
	## Console keeps a LineEdit focused — releasing here forces a click to type.
	## Pause keeps Resume focused so Enter unpauses.
	var keep_focus := (
		(_debug_console != null and _debug_console.visible)
		or (pause_menu != null and pause_menu.visible)
	)
	if viewport and not keep_focus:
		viewport.gui_release_focus()
	if wants_free_cursor(phase):
		_mouse_capture_gen += 1
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	_capture_mouse_after_ui_click()


func _capture_mouse_after_ui_click() -> void:
	_mouse_capture_gen += 1
	var gen := _mouse_capture_gen
	while (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	):
		await get_tree().process_frame
		if gen != _mouse_capture_gen or wants_free_cursor():
			return
	if gen != _mouse_capture_gen or wants_free_cursor():
		return
	var viewport := get_viewport()
	if viewport:
		viewport.gui_release_focus()
	## Godot often ignores CAPTURED on the same frame as a GUI click.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame
	if gen != _mouse_capture_gen or wants_free_cursor():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _flash_player_hit() -> void:
	if hit_flash == null:
		return
	hit_flash.visible = true
	hit_flash.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(hit_flash, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func() -> void: hit_flash.visible = false)


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.show()
	await get_tree().create_timer(2.5).timeout
	message_label.hide()


func _on_left_route_pressed() -> void:
	GameSession.choose_route(&"left")


func _on_straight_route_pressed() -> void:
	GameSession.choose_route(&"straight")


func _on_right_route_pressed() -> void:
	GameSession.choose_route(&"right")


func open_driver_talk() -> void:
	_driver_talk.open()


func close_driver_talk() -> void:
	_driver_talk.close()


func _on_start_run_pressed() -> void:
	request_driver_boost()


func _on_accelerate_pressed() -> void:
	if request_driver_boost():
		close_driver_talk()


func _on_slow_pressed() -> void:
	if request_driver_slow_or_go():
		close_driver_talk()


func _on_hud_boost_pressed() -> void:
	request_driver_boost()
	_capture_mouse_after_ui_click()


func _on_hud_slow_pressed() -> void:
	request_driver_slow_or_go()
	_capture_mouse_after_ui_click()


func _on_driver_talk_close_pressed() -> void:
	close_driver_talk()


## Shift, cab-door ACCELERATE, and the HUD GO button share TravelController boost cooldown.
## In IDLE the same yell starts the run — no boost cooldown until you're actually travelling.
func request_driver_boost() -> bool:
	return _driver_talk.request_boost()


## C / HUD: ease off, or resume if already crawling.
func request_driver_slow_or_go() -> bool:
	return _driver_talk.request_slow_or_go()


func seal_van_after_stop() -> void:
	_set_stop_rear_exit(false)
	rest_toast.text = _hud.stop_toast_leaving()
	rest_toast.show()


func seal_van_after_shop() -> void:
	seal_van_after_stop()


func _set_stop_rear_exit(allowed: bool) -> void:
	if player_containment:
		player_containment.set_rear_exit_allowed(allowed)
	var rear_doors: Node = get_tree().get_first_node_in_group(&"rear_doors")
	if rear_doors == null:
		return
	if allowed and rear_doors.has_method(&"open"):
		rear_doors.open()
	elif not allowed and rear_doors.has_method(&"close"):
		rear_doors.close()


func _on_main_menu_pressed() -> void:
	leave_to_main_menu()


func leave_to_main_menu() -> void:
	SaveManager.save_active_session()
	SceneRouter.go_to_main_menu()


func quit_game() -> void:
	SaveManager.save_active_session()
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	tree.quit()
