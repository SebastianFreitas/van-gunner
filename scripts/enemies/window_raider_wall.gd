extends RefCounted

## Wall-grip maths for the window loper: launch, grip and cling points on the van skin and the per-frame jump/climb move.

## Loper origin when its feet stand on the road.
const ROAD_ORIGIN_Y := VanWheels.ROAD_Y + 1.62
## Origin height when it first latches on the wall (claws about 0.7 m under the floor).
const GRIP_Y := 0.6
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
const LAUNCH_SIDE_X := 6.0
const LAUNCH_REAR_Z := 8.0
## Behind the grown rear-leaf keep-out, where a run-up turns the corner.
const CORNER_Z := 8.6
const JUMP_TIME := 0.8
const JUMP_APEX := 1.1
## Knocked out of a jump: gravity, sideways drift off the van, then the ground tumble slide.
const FALL_GRAVITY := 9.8
const FALL_DRIFT := 0.8
const TUMBLE_SLIDE := 1.5
const TUMBLE_TIME := 0.5
const CLIMB_SPEED := 1.0
## How far above the breach marker the loper grips the bars: its card then spans about
## y 0.5..2.4 at a side window (1.07..2.48), so it crawls about 1.5 m up from the grip.
const ATTACK_RISE := 0.5
## Waiting spots on the walls; x holds only the side sign, the real x comes from side_point.
const CLING_SPOTS: Array[Vector3] = [
	Vector3(-1, CLING_Y, 4.2),
	Vector3(-1, CLING_Y, 1.23),
	Vector3(1, CLING_Y, 4.2),
	Vector3(1, CLING_Y, 1.23),
]

## The body is freed once it is this many metres behind the van along +Z.
const BODY_KEEP_BEHIND := 40.0
## Spot index -> raider instance id.
static var _cling_owners: Dictionary = {}

var raider: Node3D
var _from: Vector3
var _to: Vector3
var _t := 0.0
var _duration := 0.0
var _arc := 0.0
var done := true
## True from the moment a knocked fall touches the road; the tumble slide runs after it.
var fall_landed := false
var _falling := false
var _fall_vy := 0.0
var _fall_drift := Vector3.ZERO
var _slide_t := 0.0
## True once the raider was shot dead on the wall: the body falls, then is left on the road.
var body_mode := false


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
	_falling = false
	fall_landed = false
	done = false


func start_climb(to: Vector3) -> void:
	_from = raider.position
	_to = to
	_t = 0.0
	_duration = maxf(raider.position.distance_to(to) / CLIMB_SPEED, 0.05)
	_arc = 0.0
	_falling = false
	fall_landed = false
	done = false


## Drops the raider from where it is (shot out of a jump), drifting off the van.
func start_fall() -> void:
	var height := maxf(raider.position.y - ROAD_ORIGIN_Y, 0.0)
	var fall_time := sqrt(2.0 * height / FALL_GRAVITY)
	var out := Vector3(signf(raider.position.x), 0.0, 0.0)
	if is_rear(raider.position):
		out = Vector3(0.0, 0.0, 1.0)
	_fall_drift = out * FALL_DRIFT / maxf(fall_time, 0.001)
	if height <= 0.0:
		_fall_drift = Vector3.ZERO
	_fall_vy = 0.0
	_slide_t = 0.0
	fall_landed = false
	_falling = true
	done = false


## Starts the fall of a raider shot dead on the wall (same drift, landing and short slide).
func start_death_fall() -> void:
	body_mode = true
	start_fall()


## Per-frame move of a dead body: the fall and slide, then it stays put on the road while the
## van drives on. True once it is BODY_KEEP_BEHIND behind the van and can be freed.
func step_body(delta: float, van_speed: float) -> bool:
	if (_falling or fall_landed) and not done:
		step(delta)
	if fall_landed:
		raider.position.z += van_speed * delta
	return raider.position.z > BODY_KEEP_BEHIND


func _step_fall(delta: float) -> void:
	var p := raider.position
	if _falling:
		_fall_vy -= FALL_GRAVITY * delta
		p += _fall_drift * delta
		p.y += _fall_vy * delta
		if p.y <= ROAD_ORIGIN_Y:
			p.y = ROAD_ORIGIN_Y
			_falling = false
			fall_landed = true
		raider.position = p
		return
	var slide := minf(delta, TUMBLE_TIME - _slide_t)
	_slide_t += slide
	p.z += TUMBLE_SLIDE * slide / TUMBLE_TIME
	p.y = ROAD_ORIGIN_Y
	raider.position = p
	done = _slide_t >= TUMBLE_TIME


func step(delta: float) -> void:
	if done:
		return
	if _falling or fall_landed:
		_step_fall(delta)
		return
	_t = minf(_t + delta / _duration, 1.0)
	var p := _from.lerp(_to, _t)
	p.y += _arc * 4.0 * _t * (1.0 - _t)
	raider.position = p
	done = _t >= 1.0
