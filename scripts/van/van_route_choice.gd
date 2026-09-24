extends RefCounted

## Builds and refreshes the ROUTE_CHOICE panel: card art, stop labels, highlight state.

const _ROUTE_ACCENT := Color(0.86, 0.74, 0.46, 1.0)
const _ROUTE_MUTED := Color(0.42, 0.40, 0.36, 1.0)
const _ROUTE_BLESSING := Color(0.52, 0.70, 0.88, 1.0)
const _ROUTE_DANGER := Color(0.84, 0.30, 0.24, 1.0)
const _ROUTE_INK := Color(0.08, 0.08, 0.07, 1.0)

var van: Node3D  # untyped owner; van.gd has no class_name (cycle rule), so fields are read dynamically


func _init(owner: Node3D) -> void:
	van = owner


func bind_buttons() -> void:
	if van._left_route_btn == null:
		van._left_route_btn = van.route_panel.get_node("Layout/Buttons/Left") as Button
		if van._left_route_btn:
			van._left_route_btn.mouse_entered.connect(van._set_route_highlight.bind(&"left"))
	if van._straight_route_btn == null:
		van._straight_route_btn = van.route_panel.get_node_or_null("Layout/Buttons/Straight") as Button
		if van._straight_route_btn:
			van._straight_route_btn.mouse_entered.connect(van._set_route_highlight.bind(&"straight"))
	if van._right_route_btn == null:
		van._right_route_btn = van.route_panel.get_node("Layout/Buttons/Right") as Button
		if van._right_route_btn:
			van._right_route_btn.mouse_entered.connect(van._set_route_highlight.bind(&"right"))


func refresh_labels() -> void:
	bind_buttons()
	var travel := van.get_tree().get_first_node_in_group(&"travel_controller")
	var offers := GameSession.peek_route_cards()
	var t_fork := GameSession.uses_t_junction()
	var title: Label = van.route_panel.get_node_or_null("Layout/Title") as Label
	if title:
		title.text = "THE ROAD SPLITS" if t_fork else "FOUR WAYS"
	if van._straight_route_btn:
		van._straight_route_btn.visible = not t_fork
	var left_card: ActCardDefinition = offers[0] if offers.size() > 0 else null
	var straight_card: ActCardDefinition = offers[1] if (not t_fork and offers.size() > 1) else null
	var right_card: ActCardDefinition
	if t_fork:
		right_card = offers[1] if offers.size() > 1 else left_card
	else:
		right_card = offers[2] if offers.size() > 2 else straight_card
	var left_stop := fork_stop_for(travel, &"left")
	var straight_stop := fork_stop_for(travel, &"straight")
	var right_stop := fork_stop_for(travel, &"right")
	populate_route_button(van._left_route_btn, left_card, left_stop != null, &"left", left_stop)
	populate_route_button(
		van._straight_route_btn, straight_card, straight_stop != null, &"straight", straight_stop
	)
	populate_route_button(van._right_route_btn, right_card, right_stop != null, &"right", right_stop)
	if van._route_highlight not in GameSession.get_route_directions():
		van._route_highlight = &"left"
	sync_highlight()


func sync_highlight() -> void:
	if van._left_route_btn == null or van._right_route_btn == null:
		return
	apply_route_highlight_look(van._left_route_btn, van._route_highlight == &"left")
	if van._straight_route_btn and van._straight_route_btn.visible:
		apply_route_highlight_look(van._straight_route_btn, van._route_highlight == &"straight")
	apply_route_highlight_look(van._right_route_btn, van._route_highlight == &"right")
	var hint: Label = van.route_panel.get_node("Layout/Hint")
	var side := String(van._route_highlight).to_upper()
	hint.text = "Gold frame is %s. Click that card (or Enter) to take it." % side
	set_route_pick_label(van._left_route_btn, &"left")
	set_route_pick_label(van._straight_route_btn, &"straight")
	set_route_pick_label(van._right_route_btn, &"right")


func set_route_pick_label(button: Button, direction: StringName) -> void:
	if button == null:
		return
	var pick := button.get_node_or_null("Stack/PickLabel") as Label
	if pick == null:
		return
	if van._route_highlight == direction:
		pick.text = "SELECTED — TAKE THIS ROAD"
	else:
		pick.text = route_dir_caption(direction)


func fork_stop_for(travel: Node, direction: StringName) -> SideStopDefinition:
	if travel == null or not travel.has_method(&"get_fork_stop_for"):
		return null
	return travel.get_fork_stop_for(direction) as SideStopDefinition


func route_dir_caption(direction: StringName) -> String:
	match direction:
		&"left":
			return "← LEFT"
		&"straight":
			return "↑ STRAIGHT"
		_:
			return "RIGHT →"


