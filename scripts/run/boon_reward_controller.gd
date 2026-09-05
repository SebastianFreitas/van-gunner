class_name BoonRewardController
extends Node

## During REST, grants a 3-choice boon for the street card committed at the last fork.

signal rest_resolved

const CHOICE_COUNT := 3

var _player: Node3D
var _panel: Control
var _awaiting_resolution := false


func bind(player: Node3D, panel: Control = null) -> void:
	_player = player
	_panel = panel
	add_to_group(&"boon_reward_controller")
	if not GameSession.phase_changed.is_connected(_on_phase_changed):
		GameSession.phase_changed.connect(_on_phase_changed)
	if _panel and _panel.has_signal(&"choice_made"):
		if not _panel.choice_made.is_connected(_on_choice_made):
			_panel.choice_made.connect(_on_choice_made)


func is_awaiting_resolution() -> bool:
	return _awaiting_resolution


## Bonus 3-choice pick (warehouse chest). Does not consume the street REST boon.
func present_bonus_choices() -> void:
	if not _player:
		return
	if _is_debug_speed_mode():
		_auto_collect_one()
		SaveManager.save_active_session()
		return
	var exclude := _owned_boon_ids()
	var area := GameSession.get_rest_area()
	var choices := ItemPoolRegistry.pick_rest_choices(area, CHOICE_COUNT, exclude)
	if choices.is_empty():
		return
	if _panel and _panel.has_method(&"present"):
		_panel.present(choices)
	else:
		choices[0].collect(_player)
		SaveManager.save_active_session()


func wait_for_rest_resolution() -> void:
	if _is_debug_speed_mode():
		return
	while _awaiting_resolution:
		await get_tree().process_frame


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	if next_phase != GameSession.RunPhase.REST:
		_awaiting_resolution = false
		return
	# Intro / pre-combat rests do not grant street boons.
	if GameSession.wave_count <= 0:
		return
	if GameSession.pending_boon_card_id == &"":
		return
	if _is_debug_speed_mode():
		_grant_boon_immediate()
		return
	_awaiting_resolution = true
	_present_boon_choices()


func _grant_boon_immediate() -> void:
	if GameSession.pending_boon_card_id == &"":
		return
	_auto_collect_one()
	GameSession.clear_pending_boon_card()
	SaveManager.save_active_session()


func _present_boon_choices() -> void:
	if not _player:
		_finish_resolution()
		return
	var exclude := _owned_boon_ids()
	var area := GameSession.get_rest_area()
	var choices := ItemPoolRegistry.pick_rest_choices(area, CHOICE_COUNT, exclude)
	if choices.is_empty():
		_finish_resolution()
		return
	if _panel and _panel.has_method(&"present"):
		_panel.present(choices)
	else:
		choices[0].collect(_player)
		_finish_resolution()


func _on_choice_made(_item: ItemDefinition) -> void:
	if _awaiting_resolution:
		_finish_resolution()
		return
	SaveManager.save_active_session()


func _finish_resolution() -> void:
	GameSession.clear_pending_boon_card()
	_awaiting_resolution = false
	rest_resolved.emit()
	SaveManager.save_active_session()


func _auto_collect_one() -> void:
	if not _player:
		return
	var exclude := _owned_boon_ids()
	var area := GameSession.get_rest_area()
	var choices := ItemPoolRegistry.pick_rest_choices(area, 1, exclude)
	if choices.is_empty():
		return
	var item: ItemDefinition = choices[0]
	item.collect(_player)


func _owned_boon_ids() -> Array:
	var ids: Array = []
	var controller := _player.get_node_or_null("Usables") as UsablesController
	if not controller:
		return ids
	for boon in controller.get_boons():
		if boon:
			ids.append(boon.id)
	return ids


func _is_debug_speed_mode() -> bool:
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	return (
		travel != null
		and travel.has_method(&"is_debug_speed_mode")
		and travel.is_debug_speed_mode()
	)