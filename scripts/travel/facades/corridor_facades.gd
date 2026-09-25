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
const _FacadeSigns := preload("res://scripts/travel/facades/facade_signs.gd")
const _FacadeFixtures := preload("res://scripts/travel/facades/facade_fixtures.gd")
const _FacadeSetPieces := preload("res://scripts/travel/facades/facade_set_pieces.gd")

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
## The rolled set-piece for this tile: piece + side_idx, or empty.
var _rare: Dictionary = {}
var _tile_rng_seed := 0
## The plan index within the rolled side's plans that the set-piece targets; set by rebuild_side.
var _rare_plan_index := -1


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
	var district_res: FacadeDistrict = _FacadeRegistry.district(district)
	var tile_rng := RandomNumberGenerator.new()
	tile_rng.seed = hash([seed, &"rare"])
	_tile_rng_seed = tile_rng.seed
	_rare = _FacadeSetPieces.roll(tile_rng, district_res, allow_rare, _openings)
	rebuild_side(0)
	rebuild_side(1)
	if not _rare.is_empty() and (_rare[&"piece"] as FacadeSetPiece).span:
		_build_span()
	return not _rare.is_empty()


func set_opening(side_idx: int, opening: int) -> void:
	if _openings[side_idx] == opening and _built[side_idx]:
		return
	# A bay or side street always wins over a rare: drop it (and any span) before the rebuild.
	var rare_piece: FacadeSetPiece = _rare.get(&"piece")
	if opening != 0 and rare_piece and (rare_piece.span or _rare[&"side_idx"] == side_idx):
		_rare = {}
		var span_root := _facades_host().get_node_or_null("Span")
		if span_root:
			span_root.queue_free()
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
	if _rare_targets(side_idx):
		var piece: FacadeSetPiece = _rare[&"piece"]
		if piece.can_apply(plans_out):
			var target := piece.pick_plan(plans_out, rng)
			piece.apply_plans(plans_out, rng)
			_rare_plan_index = target
		else:
			_rare = {}
	elif not _rare.is_empty() and (_rare[&"piece"] as FacadeSetPiece).id == &"power_outage":
		# power_outage is the one "atmosphere" piece that spans the tile without geometry: it
		# darkens both sides even though the roll only picked one side to "own" it.
		(_rare[&"piece"] as FacadeSetPiece).apply_plans(plans_out, rng)
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
		_FacadeSigns.build(
			root, plans_out[i], SIDE_SIGNS[side_idx], keep_out, rng, district_res
		)
	var force_dead := rare_id() == &"power_outage"
	_FacadeFixtures.build_fixtures(
		root, plans_out, SIDE_SIGNS[side_idx], keep_out, rng, district_res, force_dead
	)
	if _rare_targets(side_idx):
		(_rare[&"piece"] as FacadeSetPiece).build({
			&"host": root,
			&"plans": plans_out,
			&"side_sign": SIDE_SIGNS[side_idx],
			&"keep_out": keep_out,
			&"rng": rng,
			&"district": district_res,
			&"plan": plans_out[_rare_plan_index],
			&"tile_seed": seed,
		})
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
	if not _rare.is_empty():
		lines.append("rare=%s" % String(rare_id()))
	return "\n".join(lines)


func rare_id() -> StringName:
	if _rare.is_empty():
		return &""
	return (_rare[&"piece"] as FacadeSetPiece).id


## True when the rolled piece is a side piece targeting this open side.
func _rare_targets(side_idx: int) -> bool:
	if _rare.is_empty():
		return false
	var piece: FacadeSetPiece = _rare[&"piece"]
	return not piece.span and _rare[&"side_idx"] == side_idx and _openings[side_idx] == 0


## The rolled piece is a span: builds it under Facades/Span, spanning both sides at once.
func _build_span() -> void:
	var facades := _facades_host()
	var span_root := Node3D.new()
	span_root.name = "Span"
	facades.add_child(span_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, &"span"])
	var district_res: FacadeDistrict = _FacadeRegistry.district(district)
	var piece: FacadeSetPiece = _rare[&"piece"]
	piece.build({
		&"host": span_root,
		&"plans_left": _plans[0],
		&"plans_right": _plans[1],
		&"side_sign": 0.0,
		&"keep_out": _keep_outs[1],
		&"rng": rng,
		&"district": district_res,
		&"tile_seed": seed,
	})
	for inst: GeometryInstance3D in span_root.find_children("*", "GeometryInstance3D", true, false):
		inst.visibility_range_end = 64.0


func _facades_host() -> Node3D:
	var facades := segment.get_node_or_null(FACADES_NODE) as Node3D
	if facades == null:
		facades = Node3D.new()
		facades.name = FACADES_NODE
		segment.add_child(facades)
	return facades
