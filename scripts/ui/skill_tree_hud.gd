extends Control

## Van schematic overlay. Hover/click nodes; pending requests ghost until the
## next run (or apply now while still IDLE). Preload types instead of class_name
## so van.gd / autoloads do not hit a parse cycle.

signal closed

const _SkillNodeDefinition := preload("res://scripts/meta/skill_node_definition.gd")
const _SkillTreeRegistry := preload("res://scripts/core/skill_tree_registry.gd")

const ACCENT := Color(0.91, 0.78, 0.48, 1.0)
const DIM := Color(0.45, 0.48, 0.47, 1.0)
const PENDING := Color(0.86, 0.58, 0.28, 1.0)
const LIVE := Color(0.52, 0.82, 0.62, 1.0)
const LOCKED := Color(0.22, 0.24, 0.24, 1.0)
const NODE_SIZE := 72.0
const GRID := 96.0
const TOOLTIP_OFFSET := Vector2(20, 18)
const TOOLTIP_MARGIN := 12.0

@onready var parts_label: Label = %PartsLabel
@onready var cap_label: Label = %CapLabel
@onready var hint_label: Label = %HintLabel
@onready var canvas: Control = %TreeCanvas
@onready var tooltip: PanelContainer = %Tooltip
@onready var tooltip_title: Label = %TooltipTitle
@onready var tooltip_kind: Label = %TooltipKind
@onready var tooltip_body: Label = %TooltipBody

var _buttons: Dictionary = {} ## StringName → Button
var _hovered: _SkillNodeDefinition = null
var _lines: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	set_process(false)
	tooltip.hide()
	canvas.draw.connect(_on_canvas_draw)
	MetaProgression.tree_changed.connect(_on_tree_changed)
	MetaProgression.rare_parts_changed.connect(_on_parts_changed)


func open() -> void:
	if visible:
		return
	show()
	set_process(true)
	call_deferred(&"_rebuild")


func close() -> void:
	if not visible:
		return
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


func _process(_delta: float) -> void:
	if _hovered:
		_position_tooltip()


func _on_tree_changed() -> void:
	if visible:
		_rebuild()


func _on_parts_changed(_total: int) -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	_clear_tooltip()
	while canvas.get_child_count() > 0:
		var child := canvas.get_child(0)
		canvas.remove_child(child)
		child.free()
	_buttons.clear()
	_lines = PackedVector2Array()
	_refresh_header()
	var origin := canvas.size * 0.5
	if origin.x < 32.0 or origin.y < 32.0:
		var parent_size := (canvas.get_parent() as Control).size if canvas.get_parent() is Control else Vector2.ZERO
		origin = parent_size * 0.5
	if origin.x < 32.0 or origin.y < 32.0:
		origin = Vector2(640, 280)
	for node in _SkillTreeRegistry.list_definitions():
		var pos := origin + node.layout_offset * GRID
		if node.parent_id != &"":
			var parent: _SkillNodeDefinition = _SkillTreeRegistry.get_definition(node.parent_id)
			if parent:
				var parent_pos := origin + parent.layout_offset * GRID
				_lines.append(parent_pos)
				_lines.append(pos)
		var button := _make_node_button(node)
		button.position = pos - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
		canvas.add_child(button)
		_buttons[node.id] = button
	canvas.queue_redraw()


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


func _make_node_button(node: _SkillNodeDefinition) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state := _node_state(node)
	button.disabled = state == &"locked" or state == &"stub"
	_style_node_button(button, state)
	if node.icon:
		button.icon = node.icon
		button.expand_icon = true
		button.text = ""
	else:
		button.text = String(node.id).left(2).to_upper()
	button.mouse_entered.connect(_on_node_hovered.bind(node))
	button.mouse_exited.connect(_on_node_unhovered.bind(node))
	button.pressed.connect(_on_node_pressed.bind(node))
	return button


