extends RefCounted

## Builds the reveal chrome (backdrop, title, card row) and the per-card
## visuals for ActRevealPanel: card backs, flipped faces and the continue
## button's stylebox.

const ACCENT := Color(0.86, 0.74, 0.46, 1.0)
const MUTED := Color(0.42, 0.40, 0.36, 1.0)
const BLESSING_COLOR := Color(0.52, 0.70, 0.88, 1.0)
const DANGER_COLOR := Color(0.84, 0.30, 0.24, 1.0)
const INK := Color(0.08, 0.08, 0.07, 0.96)
const CARD_BACK := Color(0.07, 0.07, 0.06, 1.0)

var panel: Control  # the owning ActRevealPanel; reads/writes its fields when called


func _init(owner: Control) -> void:
	panel = owner


func build_present(
	cards: Array[ActCardDefinition],
	title: String,
	flavor: String,
	hint: String,
	show_continue: bool
) -> void:
	panel._clear()
	if cards.is_empty():
		panel.hide()
		return

	panel._present_id += 1

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.02, 0.02, 0.84)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", 18)
	center.add_child(stack)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override(&"font_color", ACCENT)
	title_label.add_theme_font_size_override(&"font_size", 24)
	stack.add_child(title_label)

	var flavor_label := Label.new()
	flavor_label.text = flavor
	flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor_label.add_theme_color_override(&"font_color", MUTED)
	stack.add_child(flavor_label)

	panel._hint_label = Label.new()
	panel._hint_label.text = hint
	panel._hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel._hint_label.add_theme_color_override(&"font_color", MUTED)
	panel._hint_label.add_theme_font_size_override(&"font_size", 12)
	stack.add_child(panel._hint_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	stack.add_child(row)

	panel._card_panels.clear()
	panel._card_labels.clear()
	panel._card_gui_connected.clear()
	for i in cards.size():
		var card_panel := make_card_back()
		row.add_child(card_panel)
		panel._card_panels.append(card_panel)
		panel._card_gui_connected.append(false)
		var index := i
		card_panel.gui_input.connect(
			func(event: InputEvent) -> void: panel._on_card_gui_input(index, event)
		)
		panel._card_gui_connected[i] = true

	panel._continue_btn = Button.new()
	panel._continue_btn.text = "CONTINUE"
	panel._continue_btn.custom_minimum_size = Vector2(196, 42)
	panel._continue_btn.disabled = true
	panel._continue_btn.focus_mode = Control.FOCUS_NONE
	panel._continue_btn.pressed.connect(panel._on_continue_pressed)
	style_continue_button(panel._continue_btn)
	var btn_wrap := CenterContainer.new()
	btn_wrap.add_child(panel._continue_btn)
	stack.add_child(btn_wrap)
	if not show_continue:
		panel._continue_btn.hide()
		btn_wrap.hide()

	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func shuffle_pick_order() -> void:
	if panel._shuffled_cards.size() <= 1:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(panel._shuffled_cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: ActCardDefinition = panel._shuffled_cards[i]
		panel._shuffled_cards[i] = panel._shuffled_cards[j]
		panel._shuffled_cards[j] = tmp


func flip_card(index: int, card: ActCardDefinition) -> void:
	if index < 0 or index >= panel._card_panels.size() or card == null:
		return
	var card_panel: PanelContainer = panel._card_panels[index]
	for child in card_panel.get_children():
		card_panel.remove_child(child)
		child.queue_free()

	var accent := DANGER_COLOR if card.is_danger() else BLESSING_COLOR
	card_panel.add_theme_stylebox_override(&"panel", ink_plate(accent))

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override(&"separation", 5)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(stack)

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

	add_corner_ticks(card_panel, Color(ACCENT, 0.45))
	ignore_mouse_tree(stack)

	panel._card_labels.append(name_label)

	card_panel.scale = Vector2(0.85, 1.0)
	var tween := panel.create_tween()
	tween.tween_property(card_panel, "scale", Vector2.ONE, 0.12)


func ignore_mouse_tree(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			ignore_mouse_tree(child)


func make_card_back() -> PanelContainer:
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(118, 196)
	card_panel.pivot_offset = Vector2(59, 98)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	show_card_back(card_panel, ACCENT)
	return card_panel


func show_card_back(card_panel: PanelContainer, border_color: Color = MUTED) -> void:
	for child in card_panel.get_children():
		card_panel.remove_child(child)
		child.queue_free()
	var q := Label.new()
	q.text = "?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.add_theme_color_override(&"font_color", Color(MUTED, 0.55))
	q.add_theme_font_size_override(&"font_size", 28)
	card_panel.add_child(q)
	card_panel.add_theme_stylebox_override(&"panel", ink_plate(border_color, false))
	add_corner_ticks(card_panel, Color(border_color, 0.28))


func ink_plate(accent: Color, stripe: bool = true) -> StyleBoxFlat:
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


func add_corner_ticks(host: Control, color: Color) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(overlay)
	var tick_len := 12.0
	var thick := 1.0
	place_tick(overlay, Vector2(6, 6), Vector2(tick_len, thick), color)
	place_tick(overlay, Vector2(6, 6), Vector2(thick, tick_len), color)
	place_tick(overlay, Vector2(-6 - tick_len, 6), Vector2(tick_len, thick), color, true, false)
	place_tick(overlay, Vector2(-6 - thick, 6), Vector2(thick, tick_len), color, true, false)
	place_tick(overlay, Vector2(6, -6 - thick), Vector2(tick_len, thick), color, false, true)
	place_tick(overlay, Vector2(6, -6 - tick_len), Vector2(thick, tick_len), color, false, true)
	place_tick(overlay, Vector2(-6 - tick_len, -6 - thick), Vector2(tick_len, thick), color, true, true)
	place_tick(overlay, Vector2(-6 - thick, -6 - tick_len), Vector2(thick, tick_len), color, true, true)


func place_tick(
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


func style_continue_button(button: Button) -> void:
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
