extends Control

## Hotbar for tools and a row of collected boon icons.

const SLOT_SCENE := preload("res://scenes/ui/usable_slot.tscn")

@onready var slots_row: HBoxContainer = %SlotsRow
@onready var boons_row: HBoxContainer = %BoonsRow
@onready var hotbar_panel: VBoxContainer = %Hotbar
@onready var hint_label: Label = %UseHint

var _controller: UsablesController
var _slot_widgets: Array[PanelContainer] = []


func bind(controller: UsablesController) -> void:
	if _controller:
		if _controller.slots_changed.is_connected(_refresh_slots):
			_controller.slots_changed.disconnect(_refresh_slots)
		if _controller.boons_changed.is_connected(_refresh_boons):
			_controller.boons_changed.disconnect(_refresh_boons)
	_controller = controller
	if not _controller:
		return
	_controller.slots_changed.connect(_refresh_slots)
	_controller.boons_changed.connect(_refresh_boons)
	_refresh_slots()
	_refresh_boons()


func _process(_delta: float) -> void:
	if not _controller or _slot_widgets.is_empty():
		return
	var slots := _controller.get_slots()
	for index in range(_slot_widgets.size()):
		if index >= slots.size():
			continue
		_slot_widgets[index].refresh(slots[index], false, index)


func _refresh_slots() -> void:
	for child in slots_row.get_children():
		child.queue_free()
	_slot_widgets.clear()
	if not _controller:
		hotbar_panel.visible = false
		return
	var slots := _controller.get_slots()
	hotbar_panel.visible = not slots.is_empty()
	hint_label.text = "1-4  USE TOOL"
	for index in range(slots.size()):
		var slot_ui := SLOT_SCENE.instantiate() as PanelContainer
		slots_row.add_child(slot_ui)
		_slot_widgets.append(slot_ui)
		slot_ui.setup(slots[index], false, index)


func _refresh_boons() -> void:
	for child in boons_row.get_children():
		child.queue_free()
	if not _controller:
		return
	for boon in _controller.get_boons():
		if not boon or not boon.icon:
			continue
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = boon.icon
		icon.tooltip_text = boon.display_name
		boons_row.add_child(icon)
