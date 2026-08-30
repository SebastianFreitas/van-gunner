extends Node3D

@onready var player: FpsPlayer = $TravelPath/VanFollow/VanRig/Player
@onready var weapon: GunController = $TravelPath/VanFollow/VanRig/Player/Head/Camera3D/Weapon
@onready var usables: UsablesController = $TravelPath/VanFollow/VanRig/Player/Usables
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
@onready var rest_toast: Label = %RestToast
@onready var game_over_panel: Control = %GameOver
@onready var bench_screen: BenchScreen = %BenchScreen
@onready var crafting_table: CraftingTable = (
	$TravelPath/VanFollow/VanRig/Interior/Props/CraftingTable
)


func _ready() -> void:
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
	_on_health_changed(GameSession.van_health, GameSession.MAX_VAN_HEALTH)
	_on_wave_changed(GameSession.wave_count)
	_on_phase_changed(GameSession.phase)
	_on_ammo_changed(weapon.get_current_ammo(), weapon.get_mag_size())
	item_hud.bind(usables)
	usables.item_acquired.connect(_on_item_acquired)
	usables.usable_activated.connect(_on_usable_activated)


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
	game_over_panel.visible = next_phase == GameSession.RunPhase.GAME_OVER

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
		_:
			rest_toast.hide()

	var bench_blocked := next_phase in [
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.ROUTE_CHOICE,
		GameSession.RunPhase.GAME_OVER,
	]
	if bench_screen.visible:
		# close() re-applies the mouse mode through _on_bench_closed.
		if bench_blocked:
			bench_screen.close()
		return
	_apply_phase_mouse_mode(next_phase)


func _apply_phase_mouse_mode(phase: GameSession.RunPhase) -> void:
	var free_cursor := phase in [
		GameSession.RunPhase.ROUTE_CHOICE,
		GameSession.RunPhase.GAME_OVER,
	]
	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE if free_cursor else Input.MOUSE_MODE_CAPTURED
	)


func _open_bench() -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	bench_screen.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_bench_closed() -> void:
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
	if item.kind == ItemDefinition.ItemKind.BOON:
		_show_message("BOON  %s" % item.display_name.to_upper())
	elif item.is_usable() and slot_index >= 0:
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


func _on_main_menu_pressed() -> void:
	SaveManager.save_active_session()
	SceneRouter.go_to_main_menu()
