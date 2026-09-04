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

const ACCENT := Color(0.86, 0.74, 0.46, 1.0)
const MUTED := Color(0.42, 0.40, 0.36, 1.0)
const BLESSING_COLOR := Color(0.52, 0.70, 0.88, 1.0)
const DANGER_COLOR := Color(0.84, 0.30, 0.24, 1.0)
const INK := Color(0.08, 0.08, 0.07, 0.96)
const CARD_BACK := Color(0.07, 0.07, 0.06, 1.0)
const FLIP_DELAY := 0.35
const SHUFFLE_DURATION := 0.55
const BOSS_HOLD_FACE_UP := 0.7
const REDEAL_DURATION := 0.4

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
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func present(display_cards: Array[ActCardDefinition], act_number: int, area_flavor: String) -> void:
	_mode = Mode.ACT_REVEAL
	_begin_present(
		display_cards,
		"ACT %d — THE ROAD AHEAD" % act_number,
		"Area: %s  ·  Order unknown" % area_flavor,
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
	act_number: int,
	area_flavor: String
) -> void:
	_mode = Mode.BOSS_PICK
	_pick_count = maxi(1, pick_count)
	_begin_present(
		display_cards,
		"ACT %d — THE JUDGE" % act_number,
		"Area: %s  ·  %d streets stack on the boss" % [area_flavor, _pick_count],
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
	_clear()
	if display_cards.is_empty():
		hide()
		return

	_present_id += 1

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.02, 0.02, 0.84)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", 18)
	center.add_child(stack)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", ACCENT)
	title.add_theme_font_size_override(&"font_size", 24)
	stack.add_child(title)

	var flavor := Label.new()
	flavor.text = flavor_text
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.add_theme_color_override(&"font_color", MUTED)
	stack.add_child(flavor)

	_hint_label = Label.new()
	_hint_label.text = hint_text
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override(&"font_color", MUTED)
	_hint_label.add_theme_font_size_override(&"font_size", 12)
	stack.add_child(_hint_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	stack.add_child(row)

	_card_panels.clear()
	_card_labels.clear()
	_card_gui_connected.clear()
	for i in display_cards.size():
		var panel := _make_card_back()
		row.add_child(panel)
		_card_panels.append(panel)
		_card_gui_connected.append(false)
		var index := i
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_card_gui_input(index, event))
		_card_gui_connected[i] = true

	_continue_btn = Button.new()
	_continue_btn.text = "CONTINUE"
	_continue_btn.custom_minimum_size = Vector2(196, 42)
	_continue_btn.disabled = true
	_continue_btn.focus_mode = Control.FOCUS_NONE
	_continue_btn.pressed.connect(_on_continue_pressed)
	_style_continue_button(_continue_btn)
	var btn_wrap := CenterContainer.new()
	btn_wrap.add_child(_continue_btn)
	stack.add_child(btn_wrap)
	if not show_continue:
		_continue_btn.hide()
		btn_wrap.hide()

	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
		_flip_card(i, display_cards[i])

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
		_flip_card(i, display_cards[i])

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

	_shuffle_pick_order()
	if _hint_label:
		_hint_label.text = "Pick %d face-down streets. Both apply to the boss." % _pick_count
	_selectable = true
	for panel in _card_panels:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _shuffle_pick_order() -> void:
	if _shuffled_cards.size() <= 1:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(_shuffled_cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := _shuffled_cards[i]
		_shuffled_cards[i] = _shuffled_cards[j]
		_shuffled_cards[j] = tmp


func _flip_card(index: int, card: ActCardDefinition) -> void:
	if index < 0 or index >= _card_panels.size() or card == null:
		return
	var panel := _card_panels[index]
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

	var accent := DANGER_COLOR if card.is_danger() else BLESSING_COLOR
	panel.add_theme_stylebox_override(&"panel", _ink_plate(accent))

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override(&"separation", 5)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)

	var polarity := Label.new()
	polarity.text = card.polarity_label()
	polarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	polarity.add_theme_color_override(&"font_color", accent)
	polarity.add_theme_font_size_override(&"font_size", 11)
	stack.add_child(polarity)

	if card.icon:
		var icon := TextureRect.new()
		icon.texture = card.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.modulate = Color(0.62, 0.60, 0.56, 1.0)
		stack.add_child(icon)

	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override(&"font_color", ACCENT)
	name_label.add_theme_font_size_override(&"font_size", 13)
	stack.add_child(name_label)

	var rule := ColorRect.new()
	rule.color = Color(ACCENT, 0.35)
	rule.custom_minimum_size = Vector2(36, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(rule)

	var body := Label.new()
	body.text = card.description.strip_edges()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override(&"font_color", MUTED)
	body.add_theme_font_size_override(&"font_size", 10)
	body.custom_minimum_size = Vector2(100, 0)
	stack.add_child(body)

	_add_corner_ticks(panel, Color(ACCENT, 0.45))
	_ignore_mouse_tree(stack)

	_card_labels.append(name_label)

	panel.scale = Vector2(0.85, 1.0)
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.12)


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
		_show_card_back(panel)
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


