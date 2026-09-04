class_name BenchScreen
extends Control

## Bench overlay: stats + gold spending on the left, boons and tools on the right.

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
@onready var gold_label: Label = %GoldLabel
@onready var items_column: VBoxContainer = %ItemsColumn
@onready var tooltip: PanelContainer = %Tooltip
@onready var tooltip_title: Label = %TooltipTitle
@onready var tooltip_kind: Label = %TooltipKind
@onready var tooltip_body: Label = %TooltipBody

var _player: FpsPlayer
var _usables: UsablesController
var _gun_stats: GunStatsController
var _weapon: GunController
var _weapon_inventory: WeaponInventory
var _hovered_item: ItemDefinition
var _stats_target: VBoxContainer
var _page := 0 ## 0 overview, 1 weapons
var _selected_weapon_slot := 0
var _overview_body: Control
var _weapons_page: Control
var _tab_overview: Button
var _tab_weapons: Button
var _weapons_content: VBoxContainer


func _ready() -> void:
	set_process(false)
	tooltip.hide()
	_ensure_tabs()


func bind(
	player: FpsPlayer,
	usables: UsablesController,
	gun_stats: GunStatsController,
	weapon: GunController,
	weapon_inventory: WeaponInventory = null
) -> void:
	_player = player
	_usables = usables
	_gun_stats = gun_stats
	_weapon = weapon
	_weapon_inventory = weapon_inventory
	if _weapon_inventory == null and _player:
		_weapon_inventory = _player.get_node_or_null("WeaponInventory") as WeaponInventory
	if _gun_stats:
		_gun_stats.stats_changed.connect(_refresh_stats)
	if _weapon:
		_weapon.ammo_changed.connect(_on_ammo_changed)
	if _usables:
		_usables.slots_changed.connect(_refresh_items)
		_usables.boons_changed.connect(_refresh_items)
	if _weapon_inventory:
		_weapon_inventory.loadout_changed.connect(_refresh_weapons_page)
	GameSession.van_health_changed.connect(_on_van_health_changed)
	GameSession.coins_changed.connect(_on_coins_changed)
	GameSession.wave_changed.connect(_on_wave_changed)
	MetaProgression.van_speed_changed.connect(_on_meta_van_speed_changed)


func open() -> void:
	if visible:
		return
	show()
	set_process(true)
	_show_page(_page)
	_refresh_stats()
	_refresh_items()
	_refresh_weapons_page()


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


func _refresh_stats() -> void:
	if not visible:
		return
	gold_label.text = "%d GOLD" % GameSession.coins
	_clear(stats_primary)
	_clear(stats_secondary)
	_stats_target = stats_primary

	_add_section("VAN")
	_add_health_bar()
	_add_row(
		"Hull",
		"%d / %d" % [roundi(GameSession.van_health), roundi(GameSession.get_max_van_health())]
	)
	_add_row("Waves", str(GameSession.wave_count))
	_add_row("Act", str(GameBalance.get_act(GameSession.route_step)))

	_add_section("UPGRADES")
	_add_row("Van speed", "%s m/s" % ItemDescriber.format_number(MetaProgression.get_van_speed()))
	_add_row(
		"Speed level",
		"%d / %d" % [MetaProgression.van_speed_level, GameBalance.VAN_SPEED_MAX_LEVEL]
	)
	_add_upgrade_button()

	_stats_target = stats_secondary
	_add_section("GUNNER")
	if _player:
		_add_row("Move speed", "%s m/s" % ItemDescriber.format_number(_player.move_speed))
	var boon_count := _usables.get_boons().size() if _usables else 0
	var slot_count := _usables.get_slots().size() if _usables else 0
	_add_row("Boons", str(boon_count))
	_add_row("Tools", "%d / %d" % [slot_count, UsablesController.MAX_SLOTS])

	var stats := _gun_stats.get_stats() if _gun_stats else null
	if stats:
		_add_section("GUN")
		_add_row("Damage", ItemDescriber.format_number(stats.damage_per_shot))
		_add_row("Fire rate", "%s/s" % ItemDescriber.format_number(stats.fire_rate))
		_add_row("DPS", ItemDescriber.format_number(stats.damage_per_shot * stats.fire_rate))
		_add_row("Damage type", ItemDescriber.damage_type_name(stats.damage_type))
		var ammo := _weapon.get_current_ammo() if _weapon else stats.mag_size
		_add_row("Magazine", "%d / %d" % [ammo, stats.mag_size])
		_add_row("Reload", "%ss" % ItemDescriber.format_number(stats.reload_speed))
		_add_row("Range", "%sm" % ItemDescriber.format_number(stats.aim_range))
		_add_row("Bounces", str(stats.max_bounces))
		_add_row(
			"Bounce retention",
			"%s%% spd · %s%% dmg" % [
				ItemDescriber.format_number(stats.bounce_speed_retention * 100.0),
				ItemDescriber.format_number(stats.bounce_damage_retention * 100.0),
			]
		)


