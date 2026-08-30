extends Node

const DAMAGE_NUMBER_SCENE := preload("res://scenes/ui/damage_number.tscn")

var _layer: CanvasLayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 15
	_layer.name = "DamageNumbers"
	add_child(_layer)


func show_damage(
	world_position: Vector3,
	amount: float,
	is_headshot: bool,
	damage_type: DamageType.Type
) -> void:
	if amount <= 0.0 or _layer == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if camera.is_position_behind(world_position):
		return

	var popup := DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	_layer.add_child(popup)
	var screen_pos := camera.unproject_position(world_position)
	popup.position = screen_pos + Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 4.0))
	popup.setup(amount, is_headshot, damage_type)
