class_name EnemyHealthBar
extends Node3D

const BAR_WIDTH := 120
const BAR_HEIGHT := 14

var _fill: ColorRect
var _revealed := false


func _ready() -> void:
	visible = false
	position = Vector3(0, 1.52, 0)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.08, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	_fill = ColorRect.new()
	_fill.color = Color(0.85, 0.22, 0.18, 1.0)
	_fill.anchor_right = 1.0
	_fill.anchor_bottom = 1.0
	_fill.offset_left = 2.0
	_fill.offset_top = 2.0
	_fill.offset_right = -2.0
	_fill.offset_bottom = -2.0
	root.add_child(_fill)

	var sprite := Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.0065
	sprite.render_priority = 10
	add_child(sprite)


func update_ratio(ratio: float) -> void:
	if not _revealed:
		_revealed = true
		visible = true
	ratio = clampf(ratio, 0.0, 1.0)
	var inner_width := float(BAR_WIDTH - 4)
	_fill.offset_right = -2.0 - inner_width * (1.0 - ratio)
	if ratio > 0.5:
		_fill.color = Color(0.28, 0.82, 0.32).lerp(Color(0.92, 0.72, 0.18), (1.0 - ratio) * 2.0)
	else:
		_fill.color = Color(0.92, 0.72, 0.18).lerp(Color(0.85, 0.22, 0.18), (0.5 - ratio) * 2.0)