func _add_section(title: String) -> void:
	if _stats_target.get_child_count() > 0:
		_add_spacer(10)
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


func _add_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_target.add_child(spacer)


func _add_health_bar() -> void:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = GameSession.get_max_van_health()
	bar.value = GameSession.van_health
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_target.add_child(bar)


func _add_upgrade_button() -> void:
	if not MetaProgression.can_upgrade_van_speed():
		_add_row("Van speed", "Max")
		return

	var cost := MetaProgression.get_van_speed_upgrade_cost()
	var next_speed := GameBalance.get_van_speed_for_level(MetaProgression.van_speed_level + 1)
	var can_afford := GameSession.coins >= cost

	var button := Button.new()
	button.text = "Speed → %s m/s  ·  %d gold" % [
		ItemDescriber.format_number(next_speed),
		cost,
	]
	button.disabled = not can_afford
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 14)
	button.add_theme_color_override(&"font_color", ACCENT)
	button.add_theme_color_override(&"font_disabled_color", DIM)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.13, 1.0)
	style.border_color = ACCENT if can_afford else DIM
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	button.add_theme_stylebox_override(&"normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.18, 0.17, 1.0)
	button.add_theme_stylebox_override(&"hover", hover)
	var disabled := style.duplicate() as StyleBoxFlat
	disabled.border_color = DIM
	disabled.bg_color = Color(0.08, 0.09, 0.09, 1.0)
	button.add_theme_stylebox_override(&"disabled", disabled)
	button.pressed.connect(_on_van_speed_upgrade_pressed)
	_stats_target.add_child(button)


func _on_van_speed_upgrade_pressed() -> void:
	var result := MetaProgression.try_upgrade_van_speed(GameSession.coins)
	if not result.get("ok", false):
		return
	GameSession.spend_coins(int(result.get("cost", 0)))
	_refresh_stats()


func _on_meta_van_speed_changed(_level: int, _speed: float) -> void:
	_refresh_stats()


func _refresh_items() -> void:
	if not visible:
		return
	_clear_tooltip()
	_clear(items_column)

	var total := 0
	total += _add_item_section("BOONS", _boon_entries())
	total += _add_item_section("TOOLS", _slot_entries())
	if total == 0:
		var empty := Label.new()
		empty.text = "Nothing yet."
		empty.add_theme_color_override(&"font_color", MUTED)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		items_column.add_child(empty)


func _add_item_section(title: String, entries: Array[Dictionary]) -> int:
	if entries.is_empty():
		return 0
	if items_column.get_child_count() > 0:
		_add_spacer_to(items_column, 12)

	var title_label := Label.new()
	title_label.text = "%s  (%d)" % [title, entries.size()]
	title_label.add_theme_color_override(&"font_color", ACCENT)
	title_label.add_theme_font_size_override(&"font_size", 13)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_column.add_child(title_label)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	items_column.add_child(grid)
	for entry in entries:
		grid.add_child(_make_cell(entry))
	return entries.size()


func _add_spacer_to(container: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(spacer)


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


func _on_ammo_changed(_current: int, _max_ammo: int) -> void:
	_refresh_stats()


func _on_van_health_changed(_current: float, _maximum: float) -> void:
	_refresh_stats()


func _on_coins_changed(_total: int) -> void:
	_refresh_stats()
	_refresh_weapons_page()


func _on_wave_changed(_wave: int) -> void:
	_refresh_stats()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _ensure_tabs() -> void:
	var layout := get_node_or_null("Margin/Layout") as VBoxContainer
	var body := get_node_or_null("Margin/Layout/Body") as Control
	if layout == null or body == null:
		return
	_overview_body = body
	if layout.has_node("PageTabs"):
		_tab_overview = layout.get_node("PageTabs/OverviewTab") as Button
		_tab_weapons = layout.get_node("PageTabs/WeaponsTab") as Button
		_weapons_page = layout.get_node_or_null("WeaponsPage") as Control
		return

	var tabs := HBoxContainer.new()
	tabs.name = &"PageTabs"
	tabs.add_theme_constant_override(&"separation", 8)
	layout.add_child(tabs)
	layout.move_child(tabs, body.get_index())

	_tab_overview = Button.new()
	_tab_overview.name = &"OverviewTab"
	_tab_overview.text = "Overview"
	_tab_overview.focus_mode = Control.FOCUS_NONE
	_tab_overview.pressed.connect(func() -> void: _show_page(0))
	tabs.add_child(_tab_overview)

	_tab_weapons = Button.new()
	_tab_weapons.name = &"WeaponsTab"
	_tab_weapons.text = "Weapons"
	_tab_weapons.focus_mode = Control.FOCUS_NONE
	_tab_weapons.pressed.connect(func() -> void: _show_page(1))
	tabs.add_child(_tab_weapons)

	_weapons_page = ScrollContainer.new()
	_weapons_page.name = &"WeaponsPage"
	_weapons_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_weapons_page.visible = false
	layout.add_child(_weapons_page)

	_weapons_content = VBoxContainer.new()
	_weapons_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapons_content.add_theme_constant_override(&"separation", 12)
	_weapons_page.add_child(_weapons_content)


func _show_page(page: int) -> void:
	_page = page
	if _overview_body:
		_overview_body.visible = page == 0
	if _weapons_page:
		_weapons_page.visible = page == 1
	if _tab_overview:
		_tab_overview.disabled = page == 0
	if _tab_weapons:
		_tab_weapons.disabled = page == 1
	if page == 0:
		_refresh_stats()
		_refresh_items()
	else:
		_refresh_weapons_page()


func _refresh_weapons_page() -> void:
	if not visible or _page != 1 or _weapons_content == null:
		return
	gold_label.text = "%d GOLD" % GameSession.coins
	_clear(_weapons_content)

	if _weapon_inventory == null:
		var empty := Label.new()
		empty.text = "No weapon inventory."
		empty.add_theme_color_override(&"font_color", MUTED)
		_weapons_content.add_child(empty)
		return

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override(&"separation", 16)
	_weapons_content.add_child(slots_row)

	for i in 2:
		slots_row.add_child(_build_weapon_slot_card(i))

	var inst := _weapon_inventory.get_slot(_selected_weapon_slot) as WeaponInstance
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override(&"separation", 8)
	_weapons_content.add_child(detail)

	var detail_title := Label.new()
	detail_title.add_theme_color_override(&"font_color", ACCENT)
	detail_title.add_theme_font_size_override(&"font_size", 16)
	detail.add_child(detail_title)

	if inst == null:
		detail_title.text = "Empty — find a gun"
		return

	detail_title.text = "%s  ·  Lv %d  ·  %d mods" % [
		inst.display_name(), inst.weapon_level, inst.mods.size()
	]

	## Effective stats preview for selected gun (uses builder + active if selected).
	var preview: GunStats = WeaponStatsBuilder.build(inst)
	if _gun_stats and _weapon_inventory.active_index == _selected_weapon_slot:
		preview = _gun_stats.get_stats()
	_add_weapon_stat_lines(detail, preview, inst)

	var mods_title := Label.new()
	mods_title.text = "MODS"
	mods_title.add_theme_color_override(&"font_color", ACCENT)
	detail.add_child(mods_title)
	if inst.mods.is_empty():
		var none := Label.new()
		none.text = "No mods"
		none.add_theme_color_override(&"font_color", MUTED)
		detail.add_child(none)
	else:
		for mi in inst.mods.size():
			var mod: WeaponMod = inst.mods[mi]
			var row := HBoxContainer.new()
			var lab := Label.new()
			lab.text = mod.format_line()
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lab)
			var rem := Button.new()
			var rem_cost := WeaponPricing.craft_remove_cost(inst)
			rem.text = "Remove  %d g" % rem_cost
			rem.focus_mode = Control.FOCUS_NONE
			rem.disabled = GameSession.coins < rem_cost
			rem.pressed.connect(_on_remove_mod.bind(_selected_weapon_slot, mi))
			row.add_child(rem)
			detail.add_child(row)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 12)
	detail.add_child(actions)

	var add_cost := WeaponPricing.craft_add_cost(inst)
	var add_btn := Button.new()
	add_btn.text = "Add Random Mod  %d g" % add_cost
	add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.disabled = (
		not inst.can_add_mod()
		or GameSession.coins < add_cost
	)
	add_btn.pressed.connect(_on_add_mod.bind(_selected_weapon_slot))
	actions.add_child(add_btn)

	var destroy_btn := Button.new()
	destroy_btn.text = "Destroy Weapon"
	destroy_btn.focus_mode = Control.FOCUS_NONE
	destroy_btn.disabled = _weapon_inventory.occupied_count() <= 1
	destroy_btn.pressed.connect(_on_destroy_weapon.bind(_selected_weapon_slot))
	actions.add_child(destroy_btn)


