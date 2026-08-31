class_name BenchScreen
extends Control

## Crafting bench overlay: character/van stats on the left, owned items on the
## right. Hovering an item icon shows what it actually does.

signal closed

const ACCENT := Color(0.91, 0.78, 0.48, 1.0)
const MUTED := Color(0.62, 0.66, 0.64, 1.0)
const DIM := Color(0.45, 0.48, 0.47, 1.0)
const CELL_SIZE := Vector2(94, 88)
const GRID_COLUMNS := 5
const TOOLTIP_OFFSET := Vector2(20, 18)
const TOOLTIP_MARGIN := 12.0

@onready var stats_primary: VBoxContainer = %StatsPrimary
@onready var stats_secondary: VBoxContainer = %StatsSecondary
@onready var items_column: VBoxContainer = %ItemsColumn
@onready var tooltip: PanelContainer = %Tooltip
@onready var tooltip_title: Label = %TooltipTitle
@onready var tooltip_kind: Label = %TooltipKind
@onready var tooltip_body: Label = %TooltipBody

var _player: FpsPlayer
var _usables: UsablesController
var _gun_stats: GunStatsController
var _weapon: GunController
var _hovered_item: ItemDefinition
var _stats_target: VBoxContainer


func _ready() -> void:
	set_process(false)
	tooltip.hide()


func bind(
	player: FpsPlayer,
	usables: UsablesController,
	gun_stats: GunStatsController,
	weapon: GunController
) -> void:
	_player = player
	_usables = usables
	_gun_stats = gun_stats
	_weapon = weapon
	if _gun_stats:
		_gun_stats.stats_changed.connect(_refresh_stats)
	if _weapon:
		_weapon.ammo_changed.connect(_on_ammo_changed)
	if _usables:
		_usables.slots_changed.connect(_refresh_items)
		_usables.boons_changed.connect(_refresh_items)
	GameSession.van_health_changed.connect(_on_van_health_changed)
	GameSession.coins_changed.connect(_on_coins_changed)
	GameSession.wave_changed.connect(_on_wave_changed)


func open() -> void:
	if visible:
		return
	show()
	set_process(true)
	_refresh_stats()
	_refresh_items()


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
	if _hovered_item:
		_position_tooltip()


# --- stats -------------------------------------------------------------------


func _refresh_stats() -> void:
	if not visible:
		return
	_clear(stats_primary)
	_clear(stats_secondary)
	_stats_target = stats_primary

	_add_section("GUNNER")
	if _player:
		_add_row("Move speed", "%s m/s" % ItemDescriber.format_number(_player.move_speed))
		_add_row("Acceleration", ItemDescriber.format_number(_player.acceleration))
	var boon_count := _usables.get_boons().size() if _usables else 0
	var slot_count := _usables.get_slots().size() if _usables else 0
	_add_row("Boons held", str(boon_count))
	_add_row("Hotbar slots", "%d / %d" % [slot_count, UsablesController.MAX_SLOTS])

	_add_section("VAN")
	_add_row(
		"Hull",
		"%d / %d" % [roundi(GameSession.van_health), roundi(GameSession.get_max_van_health())]
	)
	_add_health_bar()
	_add_row("Coins", str(GameSession.coins))
	_add_row("Waves cleared", str(GameSession.wave_count))
	_add_row("Forks taken", str(GameSession.route_step))
	_add_row("Last turn", String(GameSession.last_direction).capitalize())
	_add_row("Room", String(GameSession.current_room).capitalize())
	_add_row(
		"Phase",
		String(GameSession.RunPhase.keys()[GameSession.phase]).replace("_", " ").capitalize()
	)

	_stats_target = stats_secondary
	var stats := _gun_stats.get_stats() if _gun_stats else null
	if stats:
		_add_section("GUN")
		_add_row("Damage", ItemDescriber.format_number(stats.damage_per_shot))
		_add_row("Fire rate", "%s shots/s" % ItemDescriber.format_number(stats.fire_rate))
		_add_row(
			"Damage per second",
			ItemDescriber.format_number(stats.damage_per_shot * stats.fire_rate)
		)
		_add_row("Damage type", ItemDescriber.damage_type_name(stats.damage_type))
		var ammo := _weapon.get_current_ammo() if _weapon else stats.mag_size
		_add_row("Magazine", "%d / %d" % [ammo, stats.mag_size])
		_add_row("Reload time", "%ss" % ItemDescriber.format_number(stats.reload_speed))
		_add_row("Range", "%sm" % ItemDescriber.format_number(stats.aim_range))
		_add_row("Bullet speed", "%s m/s" % ItemDescriber.format_number(stats.bullet_speed))
		_add_row("Bullet size", ItemDescriber.format_number(stats.bullet_size))
		_add_row("Bullet weight", ItemDescriber.format_number(stats.bullet_weight))
		_add_row("Blast radius", "%sm" % ItemDescriber.format_number(stats.explosion_radius))

		_add_section("RICOCHET")
		_add_row("Bounces", str(stats.max_bounces))
		_add_row(
			"Speed kept per bounce",
			"%s%%" % ItemDescriber.format_number(stats.bounce_speed_retention * 100.0)
		)
		_add_row(
			"Damage kept per bounce",
			"%s%%" % ItemDescriber.format_number(stats.bounce_damage_retention * 100.0)
		)


