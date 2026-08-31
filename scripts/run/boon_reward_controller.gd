class_name BoonRewardController
extends Node

## Offers REST-break rewards (boons + tools) themed by the current route area.

const CHOICE_COUNT := 3

var _player: Node3D
var _panel: BoonChoicePanel
var _offered := false
var _awaiting_choice := false


func bind(player: Node3D, panel: BoonChoicePanel) -> void:
	_player = player
	_panel = panel
	add_to_group(&"boon_reward_controller")
	GameSession.phase_changed.connect(_on_phase_changed)
	if not _panel.choice_made.is_connected(_on_reward_chosen):
		_panel.choice_made.connect(_on_reward_chosen)


func is_awaiting_choice() -> bool:
	return _awaiting_choice


func wait_for_rest_resolution() -> void:
	while _awaiting_choice:
		await get_tree().process_frame


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	if next_phase != GameSession.RunPhase.REST:
		_offered = false
		_awaiting_choice = false
		if _panel:
			_panel.dismiss()
		return
	if _offered or GameSession.wave_count <= 0 or GameSession.wave_count % 10 != 0:
		return
	_offered = true
	_offer_boons()


func _offer_boons() -> void:
	if not _panel or not _player:
		return
	var exclude := _owned_boon_ids()
	var area := GameSession.get_rest_area()
	var choices := ItemPoolRegistry.pick_rest_choices(area, CHOICE_COUNT, exclude)
	if choices.is_empty():
		return
	_awaiting_choice = true
	_panel.present(choices)


func _on_reward_chosen(_item: ItemDefinition) -> void:
	_awaiting_choice = false


func _owned_boon_ids() -> Array:
	var ids: Array = []
	var controller := _player.get_node_or_null("Usables") as UsablesController
	if not controller:
		return ids
	for boon in controller.get_boons():
		if boon:
			ids.append(boon.id)
	return ids
