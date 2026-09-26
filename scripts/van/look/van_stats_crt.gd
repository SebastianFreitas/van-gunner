class_name VanStatsCrt
extends Node3D
## A second PC-rig CRT stacked on the desk tower that prints live run stats (act and street, hull,
## gold and parts, gun) in green phosphor text, refreshed on the signals that change them.

var _label: Label3D
var _screen: ShaderMaterial
var _gun: Node


func _ready() -> void:
	var beige := MachineParts.dark(Color(0.42, 0.39, 0.32), 0.85)

	_screen = ShaderMaterial.new()
	_screen.shader = preload("res://scenes/van/crt_screen.gdshader")
	_screen.set_shader_parameter(&"text_amount", 0.0)
	_screen.set_shader_parameter(&"brightness", 0.35)

	var crt := MachineParts.crt(self, Vector3.ZERO, beige, _screen, 0.34)

	var screen_node := crt.get_node_or_null("Screen") as Node3D
	var label_parent: Node3D = screen_node if screen_node else crt
	# Top-left of the 0.272 x 0.204 screen quad, inset by a 0.02 margin, nudged 0.004 toward the
	# viewer along the +Z screen normal. When "Screen" is missing, fold in its own 0.061 offset.
	var label_pos := Vector3(-0.116, 0.082, 0.004 if screen_node else 0.065)

	_label = Label3D.new()
	_label.name = "Text"
	_label.layers = 2
	_label.font_size = 18
	_label.outline_size = 0
	_label.pixel_size = 0.00125
	_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_label.modulate = Color(0.35, 0.95, 0.45)
	_label.shaded = false
	_label.double_sided = false
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.width = 186.0
	_label.position = label_pos
	label_parent.add_child(_label)

	if not GameSession.phase_changed.is_connected(_on_phase):
		GameSession.phase_changed.connect(_on_phase)
	if not GameSession.coins_changed.is_connected(_on_count):
		GameSession.coins_changed.connect(_on_count)
	if not GameSession.van_health_changed.is_connected(_on_health):
		GameSession.van_health_changed.connect(_on_health)
	if not MetaProgression.rare_parts_changed.is_connected(_on_count):
		MetaProgression.rare_parts_changed.connect(_on_count)

	_bind_gun.call_deferred()
	_refresh()


## Looks up the GunStatsController the way GunController does (a group, since the player and its
## gun stats may not exist yet when this CRT is built).
func _bind_gun() -> void:
	var gun := get_tree().get_first_node_in_group(&"gun_stats")
	if gun and gun.has_signal(&"stats_changed"):
		if not gun.stats_changed.is_connected(_on_gun):
			gun.stats_changed.connect(_on_gun)
		_gun = gun
	_refresh()


func _on_phase(_phase: int) -> void:
	if _gun == null or not is_instance_valid(_gun):
		_bind_gun()
	_refresh()


func _on_count(_total: int) -> void:
	_refresh()


func _on_health(_current: float, _maximum: float) -> void:
	_refresh()


func _on_gun() -> void:
	_refresh()


func _refresh() -> void:
	var act := GameSession.run_act
	var total := GameSession.act_cards_total
	var street_str := "ST -/-" if total <= 0 else "ST %d/%d" % [GameSession.act_cards_resolved_count(), total]
	var hull := roundi(GameSession.van_health)
	var hull_max := roundi(GameSession.van_max_health)

	var gun_lines := "DMG --  RPS --\nMAG --  RLD --"
	if _gun != null and is_instance_valid(_gun):
		var controller := _gun as GunStatsController
		var stats := controller.get_stats()
		gun_lines = "DMG %.0f  RPS %.1f\nMAG %d  RLD %.1fs" % [
			stats.damage_per_shot, stats.fire_rate, stats.mag_size, stats.reload_speed,
		]

	_label.text = "ACT %d  %s\nHULL %d/%d\nGOLD %d  PARTS %d\n%s" % [
		act, street_str, hull, hull_max, GameSession.coins, MetaProgression.rare_parts, gun_lines,
	]


func _exit_tree() -> void:
	if GameSession.phase_changed.is_connected(_on_phase):
		GameSession.phase_changed.disconnect(_on_phase)
	if GameSession.coins_changed.is_connected(_on_count):
		GameSession.coins_changed.disconnect(_on_count)
	if GameSession.van_health_changed.is_connected(_on_health):
		GameSession.van_health_changed.disconnect(_on_health)
	if MetaProgression.rare_parts_changed.is_connected(_on_count):
		MetaProgression.rare_parts_changed.disconnect(_on_count)
	if _gun != null and is_instance_valid(_gun) and _gun.stats_changed.is_connected(_on_gun):
		_gun.stats_changed.disconnect(_on_gun)
