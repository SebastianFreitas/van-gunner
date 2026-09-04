class_name ActRevealPanel
extends Control

## Act-start overlay: flips street cards (name + modifiers), then shuffles order out of view.

signal reveal_finished

const ACCENT := Color(0.91, 0.78, 0.48, 1.0)
const MUTED := Color(0.62, 0.66, 0.64, 1.0)
const BLESSING_COLOR := Color(0.55, 0.78, 0.62, 1.0)
const DANGER_COLOR := Color(0.86, 0.42, 0.36, 1.0)
const CARD_BACK := Color(0.12, 0.14, 0.16, 1.0)
const FLIP_DELAY := 0.35
const SHUFFLE_DURATION := 0.55

var _present_id := 0
var _continue_btn: Button
var _card_panels: Array[PanelContainer] = []
var _card_labels: Array[Label] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func present(display_cards: Array[ActCardDefinition], act_number: int, area_flavor: String) -> void:
	_clear()
	if display_cards.is_empty():
		hide()
		reveal_finished.emit()
		return

	_present_id += 1
	var present_id := _present_id

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.04, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", 18)
	center.add_child(stack)

	var title := Label.new()
	title.text = "ACT %d — THE ROAD AHEAD" % act_number
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", ACCENT)
	title.add_theme_font_size_override(&"font_size", 24)
	stack.add_child(title)

	var flavor := Label.new()
	flavor.text = "Area: %s  ·  Order unknown" % area_flavor
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.add_theme_color_override(&"font_color", MUTED)
	stack.add_child(flavor)

	var hint := Label.new()
	hint.text = "Six streets. Modifiers shown. Sequence stays hidden. One boon each."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override(&"font_color", MUTED)
	hint.add_theme_font_size_override(&"font_size", 12)
	stack.add_child(hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	stack.add_child(row)

	_card_panels.clear()
	_card_labels.clear()
	for _i in display_cards.size():
		var panel := _make_card_back()
		row.add_child(panel)
		_card_panels.append(panel)

	_continue_btn = Button.new()
	_continue_btn.text = "CONTINUE"
	_continue_btn.custom_minimum_size = Vector2(180, 40)
	_continue_btn.disabled = true
	_continue_btn.focus_mode = Control.FOCUS_NONE
	_continue_btn.pressed.connect(_on_continue_pressed)
	var btn_wrap := CenterContainer.new()
	btn_wrap.add_child(_continue_btn)
	stack.add_child(btn_wrap)

	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run_reveal(display_cards, present_id)


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
	await get_tree().create_timer(0.25).timeout
	if present_id != _present_id:
		return
	await _play_shuffle(present_id)
	if present_id != _present_id:
		return
	if _continue_btn:
		_continue_btn.disabled = false


func _flip_card(index: int, card: ActCardDefinition) -> void:
	if index < 0 or index >= _card_panels.size() or card == null:
		return
	var panel := _card_panels[index]
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

	var accent := DANGER_COLOR if card.is_danger() else BLESSING_COLOR
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.11, 1.0)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override(&"panel", style)

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override(&"separation", 4)
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
		stack.add_child(icon)

	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override(&"font_color", ACCENT)
	name_label.add_theme_font_size_override(&"font_size", 13)
	stack.add_child(name_label)

	var body := Label.new()
	body.text = card.description.strip_edges()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override(&"font_color", MUTED)
	body.add_theme_font_size_override(&"font_size", 10)
	body.custom_minimum_size = Vector2(100, 0)
	stack.add_child(body)

	_card_labels.append(name_label)

	panel.scale = Vector2(0.85, 1.0)
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.12)


func _play_shuffle(present_id: int) -> void:
	if _card_panels.is_empty():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	for panel in _card_panels:
		if present_id != _present_id:
			return
		# Hide faces during the shuffle so play order cannot be read from layout.
		for child in panel.get_children():
			panel.remove_child(child)
			child.queue_free()
		var q := Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		q.add_theme_color_override(&"font_color", MUTED)
		q.add_theme_font_size_override(&"font_size", 28)
		panel.add_child(q)
		var style := StyleBoxFlat.new()
		style.bg_color = CARD_BACK
		style.border_color = MUTED
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override(&"panel", style)
		var offset := Vector2(randf_range(-28.0, 28.0), randf_range(-10.0, 10.0))
		tween.tween_property(panel, "position", panel.position + offset, SHUFFLE_DURATION * 0.5)
		tween.tween_property(panel, "modulate:a", 0.35, SHUFFLE_DURATION).set_delay(
			SHUFFLE_DURATION * 0.35
		)
	await tween.finished
	if present_id != _present_id:
		return
	for panel in _card_panels:
		panel.modulate.a = 0.2


func _make_card_back() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(118, 196)
	panel.pivot_offset = Vector2(59, 98)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BACK
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override(&"panel", style)

	var label := Label.new()
	label.text = "?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	label.add_theme_color_override(&"font_color", MUTED)
	label.add_theme_font_size_override(&"font_size", 28)
	panel.add_child(label)
	return panel


func _on_continue_pressed() -> void:
	dismiss()
	reveal_finished.emit()


func _clear() -> void:
	_continue_btn = null
	_card_panels.clear()
	_card_labels.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()