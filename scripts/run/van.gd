extends Node3D

@onready var player: FpsPlayer = $TravelPath/VanFollow/VanRig/Player
@onready var prompt_label: Label = %InteractionPrompt
@onready var phase_label: Label = %PhaseLabel
@onready var wave_label: Label = %WaveLabel
@onready var health_bar: ProgressBar = %VanHealth
@onready var health_label: Label = %HealthLabel
@onready var message_label: Label = %MessageLabel
@onready var crosshair: Label = %Crosshair
@onready var route_panel: Control = %RouteChoice
@onready var rest_toast: Label = %RestToast
@onready var game_over_panel: Control = %GameOver
@onready var crafting_table: CraftingTable = (
	$TravelPath/VanFollow/VanRig/Interior/Props/CraftingTable
)


func _ready() -> void:
	player.interaction_prompt_changed.connect(_on_prompt_changed)
	player.shot_fired.connect(_on_shot_fired)
	crafting_table.inspected.connect(_show_message)
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.van_health_changed.connect(_on_health_changed)
	GameSession.wave_changed.connect(_on_wave_changed)
	GameSession.room_changed.connect(_on_room_changed)
	_on_health_changed(GameSession.van_health, GameSession.MAX_VAN_HEALTH)
	_on_wave_changed(GameSession.wave_count)
	_on_phase_changed(GameSession.phase)


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text


func _on_shot_fired(hit: bool) -> void:
	crosshair.modulate = Color("#e7c45b") if hit else Color("#d86a4d")
	await get_tree().create_timer(0.09).timeout
	crosshair.modulate = Color.WHITE


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
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		GameSession.RunPhase.TURNING:
			rest_toast.text = "TURNING %s..." % String(GameSession.last_direction).to_upper()
			rest_toast.show()
			route_panel.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		GameSession.RunPhase.ROUTE_CHOICE:
			rest_toast.hide()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameSession.RunPhase.GAME_OVER:
			rest_toast.hide()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_:
			rest_toast.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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


func _on_left_route_pressed() -> void:
	GameSession.choose_route(&"left")


func _on_right_route_pressed() -> void:
	GameSession.choose_route(&"right")


func _on_main_menu_pressed() -> void:
	SaveManager.save_active_session()
	SceneRouter.go_to_main_menu()