func _ignore_mouse_tree(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse_tree(child)


func _make_card_back() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(118, 196)
	panel.pivot_offset = Vector2(59, 98)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_show_card_back(panel, ACCENT)
	return panel


func _show_card_back(panel: PanelContainer, border_color: Color = MUTED) -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var q := Label.new()
	q.text = "?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.add_theme_color_override(&"font_color", Color(MUTED, 0.55))
	q.add_theme_font_size_override(&"font_size", 28)
	panel.add_child(q)
	panel.add_theme_stylebox_override(&"panel", _ink_plate(border_color, false))
	_add_corner_ticks(panel, Color(border_color, 0.28))


func _ink_plate(accent: Color, stripe: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.set_corner_radius_all(0)
	style.set_border_width_all(0)
	if stripe:
		style.border_width_left = 3
		style.border_color = accent
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 12 if stripe else 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _add_corner_ticks(host: Control, color: Color) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(overlay)
	var len := 12.0
	var thick := 1.0
	_place_tick(overlay, Vector2(6, 6), Vector2(len, thick), color)
	_place_tick(overlay, Vector2(6, 6), Vector2(thick, len), color)
	_place_tick(overlay, Vector2(-6 - len, 6), Vector2(len, thick), color, true, false)
	_place_tick(overlay, Vector2(-6 - thick, 6), Vector2(thick, len), color, true, false)
	_place_tick(overlay, Vector2(6, -6 - thick), Vector2(len, thick), color, false, true)
	_place_tick(overlay, Vector2(6, -6 - len), Vector2(thick, len), color, false, true)
	_place_tick(overlay, Vector2(-6 - len, -6 - thick), Vector2(len, thick), color, true, true)
	_place_tick(overlay, Vector2(-6 - thick, -6 - len), Vector2(thick, len), color, true, true)


func _place_tick(
	overlay: Control,
	offset: Vector2,
	size: Vector2,
	color: Color,
	from_right: bool = false,
	from_bottom: bool = false
) -> void:
	var tick := ColorRect.new()
	tick.color = color
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.anchor_left = 1.0 if from_right else 0.0
	tick.anchor_right = 1.0 if from_right else 0.0
	tick.anchor_top = 1.0 if from_bottom else 0.0
	tick.anchor_bottom = 1.0 if from_bottom else 0.0
	tick.offset_left = offset.x
	tick.offset_top = offset.y
	tick.offset_right = offset.x + size.x
	tick.offset_bottom = offset.y + size.y
	overlay.add_child(tick)


func _style_continue_button(button: Button) -> void:
	var idle := StyleBoxFlat.new()
	idle.bg_color = CARD_BACK
	idle.set_corner_radius_all(0)
	idle.set_border_width_all(0)
	idle.border_width_top = 2
	idle.border_color = ACCENT
	idle.content_margin_left = 18
	idle.content_margin_right = 18
	idle.content_margin_top = 10
	idle.content_margin_bottom = 10
	var hover := idle.duplicate()
	hover.bg_color = Color(0.12, 0.11, 0.09, 1.0)
	var pressed := idle.duplicate()
	pressed.bg_color = Color(0.05, 0.05, 0.04, 1.0)
	var disabled := idle.duplicate()
	disabled.border_color = Color(ACCENT, 0.22)
	disabled.bg_color = Color(0.06, 0.06, 0.05, 1.0)
	button.add_theme_stylebox_override(&"normal", idle)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", pressed)
	button.add_theme_stylebox_override(&"disabled", disabled)
	button.add_theme_stylebox_override(&"focus", idle)
	button.add_theme_color_override(&"font_color", ACCENT)
	button.add_theme_color_override(&"font_hover_color", ACCENT.lightened(0.12))
	button.add_theme_color_override(&"font_pressed_color", ACCENT.darkened(0.1))
	button.add_theme_color_override(&"font_disabled_color", Color(MUTED, 0.55))


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
	_flip_card(index, _shuffled_cards[index])
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