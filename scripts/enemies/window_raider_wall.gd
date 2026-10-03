extends RefCounted

## Wall-grip maths for the window loper: launch, grip and cling points on the van skin and the per-frame jump/climb move.

## Loper origin when its feet stand on the road.
const ROAD_ORIGIN_Y := VanWheels.ROAD_Y + 1.62
## Origin height when it first latches on the wall (claws about 0.7 m under the floor).
const GRIP_Y := 0.9
## Origin height while clinging and waiting.
const CLING_Y := 1.2
## How far the body centre sits off the skin.
const BODY_DEPTH := 0.35
## Hull skin outside the wall profile (VanHull.SIDE_SKIN_OUTER_M).
const SKIN_OUT := 0.22
# Wall profile, mirroring the VanSideWall exports.
const WALL_HEIGHT := 3.08
const BOTTOM_HALF := 2.42
const TOP_HALF := 2.0
const BOW_OUT := 0.18
## Rear doors' outer face (4.71 + 0.22).
const REAR_SKIN_Z := 4.93
## Road points just outside OUTSIDE_KEEP_OUT.
const LAUNCH_SIDE_X := 4.3
const LAUNCH_REAR_Z := 6.2
## Behind the grown rear-leaf keep-out, where a run-up turns the corner.
const CORNER_Z := 8.2
const JUMP_TIME := 0.55
const JUMP_APEX := 0.7
const CLIMB_SPEED := 1.6
## Waiting spots on the walls; x holds only the side sign, the real x comes from side_point.
const CLING_SPOTS: Array[Vector3] = [
	Vector3(-1, CLING_Y, 4.2),
	Vector3(-1, CLING_Y, 1.23),
	Vector3(1, CLING_Y, 4.2),
	Vector3(1, CLING_Y, 1.23),
]

## Spot index -> raider instance id.
static var _cling_owners: Dictionary = {}

var raider: Node3D
var _from: Vector3
var _to: Vector3
var _t := 0.0
var _duration := 0.0
var _arc := 0.0
var done := true


func _init(owner: Node3D) -> void:
	raider = owner


static func skin_x_at(y: float) -> float:
	var t := clampf(y / WALL_HEIGHT, 0.0, 1.0)
	return lerpf(BOTTOM_HALF, TOP_HALF, t * t) + BOW_OUT * sin(PI * t) + SKIN_OUT


static func is_rear(marker_local: Vector3) -> bool:
	return marker_local.z > 4.5


## x uses the sprite centre, 0.66 m below the origin.
static func side_point(sign_x: float, origin_y: float, z: float) -> Vector3:
	return Vector3(signf(sign_x) * (skin_x_at(origin_y - 0.66) + BODY_DEPTH), origin_y, z)


static func grip_point(marker_local: Vector3) -> Vector3:
	if is_rear(marker_local):
		return Vector3(marker_local.x, GRIP_Y, REAR_SKIN_Z + BODY_DEPTH)
	return side_point(marker_local.x, GRIP_Y, marker_local.z)


static func launch_point(grip: Vector3) -> Vector3:
	if grip.z > 4.5:
		return Vector3(grip.x, ROAD_ORIGIN_Y, LAUNCH_REAR_Z)
	return Vector3(signf(grip.x) * LAUNCH_SIDE_X, ROAD_ORIGIN_Y, grip.z)


## Waypoints from `from` to a launch point. A raider behind the van running straight to a side
## launch point is pinned by the open rear-leaf keep-out, so it rounds the corner first.
static func approach_path(from: Vector3, launch: Vector3) -> Array[Vector3]:
	if launch.z > 4.5:
		return [launch]
	if from.z > 3.5 and absf(from.x) < LAUNCH_SIDE_X - 0.05:
		return [Vector3(signf(launch.x) * LAUNCH_SIDE_X, launch.y, maxf(from.z, CORNER_Z)), launch]
	return [launch]


static func cling_point(index: int) -> Vector3:
	return side_point(CLING_SPOTS[index].x, CLING_Y, CLING_SPOTS[index].z)


func claim_cling(near: Vector3) -> int:
	release_cling()
	for key: int in _cling_owners.keys():
		var other := instance_from_id(_cling_owners[key] as int)
		if other == null or other.is_queued_for_deletion():
			_cling_owners.erase(key)
	var best := -1
	var best_d := INF
	for i in CLING_SPOTS.size():
		if _cling_owners.has(i):
			continue
		var p := cling_point(i)
		var d := Vector2(p.x - near.x, p.z - near.z).length()
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_cling_owners[best] = raider.get_instance_id()
	return best


func release_cling() -> void:
	var id := raider.get_instance_id()
	for key: int in _cling_owners.keys():
		if _cling_owners[key] == id:
			_cling_owners.erase(key)


func start_jump(to: Vector3) -> void:
	_from = raider.position
	_to = to
	_t = 0.0
	_duration = JUMP_TIME
	_arc = JUMP_APEX
	done = false


func start_climb(to: Vector3) -> void:
	_from = raider.position
	_to = to
	_t = 0.0
	_duration = maxf(raider.position.distance_to(to) / CLIMB_SPEED, 0.05)
	_arc = 0.0
	done = false


func step(delta: float) -> void:
	if done:
		return
	_t = minf(_t + delta / _duration, 1.0)
	var p := _from.lerp(_to, _t)
	p.y += _arc * 4.0 * _t * (1.0 - _t)
	raider.position = p
	done = _t >= 1.0
