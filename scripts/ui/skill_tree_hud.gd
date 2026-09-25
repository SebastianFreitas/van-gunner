extends Control

## Van schematic overlay. Hover/click nodes; pending requests ghost until the
## next run (or apply now while still IDLE). Tree lives on a pan/zoom world
## under a clipped canvas so the speed chain is not pinned off-screen.
## Preload types instead of class_name so van.gd / autoloads do not hit a
## parse cycle.

signal closed

const _SkillNodeDefinition := preload("res://scripts/meta/skill_node_definition.gd")
const _SkillTreeRegistry := preload("res://scripts/core/skill_tree_registry.gd")
const SkillTreeNodes := preload("res://scripts/ui/skill_tree_nodes.gd")

const NODE_SIZE := 72.0
const GRID := 96.0
const TOOLTIP_OFFSET := Vector2(20, 18)
const TOOLTIP_MARGIN := 12.0
const ZOOM_MIN := 0.45
const ZOOM_MAX := 2.0
const ZOOM_STEP := 1.12
const FIT_PADDING := 48.0
const PAN_THRESHOLD := 6.0
const BRANCH_LABEL_SIZE := Vector2(160, 24)
const SPEED_LABEL_GRID := Vector2(0, -4.7)
const HULL_LABEL_GRID := Vector2(0, 2.7)

@onready var parts_label: Label = %PartsLabel
@onready var cap_label: Label = %CapLabel
@onready var hint_label: Label = %HintLabel
@onready var fit_button: Button = %FitButton
@onready var canvas: Control = %TreeCanvas
@onready var world: Control = %TreeWorld
@onready var tooltip: PanelContainer = %Tooltip
@onready var tooltip_title: Label = %TooltipTitle
@onready var tooltip_kind: Label = %TooltipKind
@onready var tooltip_body: Label = %TooltipBody

var _nodes: SkillTreeNodes
var _buttons: Dictionary = {} ## StringName → Button
var _hovered: _SkillNodeDefinition = null
var _lines: PackedVector2Array = PackedVector2Array()
var _fit_after_rebuild := false
var _pan_button := -1
var _panning := false
var _pan_start_mouse := Vector2.ZERO
var _pan_start_world_pos := Vector2.ZERO


func _ready() -> void:
	_nodes = SkillTreeNodes.new(self)
	set_process(false)
	tooltip.hide()
	world.draw.connect(_on_world_draw)
	canvas.gui_input.connect(_on_canvas_gui_input)
	canvas.resized.connect(_on_canvas_resized)
	fit_button.pressed.connect(_fit_view)
	fit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	MetaProgression.tree_changed.connect(_on_tree_changed)
	MetaProgression.rare_parts_changed.connect(_on_parts_changed)


func open() -> void:
	if visible:
		return
	show()
	set_process(true)
	_fit_after_rebuild = true
	call_deferred(&"_rebuild")


func close() -> void:
	if not visible:
		return
	_cancel_pan()
	_clear_tooltip()
	hide()
	set_process(false)
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			if _mouse_over_canvas():
				_zoom_at(canvas.get_local_mouse_position(), ZOOM_STEP)
				get_viewport().set_input_as_handled()
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			if _mouse_over_canvas():
				_zoom_at(canvas.get_local_mouse_position(), 1.0 / ZOOM_STEP)
				get_viewport().set_input_as_handled()
			return
		if mouse.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse.pressed and _mouse_over_canvas():
				_begin_pan(MOUSE_BUTTON_MIDDLE)
				get_viewport().set_input_as_handled()
			elif not mouse.pressed:
				_end_pan(MOUSE_BUTTON_MIDDLE)
			return
		if not mouse.pressed:
			_end_pan(mouse.button_index)
		return
	if event is InputEventMouseMotion and _pan_button != -1:
		_update_pan(canvas.get_local_mouse_position())
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _hovered:
		_position_tooltip()


func _on_tree_changed() -> void:
	if visible:
		_rebuild()


func _on_parts_changed(_total: int) -> void:
	if visible:
		_rebuild()


func _on_canvas_resized() -> void:
	if visible and _fit_after_rebuild:
		_try_fit_view()


func _on_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed and mouse.double_click:
			_cancel_pan()
			_fit_view()
			canvas.accept_event()
			return
		if mouse.pressed:
			_begin_pan(MOUSE_BUTTON_LEFT)
			canvas.accept_event()


func _rebuild() -> void:
	_clear_tooltip()
	while world.get_child_count() > 0:
		var child := world.get_child(0)
		world.remove_child(child)
		child.free()
	_buttons.clear()
	_lines = PackedVector2Array()
	_refresh_header()
	var bounds := _nodes.content_rect()
	var shift := -bounds.position
	world.size = bounds.size
	for node in _SkillTreeRegistry.list_definitions():
		var pos := node.layout_offset * GRID + shift
		if node.parent_id != &"":
			var parent: _SkillNodeDefinition = _SkillTreeRegistry.get_definition(
				node.parent_id
			)
			if parent:
				_lines.append(parent.layout_offset * GRID + shift)
				_lines.append(pos)
		var button := _nodes.make_node_button(node)
		button.position = pos - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
		world.add_child(button)
		_buttons[node.id] = button
	_nodes.add_branch_label("SPEED", SPEED_LABEL_GRID * GRID + shift)
	_nodes.add_branch_label("HULL", HULL_LABEL_GRID * GRID + shift)
	world.queue_redraw()
	if _fit_after_rebuild:
		_try_fit_view()


