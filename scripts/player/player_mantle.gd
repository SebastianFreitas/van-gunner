extends RefCounted
## The player's mantles: the silent step over low edges and the timed climb onto ledges up to chest height.

## Highest ledge, above the feet, the climb can reach.
const CLIMB_MAX_RISE := 1.6
## Horizontal distances ahead of the capsule centre where a ledge is looked for.
const CLIMB_REACHES := [0.35, 0.55, 0.75, 1.0]
## How far past the ledge edge the player lands.
const LAND_AHEAD := 0.25
## Upward speed of the climb, m/s.
const RISE_SPEED := 4.0
## Seconds of the forward move over the ledge.
const OVER_TIME := 0.15
## Exponential rate (1/s) the head eases back up after a step.
const STEP_EASE := 12.0

var _player: FpsPlayer
var _head_base_y := 0.0
## How far the head is lowered below its rest height after a step, eased back to zero.
var _head_drop := 0.0
## World y of the feet the last frame the player was on the floor.
var _last_floor_y := 0.0
var _climbing := false
var _rising := false
var _t := 0.0
var _start := Vector3.ZERO
var _mid := Vector3.ZERO
var _landing_local := Vector3.ZERO


func _init(player: FpsPlayer) -> void:
	_player = player
	_head_base_y = player.head.position.y


## Snaps the player up a low edge in the walking direction; the camera eases up after.
func try_step(wish_direction: Vector3) -> bool:
	if not _player.is_on_floor():
		return false

	var direction := Vector3(wish_direction.x, 0.0, wish_direction.z)
	if direction.length_squared() < 0.01:
		return false
	direction = direction.normalized()

	var step_height := _player.step_height
	var step_check_distance := _player.step_check_distance
	var collision_mask := _player.collision_mask
	var space := _player.get_world_3d().direct_space_state
	var exclude := [_player.get_rid()]
	var origin := _player.global_position

	var foot := origin + Vector3.UP * 0.05
	var query := PhysicsRayQueryParameters3D.create(
		foot,
		foot + direction * step_check_distance
	)
	query.exclude = exclude
	query.collision_mask = collision_mask
	var low_hit := space.intersect_ray(query)
	if low_hit.is_empty():
		return false
	if low_hit.normal.y > 0.55:
		return false

	var head_pos := origin + Vector3.UP * (step_height + 0.05)
	query = PhysicsRayQueryParameters3D.create(
		head_pos,
		head_pos + direction * step_check_distance
	)
	query.exclude = exclude
	query.collision_mask = collision_mask
	if not space.intersect_ray(query).is_empty():
		return false

	var probe := head_pos + direction * step_check_distance
	query = PhysicsRayQueryParameters3D.create(
		probe,
		probe + Vector3.DOWN * (step_height + 0.1)
	)
	query.exclude = exclude
	query.collision_mask = collision_mask
	var floor_hit := space.intersect_ray(query)
	if floor_hit.is_empty():
		return false

	var rise: float = floor_hit.position.y - origin.y
	if rise <= 0.01 or rise > step_height:
		return false

	_player.global_position.y += rise
	_player.velocity.y = 0.0
	_head_drop = minf(_head_drop + rise, step_height)
	return true


## Eases the head back to its rest height; call once per physics frame.
func update_head(delta: float) -> void:
	_head_drop *= exp(-STEP_EASE * delta)
	if _head_drop < 0.002:
		_head_drop = 0.0
	_player.head.position.y = _head_base_y - _head_drop


## Remembers the feet height while on the floor, so an airborne mantle ignores the ground left.
func note_floor() -> void:
	_last_floor_y = _player.global_position.y


## Looks for a ledge ahead in the horizontal world direction the capsule fits on.
## Returns { "landing": Vector3 (world), "rise": float }, or {} when there is none.
func find_ledge(direction: Vector3) -> Dictionary:
	var space := _player.get_world_3d().direct_space_state
	var origin := _player.global_position
	var step_height := _player.step_height
	var shape_node := _player.get_node("CollisionShape3D") as CollisionShape3D
	var airborne := not _player.is_on_floor()
	# Mid-jump the feet may already be level with or above the ledge top.
	var min_rise := -0.3 if airborne else step_height
	var ray_bottom := -0.4 if airborne else step_height * 0.5
	for reach: float in CLIMB_REACHES:
		var column := origin + direction * reach
		var query := PhysicsRayQueryParameters3D.create(
			column + Vector3.UP * (CLIMB_MAX_RISE + 0.1),
			column + Vector3.UP * ray_bottom
		)
		query.exclude = [_player.get_rid()]
		query.collision_mask = _player.collision_mask
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		# Airborne, only a ledge clearly above the floor the player left counts.
		if airborne and hit.position.y <= _last_floor_y + step_height:
			continue
		var rise: float = hit.position.y - origin.y
		if rise <= min_rise or rise > CLIMB_MAX_RISE:
			continue
		# 0.12 up keeps the capsule clear of a ramp slope or deck lip under the landing.
		var landing: Vector3 = hit.position + direction * LAND_AHEAD + Vector3.UP * 0.12
		var shape_query := PhysicsShapeQueryParameters3D.new()
		shape_query.shape = shape_node.shape
		var basis := _player.global_basis
		shape_query.transform = Transform3D(basis, landing + basis * shape_node.position)
		shape_query.collision_mask = _player.collision_mask
		shape_query.exclude = [_player.get_rid()]
		if not space.intersect_shape(shape_query, 1).is_empty():
			continue
		if _player.test_move(_player.global_transform, Vector3.UP * (maxf(rise, 0.0) + 0.04)):
			continue
		return {"landing": landing, "rise": rise}
	return {}


## Starts the climb onto the ledge the player faces; false when there is none.
func try_climb() -> bool:
	var direction := -_player.global_basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return false
	direction = direction.normalized()
	var ledge := find_ledge(direction)
	if ledge.is_empty():
		return false
	var landing_world: Vector3 = ledge["landing"]
	var parent := _player.get_parent_node_3d()
	_landing_local = parent.to_local(landing_world) if parent else landing_world
	_start = _player.position
	_mid = Vector3(_start.x, _landing_local.y, _start.z)
	_climbing = true
	_rising = true
	_t = 0.0
	_player.velocity = Vector3.ZERO
	_player.mantle_started.emit(float(ledge["rise"]), landing_world)
	return true


func is_climbing() -> bool:
	return _climbing


## Advances the climb along start, mid, landing; sets the position directly.
func step_climb(delta: float) -> void:
	if not _climbing:
		return
	if _rising:
		_player.position = _player.position.move_toward(_mid, RISE_SPEED * delta)
		if _player.position.is_equal_approx(_mid):
			_rising = false
			_t = 0.0
		return
	_t += delta
	var k := smoothstep(0.0, 1.0, clampf(_t / OVER_TIME, 0.0, 1.0))
	_player.position = _mid.lerp(_landing_local, k)
	if _t >= OVER_TIME:
		_player.position = _landing_local
		_climbing = false
		_player.velocity = Vector3.ZERO
		_player.mantle_finished.emit()
