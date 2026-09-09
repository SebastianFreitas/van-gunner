class_name PauseMenu
extends Control

## Esc overlay. PROCESS_MODE_ALWAYS so Resume/Esc still work while the tree is paused.

signal opened
signal closed
signal quit_to_menu_requested
signal quit_game_requested

@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var master_volume: HSlider = %MasterVolume
@onready var music_volume: HSlider = %MusicVolume
@onready var sfx_volume: HSlider = %SfxVolume
@onready var resume_button: Button = %Resume


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	settings_panel.hide()
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_sync_volume_sliders()
	settings_panel.hide()
	show()
	get_tree().paused = true
	resume_button.grab_focus()
	opened.emit()


func close() -> void:
	if not visible:
		return
	settings_panel.hide()
	hide()
	get_tree().paused = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed(&"pause"):
		return
	if settings_panel.visible:
		settings_panel.hide()
	else:
		close()
	get_viewport().set_input_as_handled()


func _sync_volume_sliders() -> void:
	master_volume.set_value_no_signal(MetaProgression.master_volume)
	music_volume.set_value_no_signal(MetaProgression.music_volume)
	sfx_volume.set_value_no_signal(MetaProgression.sfx_volume)


func _on_resume_pressed() -> void:
	close()


func _on_settings_pressed() -> void:
	settings_panel.visible = not settings_panel.visible


func _on_master_volume_changed(value: float) -> void:
	MetaProgression.set_master_volume(value)


func _on_music_volume_changed(value: float) -> void:
	MetaProgression.set_music_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	MetaProgression.set_sfx_volume(value)


func _on_menu_pressed() -> void:
	quit_to_menu_requested.emit()


func _on_exit_pressed() -> void:
	quit_game_requested.emit()