func _add_section(title: String) -> void:
	if _stats_target.get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_target.add_child(spacer)
	var label := Label.new()
	label.text = title
	label.add_theme_color_override(&"font_color", ACCENT)
	label.add_theme_font_size_override(&"font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_target.add_child(label)
	_stats_target.add_child(HSeparator.new())


func _add_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override(&"font_color", MUTED)
	name_label.add_theme_font_size_override(&"font_size", 14)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var value_label := Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override(&"font_size", 14)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	row.add_child(value_label)
	_stats_target.add_child(row)


func _add_health_bar() -> void:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.max_value = GameSession.get_max_van_health()
	bar.value = GameSession.van_health
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_target.add_child(bar)


# --- items -------------------------------------------------------------------


func _refresh_items() -> void:
	if not visible:
		return
	_clear_tooltip()
	_clear(items_column)

	var total := 0
	total += _add_item_section("BOONS", "Permanent run buffs", _boon_entries())
	total += _add_item_section("TOOLS", "Hotbar, keys 1-4", _slot_entries())
	total += _add_item_section("ON THE BENCH", "Walk into a drop to take it", _stash_entries())
	if total == 0:
		var empty := Label.new()
		empty.text = "Nothing collected yet. Shoot loot to send it to the bench."
		empty.add_theme_color_override(&"font_color", MUTED)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		items_column.add_child(empty)


func _add_item_section(title: String, subtitle: String, entries: Array[Dictionary]) -> int:
	if entries.is_empty():
		return 0
	if items_column.get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		items_column.add_child(spacer)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_label := Label.new()
	title_label.text = "%s  (%d)" % [title, entries.size()]
	title_label.add_theme_color_override(&"font_color", ACCENT)
	title_label.add_theme_font_size_override(&"font_size", 13)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.add_theme_color_override(&"font_color", DIM)
	subtitle_label.add_theme_font_size_override(&"font_size", 11)
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_label)
	header.add_child(subtitle_label)
	items_column.add_child(header)
	items_column.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	items_column.add_child(grid)
	for entry in entries:
		grid.add_child(_make_cell(entry))
	return entries.size()


func _boon_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not _usables:
		return entries
	for boon in _usables.get_boons():
		if boon:
			entries.append({"item": boon, "badge": "", "status": "Active", "ready": true})
	return entries


func _slot_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not _usables:
		return entries
	var slots := _usables.get_slots()
	for index in range(slots.size()):
		var state := slots[index]
		if not state or not state.definition:
			continue
		var status := "Ready — press %d" % (index + 1)
		if state.charges <= 0:
			status = "Out of charges"
		elif state.cooldown_remaining > 0.0:
			status = "Cooling down %ss" % ItemDescriber.format_number(state.cooldown_remaining)
		entries.append({
			"item": state.definition,
			"badge": "%d·x%d" % [index + 1, state.charges],
			"status": status,
			"ready": state.is_ready(),
		})
	return entries