func _node_state(node: _SkillNodeDefinition) -> StringName:
	if MetaProgression.is_allocated(node.id):
		return &"live"
	if MetaProgression.is_pending(node.id):
		return &"pending"
	if node.is_stub():
		return &"stub"
	var check := MetaProgression.can_allocate(node.id)
	if check.get("ok", false):
		return &"open"
	if check.get("reason", "") == "locked":
		return &"locked"
	return &"open"


func _style_node_button(button: Button, state: StringName) -> void:
	var border := DIM
	var bg := Color(0.08, 0.09, 0.09, 1.0)
	match state:
		&"live":
			border = LIVE
			bg = Color(0.12, 0.18, 0.14, 1.0)
		&"pending":
			border = PENDING
			bg = Color(0.18, 0.14, 0.08, 1.0)
		&"open":
			border = ACCENT
			bg = Color(0.12, 0.14, 0.13, 1.0)
		&"stub":
			border = Color(0.55, 0.4, 0.7, 1.0)
			bg = Color(0.1, 0.08, 0.12, 1.0)
		&"locked":
			border = LOCKED
			bg = Color(0.06, 0.06, 0.06, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override(&"normal", style)
	button.add_theme_stylebox_override(&"disabled", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.08)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", hover)


func _on_canvas_draw() -> void:
	var i := 0
	while i + 1 < _lines.size():
		canvas.draw_line(_lines[i], _lines[i + 1], Color(0.35, 0.38, 0.36, 0.85), 3.0, true)
		i += 2


func _on_node_hovered(node: _SkillNodeDefinition) -> void:
	_hovered = node
	_show_tooltip(node)
	set_process(true)


func _on_node_unhovered(node: _SkillNodeDefinition) -> void:
	if _hovered == node:
		_clear_tooltip()


func _on_node_pressed(node: _SkillNodeDefinition) -> void:
	if node.is_stub():
		return
	if MetaProgression.is_allocated(node.id):
		return
	if MetaProgression.is_pending(node.id):
		MetaProgression.try_refund_pending(node.id)
		return
	MetaProgression.try_allocate(node.id)


func _show_tooltip(node: _SkillNodeDefinition) -> void:
	tooltip_title.text = node.display_name
	var state := _node_state(node)
	var kind := "LOCKED"
	match state:
		&"live":
			kind = "ACTIVE"
		&"pending":
			kind = "QUEUED — NEXT RUN"
			if GameSession.phase == GameSession.RunPhase.IDLE:
				kind = "QUEUED — APPLIES NOW"
		&"open":
			if GameSession.phase == GameSession.RunPhase.IDLE:
				kind = "REQUEST  ·  %d PART%s  ·  NOW" % [
					node.cost,
					"" if node.cost == 1 else "S",
				]
			else:
				kind = "REQUEST  ·  %d PART%s  ·  NEXT RUN" % [
					node.cost,
					"" if node.cost == 1 else "S",
				]
		&"stub":
			kind = "NOT WIRED YET"
		&"locked":
			var check := MetaProgression.can_allocate(node.id)
			match str(check.get("reason", "locked")):
				"cap":
					kind = "CAP REACHED"
				"insufficient_parts":
					kind = "NEED %d RARE PARTS" % int(check.get("cost", node.cost))
				_:
					kind = "LOCKED"
	tooltip_kind.text = kind
	tooltip_body.text = node.effect_summary()
	tooltip.show()
	_position_tooltip()


func _clear_tooltip() -> void:
	_hovered = null
	tooltip.hide()


func _position_tooltip() -> void:
	if not tooltip.visible:
		return
	var pos := get_global_mouse_position() + TOOLTIP_OFFSET
	var size := tooltip.get_combined_minimum_size()
	var view := get_viewport_rect().size
	pos.x = minf(pos.x, view.x - size.x - TOOLTIP_MARGIN)
	pos.y = minf(pos.y, view.y - size.y - TOOLTIP_MARGIN)
	tooltip.global_position = pos
