class_name ActDeckController
extends Node

## Owns act-start tarot reveals and the act-end boss pick.
## Avoids typed TravelController / ActRevealPanel refs to prevent class_name cycles.

signal reveal_resolved
signal boss_pick_resolved

var _panel: Control
var _awaiting_reveal := false
var _awaiting_boss_pick := false


func bind(panel: Control) -> void:
	_panel = panel
	add_to_group(&"act_deck_controller")
	if _panel and _panel.has_signal(&"reveal_finished"):
		if not _panel.reveal_finished.is_connected(_on_reveal_finished):
			_panel.reveal_finished.connect(_on_reveal_finished)
	if _panel and _panel.has_signal(&"boss_cards_picked"):
		if not _panel.boss_cards_picked.is_connected(_on_boss_cards_picked):
			_panel.boss_cards_picked.connect(_on_boss_cards_picked)


func is_awaiting_reveal() -> bool:
	return _awaiting_reveal


func is_awaiting_boss_pick() -> bool:
	return _awaiting_boss_pick


func wait_for_reveal_resolution() -> void:
	if _is_debug_speed_mode():
		if GameSession.needs_act_reveal():
			GameSession.begin_new_act_deck()
		_awaiting_reveal = false
		return
	while _awaiting_reveal:
		await get_tree().process_frame


func wait_for_boss_pick_resolution() -> void:
	if _is_debug_speed_mode():
		if GameSession.needs_boss_pick():
			GameSession.commit_boss_picks([])
		_awaiting_boss_pick = false
		return
	while _awaiting_boss_pick:
		await get_tree().process_frame


## Starts a reveal when the deck is empty or exhausted. Returns true if a reveal ran/started.
func begin_reveal_if_needed() -> bool:
	if not GameSession.needs_act_reveal():
		return false
	if _awaiting_reveal:
		return true
	_start_reveal()
	return true


func begin_boss_pick_if_needed() -> bool:
	if not GameSession.needs_boss_pick():
		return false
	if _awaiting_boss_pick:
		return true
	_start_boss_pick()
	return true


func force_reveal() -> void:
	if _awaiting_reveal:
		return
	_start_reveal()


func force_boss_pick() -> void:
	if _awaiting_boss_pick:
		return
	GameSession.debug_prepare_boss_pick()
	_start_boss_pick()


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


func _start_boss_pick() -> void:
	var display := GameSession.get_act_source_cards()
	_awaiting_boss_pick = true
	GameSession.set_phase(GameSession.RunPhase.BOSS_PICK)
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_method(&"begin_act_statue_stop"):
		travel.begin_act_statue_stop()
	if _is_debug_speed_mode():
		GameSession.commit_boss_picks([])
		_finish_boss_pick()
		return
	if _panel and _panel.has_method(&"present_boss_pick"):
		_panel.present_boss_pick(
			display,
			GameSession.BOSS_CARD_PICK_COUNT,
			GameSession.run_act,
			GameSession.get_area_flavor_name()
		)
	else:
		GameSession.commit_boss_picks([])
		_finish_boss_pick()


func _on_reveal_finished() -> void:
	if not _awaiting_reveal:
		return
	_finish_reveal()


func _on_boss_cards_picked(card_ids: Array) -> void:
	if not _awaiting_boss_pick:
		return
	var typed: Array[StringName] = []
	for entry in card_ids:
		typed.append(StringName(str(entry)))
	GameSession.commit_boss_picks(typed)
	_finish_boss_pick()


func _finish_reveal() -> void:
	_awaiting_reveal = false
	if _panel and _panel.has_method(&"dismiss"):
		_panel.dismiss()
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_method(&"end_act_statue_stop"):
		travel.end_act_statue_stop()
	reveal_resolved.emit()
	SaveManager.save_active_session()


func _finish_boss_pick() -> void:
	_awaiting_boss_pick = false
	if _panel and _panel.has_method(&"dismiss"):
		_panel.dismiss()
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_method(&"end_act_statue_stop"):
		travel.end_act_statue_stop()
	boss_pick_resolved.emit()
	if GameSession.is_boss_combat_queued():
		GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
	SaveManager.save_active_session()


func _is_debug_speed_mode() -> bool:
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	return (
		travel != null
		and travel.has_method(&"is_debug_speed_mode")
		and travel.is_debug_speed_mode()
	)
