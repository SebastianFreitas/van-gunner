extends RefCounted
## Keep-out volumes for one facade side: the gate every facade placer passes an AABB through,
## so nothing ever stands in the raider lane, hangs over the road below 6 m, or sits in front of
## a stop-bay mouth.


const LANE_HALF_X := 7.6
const LANE_TOP_Y := 6.0
const MOUTH_NEAR_X := 6.0
const MOUTH_FAR_X := 15.0
const MOUTH_HALF_Z := 4.45
## Just under the bay header (facade_plan.BAY_HEADER_Y 7.9); the vestibule ceiling covers the
## opening above 7.8.
const MOUTH_TOP_Y := 7.85
## Props must also stay out of the space right above the mouth on the approach side.
const APPROACH_TOP_Y := 8.5
const APPROACH_FAR_X := 9.4
const MOUTH_SKY_TOP_Y := 9.5
const MOUTH_SKY_HALF_Z := 6.0
const FLANK_FAR_X := 60.0
const TILE_HALF_Z := 10.0
const BOTTOM_Y := -1.0
const TOP_Y := 60.0

## Opening codes mirror the tile's enum.
const OPENING_NONE := 0
const OPENING_SIDE_STREET := 1
const OPENING_BAY := 2

var side_sign := 1.0
var opening := 0
## What a building body must avoid.
var body_boxes: Array[AABB] = []
## What every prop, sign, light and set-piece must avoid; a superset of body_boxes.
var prop_boxes: Array[AABB] = []
## Parallel to prop_boxes (same order); conflict_name reports which one a placement hit.
var prop_names: Array[String] = []


func _init(side_sign_: float, opening_: int) -> void:
	side_sign = side_sign_
	opening = opening_
	body_boxes = body_boxes_for(side_sign_, opening_)
	prop_boxes = prop_boxes_for(side_sign_, opening_)
	prop_names = _prop_names_for(opening_)


static func lane_box() -> AABB:
	return AABB(
		Vector3(-LANE_HALF_X, BOTTOM_Y, -12.0),
		Vector3(LANE_HALF_X * 2.0, LANE_TOP_Y - BOTTOM_Y, 24.0)
	)


static func mouth_box(side_sign: float) -> AABB:
	return _side_box(side_sign, MOUTH_NEAR_X, MOUTH_FAR_X, BOTTOM_Y, MOUTH_TOP_Y, MOUTH_HALF_Z)


static func approach_box(side_sign: float) -> AABB:
	return _side_box(side_sign, MOUTH_NEAR_X, APPROACH_FAR_X, BOTTOM_Y, APPROACH_TOP_Y, TILE_HALF_Z)


static func mouth_sky_box(side_sign: float) -> AABB:
	return _side_box(
		side_sign, MOUTH_NEAR_X, APPROACH_FAR_X, APPROACH_TOP_Y, MOUTH_SKY_TOP_Y, MOUTH_SKY_HALF_Z
	)


static func flank_box(side_sign: float) -> AABB:
	return _side_box(side_sign, LANE_HALF_X, FLANK_FAR_X, BOTTOM_Y, TOP_Y, 12.0)


static func body_boxes_for(side_sign: float, opening: int) -> Array[AABB]:
	match opening:
		OPENING_BAY:
			return [lane_box(), mouth_box(side_sign)]
		OPENING_SIDE_STREET:
			return [lane_box(), flank_box(side_sign)]
		_:
			return [lane_box()]


static func prop_boxes_for(side_sign: float, opening: int) -> Array[AABB]:
	match opening:
		OPENING_BAY:
			return [
				lane_box(), mouth_box(side_sign), approach_box(side_sign), mouth_sky_box(side_sign)
			]
		OPENING_SIDE_STREET:
			return [lane_box(), flank_box(side_sign)]
		_:
			return [lane_box()]


static func _prop_names_for(opening: int) -> Array[String]:
	match opening:
		OPENING_BAY:
			return ["lane", "mouth", "approach", "mouth_sky"]
		OPENING_SIDE_STREET:
			return ["lane", "flank"]
		_:
			return ["lane"]


func allows(aabb: AABB) -> bool:
	for box: AABB in prop_boxes:
		if box.intersects(aabb):
			return false
	return true


func allows_body(aabb: AABB) -> bool:
	for box: AABB in body_boxes:
		if box.intersects(aabb):
			return false
	return true


func conflict_name(aabb: AABB) -> String:
	for i in prop_boxes.size():
		if prop_boxes[i].intersects(aabb):
			return prop_names[i]
	return ""


static func box_aabb(center: Vector3, size: Vector3, yaw: float = 0.0) -> AABB:
	var s := size.abs()
	if is_zero_approx(yaw):
		return AABB(center - s * 0.5, s)
	var half_x := s.x * 0.5
	var half_z := s.z * 0.5
	var corners: Array[Vector2] = [
		Vector2(half_x, half_z), Vector2(half_x, -half_z),
		Vector2(-half_x, half_z), Vector2(-half_x, -half_z),
	]
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for corner: Vector2 in corners:
		var rotated := corner.rotated(yaw)
		min_x = minf(min_x, rotated.x)
		max_x = maxf(max_x, rotated.x)
		min_z = minf(min_z, rotated.y)
		max_z = maxf(max_z, rotated.y)
	return AABB(
		Vector3(center.x + min_x, center.y - s.y * 0.5, center.z + min_z),
		Vector3(max_x - min_x, s.y, max_z - min_z)
	)


static func _side_box(
	side_sign: float, near_x: float, far_x: float, y0: float, y1: float, half_z: float
) -> AABB:
	var xa := near_x * side_sign
	var xb := far_x * side_sign
	var x_min := minf(xa, xb)
	var x_max := maxf(xa, xb)
	return AABB(
		Vector3(x_min, y0, -half_z),
		Vector3(x_max - x_min, y1 - y0, half_z * 2.0)
	)