func _refresh_header() -> void:
	parts_label.text = "%d RARE PARTS" % MetaProgression.rare_parts
	cap_label.text = "%d / %d NODES" % [
		MetaProgression.allocation_count(),
		_SkillTreeRegistry.MAX_ALLOCATED,
	]
	if GameSession.phase == GameSession.RunPhase.IDLE:
		hint_label.text = "Requests apply now — you have not started this run."
	else:
		hint_label.text = "Requests queue for the next run. Click a queued node to refund."


func _on_world_draw() -> void:
	var i := 0
	var color := Color(0.35, 0.38, 0.36, 0.85)
	while i + 1 < _lines.size():
		world.draw_line(_lines[i], _lines[i + 1], color, 3.0, true)
		i += 2


func _mouse_over_canvas() -> bool:
	return canvas.get_global_rect().has_point(get_global_mouse_position())


func _begin_pan(button: int) -> void:
	if _pan_button != -1:
		return
	_pan_button = button
	_panning = false
	_pan_start_mouse = canvas.get_local_mouse_position()
	_pan_start_world_pos = world.position
	if button == MOUSE_BUTTON_MIDDLE:
		_panning = true
		_set_pan_cursor(true)
		_clear_tooltip()


func _update_pan(canvas_mouse: Vector2) -> void:
	if _pan_button == -1:
		return
	var delta := canvas_mouse - _pan_start_mouse
	if not _panning:
		if delta.length() < PAN_THRESHOLD:
			return
		_panning = true
		_set_pan_cursor(true)
		_clear_tooltip()
	world.position = _pan_start_world_pos + delta


func _end_pan(button: int) -> void:
	if _pan_button != button:
		return
	_cancel_pan()


func _cancel_pan() -> void:
	_pan_button = -1
	_panning = false
	_set_pan_cursor(false)


func _set_pan_cursor(active: bool) -> void:
	var shape := Control.CURSOR_MOVE if active else Control.CURSOR_ARROW
	mouse_default_cursor_shape = shape
	canvas.mouse_default_cursor_shape = shape


func _zoom_at(canvas_point: Vector2, factor: float) -> void:
	var old_scale := world.scale.x
	if old_scale <= 0.0:
		old_scale = 1.0
	var new_scale := clampf(old_scale * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_scale, old_scale):
		return
	var world_point := (canvas_point - world.position) / old_scale
	world.scale = Vector2(new_scale, new_scale)
	world.position = canvas_point - world_point * new_scale


func _try_fit_view() -> void:
	if canvas.size.x < 32.0 or canvas.size.y < 32.0:
		return
	## Wait until rebuild has sized the world; resized can fire first.
	if world.size.x < 1.0 or world.size.y < 1.0:
		return
	_fit_view()
	_fit_after_rebuild = false


func _fit_view() -> void:
	var rect := _nodes.content_rect()
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var view := canvas.size
	if view.x < 32.0 or view.y < 32.0:
		return
	var avail := Vector2(
		maxf(view.x - FIT_PADDING * 2.0, 32.0),
		maxf(view.y - FIT_PADDING * 2.0, 32.0)
	)
	var fit_scale := minf(avail.x / rect.size.x, avail.y / rect.size.y)
	fit_scale = clampf(fit_scale, ZOOM_MIN, 1.0)
	world.scale = Vector2(fit_scale, fit_scale)
	## Rebuild shifts layout space so content sits at world local (0,0).
	world.position = view * 0.5 - rect.size * 0.5 * fit_scale


func _on_node_hovered(node: _SkillNodeDefinition) -> void:
	if _panning:
		return
	_hovered = node
	_nodes.show_tooltip(node)
	set_process(true)


func _on_node_unhovered(node: _SkillNodeDefinition) -> void:
	if _hovered == node:
		_clear_tooltip()


func _on_node_pressed(node: _SkillNodeDefinition) -> void:
	if _panning:
		return
	if node.is_stub():
		return
	if MetaProgression.is_allocated(node.id):
		return
	if MetaProgression.is_pending(node.id):
		MetaProgression.try_refund_pending(node.id)
		return
	MetaProgression.try_allocate(node.id)


func _clear_tooltip() -> void:
	_hovered = null
	tooltip.hide()


func _position_tooltip() -> void:
	if not tooltip.visible:
		return
	var pos := get_global_mouse_position() + TOOLTIP_OFFSET
	var tip_size := tooltip.get_combined_minimum_size()
	var view := get_viewport_rect().size
	pos.x = minf(pos.x, view.x - tip_size.x - TOOLTIP_MARGIN)
	pos.y = minf(pos.y, view.y - tip_size.y - TOOLTIP_MARGIN)
	tooltip.global_position = pos