func _build_weapon_slot_card(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 120)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.11, 1.0)
	style.border_color = ACCENT if index == _selected_weapon_slot else DIM
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override(&"panel", style)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var inst: WeaponInstance = null
	if _weapon_inventory:
		inst = _weapon_inventory.get_slot(index) as WeaponInstance
	var title := Label.new()
	title.text = "SLOT %s%s" % [
		"A" if index == 0 else "B",
		"  ·  ACTIVE" if _weapon_inventory and index == _weapon_inventory.active_index else "",
	]
	title.add_theme_color_override(&"font_color", ACCENT)
	vbox.add_child(title)
	var body := Label.new()
	if inst:
		body.text = "%s\n%d mods  ·  ammo %s" % [
			inst.display_name(),
			inst.mods.size(),
			str(inst.current_ammo) if inst.current_ammo >= 0 else "full",
		]
	else:
		body.text = "Empty — find a gun"
		body.add_theme_color_override(&"font_color", MUTED)
	vbox.add_child(body)

	var pick := Button.new()
	pick.text = "Select"
	pick.focus_mode = Control.FOCUS_NONE
	pick.disabled = inst == null and index != _selected_weapon_slot
	pick.pressed.connect(func() -> void:
		_selected_weapon_slot = index
		_refresh_weapons_page()
	)
	vbox.add_child(pick)
	return panel


