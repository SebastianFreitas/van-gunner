class_name DialogueHud
extends Control

## Hover-to-highlight NPC talk, Slay-the-Spire style. Click picks; E walks away.
## Talker is untyped on purpose — a class_name here would cycle with NpcTalk
## while van.gd is still compiling this file.

const ACCENT := Color(0.91, 0.78, 0.48, 1.0)
const MUTED := Color(0.62, 0.66, 0.64, 1.0)
const DISABLED := Color(0.42, 0.40, 0.36, 1.0)
const HOVER_FILL := Color(0.91, 0.78, 0.48, 0.16)

var npc: Variant

var _actor: Node3D
var _choices: Array = []
var _speaker: Label
var _line: Label
var _status: Label
var _hint: Label
var _options_box: VBoxContainer
var _status_gen := 0
var _hovered := -1


func _ready() -> void:
	add_to_group(&"dialogue_hud")
	## Full-rect IGNORE so empty space doesn't eat clicks; option rows STOP.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build()
	hide()


func is_open() -> bool:
	return visible and npc != null


func open(talk: Variant, actor: Node3D) -> void:
	npc = talk
	_actor = actor
	if not GameSession.coins_changed.is_connected(_on_coins_changed):
		GameSession.coins_changed.connect(_on_coins_changed)
	_refresh()
	show()
	_sync_mouse_mode()


func close() -> void:
	if GameSession.coins_changed.is_connected(_on_coins_changed):
		GameSession.coins_changed.disconnect(_on_coins_changed)
	_status_gen += 1
	_choices.clear()
	_hovered = -1
	var talk: Variant = npc
	npc = null
	_actor = null
	hide()
	_sync_mouse_mode()
	if talk and talk.is_talking():
		talk.close_talk()


## True if this HUD ate the key (open talk). Invalid indices still eat 1–4
## so a leftover tool slot does not fire while you're mid-conversation.
func try_choose(index: int) -> bool:
	if not is_open():
		return false
	if index < 0 or index >= _choices.size():
		return true
	_pick(index)
	return true


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER_BOTTOM)
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -280.0
	panel.offset_top = -300.0
	panel.offset_right = 280.0
	panel.offset_bottom = -92.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", _panel_style())
	add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)

	_speaker = Label.new()
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.add_theme_color_override(&"font_color", ACCENT)
	_speaker.add_theme_font_size_override(&"font_size", 18)
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_speaker)

	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_color_override(&"font_color", MUTED)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_line)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override(&"separation", 2)
	_options_box.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_child(_options_box)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override(&"font_color", ACCENT)
	_status.add_theme_font_size_override(&"font_size", 13)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_status)

	_hint = Label.new()
	_hint.text = "HOVER + CLICK      E  WALK AWAY"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override(&"font_color", DISABLED)
	_hint.add_theme_font_size_override(&"font_size", 12)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_hint)


func _refresh() -> void:
	if npc == null or _actor == null:
		return
	_speaker.text = String(npc.speaker_name).to_upper()
	_line.text = String(npc.get_speaker_line(_actor))
	_choices = npc.build_choices(_actor)
	_rebuild_options()


func _rebuild_options() -> void:
	_hovered = -1
	for child in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
	for i in _choices.size():
		_options_box.add_child(_make_option_row(i))


func _make_option_row(index: int) -> Button:
	var choice: Variant = _choices[index]
	var row := Button.new()
	row.flat = true
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_theme_font_size_override(&"font_size", 16)
	row.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if choice.available else Control.CURSOR_ARROW
	)
	row.mouse_entered.connect(_on_option_hover.bind(index))
	row.mouse_exited.connect(_on_option_unhover.bind(index))
	row.pressed.connect(_on_option_pressed.bind(index))
	_paint_option(row, index, false)
	return row


func _on_option_hover(index: int) -> void:
	_hovered = index
	_repaint_options()


func _on_option_unhover(index: int) -> void:
	if _hovered == index:
		_hovered = -1
	_repaint_options()


func _on_option_pressed(index: int) -> void:
	_pick(index)


func _pick(index: int) -> void:
	if not is_open() or index < 0 or index >= _choices.size():
		return
	if npc == null or _actor == null:
		return
	var choice: Variant = _choices[index]
	npc.last_error = ""
	if not npc.execute_choice(_actor, choice):
		var err := String(npc.last_error)
		_flash_status(err if not err.is_empty() else "CAN'T")
		_refresh()
		return
	_flash_status("")
	_refresh()


func _repaint_options() -> void:
	for i in _options_box.get_child_count():
		var row := _options_box.get_child(i) as Button
		if row:
			_paint_option(row, i, i == _hovered)


func _paint_option(row: Button, index: int, hovered: bool) -> void:
	if index < 0 or index >= _choices.size():
		return
	var choice: Variant = _choices[index]
	var available: bool = choice.available
	var lit := hovered and available
	row.text = "%s  %s" % [">" if lit else " ", String(choice.display_text())]
	row.z_index = 1 if lit else 0
	var color := DISABLED
	if available:
		color = ACCENT if lit else MUTED
	row.add_theme_color_override(&"font_color", color)
	row.add_theme_color_override(&"font_hover_color", color)
	row.add_theme_color_override(&"font_pressed_color", color)
	row.add_theme_color_override(&"font_disabled_color", color)
	row.add_theme_stylebox_override(&"normal", _option_style(lit))
	row.add_theme_stylebox_override(&"hover", _option_style(lit))
	row.add_theme_stylebox_override(&"pressed", _option_style(lit))
	row.add_theme_stylebox_override(&"disabled", _option_style(false))
	row.add_theme_stylebox_override(&"focus", _option_style(lit))


func _option_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = HOVER_FILL if hovered else Color(0, 0, 0, 0)
	style.border_color = ACCENT if hovered else Color(0, 0, 0, 0)
	style.border_width_left = 3 if hovered else 0
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _flash_status(text: String) -> void:
	_status_gen += 1
	var gen := _status_gen
	_status.text = text
	if text.is_empty():
		return
	await get_tree().create_timer(1.6).timeout
	if gen == _status_gen:
		_status.text = ""


func _on_coins_changed(_total: int) -> void:
	if is_open():
		_refresh()


func _sync_mouse_mode() -> void:
	var van := get_tree().get_first_node_in_group(&"van_run")
	if van and van.has_method(&"refresh_mouse_mode"):
		van.refresh_mouse_mode()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.045, 0.88)
	style.border_color = Color(0.86, 0.74, 0.46, 0.55)
	style.set_border_width_all(1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
