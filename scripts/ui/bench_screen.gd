class_name BenchScreen
extends Control

## Bench overlay: stats + gold spending on the left, boons and tools on the right.

signal closed

const _VanHealthBar := preload("res://scripts/ui/van_health_bar.gd")
const _BenchItemsGrid := preload("res://scripts/ui/bench_items_grid.gd")

const ACCENT := Color(0.91, 0.78, 0.48, 1.0)
const MUTED := Color(0.62, 0.66, 0.64, 1.0)
const DIM := Color(0.45, 0.48, 0.47, 1.0)
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
var _hovered_item: ItemDefinition
var _stats_target: VBoxContainer
var _items_grid: RefCounted


func _init() -> void:
	_items_grid = _BenchItemsGrid.new(self)


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
		_usables.slots_changed.connect(_items_grid.refresh_items)
		_usables.boons_changed.connect(_items_grid.refresh_items)
	GameSession.van_health_changed.connect(_on_van_health_changed)
	GameSession.coins_changed.connect(_on_coins_changed)
	GameSession.wave_changed.connect(_on_wave_changed)
	MetaProgression.van_speed_changed.connect(_on_meta_van_speed_changed)


func open() -> void:
	if visible:
		return
	show()
	set_process(true)
	_refresh_stats()
	_items_grid.refresh_items()


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
		_add_row("Class", _equipped_class_name())
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


func _equipped_class_name() -> String:
	if _player and _player.current_class:
		return _player.current_class.display_name
	return "Basic"


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
	var bar := _VanHealthBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_target.add_child(bar)


func _on_meta_van_speed_changed(_level: int, _speed: float) -> void:
	_refresh_stats()


func _clear_tooltip() -> void:
	_hovered_item = null
	tooltip.hide()


func _position_tooltip() -> void:
	var bounds := get_viewport_rect().size
	var target := get_global_mouse_position() + TOOLTIP_OFFSET
	target.x = minf(target.x, bounds.x - tooltip.size.x - TOOLTIP_MARGIN)
	target.y = minf(target.y, bounds.y - tooltip.size.y - TOOLTIP_MARGIN)
	tooltip.global_position = target.max(Vector2(TOOLTIP_MARGIN, TOOLTIP_MARGIN))


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
