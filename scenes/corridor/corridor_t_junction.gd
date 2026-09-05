extends Node3D

## Fills sidewalk corners where stem / branch / optional through-road meet the
## open junction slab. Trims adjoining sidewalk ends so corner returns own the
## mouth instead of fighting full-length curb end-caps. 4-ways add OutgoingRoad.

const CORNER_INSET := 0.9

@onready var _junction: RoadFloor = $JunctionRoad
@onready var _stem: RoadFloor = $StemRoad
@onready var _branch_left: RoadFloor = $BranchLeftRoad
@onready var _branch_right: RoadFloor = $BranchRightRoad
@onready var _outgoing: RoadFloor = get_node_or_null("OutgoingRoad") as RoadFloor


func _ready() -> void:
	_prepare_adjoining_trims()
	_build_corner_returns()


func _prepare_adjoining_trims() -> void:
	# Child RoadFloors already built in their _ready — trim junction-facing ends
	# and rebuild so blunt curb caps don't sit on top of the corner pads.
	if _stem:
		# Stem sits at +Z; junction is toward local -Z.
		_stem.set_sidewalk_end_trims(0.0, CORNER_INSET)
	if _outgoing:
		# Outgoing sits at -Z; junction is toward local +Z.
		_outgoing.set_sidewalk_end_trims(CORNER_INSET, 0.0)
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
	var out_w := _outgoing.sidewalk_width if _outgoing else left_w
	# Reach past the tile edge far enough to fill the trimmed mouth gap.
	var outward := CORNER_INSET + 0.08
	# T far wall sits on the -Z edge; a 4-way needs a full mouth like the stem.
	var far_outward := outward if _outgoing else 0.12

	# Near corners: stem sidewalk width along X, branch width along Z.
	_junction.spawn_corner_return(host, -1.0, 1.0, stem_w, left_w, "NearLeft", outward)
	_junction.spawn_corner_return(host, 1.0, 1.0, stem_w, right_w, "NearRight", outward)
	_junction.spawn_corner_return(host, -1.0, -1.0, out_w, left_w, "FarLeft", far_outward)
	_junction.spawn_corner_return(host, 1.0, -1.0, out_w, right_w, "FarRight", far_outward)
