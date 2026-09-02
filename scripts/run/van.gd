extends Node3D

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
@onready var health_bar: ProgressBar = %VanHealth
@onready var health_label: Label = %HealthLabel
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
@onready var rest_toast: Label = %RestToast
@onready var game_over_panel: Control = %GameOver
@onready var bench_screen: BenchScreen = %BenchScreen
@onready var crafting_table: CraftingTable = (
	$TravelPath/VanFollow/VanRig/Interior/Props/CraftingTable
)

var _debug_console: Control
var _boon_choice: BoonChoicePanel
var _boon_rewards: BoonRewardController
var _driver_talk_open := false


func _ready() -> void:
	if DebugConfig.ENABLED:
		_debug_console = preload("res://scenes/ui/debug_console.tscn").instantiate()
		$HUD.add_child(_debug_console)
		_debug_console.opened.connect(_on_debug_console_opened)
		_debug_console.closed.connect(_on_debug_console_closed)
	player.interaction_prompt_changed.connect(_on_prompt_changed)
	player.shot_fired.connect(_on_shot_fired)
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reloading_changed.connect(_on_reloading_changed)
	crafting_table.opened.connect(_open_bench)
	bench_screen.closed.connect(_on_bench_closed)
	bench_screen.bind(player, usables, player.gun_stats, weapon)
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.van_health_changed.connect(_on_health_changed)
	GameSession.wave_changed.connect(_on_wave_changed)
	GameSession.room_changed.connect(_on_room_changed)
	_on_health_changed(GameSession.van_health, GameSession.get_max_van_health())
	_on_wave_changed(GameSession.wave_count)
	_on_phase_changed(GameSession.phase)
	_on_ammo_changed(weapon.get_current_ammo(), weapon.get_mag_size())
	item_hud.bind(usables)
	usables.item_acquired.connect(_on_item_acquired)
	usables.usable_activated.connect(_on_usable_activated)
	_boon_choice = BoonChoicePanel.new()
	_boon_choice.bind(player)
	$HUD.add_child(_boon_choice)
	_boon_rewards = BoonRewardController.new()
	add_child(_boon_rewards)
	_boon_rewards.bind(player, _boon_choice)
	driver_talk_panel.hide()
	_refresh_driver_talk_options()
	set_process(false)


func _process(_delta: float) -> void:
	if not _driver_talk_open:
		set_process(false)
		return
	_refresh_driver_talk_options()


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text


func _on_shot_fired(hit: bool) -> void:
	crosshair.modulate = Color("#e7c45b") if hit else Color("#d86a4d")
	await get_tree().create_timer(0.09).timeout
	crosshair.modulate = Color.WHITE


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo_label.text = "AMMO  %d / %d" % [current, max_ammo]
	ammo_bar.max_value = max_ammo
	ammo_bar.value = current
	var low_ammo := current <= maxi(1, floori(max_ammo * 0.25))
	ammo_label.modulate = Color("#f0a84a") if low_ammo else Color("#e8d68c")