func _add_weapon_stat_lines(parent: VBoxContainer, stats: GunStats, _inst: WeaponInstance) -> void:
	var lines := [
		"Fire rate  %s/s" % ItemDescriber.format_number(stats.fire_rate),
		"Damage  %s  (split across %d pellets)" % [
			ItemDescriber.format_number(stats.damage_per_shot),
			maxi(stats.pellets_per_shot, 1),
		],
		"Mag  %d  ·  Reload  %ss" % [
			stats.mag_size,
			ItemDescriber.format_number(stats.reload_speed),
		],
		"Type  %s  ·  Bounces  %d" % [
			ItemDescriber.damage_type_name(stats.damage_type),
			stats.max_bounces,
		],
	]
	for line in lines:
		var lab := Label.new()
		lab.text = line
		lab.add_theme_color_override(&"font_color", MUTED)
		parent.add_child(lab)


func _on_add_mod(slot_index: int) -> void:
	if _weapon_inventory == null:
		return
	var inst := _weapon_inventory.get_slot(slot_index) as WeaponInstance
	if inst == null or not inst.can_add_mod():
		return
	var cost := WeaponPricing.craft_add_cost(inst)
	if not GameSession.spend_coins(cost):
		return
	var rolled: WeaponMod = WeaponGenerator.roll_one_mod(inst)
	if rolled == null:
		GameSession.add_coins(cost)
		return
	inst.mods.append(rolled)
	inst.times_add_used += 1
	if _weapon_inventory.active_index == slot_index:
		_weapon_inventory.refresh_active_stats()
	_refresh_weapons_page()
	_refresh_stats()


func _on_remove_mod(slot_index: int, mod_index: int) -> void:
	if _weapon_inventory == null:
		return
	var inst := _weapon_inventory.get_slot(slot_index) as WeaponInstance
	if inst == null or mod_index < 0 or mod_index >= inst.mods.size():
		return
	var cost := WeaponPricing.craft_remove_cost(inst)
	if not GameSession.spend_coins(cost):
		return
	inst.mods.remove_at(mod_index)
	if _weapon_inventory.active_index == slot_index:
		_weapon_inventory.refresh_active_stats()
	_refresh_weapons_page()
	_refresh_stats()


func _on_destroy_weapon(slot_index: int) -> void:
	if _weapon_inventory == null:
		return
	if not _weapon_inventory.destroy_slot(slot_index):
		return
	_selected_weapon_slot = _weapon_inventory.active_index
	_refresh_weapons_page()
	_refresh_stats()
