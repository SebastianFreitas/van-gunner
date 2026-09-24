extends RefCounted

## Builds skill tree node buttons and branch labels, tracks each node's
## unlock/allocation state and fills the hover tooltip's text.

const _SkillNodeDefinition := preload("res://scripts/meta/skill_node_definition.gd")
const _SkillTreeRegistry := preload("res://scripts/core/skill_tree_registry.gd")

const ACCENT := Color(0.91, 0.78, 0.48, 1.0)
const DIM := Color(0.45, 0.48, 0.47, 1.0)
const PENDING := Color(0.86, 0.58, 0.28, 1.0)
const LIVE := Color(0.52, 0.82, 0.62, 1.0)
const LOCKED := Color(0.22, 0.24, 0.24, 1.0)

var panel: Control  # the owning skill tree HUD; reads/writes its fields when called


func _init(owner: Control) -> void:
	panel = owner


func add_branch_label(text: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = panel.BRANCH_LABEL_SIZE
	label.size = panel.BRANCH_LABEL_SIZE
	label.add_theme_color_override(&"font_color", DIM)
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos - panel.BRANCH_LABEL_SIZE * 0.5
	panel.world.add_child(label)


func make_node_button(node: _SkillNodeDefinition) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(panel.NODE_SIZE, panel.NODE_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state := node_state(node)
	button.disabled = state == &"locked" or state == &"stub"
	style_node_button(button, state)
	if node.icon:
		button.icon = node.icon
		button.expand_icon = true
		button.text = ""
	else:
		button.text = String(node.id).left(2).to_upper()
	button.mouse_entered.connect(panel._on_node_hovered.bind(node))
	button.mouse_exited.connect(panel._on_node_unhovered.bind(node))
	button.pressed.connect(panel._on_node_pressed.bind(node))
	return button


func node_state(node: _SkillNodeDefinition) -> StringName:
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


func style_node_button(button: Button, state: StringName) -> void:
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


func content_rect() -> Rect2:
	var half := Vector2(panel.NODE_SIZE, panel.NODE_SIZE) * 0.5
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var any := false
	for node in _SkillTreeRegistry.list_definitions():
		var pos: Vector2 = node.layout_offset * panel.GRID
		min_p = min_p.min(pos - half)
		max_p = max_p.max(pos + half)
		any = true
	if not any:
		return Rect2()
	var label_half: Vector2 = panel.BRANCH_LABEL_SIZE * 0.5
	var speed_pos: Vector2 = panel.SPEED_LABEL_GRID * panel.GRID
	min_p = min_p.min(speed_pos - label_half)
	max_p = max_p.max(speed_pos + label_half)
	var hull_pos: Vector2 = panel.HULL_LABEL_GRID * panel.GRID
	min_p = min_p.min(hull_pos - label_half)
	max_p = max_p.max(hull_pos + label_half)
	return Rect2(min_p, max_p - min_p)


func show_tooltip(node: _SkillNodeDefinition) -> void:
	panel.tooltip_title.text = node.display_name
	var state := node_state(node)
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
	panel.tooltip_kind.text = kind
	panel.tooltip_body.text = node.effect_summary()
	panel.tooltip.show()
	panel._position_tooltip()
