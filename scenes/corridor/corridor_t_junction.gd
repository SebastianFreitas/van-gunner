extends Node3D

## Fills the blunt L where stem / branch sidewalks meet the open junction slab.

@onready var _junction: RoadFloor = $JunctionRoad
@onready var _stem: RoadFloor = $StemRoad
@onready var _branch_left: RoadFloor = $BranchLeftRoad
@onready var _branch_right: RoadFloor = $BranchRightRoad


func _ready() -> void:
	_build_corner_returns()


func _build_corner_returns() -> void:
	if _junction == null:
		return

	var existing := get_node_or_null("CornerReturns")
	if existing:
		existing.free()

	var host := Node3D.new()
	host.name = "CornerReturns"
	add_child(host)

	var stem_w := _stem.sidewalk_width if _stem else _junction.sidewalk_width
	var left_w := _branch_left.sidewalk_width if _branch_left else stem_w
	var right_w := _branch_right.sidewalk_width if _branch_right else stem_w

	# Near corners: stem sidewalk width along X, branch width along Z.
	_junction.spawn_corner_return(host, -1.0, 1.0, stem_w, left_w, "NearLeft")
	_junction.spawn_corner_return(host, 1.0, 1.0, stem_w, right_w, "NearRight")
	# Far corners: both arms match the branch sidewalks.
	_junction.spawn_corner_return(host, -1.0, -1.0, left_w, left_w, "FarLeft")
	_junction.spawn_corner_return(host, 1.0, -1.0, right_w, right_w, "FarRight")
