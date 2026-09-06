class_name DialogueHud
extends Control

## Numbered NPC talk. Mouse stays captured — 1–4 pick, E walks away.
## Talker is untyped on purpose — a class_name here would cycle with NpcTalk
## while van.gd is still compiling this file.

const ACCENT := Color(0.91, 0.78, 0.48, 1.0)
const MUTED := Color(0.62, 0.66, 0.64, 1.0)
const DISABLED := Color(0.42, 0.40, 0.36, 1.0)

var npc: Variant

var _actor: Node3D
var _choices: Array = []
var _speaker: Label
var _line: Label
var _status: Label
var _options_box: VBoxContainer
var _status_gen := 0


func _ready() -> void:
	add_to_group(&"dialogue_hud")
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


func close() -> void:
	if GameSession.coins_changed.is_connected(_on_coins_changed):
		GameSession.coins_changed.disconnect(_on_coins_changed)
	_status_gen += 1
	_choices.clear()
	var talk: Variant = npc
	npc = null
	_actor = null
	hide()
	if talk and talk.is_talking():
		talk.close_talk()


## True if this HUD ate the key (open talk). Invalid indices still eat 1–4
## so a leftover tool slot does not fire while you're mid-conversation.
func try_choose(index: int) -> bool:
	if not is_open():
		return false
	if index < 0 or index >= _choices.size():
		return true
	if npc == null or _actor == null:
		return true
	var choice: Variant = _choices[index]
	npc.last_error = ""
	if not npc.execute_choice(_actor, choice):
		var err := String(npc.last_error)
		_flash_status(err if not err.is_empty() else "CAN'T")
		_refresh()
		return true
	_flash_status("")
	_refresh()
	return true


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER_BOTTOM)
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -280.0
	panel.offset_top = -280.0
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
	_options_box.add_theme_constant_override(&"separation", 4)
	_options_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_options_box)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override(&"font_color", ACCENT)
	_status.add_theme_font_size_override(&"font_size", 13)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_status)

	var hint := Label.new()
	hint.text = "1–4  PICK      E  WALK AWAY"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override(&"font_color", DISABLED)
	hint.add_theme_font_size_override(&"font_size", 12)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(hint)


func _refresh() -> void:
	if npc == null or _actor == null:
		return
	_speaker.text = String(npc.speaker_name).to_upper()
	_line.text = String(npc.get_speaker_line(_actor))
	_choices = npc.build_choices(_actor)
	_rebuild_options()


func _rebuild_options() -> void:
	for child in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
	for i in _choices.size():
		var choice: Variant = _choices[i]
		var row := Label.new()
		row.text = String(choice.line_text(i))
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override(&"font_size", 16)
		row.add_theme_color_override(
			&"font_color", ACCENT if choice.available else DISABLED
		)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_options_box.add_child(row)


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
