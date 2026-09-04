extends Node3D

## Fills the blunt L where stem / branch sidewalks meet the open junction slab.
## Trims adjoining sidewalk ends so corner returns own the mouth instead of
## fighting full-length curb end-caps.

const CORNER_INSET := 0.9

@onready var _junction: RoadFloor = $JunctionRoad
@onready var _stem: RoadFloor = $StemRoad
@onready var _branch_left: RoadFloor = $BranchLeftRoad
@onready var _branch_right: RoadFloor = $BranchRightRoad


func _ready() -> void:
	_prepare_adjoining_trims()
	_build_corner_returns()


func _prepare_adjoining_trims() -> void:
	# Child RoadFloors already built in their _ready — trim junction-facing ends
	# and rebuild so blunt curb caps don't sit on top of the corner pads.
	if _stem:
		# Stem sits at +Z; junction is toward local -Z.
		_stem.set_sidewalk_end_trims(0.0, CORNER_INSET)
	if _branch_left:
		# Branch local -Z faces the junction mouth (see branch transforms).
		_branch_left.set_sidewalk_end_trims(0.0, CORNER_INSET)
	if _branch_right:
		_branch_right.set_sidewalk_end_trims(0.0, CORNER_INSET)


func _build_corner_returns() -> void:
	if _junction == null:
		return

	var existing := get_node_or_null("CornerReturns")
	if existing:
		remove_child(existing)
		existing.free()

	var host := Node3D.new()
	host.name = "CornerReturns"
	add_child(host)

	var stem_w := _stem.sidewalk_width if _stem else _junction.sidewalk_width
	var left_w := _branch_left.sidewalk_width if _branch_left else stem_w
	var right_w := _branch_right.sidewalk_width if _branch_right else stem_w
	# Reach past the tile edge far enough to fill the trimmed mouth gap.
	var outward := CORNER_INSET + 0.08

	# Near corners: stem sidewalk width along X, branch width along Z.
	_junction.spawn_corner_return(host, -1.0, 1.0, stem_w, left_w, "NearLeft", outward)
	_junction.spawn_corner_return(host, 1.0, 1.0, stem_w, right_w, "NearRight", outward)
	# Far corners — small outward only (far wall sits on this edge).
	_junction.spawn_corner_return(host, -1.0, -1.0, left_w, left_w, "FarLeft", 0.12)
	_junction.spawn_corner_return(host, 1.0, -1.0, right_w, right_w, "FarRight", 0.12)
