extends Node3D

const VARIANT_COUNT := 4
const SIDE_STREET_CORNER_INSET := 0.85

@onready var _variants: Array[Node3D] = [
	$Structure/Variant0,
	$Structure/Variant1,
	$Structure/Variant2,
	$Structure/Variant3,
]
@onready var _road_floor: RoadFloor = $RoadFloor
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
	_sync_road_openings()


## Open a wall gap for a shop bay without showing the cosmetic side street.
func open_shop_bay(side: StringName) -> void:
	_set_side_street(side, true)
	var side_street := _side_street_left if side == &"left" else _side_street_right
	side_street.visible = false
	_sync_road_openings()


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
	_set_side_structure_visible(side, not enabled)


func _sync_road_openings() -> void:
	if _road_floor == null:
		return
	# Wall collision disabled means the side is open (side street or shop bay).
	# Drop sidewalk there so branch / bay road meets flush carriageway.
	var left_open := _left_wall_collision.disabled
	var right_open := _right_wall_collision.disabled
	_road_floor.set_side_openings(left_open, right_open)
	_sync_side_street_branch_trims(left_open, right_open)
	_build_side_street_corner_returns(left_open, right_open)


func _sync_side_street_branch_trims(left_open: bool, right_open: bool) -> void:
	# Trim branch sidewalk ends at the corridor mouth so corner returns own it.
	var left_road := _side_street_road(_side_street_left)
	if left_road:
		if left_open:
			left_road.set_sidewalk_end_trims(0.0, SIDE_STREET_CORNER_INSET)
		else:
			left_road.set_sidewalk_end_trims(0.0, 0.0)
	var right_road := _side_street_road(_side_street_right)
	if right_road:
		if right_open:
			right_road.set_sidewalk_end_trims(0.0, SIDE_STREET_CORNER_INSET)
		else:
			right_road.set_sidewalk_end_trims(0.0, 0.0)


func _build_side_street_corner_returns(left_open: bool, right_open: bool) -> void:
	var existing := get_node_or_null("SideStreetCorners")
	if existing:
		remove_child(existing)
		existing.free()
	if not left_open and not right_open:
		return

	var host := Node3D.new()
	host.name = "SideStreetCorners"
	add_child(host)

	var main_w := _road_floor.sidewalk_width
	var outward := SIDE_STREET_CORNER_INSET + 0.08

	if left_open:
		var left_w := main_w
		var left_road := _side_street_road(_side_street_left)
		if left_road:
			left_w = left_road.sidewalk_width
		# Mouth corners on the open left edge (±Z).
		_road_floor.spawn_corner_return(host, -1.0, 1.0, main_w, left_w, "LeftPos", outward)
		_road_floor.spawn_corner_return(host, -1.0, -1.0, main_w, left_w, "LeftNeg", outward)

	if right_open:
		var right_w := main_w
		var right_road := _side_street_road(_side_street_right)
		if right_road:
			right_w = right_road.sidewalk_width
		_road_floor.spawn_corner_return(host, 1.0, 1.0, main_w, right_w, "RightPos", outward)
		_road_floor.spawn_corner_return(host, 1.0, -1.0, main_w, right_w, "RightNeg", outward)


func _side_street_road(side_street: Node3D) -> RoadFloor:
	if side_street == null:
		return null
	return side_street.get_node_or_null("RoadFloor") as RoadFloor


func _set_side_structure_visible(side: StringName, structure_visible: bool) -> void:
	for variant in _variants:
		for child in variant.get_children():
			if _is_side_structure_node(child.name, side):
				child.visible = structure_visible


func _is_side_structure_node(node_name: String, side: StringName) -> bool:
	if side == &"left":
		return (
			node_name.begins_with("Left")
			or node_name.begins_with("RibL")
			or node_name.begins_with("MainPipeLeft")
			or node_name.begins_with("ValveLeft")
			or node_name.begins_with("BraceLeft")
			or node_name.begins_with("BrokenLeft")
			or node_name == "CatwalkRailL"
		)
	return (
		node_name.begins_with("Right")
		or node_name.begins_with("RibR")
		or node_name.begins_with("MainPipeRight")
		or node_name.begins_with("ValveRight")
		or node_name.begins_with("BraceRight")
		or node_name.begins_with("BrokenRight")
		or node_name == "CatwalkRailR"
	)
