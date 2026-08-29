extends Control

@onready var slots: VBoxContainer = %Slots
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var master_volume: HSlider = %MasterVolume


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_slots()
	settings_panel.hide()
	master_volume.value = db_to_linear(AudioServer.get_bus_volume_db(0))


func _build_slots() -> void:
	for child in slots.get_children():
		child.queue_free()
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var summary := SaveManager.get_slot_summary(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var button := Button.new()
		button.custom_minimum_size = Vector2(380.0, 72.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if summary.exists:
			button.text = "SLOT %d  ·  CONTINUE\nRoute %d  ·  Van %d%%" % [
				slot,
				summary.route_step,
				roundi(summary.van_health),
			]
		else:
			button.text = "SLOT %d  ·  NEW RUN" % slot
		button.pressed.connect(_on_slot_pressed.bind(slot))
		row.add_child(button)
		if summary.exists:
			var new_button := Button.new()
			new_button.custom_minimum_size = Vector2(90.0, 72.0)
			new_button.text = "NEW"
			new_button.tooltip_text = "Overwrite this slot with a fresh run"
			new_button.pressed.connect(_on_new_run_pressed.bind(slot))
			row.add_child(new_button)
		slots.add_child(row)


func _on_slot_pressed(slot: int) -> void:
	if not SaveManager.load_slot(slot):
		GameSession.start_new(slot)
	SceneRouter.go_to_van()


func _on_new_run_pressed(slot: int) -> void:
	GameSession.start_new(slot)
	SceneRouter.go_to_van()


func _on_settings_pressed() -> void:
	settings_panel.visible = not settings_panel.visible


func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))


func _on_exit_pressed() -> void:
	get_tree().quit()
