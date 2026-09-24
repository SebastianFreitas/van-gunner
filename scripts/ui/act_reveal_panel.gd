class_name ActRevealPanel
extends Control

## Act-start overlay: flips street cards (name + modifiers) and waits.
## Continue then shuffles them into a face-down pile so play order stays hidden.
##
## Boss pick reuses the same chrome: the act's six cards appear face-up again,
## flip down, shuffle, then the player chooses N of them (stacked on the boss).
## FUTURE: persistent marks on card *backs* (MetaProgression, all runs) so a
## player can recognize a street in this face-down pick.

signal reveal_finished
signal boss_cards_picked(card_ids: Array)

enum Mode { ACT_REVEAL, BOSS_PICK }

const FLIP_DELAY := 0.35
const SHUFFLE_DURATION := 0.55
const BOSS_HOLD_FACE_UP := 0.7
const REDEAL_DURATION := 0.4

const ActRevealCards := preload("res://scripts/ui/act_reveal_cards.gd")

var _cards: ActRevealCards
var _present_id := 0
var _mode := Mode.ACT_REVEAL
var _continue_btn: Button
var _hint_label: Label
var _card_panels: Array[PanelContainer] = []
var _card_labels: Array[Label] = []
var _pick_count := 2
var _picked_indices: Array[int] = []
var _shuffled_cards: Array[ActCardDefinition] = []
var _selectable := false
var _card_gui_connected: Array[bool] = []


func _ready() -> void:
	_cards = ActRevealCards.new(self)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func present(display_cards: Array[ActCardDefinition], act_number: int) -> void:
	_mode = Mode.ACT_REVEAL
	_begin_present(
		display_cards,
		"ACT %d — THE ROAD AHEAD" % act_number,
		"Order unknown",
		"Six streets. Modifiers shown. Sequence stays hidden. One boon each.",
		true
	)
	if display_cards.is_empty():
		reveal_finished.emit()
		return
	_run_reveal(display_cards, _present_id)


func present_boss_pick(
	display_cards: Array[ActCardDefinition],
	pick_count: int,
	act_number: int
) -> void:
	_mode = Mode.BOSS_PICK
	_pick_count = maxi(1, pick_count)
	_begin_present(
		display_cards,
		"ACT %d — THE JUDGE" % act_number,
		"%d streets stack on the boss" % _pick_count,
		"Same six streets. They flip down and shuffle. Pick %d." % _pick_count,
		false
	)
	_shuffled_cards = display_cards.duplicate()
	if display_cards.is_empty():
		boss_cards_picked.emit([])
		return
	_run_boss_pick(display_cards, _present_id)


func _begin_present(
	display_cards: Array[ActCardDefinition],
	title_text: String,
	flavor_text: String,
	hint_text: String,
	show_continue: bool
) -> void:
	_cards.build_present(display_cards, title_text, flavor_text, hint_text, show_continue)


func dismiss() -> void:
	_present_id += 1
	_clear()
	hide()
	_restore_mouse_mode()


func _restore_mouse_mode() -> void:
	var van := get_tree().get_first_node_in_group(&"van_run")
	if van and van.has_method(&"refresh_mouse_mode"):
		van.refresh_mouse_mode()
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _run_reveal(display_cards: Array[ActCardDefinition], present_id: int) -> void:
	for i in display_cards.size():
		if present_id != _present_id:
			return
		await get_tree().create_timer(FLIP_DELAY).timeout
		if present_id != _present_id:
			return
		_cards.flip_card(i, display_cards[i])

	if present_id != _present_id:
		return
	if _continue_btn:
		_continue_btn.disabled = false


