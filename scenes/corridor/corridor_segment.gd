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
var _tile_seed := 0
var _has_tile_seed := false
var _building := false


func _ready() -> void:
	_ensure_facades()
	_push_sidewalk_wreck()


func _ensure_facades() -> void:
	if _facades == null:
		_facades = _CorridorFacades.new(self)


## Call before add_child. Until end_build() the road floor is not built, so it is built once from
## its final seed, wreck spans and openings instead of once per configure / opening push.
func begin_build() -> void:
	_building = true
	var floor_node := get_node_or_null(^"RoadFloor") as RoadFloor
	if floor_node != null:
		floor_node.rebuild_on_ready = false
	# The branch floors are hidden unless a side street opens, so they build on demand instead.
	for path: NodePath in [^"SideStreets/Left/RoadFloor", ^"SideStreets/Right/RoadFloor"]:
		var branch_floor := get_node_or_null(path) as RoadFloor
		if branch_floor != null:
			branch_floor.rebuild_on_ready = false


## Builds the road floor once, after configure and apply_side_streets. Does nothing unless
## begin_build() ran.
func end_build() -> void:
	if not _building:
		return
	_building = false
	if _road_floor == null:
		return
	var left_open := _left_wall_collision.disabled
	var right_open := _right_wall_collision.disabled
	# Set directly: set_side_openings would build the floor before the wreck spans are in.
	_road_floor.sidewalk_left = not left_open
	_road_floor.sidewalk_right = not right_open
	_push_sidewalk_wreck()
	_sync_road_openings()


func configure(tile_seed: int, district_idx: int, neighborhood_seed: int, allow_rare: bool) -> bool:
	_ensure_facades()
	var has_rare := _facades.configure(
		tile_seed, clampi(district_idx, 0, DISTRICT_COUNT - 1), neighborhood_seed, allow_rare
	)
	_tile_seed = tile_seed
	_has_tile_seed = true
	_push_sidewalk_wreck()
	return has_rare


## The tile's build as ordered steps for a caller that spreads them over frames: run in order they
## equal configure() + apply_side_streets() + end_build(). on_rare gets configure()'s result.
func build_steps(
	tile_seed: int, district_idx: int, neighborhood_seed: int, allow_rare: bool,
	left: bool, right: bool, on_rare: Callable
) -> Array[Callable]:
	var steps: Array[Callable] = []
	steps.append(func() -> void:
		_ensure_facades()
		_facades.configure_begin(
			tile_seed, clampi(district_idx, 0, DISTRICT_COUNT - 1), neighborhood_seed, allow_rare
		)
		_facades.rebuild_side(0)
	)
	steps.append(func() -> void:
		_facades.rebuild_side(1)
	)
	steps.append(func() -> void:
		on_rare.call(_facades.configure_finish())
		_tile_seed = tile_seed
		_has_tile_seed = true
		apply_side_streets(left, right)
	)
	steps.append(func() -> void:
		# A floor that does not rebuild in end_build must not keep the flag.
		for floor_node: RoadFloor in _tile_floors():
			floor_node.defer_wreck = true
		end_build()
		for floor_node: RoadFloor in _tile_floors():
			floor_node.defer_wreck = false
	)
	# Main floor two sides, then each branch floor two sides; an entry with nothing pending is a no-op.
	for _i in 6:
		steps.append(_build_floor_wreck)
	return steps


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


func rare_id() -> StringName:
	return _facades.rare_id()


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
	# open_bay hides the branch right after this call, so skip building its facades for a bay
	# mouth — a one-off cost that would be wasted the instant the branch goes invisible.
	if (
		enabled and opening != Opening.BAY and side_street.has_method(&"configure")
		and not side_street.is_configured()
	):
		side_street.configure(
			hash([_facades.tile_seed, &"branch", idx]), _facades.district, _facades.neighborhood_seed
		)


func _sync_road_openings() -> void:
	if _road_floor == null or _building:
		return
	# Wall collision disabled means the side is open (side street or stop bay).
	# Drop sidewalk there so branch / bay road meets flush carriageway.
	var left_open := _left_wall_collision.disabled
	var right_open := _right_wall_collision.disabled
	_road_floor.set_side_openings(left_open, right_open)
	_sync_side_street_branch_trims(left_open, right_open)
	_build_side_street_corner_returns(left_open, right_open)
	_push_sidewalk_wreck()


## Hand the floor each side's building ruin spans (tile-local z; RoadFloor sits at the segment
## origin, unrotated) so the wrecked sidewalk matches the buildings beside it. Facade side 0
## (Left, built at x < 0) maps to the floor's left, side 1 (Right, x > 0) to its right.
func _push_sidewalk_wreck() -> void:
	if _road_floor == null or not _has_tile_seed or _building:
		return
	var spans: Array[Array] = [[], []]
	for side_idx in 2:
		var out: Array[Vector3] = []
		for plan: Dictionary in _facades.plans(side_idx):
			if plan.has(&"mouth") or not (
				plan.has(&"z0") and plan.has(&"z1") and plan.has(&"ruin")
			):
				continue
			out.append(Vector3(plan[&"z0"], plan[&"z1"], plan[&"ruin"]))
		spans[side_idx] = out
	var left: Array[Vector3] = []
	left.assign(spans[0])
	var right: Array[Vector3] = []
	right.assign(spans[1])
	_road_floor.set_sidewalk_wreck(_tile_seed, left, right)


func _sync_side_street_branch_trims(left_open: bool, right_open: bool) -> void:
	# Trim branch sidewalk ends at the corridor mouth so corner returns own it.
	# A hidden branch (closed, or a stop bay) keeps its floor unbuilt: nothing shows it.
	var left_road := _side_street_road(_side_street_left)
	if left_road != null and left_open and _side_street_left.visible:
		left_road.set_sidewalk_end_trims(0.0, SIDE_STREET_CORNER_INSET)
	var right_road := _side_street_road(_side_street_right)
	if right_road != null and right_open and _side_street_right.visible:
		right_road.set_sidewalk_end_trims(0.0, SIDE_STREET_CORNER_INSET)


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


## Lays one pending wreck side, from the first floor that has one.
func _build_floor_wreck() -> void:
	for floor_node: RoadFloor in _tile_floors():
		if floor_node.build_pending_wreck():
			return


func _tile_floors() -> Array[RoadFloor]:
	var floors: Array[RoadFloor] = []
	for floor_node: RoadFloor in [
		_road_floor, _side_street_road(_side_street_left), _side_street_road(_side_street_right)
	]:
		if floor_node != null:
			floors.append(floor_node)
	return floors


func _side_street_road(side_street: Node3D) -> RoadFloor:
	if side_street == null:
		return null
	return side_street.get_node_or_null("RoadFloor") as RoadFloor