func _stash_entries() -> Array[Dictionary]:
	var counts: Dictionary = {}
	var order: Array[ItemDefinition] = []
	for node in get_tree().get_nodes_in_group(&"pickup"):
		var pickup := node as Pickup
		if not pickup or not pickup.item or not pickup._stashed or pickup._used:
			continue
		if counts.has(pickup.item.id):
			counts[pickup.item.id] += 1
		else:
			counts[pickup.item.id] = 1
			order.append(pickup.item)
	var entries: Array[Dictionary] = []
	for item in order:
		var count: int = counts[item.id]
		entries.append({
			"item": item,
			"badge": "x%d" % count if count > 1 else "",
			"status": "Waiting on the bench",
			"ready": true,
		})
	return entries


func _make_cell(entry: Dictionary) -> Control:
	var item: ItemDefinition = entry["item"]
	var is_ready: bool = entry.get("ready", true)

	var cell := PanelContainer.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.add_theme_stylebox_override(&"panel", _cell_style(is_ready))
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
	name_label.add_theme_color_override(&"font_color", MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)

	var badge_text: String = entry.get("badge", "")
	if not badge_text.is_empty():
		var badge := Label.new()
		badge.text = badge_text
		badge.add_theme_font_size_override(&"font_size", 10)
		badge.add_theme_color_override(&"font_color", ACCENT)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(badge)

	cell.mouse_entered.connect(_on_cell_entered.bind(entry))
	cell.mouse_exited.connect(_on_cell_exited.bind(item))
	return cell


func _cell_style(is_ready: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.11, 0.92)
	style.border_color = ACCENT if is_ready else Color(0.45, 0.48, 0.47, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_top = 5
	style.content_margin_right = 6
	style.content_margin_bottom = 5
	return style


# --- tooltip -----------------------------------------------------------------


func _on_cell_entered(entry: Dictionary) -> void:
	var item: ItemDefinition = entry["item"]
	_hovered_item = item
	tooltip_title.text = item.display_name
	var kind_line := ItemDescriber.kind_name(item.kind)
	var status: String = entry.get("status", "")
	if not status.is_empty():
		kind_line += "  ·  " + status
	tooltip_kind.text = kind_line

	var blocks := PackedStringArray()
	if not item.description.strip_edges().is_empty():
		blocks.append(item.description.strip_edges())
	var effects := ItemDescriber.effect_lines(item)
	if not effects.is_empty():
		blocks.append("\n".join(_bulleted(effects)))
	var usage := ItemDescriber.usage_lines(item)
	if not usage.is_empty():
		blocks.append("\n".join(_bulleted(usage)))
	if blocks.is_empty():
		blocks.append("No described effects.")
	tooltip_body.text = "\n\n".join(blocks)

	tooltip.show()
	tooltip.reset_size()
	_position_tooltip()


func _on_cell_exited(item: ItemDefinition) -> void:
	if _hovered_item == item:
		_clear_tooltip()


func _clear_tooltip() -> void:
	_hovered_item = null
	tooltip.hide()


func _position_tooltip() -> void:
	var bounds := get_viewport_rect().size
	var target := get_global_mouse_position() + TOOLTIP_OFFSET
	target.x = minf(target.x, bounds.x - tooltip.size.x - TOOLTIP_MARGIN)
	target.y = minf(target.y, bounds.y - tooltip.size.y - TOOLTIP_MARGIN)
	tooltip.global_position = target.max(Vector2(TOOLTIP_MARGIN, TOOLTIP_MARGIN))


func _bulleted(lines: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for line in lines:
		result.append("• " + line)
	return result


# --- signal plumbing ---------------------------------------------------------


func _on_ammo_changed(_current: int, _max_ammo: int) -> void:
	_refresh_stats()


func _on_van_health_changed(_current: float, _maximum: float) -> void:
	_refresh_stats()


func _on_coins_changed(_total: int) -> void:
	_refresh_stats()


func _on_wave_changed(_wave: int) -> void:
	_refresh_stats()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
