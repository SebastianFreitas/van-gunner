extends RefCounted
## Owns a corridor tile's two facade sides: their openings, plans and built nodes. Rebuilds a
## side when its opening changes, and is the only place that turns plans into scene nodes, so
## every placer runs through the keep-out gate.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeBody := preload("res://scripts/travel/facades/facade_body.gd")
const _FacadeRegistry := preload("res://scripts/travel/facades/facade_registry.gd")
const _FacadePropsUpper := preload("res://scripts/travel/facades/facade_props_upper.gd")
const _FacadePropsGround := preload("res://scripts/travel/facades/facade_props_ground.gd")

const SIDE_NAMES: Array[String] = ["Left", "Right"]
const SIDE_SIGNS: Array[float] = [-1.0, 1.0]
const FACADES_NODE := "Facades"

var segment: Node3D
var seed := 0
var district := 0
var neighborhood_seed := 0
var allow_rare := false
var _configured := false
## Opening code per side (mirrors the tile's Opening enum: NONE, SIDE_STREET, BAY).
var _openings: Array[int] = [0, 0]
## The plan dictionaries actually built for each side (facade_plan.gd's output).
var _plans: Array = [[], []]
## Whether each side has ever been built; guards set_opening against a no-op rebuild.
var _built: Array[bool] = [false, false]
## Kept for later steps (props) and for describe().
var _keep_outs: Array = [null, null]


func _init(owner: Node3D) -> void:
	segment = owner


static func side_index(side: StringName) -> int:
	return 0 if side == &"left" else 1


func configure(seed_: int, district_: int, neighborhood_seed_: int, allow_rare_: bool) -> bool:
	seed = seed_
	district = district_
	neighborhood_seed = neighborhood_seed_
	allow_rare = allow_rare_
	_configured = true
	rebuild_side(0)
	rebuild_side(1)
	return false


func set_opening(side_idx: int, opening: int) -> void:
	if _openings[side_idx] == opening and _built[side_idx]:
		return
	_openings[side_idx] = opening
	if _configured:
		rebuild_side(side_idx)


func opening(side_idx: int) -> int:
	return _openings[side_idx]


func plans(side_idx: int) -> Array:
	return _plans[side_idx]


func facade_root(side_idx: int) -> Node3D:
	var facades := _facades_host()
	return facades.get_node_or_null(SIDE_NAMES[side_idx]) as Node3D


func rebuild_side(side_idx: int) -> void:
	var facades := _facades_host()
	var old := facades.get_node_or_null(SIDE_NAMES[side_idx])
	if old:
		# Rename first so the fresh node below can take the name this same frame.
		old.name = SIDE_NAMES[side_idx] + "Old"
		old.queue_free()
	var root := Node3D.new()
	root.name = SIDE_NAMES[side_idx]
	facades.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, side_idx])
	var keep_out := _FacadeKeepOut.new(SIDE_SIGNS[side_idx], _openings[side_idx])
	_keep_outs[side_idx] = keep_out
	var district_res: FacadeDistrict = _FacadeRegistry.district(district)
	var plans_out: Array[Dictionary] = _FacadePlan.plan_side(
		rng, district_res, _openings[side_idx], neighborhood_seed
	)
	_plans[side_idx] = plans_out
	for i in plans_out.size():
		_FacadeBody.build(root, plans_out[i], SIDE_SIGNS[side_idx], i)
		if plans_out[i].get(&"mouth", false):
			_FacadeBody.build_flank_collision(root, SIDE_SIGNS[side_idx])
		_FacadePropsUpper.build(
			root, plans_out[i], SIDE_SIGNS[side_idx], keep_out, rng, district_res
		)
		_FacadePropsGround.build(
			root, plans_out[i], SIDE_SIGNS[side_idx], keep_out, rng, district_res
		)
	_FacadePropsGround.build_fixtures(
		root, plans_out, SIDE_SIGNS[side_idx], keep_out, rng, district_res
	)
	for inst: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		# Fog ends at 56 m; tiles beyond that need not render.
		inst.visibility_range_end = 64.0
	root.set_meta(&"district", district)
	root.set_meta(&"opening", _openings[side_idx])
	_built[side_idx] = true


func describe() -> String:
	var lines: Array[String] = []
	for side_idx in SIDE_NAMES.size():
		var heights: Array[float] = []
		for plan: Dictionary in _plans[side_idx]:
			heights.append(float(plan.get(&"height", 0.0)))
		lines.append(
			"%s: opening=%d plans=%d heights=%s" % [
				SIDE_NAMES[side_idx], _openings[side_idx], _plans[side_idx].size(), heights
			]
		)
	return "\n".join(lines)


func _facades_host() -> Node3D:
	var facades := segment.get_node_or_null(FACADES_NODE) as Node3D
	if facades == null:
		facades = Node3D.new()
		facades.name = FACADES_NODE
		segment.add_child(facades)
	return facades