func _on_reloading_changed(is_reloading: bool) -> void:
	reload_label.visible = is_reloading
	if is_reloading:
		ammo_label.modulate = Color("#c8c8c8")
	else:
		_on_ammo_changed(weapon.get_current_ammo(), weapon.get_mag_size())


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	phase_label.text = "%s  ·  %s ROOM" % [
		GameSession.RunPhase.keys()[next_phase].replace("_", " "),
		String(GameSession.current_room).to_upper(),
	]
	route_panel.visible = next_phase == GameSession.RunPhase.ROUTE_CHOICE
	if next_phase == GameSession.RunPhase.ROUTE_CHOICE:
		_refresh_route_choice_labels()
	game_over_panel.visible = next_phase == GameSession.RunPhase.GAME_OVER
	if next_phase == GameSession.RunPhase.GAME_OVER or next_phase == GameSession.RunPhase.ROUTE_CHOICE:
		close_driver_talk()
	else:
		_refresh_driver_talk_options()

	match next_phase:
		GameSession.RunPhase.REST:
			rest_toast.text = (
				"FIRST FORK AHEAD — ROAD KEEPS MOVING"
				if GameSession.route_step == 0
				else "BREAK — ROAD KEEPS MOVING"
			)
			rest_toast.show()
		GameSession.RunPhase.TURNING:
			rest_toast.text = "TURNING %s..." % String(GameSession.last_direction).to_upper()
			rest_toast.show()
			route_panel.hide()
		GameSession.RunPhase.PARKING:
			rest_toast.text = "PULLING INTO THE SHOP..."
			rest_toast.show()
		GameSession.RunPhase.SHOP:
			_set_shop_rear_exit(true)
			rest_toast.text = "SHOP — STEP OUT BACK, THEN TELL THE DRIVER TO CONTINUE"
			rest_toast.show()
		_:
			if player_containment and player_containment.is_rear_exit_allowed():
				_set_shop_rear_exit(false)
			rest_toast.hide()

	var bench_blocked := next_phase in [
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.ROUTE_CHOICE,
		GameSession.RunPhase.GAME_OVER,
		GameSession.RunPhase.PARKING,
	]
	if _boon_choice and _boon_choice.visible:
		bench_blocked = true
	if _driver_talk_open:
		bench_blocked = true
	if bench_screen.visible:
		# close() re-applies the mouse mode through _on_bench_closed.
		if bench_blocked:
			bench_screen.close()
		return
	_apply_phase_mouse_mode(next_phase)


func _refresh_route_choice_labels() -> void:
	var left_btn: Button = %RouteChoice.get_node("Layout/Buttons/Left")
	var right_btn: Button = %RouteChoice.get_node("Layout/Buttons/Right")
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	var shop_side: StringName = &""
	if travel and travel.has_method(&"get_shop_fork_side"):
		shop_side = travel.get_shop_fork_side()
	left_btn.text = "SHOP ←" if shop_side == &"left" else "TURN LEFT"
	right_btn.text = "SHOP →" if shop_side == &"right" else "TURN RIGHT"
	var hint: Label = %RouteChoice.get_node("Layout/Hint")
	if shop_side == &"left":
		hint.text = "Shop is on the left — or take the other road."
	elif shop_side == &"right":
		hint.text = "Shop is on the right — or take the other road."
	else:
		hint.text = "Pick a turn — or the road picks for you."


func _apply_phase_mouse_mode(phase: GameSession.RunPhase) -> void:
	var free_cursor := (
		_driver_talk_open
		or phase in [
			GameSession.RunPhase.ROUTE_CHOICE,
			GameSession.RunPhase.GAME_OVER,
		]
	)
	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE if free_cursor else Input.MOUSE_MODE_CAPTURED
	)


func _open_bench() -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	if _driver_talk_open:
		close_driver_talk()
	bench_screen.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_bench_closed() -> void:
	if _debug_console and _debug_console.visible:
		return
	if _boon_choice and _boon_choice.visible:
		return
	if _driver_talk_open:
		return
	_apply_phase_mouse_mode(GameSession.phase)


func _on_debug_console_opened() -> void:
	if bench_screen.visible:
		bench_screen.close()
	if _driver_talk_open:
		close_driver_talk()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_debug_console_closed() -> void:
	if bench_screen.visible:
		return
	if _driver_talk_open:
		return
	_apply_phase_mouse_mode(GameSession.phase)


func _on_room_changed(_room: StringName) -> void:
	_on_phase_changed(GameSession.phase)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "VAN  %d / %d" % [roundi(current), roundi(maximum)]


func _on_wave_changed(wave: int) -> void:
	wave_label.text = "WAVES CLEARED  %d  ·  ROUTE EVERY 10" % wave


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.show()
	await get_tree().create_timer(2.5).timeout
	message_label.hide()


