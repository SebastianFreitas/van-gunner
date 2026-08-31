class_name BoonChoicePanel
extends Control

## REST-break overlay: pick one of several offered boons.

signal choice_made(item: ItemDefinition)

const ACCENT := Color(0.91, 0.78, 0.48, 1.0)
const MUTED := Color(0.62, 0.66, 0.64, 1.0)

var _player: Node3D
var _choices: Array[ItemDefinition] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func bind(player: Node3D) -> void:
	_player = player


func present(choices: Array[ItemDefinition]) -> void:
	_clear_buttons()
	_choices = choices.duplicate()
	if _choices.is_empty():
		hide()
		return

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
	title.text = "CHOOSE A REWARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", ACCENT)
	title.add_theme_font_size_override(&"font_size", 22)
	stack.add_child(title)

	var hint := Label.new()
	hint.text = "Pick one boon or tool for the rest of the run."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override(&"font_color", MUTED)
	stack.add_child(hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 14)
	stack.add_child(row)

	for item in _choices:
		row.add_child(_make_choice_button(item))

	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func dismiss() -> void:
	_choices.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	hide()


func _make_choice_button(item: ItemDefinition) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(220, 180)
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stack.add_theme_constant_override(&"separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stack)

	if item.icon:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(0, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(icon)

	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override(&"font_color", ACCENT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)

	if not item.description.strip_edges().is_empty():
		var body := Label.new()
		body.text = item.description.strip_edges()
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_color_override(&"font_color", MUTED)
		body.add_theme_font_size_override(&"font_size", 11)
		body.custom_minimum_size = Vector2(200, 0)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(body)

	button.pressed.connect(_on_choice_pressed.bind(item))
	return button


func _on_choice_pressed(item: ItemDefinition) -> void:
	if not item or not _player:
		dismiss()
		return
	item.collect(_player)
	choice_made.emit(item)
	dismiss()


func _clear_buttons() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
