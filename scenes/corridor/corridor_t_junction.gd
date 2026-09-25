extends Node3D

## Fills sidewalk corners where stem / branch / optional through-road meet the
## open junction slab. Trims adjoining sidewalk ends so corner returns own the
## mouth instead of fighting full-length curb end-caps. 4-ways add OutgoingRoad.

const CORNER_INSET := 0.9

const _FacadeSpans := preload("res://scripts/travel/facades/facade_spans.gd")
const _FacadeRegistry := preload("res://scripts/travel/facades/facade_registry.gd")

@onready var _junction: RoadFloor = $JunctionRoad
@onready var _stem: RoadFloor = $StemRoad
@onready var _branch_left: RoadFloor = $BranchLeftRoad
@onready var _branch_right: RoadFloor = $BranchRightRoad
@onready var _outgoing: RoadFloor = get_node_or_null("OutgoingRoad") as RoadFloor

var _facades_built := false


func _ready() -> void:
	_prepare_adjoining_trims()
	_build_corner_returns()
	call_deferred(&"_ensure_facades")


## Fallback for any instantiation that never calls configure directly; travel_world always does.
func _ensure_facades() -> void:
	if not _facades_built:
		configure(0, 0, 0)


## Builds the procedural facades on every stem / branch / outgoing wall and the corner towers.
## Idempotent: travel_world calls this once per spawn, and _ensure_facades is only a fallback.
func configure(seed_value: int, district: int, neighborhood_seed: int) -> void:
	if _facades_built:
		return
	var facades := Node3D.new()
	facades.name = "Facades"
	add_child(facades)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, &"junction"])
	var district_res: FacadeDistrict = _FacadeRegistry.district(district)
	_FacadeSpans.build_span(
		facades, "StemLeft", Vector3(-9.0, 0.0, 14.47), Vector3.RIGHT, 11.184,
		rng, district_res, neighborhood_seed
	)
	_FacadeSpans.build_span(
		facades, "StemRight", Vector3(9.0, 0.0, 14.52), Vector3.LEFT, 11.184,
		rng, district_res, neighborhood_seed
	)
	_FacadeSpans.build_span(
		facades, "BranchLeftNorth", Vector3(-14.5, 0.0, -9.0), Vector3.BACK, 11.172,
		rng, district_res, neighborhood_seed
	)
	_FacadeSpans.build_span(
		facades, "BranchLeftSouth", Vector3(-14.5, 0.0, 9.0), Vector3.FORWARD, 11.172,
		rng, district_res, neighborhood_seed
	)
	_FacadeSpans.build_span(
		facades, "BranchRightNorth", Vector3(14.5, 0.0, -9.0), Vector3.BACK, 11.172,
		rng, district_res, neighborhood_seed
	)
	_FacadeSpans.build_span(
		facades, "BranchRightSouth", Vector3(14.5, 0.0, 9.0), Vector3.FORWARD, 11.172,
		rng, district_res, neighborhood_seed
	)
	if _outgoing:
		_FacadeSpans.build_span(
			facades, "OutgoingLeft", Vector3(-9.0, 0.0, -14.47), Vector3.RIGHT, 11.184,
			rng, district_res, neighborhood_seed
		)
		_FacadeSpans.build_span(
			facades, "OutgoingRight", Vector3(9.0, 0.0, -14.52), Vector3.LEFT, 11.184,
			rng, district_res, neighborhood_seed
		)
	else:
		_FacadeSpans.build_span(
			facades, "FarWall", Vector3(0.0, 0.0, -9.0), Vector3.BACK, 18.0,
			rng, district_res, neighborhood_seed
		)
	_FacadeSpans.build_corner_tower(facades, "CornerNearLeft", Vector3(-9.0, 0.0, 9.0), 40.0)
	_FacadeSpans.build_corner_tower(facades, "CornerNearRight", Vector3(9.0, 0.0, 9.0), 40.0)
	_FacadeSpans.build_corner_tower(facades, "CornerFarLeft", Vector3(-9.0, 0.0, -9.0), 40.0)
	_FacadeSpans.build_corner_tower(facades, "CornerFarRight", Vector3(9.0, 0.0, -9.0), 40.0)
	_facades_built = true


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