func apply_route_highlight_look(button: Button, selected: bool) -> void:
	if button == null:
		return
	button.modulate = Color.WHITE if selected else Color(0.55, 0.54, 0.52, 1.0)
	button.z_index = 1 if selected else 0
	var stripe: Color = button.get_meta(&"route_stripe", _ROUTE_ACCENT)
	var selected_bg := Color(0.18, 0.16, 0.11, 1.0)
	var style := make_route_style(selected_bg if selected else _ROUTE_INK, stripe, selected)
	button.add_theme_stylebox_override(&"normal", style)
	button.add_theme_stylebox_override(&"hover", style)
	button.add_theme_stylebox_override(&"pressed", style)
	button.add_theme_stylebox_override(&"focus", style)
	var pick := button.get_node_or_null("Stack/PickLabel") as Label
	if pick:
		pick.add_theme_color_override(
			&"font_color", _ROUTE_ACCENT if selected else _ROUTE_MUTED
		)
		pick.add_theme_font_size_override(&"font_size", 13 if selected else 11)


func populate_route_button(
	button: Button,
	card: ActCardDefinition,
	is_stop: bool,
	direction: StringName,
	fork_stop: SideStopDefinition = null
) -> void:
	if button == null:
		return
	for child in button.get_children():
		button.remove_child(child)
		child.queue_free()

	button.text = ""
	button.clip_contents = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(236, 268)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.autowrap_mode = TextServer.AUTOWRAP_OFF

	var is_danger := card != null and card.is_danger()
	var polarity := _ROUTE_DANGER if is_danger else _ROUTE_BLESSING
	button.set_meta(&"route_stripe", polarity)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override(&"separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stack)

	var dir := Label.new()
	dir.name = "PickLabel"
	dir.text = route_dir_caption(direction)
	dir.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dir.add_theme_color_override(&"font_color", _ROUTE_MUTED)
	dir.add_theme_font_size_override(&"font_size", 11)
	dir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(dir)

	# Always occupy the same vertical strip so stop / street cards line up.
	stack.add_child(make_route_stop_slot(is_stop, fork_stop))

	if card == null:
		var empty := Label.new()
		empty.text = "Unknown road"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override(&"font_color", _ROUTE_MUTED)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(empty)
		return

	var card_panel := PanelContainer.new()
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.06, 0.05, 0.92)
	card_style.set_corner_radius_all(0)
	card_style.set_border_width_all(0)
	card_style.border_width_left = 3
	card_style.border_color = polarity
	card_style.content_margin_left = 8
	card_style.content_margin_right = 6
	card_style.content_margin_top = 6
	card_style.content_margin_bottom = 6
	card_panel.add_theme_stylebox_override(&"panel", card_style)
	stack.add_child(card_panel)

	var card_stack := VBoxContainer.new()
	card_stack.add_theme_constant_override(&"separation", 3)
	card_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	card_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(card_stack)

	var polarity_label := Label.new()
	polarity_label.text = card.polarity_label()
	polarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	polarity_label.add_theme_color_override(&"font_color", polarity)
	polarity_label.add_theme_font_size_override(&"font_size", 10)
	polarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_stack.add_child(polarity_label)

	if card.icon:
		var icon := TextureRect.new()
		icon.texture = card.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(36, 36)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(0.62, 0.60, 0.56, 1.0)
		card_stack.add_child(icon)

	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override(&"font_color", _ROUTE_ACCENT)
	name_label.add_theme_font_size_override(&"font_size", 13)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_stack.add_child(name_label)

	var body := Label.new()
	body.text = card.description.strip_edges()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override(&"font_color", _ROUTE_MUTED)
	body.add_theme_font_size_override(&"font_size", 9)
	body.custom_minimum_size = Vector2(196, 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_stack.add_child(body)


func make_route_stop_slot(is_stop: bool, fork_stop: SideStopDefinition) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(0, 26)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(0)
	style.set_border_width_all(0)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.bg_color = Color(0.18, 0.17, 0.16, 1.0) if is_stop else Color(0.11, 0.11, 0.10, 1.0)
	slot.add_theme_stylebox_override(&"panel", style)
	var stop_label := Label.new()
	stop_label.text = fork_stop.fork_label() if is_stop and fork_stop else "—"
	stop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stop_label.add_theme_color_override(
		&"font_color", Color(0.72, 0.70, 0.64, 1.0) if is_stop else Color(0.28, 0.27, 0.25, 1.0)
	)
	stop_label.add_theme_font_size_override(&"font_size", 11)
	stop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(stop_label)
	return slot


func make_route_style(bg: Color, stripe: Color, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(0)
	if selected:
		style.set_border_width_all(4)
		style.border_color = _ROUTE_ACCENT
		style.shadow_color = Color(0.95, 0.82, 0.38, 0.55)
		style.shadow_size = 18
		style.shadow_offset = Vector2(0, 0)
	else:
		style.set_border_width_all(0)
		style.border_width_left = 3
		style.border_color = stripe
		style.shadow_color = Color(0, 0, 0, 0.55)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
