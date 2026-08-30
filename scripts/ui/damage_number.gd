class_name DamageNumber
extends Label

const HEADSHOT_COLOR := Color(1.0, 0.86, 0.28, 1.0)
const NORMAL_COLOR := Color(0.95, 0.92, 0.82, 1.0)


func setup(amount: float, is_headshot: bool, damage_type: DamageType.Type) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override(&"font_color", _color_for(damage_type, is_headshot))
	add_theme_color_override(&"font_shadow_color", Color(0.02, 0.02, 0.02, 0.95))
	add_theme_constant_override(&"shadow_offset_x", 2)
	add_theme_constant_override(&"shadow_offset_y", 2)
	add_theme_font_size_override(&"font_size", 30 if is_headshot else 22)
	text = _format_amount(amount)
	if is_headshot:
		text = "HS %s" % text
	custom_minimum_size = Vector2(80, 28)
	pivot_offset = custom_minimum_size * 0.5

	var start_y := position.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", start_y - 42.0, 0.55).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.18)
	tween.chain().tween_callback(queue_free)


func _format_amount(amount: float) -> String:
	if amount >= 10.0:
		return str(int(round(amount)))
	if amount >= 1.0:
		return str(snapped(amount, 0.1)).trim_suffix(".0")
	return "%.1f" % amount


func _color_for(damage_type: DamageType.Type, is_headshot: bool) -> Color:
	if is_headshot:
		return HEADSHOT_COLOR
	match damage_type:
		DamageType.Type.POISON:
			return Color(0.45, 0.95, 0.35, 1.0)
		DamageType.Type.FIRE:
			return Color(1.0, 0.5, 0.15, 1.0)
		DamageType.Type.COLD:
			return Color(0.55, 0.82, 1.0, 1.0)
		DamageType.Type.LIGHTNING:
			return Color(0.82, 0.72, 1.0, 1.0)
		DamageType.Type.EXPLOSIVE:
			return Color(1.0, 0.55, 0.22, 1.0)
	return NORMAL_COLOR
