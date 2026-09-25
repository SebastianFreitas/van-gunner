extends Node3D
## A single corridor tile: road floor, wall collision, procedural facades on both sides, and the
## side-street / stop-bay openings that carve them.

enum Opening { NONE, SIDE_STREET, BAY }

const DISTRICT_COUNT := 5
const SIDE_STREET_CORNER_INSET := 0.85
const _CorridorFacades := preload("res://scripts/travel/facades/corridor_facades.gd")

@onready var _road_floor: RoadFloor = $RoadFloor
@onready var _left_wall_collision: CollisionShape3D = $Surfaces/LeftWallCollision
@onready var _right_wall_collision: CollisionShape3D = $Surfaces/RightWallCollision
@onready var _left_wall_upper_collision: CollisionShape3D = $Surfaces/LeftWallUpperCollision
@onready var _right_wall_upper_collision: CollisionShape3D = $Surfaces/RightWallUpperCollision
@onready var _side_street_left: Node3D = $SideStreets/Left
@onready var _side_street_right: Node3D = $SideStreets/Right

var _facades: _CorridorFacades


func _ready() -> void:
	_ensure_facades()


func _ensure_facades() -> void:
	if _facades == null:
		_facades = _CorridorFacades.new(self)


func configure(seed: int, district: int, neighborhood_seed: int, allow_rare: bool) -> bool:
	_ensure_facades()
	return _facades.configure(
		seed, clampi(district, 0, DISTRICT_COUNT - 1), neighborhood_seed, allow_rare
	)


func apply_side_streets(left: bool, right: bool) -> void:
	_set_side_street(&"left", left)
	_set_side_street(&"right", right)
	_sync_road_openings()


## Open a wall gap for a side-stop bay without showing the cosmetic side street.
func open_bay(side: StringName) -> void:
	_set_side_street(side, true, Opening.BAY)
	var side_street := _side_street_left if side == &"left" else _side_street_right
	side_street.visible = false
	_sync_road_openings()


## Elevator stops hide this tile's road so the pad can fall through a real hole.
func set_carriageway_visible(road_on: bool) -> void:
	if _road_floor == null:
		return
	if _road_floor.has_method(&"set_enabled"):
		_road_floor.set_enabled(road_on)
	else:
		_road_floor.visible = road_on


func opening_of(side: StringName) -> int:
	return _facades.opening(_CorridorFacades.side_index(side))


func facade_root(side: StringName) -> Node3D:
	return _facades.facade_root(_CorridorFacades.side_index(side))


func district() -> int:
	return _facades.district


func describe_facades() -> String:
	return _facades.describe()


func _set_side_street(side: StringName, enabled: bool, opening: int = -1) -> void:
	var is_left := side == &"left"
	var wall_collision := _left_wall_collision if is_left else _right_wall_collision
	var wall_upper_collision := (
		_left_wall_upper_collision if is_left else _right_wall_upper_collision
	)
	var side_street := _side_street_left if is_left else _side_street_right

	wall_collision.disabled = enabled
	wall_upper_collision.disabled = enabled
	side_street.visible = enabled
	_ensure_facades()
	var idx := _CorridorFacades.side_index(side)
	_facades.set_opening(
		idx, opening if opening >= 0 else (Opening.SIDE_STREET if enabled else Opening.NONE)
	)


func _sync_road_openings() -> void:
	if _road_floor == null:
		return
	# Wall collision disabled means the side is open (side street or stop bay).
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
