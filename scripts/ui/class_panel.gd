extends Control

## Class picker overlay: one card per class, click to equip. The class board
## opens it in IDLE only, and it closes itself when the phase moves on.
## Preloaded by van.gd without a class_name, like the other run overlays.

signal closed

const ACCENT := Color(0.91, 0.78, 0.48, 1.0)
const MUTED := Color(0.62, 0.66, 0.64, 1.0)
const DIM := Color(0.45, 0.48, 0.47, 1.0)
const CARD_BG := Color(0.1, 0.12, 0.11, 1.0)
const CARD_BG_HOVER := Color(0.14, 0.17, 0.16, 1.0)
const CARD_SIZE := Vector2(230, 270)

var _cards_row: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	_build_frame()
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.class_changed.connect(_on_class_changed)


func open() -> void:
	if visible:
		return
	_rebuild_cards()
	show()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	## _input runs before van.gd's _unhandled_input, so Esc closes this first
	## instead of stacking the pause menu on top.
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	if visible and next_phase != GameSession.RunPhase.IDLE:
		close()


func _on_class_changed(_class_id: StringName) -> void:
	if visible:
		_rebuild_cards()


func _build_frame() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.04, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", 16)
	center.add_child(stack)

	var title := Label.new()
	title.text = "CHOOSE A CLASS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", ACCENT)
	title.add_theme_font_size_override(&"font_size", 22)
	stack.add_child(title)

	var hint := Label.new()
	hint.text = "Click a card to equip it. E or Esc closes."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override(&"font_color", MUTED)
	stack.add_child(hint)

	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override(&"separation", 14)
	stack.add_child(_cards_row)


func _rebuild_cards() -> void:
	for child in _cards_row.get_children():
		_cards_row.remove_child(child)
		child.queue_free()
	for def in ClassCatalog.list_all():
		_cards_row.add_child(_make_card(def))


func _make_card(def: ClassDefinition) -> Button:
	var equipped := def.id == GameSession.class_id
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override(&"normal", _card_style(equipped, CARD_BG))
	button.add_theme_stylebox_override(&"hover", _card_style(equipped, CARD_BG_HOVER))
	button.add_theme_stylebox_override(&"pressed", _card_style(equipped, CARD_BG_HOVER))

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stack.add_theme_constant_override(&"separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stack)

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override(&"font_color", ACCENT)
	name_label.add_theme_font_size_override(&"font_size", 18)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)

	var tag := Label.new()
	tag.text = "EQUIPPED" if equipped else " "
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override(&"font_color", ACCENT if equipped else DIM)
	tag.add_theme_font_size_override(&"font_size", 11)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(tag)

	var body := Label.new()
	body.text = def.description.strip_edges()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override(&"font_color", MUTED)
	body.add_theme_font_size_override(&"font_size", 12)
	body.custom_minimum_size = Vector2(200, 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(body)

	for line in _stat_lines(def):
		var stat := Label.new()
		stat.text = line
		stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat.add_theme_color_override(&"font_color", MUTED)
		stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(stat)

	button.pressed.connect(_on_card_pressed.bind(def.id))
	return button


func _card_style(equipped: bool, bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = ACCENT if equipped else DIM
	style.set_border_width_all(3 if equipped else 2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style


## Base numbers for the card: balance floor and class only, no boons. Shotgun
## damage is the whole spread, since pellets split it.
func _stat_lines(def: ClassDefinition) -> PackedStringArray:
	var stats := GunStatsController.build_class_stats(def)
	var pellets := maxi(stats.pellets_per_shot, 1)
	var damage_label := "Damage"
	if pellets > 1:
		damage_label = "Damage (%d pellets)" % pellets
	return PackedStringArray([
		"%s  %s" % [damage_label, ItemDescriber.format_number(stats.damage_per_shot)],
		"Shots/s  %s" % ItemDescriber.format_number(stats.fire_rate),
		"Magazine  %d" % stats.mag_size,
		"Reload  %ss" % ItemDescriber.format_number(stats.reload_speed),
	])


func _on_card_pressed(class_id: StringName) -> void:
	if GameSession.phase != GameSession.RunPhase.IDLE:
		close()
		return
	GameSession.equip_class(class_id)
