class_name BoonRewardController
extends Node

## Resolves the next act-deck card during REST (auto-grant BOON or flag DANGER).

signal rest_resolved

const GRANT_BEAT_SECONDS := 1.6

var _player: Node3D
var _awaiting_resolution := false


func bind(player: Node3D) -> void:
	_player = player
	add_to_group(&"boon_reward_controller")
	GameSession.phase_changed.connect(_on_phase_changed)


func is_awaiting_resolution() -> bool:
	return _awaiting_resolution


func wait_for_rest_resolution() -> void:
	if _is_debug_speed_mode():
		return
	while _awaiting_resolution:
		await get_tree().process_frame


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	if next_phase != GameSession.RunPhase.REST:
		_awaiting_resolution = false
		return
	# Intro / pre-combat rests do not resolve act cards.
	if GameSession.wave_count <= 0:
		return
	if _is_debug_speed_mode():
		_resolve_card_immediate()
		return
	_awaiting_resolution = true
	_resolve_card()


func _resolve_card_immediate() -> void:
	if GameSession.needs_act_reveal():
		return
	var kind := GameSession.resolve_next_act_card()
	if kind == GameSession.CARD_BOON:
		_grant_boon()


func _resolve_card() -> void:
	if GameSession.needs_act_reveal():
		_awaiting_resolution = false
		rest_resolved.emit()
		return
	var kind := GameSession.resolve_next_act_card()
	match kind:
		GameSession.CARD_BOON:
			_grant_boon()
			await get_tree().create_timer(GRANT_BEAT_SECONDS).timeout
		GameSession.CARD_DANGER:
			_toast_danger()
			await get_tree().create_timer(GRANT_BEAT_SECONDS).timeout
		_:
			pass
	_awaiting_resolution = false
	rest_resolved.emit()
	SaveManager.save_active_session()


func _grant_boon() -> void:
	if not _player:
		return
	var exclude := _owned_boon_ids()
	var area := GameSession.get_rest_area()
	var choices := ItemPoolRegistry.pick_rest_choices(area, 1, exclude)
	if choices.is_empty():
		return
	var item: ItemDefinition = choices[0]
	item.collect(_player)


func _toast_danger() -> void:
	var host := get_parent()
	if host and host.has_method(&"_show_message"):
		host.call(&"_show_message", "DANGER  —  HARD ROAD AHEAD")


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
