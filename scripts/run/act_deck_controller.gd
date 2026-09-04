class_name ActDeckController
extends Node

## Owns act-start tarot reveals: builds the deck, shows the panel, coordinates travel stop.
## Avoids typed TravelController / ActRevealPanel refs to prevent class_name cycles.

signal reveal_resolved

var _panel: Control
var _awaiting_reveal := false


func bind(panel: Control) -> void:
	_panel = panel
	add_to_group(&"act_deck_controller")
	if _panel and _panel.has_signal(&"reveal_finished"):
		if not _panel.reveal_finished.is_connected(_on_reveal_finished):
			_panel.reveal_finished.connect(_on_reveal_finished)


func is_awaiting_reveal() -> bool:
	return _awaiting_reveal


func wait_for_reveal_resolution() -> void:
	if _is_debug_speed_mode():
		if GameSession.needs_act_reveal():
			GameSession.begin_new_act_deck()
		_awaiting_reveal = false
		return
	while _awaiting_reveal:
		await get_tree().process_frame


## Starts a reveal when the deck is empty or exhausted. Returns true if a reveal ran/started.
func begin_reveal_if_needed() -> bool:
	if not GameSession.needs_act_reveal():
		return false
	if _awaiting_reveal:
		return true
	_start_reveal()
	return true


func force_reveal() -> void:
	if _awaiting_reveal:
		return
	_start_reveal()


func _start_reveal() -> void:
	var display := GameSession.begin_new_act_deck()
	_awaiting_reveal = true
	GameSession.set_phase(GameSession.RunPhase.ACT_REVEAL)
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_method(&"begin_act_statue_stop"):
		travel.begin_act_statue_stop()
	if _is_debug_speed_mode():
		_finish_reveal()
		return
	if _panel and _panel.has_method(&"present"):
		_panel.present(
			display,
			GameSession.run_act,
			GameSession.get_area_flavor_name()
		)
	else:
		_finish_reveal()


func _on_reveal_finished() -> void:
	if not _awaiting_reveal:
		return
	_finish_reveal()


func _finish_reveal() -> void:
	_awaiting_reveal = false
	if _panel and _panel.has_method(&"dismiss"):
		_panel.dismiss()
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_method(&"end_act_statue_stop"):
		travel.end_act_statue_stop()
	reveal_resolved.emit()
	SaveManager.save_active_session()


func _is_debug_speed_mode() -> bool:
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	return (
		travel != null
		and travel.has_method(&"is_debug_speed_mode")
		and travel.is_debug_speed_mode()
	)
