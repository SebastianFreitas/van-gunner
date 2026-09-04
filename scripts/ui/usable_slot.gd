extends PanelContainer

@onready var icon_rect: TextureRect = %Icon
@onready var charges_label: Label = %Charges
@onready var cooldown_bar: ProgressBar = %Cooldown
@onready var slot_label: Label = %SlotIndex


func setup(state: UsableState, _is_active: bool, slot_index: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72, 72)
	var item := state.definition
	icon_rect.texture = item.icon if item else null
	charges_label.text = "x%s" % state.charges
	slot_label.text = str(slot_index + 1)
	cooldown_bar.max_value = 1.0
	var config := state.get_config()
	if config and config.recharge_cooldown_sec > 0.0 and state.cooldown_remaining > 0.0:
		cooldown_bar.value = 1.0 - state.cooldown_remaining / config.recharge_cooldown_sec
		cooldown_bar.visible = true
	else:
		cooldown_bar.visible = false
	modulate = Color.WHITE if state.is_ready() else Color(0.55, 0.55, 0.55, 1.0)
	add_theme_stylebox_override(&"panel", _slot_style(state.is_ready()))


func refresh(state: UsableState, is_active: bool, slot_index: int) -> void:
	setup(state, is_active, slot_index)


func _slot_style(is_ready: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.11, 0.92)
	style.border_color = Color(0.91, 0.78, 0.48, 0.95) if is_ready else Color(0.45, 0.48, 0.47, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	return style
