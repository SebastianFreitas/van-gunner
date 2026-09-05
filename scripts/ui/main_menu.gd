extends Control

@onready var slots: VBoxContainer = %Slots
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var music_volume: HSlider = %MusicVolume
@onready var sfx_volume: HSlider = %SfxVolume
@onready var loading_overlay: ColorRect = %LoadingOverlay
@onready var loading_label: Label = %LoadingLabel

var _starting := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_slots()
	settings_panel.hide()
	loading_overlay.hide()
	music_volume.set_value_no_signal(MetaProgression.music_volume)
	sfx_volume.set_value_no_signal(MetaProgression.sfx_volume)
	call_deferred("_deferred_preload_van")


func _deferred_preload_van() -> void:
	SceneRouter.preload_van()


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
		if not summary.exists:
			button.text = "SLOT %d  ·  NEW RUN" % slot
		elif bool(summary.get("compatible", false)):
			button.text = "SLOT %d  ·  CONTINUE\nRoute %d  ·  Van %d%%" % [
				slot,
				summary.route_step,
				roundi(summary.van_health),
			]
		else:
			var file_version := int(summary.get("file_version", -1))
			if file_version >= 0:
				button.text = "SLOT %d  ·  CAN'T CONTINUE\nv%d save, this build wants v%d" % [
					slot,
					file_version,
					SaveManager.SAVE_VERSION,
				]
			else:
				button.text = "SLOT %d  ·  CAN'T CONTINUE\nSave file is unreadable" % slot
			button.tooltip_text = "Use NEW to overwrite this slot"
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
	if _starting:
		return
	_starting = true
	await _begin_run()
	if SaveManager.has_save(slot):
		if not SaveManager.load_slot(slot):
			## Rejected files (old version, corrupt JSON) used to look like NEW RUN
			## and this click started a fresh save over them.
			_starting = false
			loading_overlay.hide()
			_build_slots()
			return
	else:
		GameSession.start_new(slot)
	SceneRouter.go_to_van()


func _on_new_run_pressed(slot: int) -> void:
	if _starting:
		return
	_starting = true
	await _begin_run()
	GameSession.start_new(slot)
	SceneRouter.go_to_van()


func _begin_run() -> void:
	loading_label.text = "LOADING..."
	loading_overlay.show()
	# Let the overlay paint before the scene swap hitch.
	await get_tree().process_frame
	await get_tree().process_frame


func _on_settings_pressed() -> void:
	if _starting:
		return
	settings_panel.visible = not settings_panel.visible


func _on_music_volume_changed(value: float) -> void:
	MetaProgression.set_music_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	MetaProgression.set_sfx_volume(value)


func _on_exit_pressed() -> void:
	if _starting:
		return
	get_tree().quit()