func _run_boss_pick(display_cards: Array[ActCardDefinition], present_id: int) -> void:
	for i in display_cards.size():
		if present_id != _present_id:
			return
		await get_tree().create_timer(FLIP_DELAY).timeout
		if present_id != _present_id:
			return
		_cards.flip_card(i, display_cards[i])

	if present_id != _present_id:
		return
	if _hint_label:
		_hint_label.text = "Remember them. They are about to turn over."
	await get_tree().create_timer(BOSS_HOLD_FACE_UP).timeout
	if present_id != _present_id:
		return

	await _play_shuffle(present_id, true)
	if present_id != _present_id:
		return

	_cards.shuffle_pick_order()
	if _hint_label:
		_hint_label.text = "Pick %d face-down streets. Both apply to the boss." % _pick_count
	_selectable = true
	for panel in _card_panels:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _play_shuffle(present_id: int, redeal: bool = false) -> void:
	if _card_panels.is_empty():
		return

	var pile_host := Control.new()
	pile_host.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	pile_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pile_host)

	var start_globals: Array[Vector2] = []
	var start_sizes: Array[Vector2] = []
	for panel in _card_panels:
		start_globals.append(panel.global_position)
		start_sizes.append(panel.size)

	var row := _card_panels[0].get_parent() as Control
	if row:
		row.custom_minimum_size = row.size

	var pile_center := Vector2.ZERO
	for origin in start_globals:
		pile_center += origin
	pile_center /= float(start_globals.size())
	pile_center += start_sizes[0] * 0.5

	for i in _card_panels.size():
		if present_id != _present_id:
			return
		var panel := _card_panels[i]
		_cards.show_card_back(panel)
		panel.reparent(pile_host)
		panel.size = start_sizes[i]
		panel.global_position = start_globals[i]
		panel.pivot_offset = panel.size * 0.5
		panel.z_index = i

	var gather := create_tween()
	gather.set_parallel(true)
	for i in _card_panels.size():
		var panel := _card_panels[i]
		var jitter := Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
		var dest := pile_center - panel.size * 0.5 + jitter
		var delay := float(i) * 0.045
		gather.tween_property(panel, "global_position", dest, SHUFFLE_DURATION).set_delay(delay)
		gather.tween_property(panel, "rotation", randf_range(-0.22, 0.22), SHUFFLE_DURATION).set_delay(
			delay
		)
	await gather.finished
	if present_id != _present_id:
		return

	var mix := create_tween()
	mix.set_parallel(true)
	for panel in _card_panels:
		var mix_dest := (
			pile_center
			- panel.size * 0.5
			+ Vector2(randf_range(-12.0, 12.0), randf_range(-10.0, 10.0))
		)
		mix.tween_property(panel, "global_position", mix_dest, 0.22)
		mix.tween_property(panel, "rotation", randf_range(-0.28, 0.28), 0.22)
		if not redeal:
			mix.tween_property(panel, "modulate:a", 0.35, 0.28)
	await mix.finished
	if present_id != _present_id:
		return
	if not redeal:
		for panel in _card_panels:
			panel.modulate.a = 0.2
		return

	for panel in _card_panels:
		panel.modulate.a = 1.0
	var deal := create_tween()
	deal.set_parallel(true)
	for i in _card_panels.size():
		var panel := _card_panels[i]
		var delay := float(i) * 0.05
		deal.tween_property(panel, "global_position", start_globals[i], REDEAL_DURATION).set_delay(
			delay
		)
		deal.tween_property(panel, "rotation", 0.0, REDEAL_DURATION).set_delay(delay)
		deal.tween_property(panel, "modulate:a", 1.0, 0.12).set_delay(delay)
	await deal.finished
	if present_id != _present_id:
		return
	for i in _card_panels.size():
		var panel := _card_panels[i]
		panel.rotation = 0.0
		panel.z_index = i
		panel.modulate.a = 1.0


func _on_card_gui_input(index: int, event: InputEvent) -> void:
	if not _selectable or _mode != Mode.BOSS_PICK:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_try_pick_card(index)


func _try_pick_card(index: int) -> void:
	if not _selectable:
		return
	if index < 0 or index >= _shuffled_cards.size():
		return
	if index in _picked_indices:
		return
	_picked_indices.append(index)
	_cards.flip_card(index, _shuffled_cards[index])
	var remaining := _pick_count - _picked_indices.size()
	if _hint_label:
		if remaining > 0:
			_hint_label.text = "Pick %d more." % remaining
		else:
			_hint_label.text = "Those streets bind the judge."
	if _picked_indices.size() < _pick_count:
		return
	_selectable = false
	var present_id := _present_id
	await get_tree().create_timer(0.85).timeout
	if present_id != _present_id:
		return
	var ids: Array[StringName] = []
	for picked_index in _picked_indices:
		if picked_index >= 0 and picked_index < _shuffled_cards.size():
			var card := _shuffled_cards[picked_index]
			if card:
				ids.append(card.id)
	boss_cards_picked.emit(ids)


func _on_continue_pressed() -> void:
	if _continue_btn:
		_continue_btn.disabled = true
	var present_id := _present_id
	await _play_shuffle(present_id)
	if present_id != _present_id:
		return
	reveal_finished.emit()


func _clear() -> void:
	_continue_btn = null
	_hint_label = null
	_selectable = false
	_picked_indices.clear()
	_card_panels.clear()
	_card_labels.clear()
	_card_gui_connected.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()