extends RefCounted

## Builds the boons/tools item grid cells and their hover tooltips for BenchScreen.

const CELL_SIZE := Vector2(94, 88)
const GRID_COLUMNS := 5

var bench: Control  # the owning BenchScreen; reads/writes its fields when called


func _init(owner: Control) -> void:
	bench = owner


func refresh_items() -> void:
	if not bench.visible:
		return
	bench._clear_tooltip()
	bench._clear(bench.items_column)

	var total := 0
	total += add_item_section("BOONS", boon_entries())
	total += add_item_section("TOOLS", slot_entries())
	if total == 0:
		var empty := Label.new()
		empty.text = "Nothing yet."
		empty.add_theme_color_override(&"font_color", bench.MUTED)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bench.items_column.add_child(empty)


func add_item_section(title: String, entries: Array[Dictionary]) -> int:
	if entries.is_empty():
		return 0
	if bench.items_column.get_child_count() > 0:
		add_spacer_to(bench.items_column, 12)

	var title_label := Label.new()
	title_label.text = "%s  (%d)" % [title, entries.size()]
	title_label.add_theme_color_override(&"font_color", bench.ACCENT)
	title_label.add_theme_font_size_override(&"font_size", 13)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bench.items_column.add_child(title_label)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	bench.items_column.add_child(grid)
	for entry in entries:
		grid.add_child(make_cell(entry))
	return entries.size()


func add_spacer_to(container: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(spacer)


func boon_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not bench._usables:
		return entries
	for boon in bench._usables.get_boons():
		if boon:
			entries.append({"item": boon, "badge": "", "status": "Active", "ready": true})
	return entries


func slot_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not bench._usables:
		return entries
	var slots: Array[UsableState] = bench._usables.get_slots()
	for index in range(slots.size()):
		var state: UsableState = slots[index]
		if not state or not state.definition:
			continue
		var status := "Press %d" % (index + 1)
		if state.charges <= 0:
			status = "Empty"
		elif state.cooldown_remaining > 0.0:
			status = "%ss cooldown" % ItemDescriber.format_number(state.cooldown_remaining)
		entries.append({
			"item": state.definition,
			"badge": "%d·x%d" % [index + 1, state.charges],
			"status": status,
			"ready": state.is_ready(),
		})
	return entries


func make_cell(entry: Dictionary) -> Control:
	var item: ItemDefinition = entry["item"]
	var is_ready: bool = entry.get("ready", true)

	var cell := PanelContainer.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.add_theme_stylebox_override(&"panel", cell_style(is_ready))
	cell.modulate = Color.WHITE if is_ready else Color(0.6, 0.6, 0.6, 1.0)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override(&"separation", 2)
	cell.add_child(stack)

	if item.icon:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(0, 46)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(icon)
	else:
		var placeholder := Label.new()
		placeholder.text = item.display_name.substr(0, 2).to_upper()
		placeholder.custom_minimum_size = Vector2(0, 46)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(placeholder)

	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_size_override(&"font_size", 9)
	name_label.add_theme_color_override(&"font_color", bench.MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)

	var badge_text: String = entry.get("badge", "")
	if not badge_text.is_empty():
		var badge := Label.new()
		badge.text = badge_text
		badge.add_theme_font_size_override(&"font_size", 10)
		badge.add_theme_color_override(&"font_color", bench.ACCENT)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(badge)

	cell.mouse_entered.connect(on_cell_entered.bind(entry))
	cell.mouse_exited.connect(on_cell_exited.bind(item))
	return cell


func cell_style(is_ready: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.11, 0.92)
	style.border_color = bench.ACCENT if is_ready else Color(0.45, 0.48, 0.47, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_top = 5
	style.content_margin_right = 6
	style.content_margin_bottom = 5
	return style


func on_cell_entered(entry: Dictionary) -> void:
	var item: ItemDefinition = entry["item"]
	bench._hovered_item = item
	bench.tooltip_title.text = item.display_name
	var kind_line := ItemDescriber.kind_name(item.kind)
	var status: String = entry.get("status", "")
	if not status.is_empty():
		kind_line += "  ·  " + status
	bench.tooltip_kind.text = kind_line

	var blocks := PackedStringArray()
	if not item.description.strip_edges().is_empty():
		blocks.append(item.description.strip_edges())
	var effects := ItemDescriber.effect_lines(item)
	if not effects.is_empty():
		blocks.append("\n".join(bulleted(effects)))
	var usage := ItemDescriber.usage_lines(item)
	if not usage.is_empty():
		blocks.append("\n".join(bulleted(usage)))
	if blocks.is_empty():
		blocks.append("No described effects.")
	bench.tooltip_body.text = "\n\n".join(blocks)

	bench.tooltip.show()
	bench.tooltip.reset_size()
	bench._position_tooltip()


func on_cell_exited(item: ItemDefinition) -> void:
	if bench._hovered_item == item:
		bench._clear_tooltip()


func bulleted(lines: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for line in lines:
		result.append("• " + line)
	return result