func _on_item_acquired(item: ItemDefinition, charges: int, slot_index: int) -> void:
	if not item:
		return
	match item.kind:
		ItemDefinition.ItemKind.BOON:
			_show_message("BOON  %s" % item.display_name.to_upper())
		ItemDefinition.ItemKind.MONEY:
			_show_message("COINS  %s" % item.display_name.to_upper())
		ItemDefinition.ItemKind.CONSUMABLE:
			_show_message("USED  %s" % item.display_name.to_upper())
		ItemDefinition.ItemKind.TOOL:
			if slot_index >= 0:
				_show_message("TOOL  %s  x%d  —  PRESS %d" % [
					item.display_name.to_upper(),
					charges,
					slot_index + 1,
				])


func _on_usable_activated(item: ItemDefinition, success: bool) -> void:
	if not item:
		return
	if success:
		_show_message("USED  %s" % item.display_name.to_upper())
	else:
		_show_message("%s  NOT READY" % item.display_name.to_upper())


func _on_left_route_pressed() -> void:
	GameSession.choose_route(&"left")


func _on_right_route_pressed() -> void:
	GameSession.choose_route(&"right")


func open_driver_talk() -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	if GameSession.phase == GameSession.RunPhase.ROUTE_CHOICE:
		return
	if GameSession.phase == GameSession.RunPhase.SHOP:
		return
	if GameSession.phase == GameSession.RunPhase.PARKING:
		return
	if _boon_choice and _boon_choice.visible:
		return
	if bench_screen.visible:
		bench_screen.close()
	_driver_talk_open = true
	_refresh_driver_talk_options()
	driver_talk_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process(true)


func close_driver_talk() -> void:
	if not _driver_talk_open and not driver_talk_panel.visible:
		return
	_driver_talk_open = false
	driver_talk_panel.hide()
	set_process(false)
	_apply_phase_mouse_mode(GameSession.phase)


func _refresh_driver_talk_options() -> void:
	var idle := GameSession.phase == GameSession.RunPhase.IDLE
	start_run_button.visible = idle
	accelerate_button.visible = not idle
	if idle:
		driver_talk_hint.text = "Ready when you are."
		start_run_button.disabled = false
		return

	var travel := get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel == null:
		driver_talk_hint.text = "Ask the driver for more speed."
		accelerate_button.disabled = true
		accelerate_button.text = "ACCELERATE"
		return

	if travel.is_boosting():
		driver_talk_hint.text = "Hold on — flooring it."
		accelerate_button.disabled = true
		accelerate_button.text = "FLOORING IT"
	elif not travel.can_boost():
		var wait := ceili(travel.get_boost_cooldown_remaining())
		driver_talk_hint.text = "Engine's hot — give it a moment."
		accelerate_button.disabled = true
		accelerate_button.text = "WAIT %ds" % wait
	else:
		driver_talk_hint.text = "Ask the driver for more speed."
		accelerate_button.disabled = false
		accelerate_button.text = "ACCELERATE"


func _on_start_run_pressed() -> void:
	GameSession.begin_run()
	_refresh_driver_talk_options()
	close_driver_talk()
	_show_message("RUN STARTED — ROAD AHEAD")


func _on_accelerate_pressed() -> void:
	var travel := get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel == null or not travel.try_boost():
		_refresh_driver_talk_options()
		return
	close_driver_talk()
	_show_message("DRIVER FLOORS IT")


func _on_driver_talk_close_pressed() -> void:
	close_driver_talk()


func seal_van_after_shop() -> void:
	_set_shop_rear_exit(false)


func _set_shop_rear_exit(allowed: bool) -> void:
	if player_containment:
		player_containment.set_rear_exit_allowed(allowed)


func _on_main_menu_pressed() -> void:
	SaveManager.save_active_session()
	SceneRouter.go_to_main_menu()
