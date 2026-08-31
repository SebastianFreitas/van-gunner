extends Node3D

const VARIANT_COUNT := 4

@onready var _variants: Array[Node3D] = [
	$Structure/Variant0,
	$Structure/Variant1,
	$Structure/Variant2,
	$Structure/Variant3,
]
@onready var _left_wall: Node3D = $LeftWall
@onready var _right_wall: Node3D = $RightWall
@onready var _left_wall_upper: Node3D = $RightWall/LeftWall
@onready var _right_wall_upper: Node3D = $RightWall/RightWall
@onready var _left_wall_collision: CollisionShape3D = $Surfaces/LeftWallCollision
@onready var _right_wall_collision: CollisionShape3D = $Surfaces/RightWallCollision
@onready var _left_wall_upper_collision: CollisionShape3D = $Surfaces/LeftWallUpperCollision
@onready var _right_wall_upper_collision: CollisionShape3D = $Surfaces/RightWallUpperCollision
@onready var _side_street_left: Node3D = $SideStreets/Left
@onready var _side_street_right: Node3D = $SideStreets/Right


func apply_variant(index: int) -> void:
	index = clampi(index, 0, VARIANT_COUNT - 1)
	for variant_index in _variants.size():
		_variants[variant_index].visible = variant_index == index


func apply_side_streets(left: bool, right: bool) -> void:
	_set_side_street(&"left", left)
	_set_side_street(&"right", right)


func _set_side_street(side: StringName, enabled: bool) -> void:
	var is_left := side == &"left"
	var wall := _left_wall if is_left else _right_wall
	var wall_upper := _left_wall_upper if is_left else _right_wall_upper
	var wall_collision := _left_wall_collision if is_left else _right_wall_collision
	var wall_upper_collision := (
		_left_wall_upper_collision if is_left else _right_wall_upper_collision
	)
	var side_street := _side_street_left if is_left else _side_street_right

	wall.visible = not enabled
	wall_upper.visible = not enabled
	wall_collision.disabled = enabled
	wall_upper_collision.disabled = enabled
	side_street.visible = enabled
