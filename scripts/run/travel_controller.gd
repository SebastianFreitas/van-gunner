class_name TravelController
extends Node

enum TurnState {
	NONE,
	APPROACHING,
	TURNING,
	PARKING,
	LEAVING_SHOP,
}

const QUARTER_CIRCLE_HANDLE := 0.55228475
const SEGMENT_VARIANT_COUNT := 4
const NEIGHBORHOOD_MIN_LENGTH := 2
const NEIGHBORHOOD_MAX_LENGTH := 5
const SIDE_STREET_RUN_CHANCE := 0.26
const SIDE_STREET_RUN_MIN := 2
const SIDE_STREET_RUN_MAX := 4
const SIDE_STREET_START_SEGMENT := 4
const SHOP_SPAWN_MIN_SEGMENTS_AHEAD := 1
const SHOP_SPAWN_MAX_SEGMENTS_AHEAD := 2
const SHOP_PARK_LEAD_IN := 6.0

## Overwritten in _ready from MetaProgression → GameBalance van speed curve.
## Live value includes temporary driver boosts (raiders read this every frame).
@export var travel_speed := 8.0
@export var segment_scene: PackedScene
@export var t_junction_scene: PackedScene
@export var shop_scene: PackedScene
@export var segment_length := 20.0
@export var segment_ahead_distance := 80.0
@export var world_cull_distance := 140.0
@export var route_length := 10000.0
@export var intro_peace_seconds := 4.0
@export var intro_rest_seconds := 10.0
@export var junction_distance := 55.0
@export var junction_incoming_length := 20.0
@export var turn_radius := 10.0
@export var boost_multiplier := 1.75
@export var boost_duration := 5.0
@export var boost_cooldown := 14.0
@export var park_speed_scale := 0.55

var distance := 0.0

var _world_pieces: Array[Node3D] = []
var _intro_handled := false
var _sequence_id := 0
var _turn_state := TurnState.NONE
var _turn_direction: StringName = &""
var _active_junction: Node3D
var _approach_stop_progress := INF
var _turn_end_progress := INF
var _next_segment_progress := 0.0
var _segment_spawning_paused := false
var _segment_index := 0
var _neighborhood_variant := 0
var _neighborhood_remaining := 0
var _last_neighborhood_variant := -1
var _side_street_remaining := 0
var _side_street_left := false
var _side_street_right := false
var _rng: RandomNumberGenerator
var _van_velocity := Vector3.ZERO
var _base_travel_speed := 8.0
var _boost_remaining := 0.0
var _boost_cooldown_remaining := 0.0

## Which fork button is the shop this choice (left/right). Empty when none.
var _shop_fork_side: StringName = &""
## Player took the shop fork — spawn a side bay after the turn.
var _shop_pending := false
var _shop_attach_segment_index := -1
var _shop_bay_side: StringName = &""
var _active_shop: Node3D
var _shop_align_progress := INF

@onready var corridor_root: Node3D = $"../../ExteriorCorridor"
@onready var travel_path: Path3D = $"../../TravelPath"
@onready var van_follow: PathFollow3D = $"../../TravelPath/VanFollow"
@onready var van_rig: Node3D = $"../../TravelPath/VanFollow/VanRig"


func _ready() -> void:
	process_physics_priority = -100
	add_to_group(&"travel_controller")
	_rng = RandomNumberGenerator.new()
	_rng.seed = GameSession.run_seed
	_apply_meta_travel_speed()
	_configure_initial_route()
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.route_chosen.connect(_on_route_chosen)
	MetaProgression.van_speed_changed.connect(_on_van_speed_changed)
	if GameSession.phase == GameSession.RunPhase.TRAVELLING:
		_maybe_start_intro()


func _apply_meta_travel_speed() -> void:
	_base_travel_speed = MetaProgression.get_van_speed()
	_refresh_travel_speed()


func _on_van_speed_changed(_level: int, speed: float) -> void:
	_base_travel_speed = speed
	_refresh_travel_speed()


func _refresh_travel_speed() -> void:
	var mult := boost_multiplier if _boost_remaining > 0.0 else 1.0
	if _turn_state in [TurnState.PARKING, TurnState.LEAVING_SHOP]:
		mult *= park_speed_scale
	travel_speed = _base_travel_speed * mult


func can_boost() -> bool:
	return (
		_boost_remaining <= 0.0
		and _boost_cooldown_remaining <= 0.0
		and GameSession.phase != GameSession.RunPhase.IDLE
		and GameSession.phase != GameSession.RunPhase.GAME_OVER
		and GameSession.phase != GameSession.RunPhase.SHOP
		and GameSession.phase != GameSession.RunPhase.PARKING
	)


func is_boosting() -> bool:
	return _boost_remaining > 0.0


func get_boost_cooldown_remaining() -> float:
	return maxf(_boost_cooldown_remaining, 0.0)


## Temporary overspeed so raiders close slower (or fall behind). Returns false if on cooldown.
func try_boost() -> bool:
	if not can_boost():
		return false
	_boost_remaining = boost_duration
	_boost_cooldown_remaining = boost_cooldown
	_refresh_travel_speed()
	return true


func get_shop_fork_side() -> StringName:
	return _shop_fork_side


func is_shop_docked() -> bool:
	return GameSession.phase == GameSession.RunPhase.SHOP


## True from shop-fork choice until the van has left the bay — blocks wave combat.
func is_shop_visit_active() -> bool:
	if _shop_pending:
		return true
	if is_instance_valid(_active_shop):
		return true
	if _turn_state in [TurnState.PARKING, TurnState.LEAVING_SHOP]:
		return true
	return GameSession.phase in [GameSession.RunPhase.PARKING, GameSession.RunPhase.SHOP]


func leave_shop() -> void:
	if GameSession.phase != GameSession.RunPhase.SHOP:
		return
	if not is_instance_valid(_active_shop):
		_clear_shop_state()
		GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
		return
	_build_leave_shop_route()


func _configure_initial_route() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -route_length))
	travel_path.curve = curve
	van_follow.progress = 0.0
	van_rig.transform = Transform3D.IDENTITY

	_spawn_world_segment(
		Transform3D(
			travel_path.global_basis,
			travel_path.global_position + travel_path.global_basis * Vector3(0.0, 0.0, segment_length)
		)
	)
	_next_segment_progress = 0.0
	_spawn_route_segments_until(segment_ahead_distance)


func get_van_velocity() -> Vector3:
	return _van_velocity


func _physics_process(delta: float) -> void:
	_tick_boost(delta)
	if not _should_scroll():
		_van_velocity = Vector3.ZERO
		return

	# Never park at the fork — if the player hasn't chosen, pick randomly in time to turn.
	_maybe_auto_choose_route(delta)

	var movement := travel_speed * delta
	if movement <= 0.0:
		_van_velocity = Vector3.ZERO
		return

	var previous_position := van_follow.global_position
	distance += movement
	van_follow.progress += movement
	if delta > 0.0:
		_van_velocity = (van_follow.global_position - previous_position) / delta
	else:
		_van_velocity = Vector3.ZERO
	_spawn_segments_ahead()
	_maybe_begin_shop_park()
	_update_turn()
	_prune_world()


func _tick_boost(delta: float) -> void:
	if _boost_remaining > 0.0:
		_boost_remaining = maxf(0.0, _boost_remaining - delta)
		if _boost_remaining <= 0.0:
			_refresh_travel_speed()
	if _boost_cooldown_remaining > 0.0:
		_boost_cooldown_remaining = maxf(0.0, _boost_cooldown_remaining - delta)


func _should_scroll() -> bool:
	# Chill pauses encounters only. IDLE scrolls too so a new game isn't parked
	# while waiting for the cab-door knock to begin the run.
	if _turn_state == TurnState.LEAVING_SHOP:
		return true
	return GameSession.phase in [
		GameSession.RunPhase.IDLE,
		GameSession.RunPhase.TRAVELLING,
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.REST,
		GameSession.RunPhase.TURNING,
		GameSession.RunPhase.ROUTE_CHOICE,
		GameSession.RunPhase.PARKING,
	]


func _maybe_auto_choose_route(delta: float) -> void:
	if _turn_state != TurnState.APPROACHING or _turn_direction != &"":
		return
	if GameSession.phase != GameSession.RunPhase.ROUTE_CHOICE:
		return
	var remaining := _approach_stop_progress - van_follow.progress
	if remaining > travel_speed * delta:
		return
	var direction: StringName = &"left" if _rng.randi() % 2 == 0 else &"right"
	GameSession.choose_route(direction)


func _spawn_segments_ahead() -> void:
	if _segment_spawning_paused:
		return
	_spawn_route_segments_until(van_follow.progress + segment_ahead_distance)


func _spawn_route_segments_until(target_progress: float) -> void:
	var route_end := travel_path.curve.get_baked_length()
	while _next_segment_progress <= target_progress and _next_segment_progress < route_end:
		_spawn_world_segment(_sample_route_transform(_next_segment_progress))
		_next_segment_progress += segment_length


func _spawn_world_segment(world_transform: Transform3D) -> void:
	var segment := segment_scene.instantiate() as Node3D
	corridor_root.add_child(segment)
	segment.global_transform = world_transform
	if segment.has_method(&"apply_variant"):
		segment.apply_variant(_pick_segment_variant())
	if segment.has_method(&"apply_side_streets"):
		var side_streets := _pick_side_streets()
		segment.apply_side_streets(side_streets.x != 0, side_streets.y != 0)
	_world_pieces.append(segment)
	_segment_index += 1


func _attach_shop_at_progress(shop_progress: float) -> void:
	if shop_scene == null or is_instance_valid(_active_shop):
		return
	if _shop_bay_side != &"left" and _shop_bay_side != &"right":
		_shop_bay_side = &"right" if _rng.randi() % 2 == 0 else &"left"

	# Make sure a corridor tile exists under the bay, then open that wall.
	_spawn_route_segments_until(shop_progress + segment_length * 0.5)
	var segment_transform := _sample_route_transform(shop_progress)
	var host_segment := _find_nearest_corridor_segment(segment_transform.origin)
	if host_segment and host_segment.has_method(&"open_shop_bay"):
		host_segment.open_shop_bay(_shop_bay_side)
	elif host_segment and host_segment.has_method(&"apply_side_streets"):
		host_segment.apply_side_streets(_shop_bay_side == &"left", _shop_bay_side == &"right")

	_active_shop = shop_scene.instantiate() as Node3D
	corridor_root.add_child(_active_shop)
	var side := 1.0 if _shop_bay_side == &"right" else -1.0
	var yaw := 0.0 if _shop_bay_side == &"right" else PI
	var local := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), Vector3(side * 9.0, 0.0, 0.0))
	_active_shop.global_transform = segment_transform * local
	_world_pieces.append(_active_shop)
	_shop_align_progress = shop_progress
	_shop_pending = false
	_shop_attach_segment_index = -1


func _find_nearest_corridor_segment(world_origin: Vector3) -> Node3D:
	var best: Node3D
	var best_dist := INF
	for piece in _world_pieces:
		if not is_instance_valid(piece):
			continue
		if not piece.has_method(&"apply_variant") and not piece.has_method(&"open_shop_bay"):
			continue
		var dist := piece.global_position.distance_to(world_origin)
		if dist < best_dist:
			best_dist = dist
			best = piece
	return best


func _pick_segment_variant() -> int:
	if _neighborhood_remaining <= 0:
		_neighborhood_variant = _rng.randi() % SEGMENT_VARIANT_COUNT
		if (
			_last_neighborhood_variant >= 0
			and _neighborhood_variant == _last_neighborhood_variant
		):
			_neighborhood_variant = (_neighborhood_variant + 1) % SEGMENT_VARIANT_COUNT
		_neighborhood_remaining = _rng.randi_range(
			NEIGHBORHOOD_MIN_LENGTH,
			NEIGHBORHOOD_MAX_LENGTH
		)
		_last_neighborhood_variant = _neighborhood_variant
	_neighborhood_remaining -= 1
	return _neighborhood_variant


func _pick_side_streets() -> Vector2i:
	if _segment_index < SIDE_STREET_START_SEGMENT:
		return Vector2i.ZERO

	if _side_street_remaining <= 0:
		_side_street_left = false
		_side_street_right = false
		if _rng.randf() < SIDE_STREET_RUN_CHANCE:
			match _rng.randi_range(0, 2):
				0:
					_side_street_left = true
				1:
					_side_street_right = true
				2:
					_side_street_left = true
					_side_street_right = true
			_side_street_remaining = _rng.randi_range(
				SIDE_STREET_RUN_MIN,
				SIDE_STREET_RUN_MAX
			)

	if _side_street_remaining > 0:
		_side_street_remaining -= 1

	return Vector2i(int(_side_street_left), int(_side_street_right))


func _sample_route_transform(progress: float) -> Transform3D:
	return travel_path.global_transform * travel_path.curve.sample_baked_with_rotation(
		progress,
		true,
		true
	)


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	if next_phase == GameSession.RunPhase.TRAVELLING:
		_maybe_start_intro()
	elif next_phase == GameSession.RunPhase.ROUTE_CHOICE:
		_prepare_shop_fork()
		_spawn_approaching_junction()


func _prepare_shop_fork() -> void:
	# Every fork offers a shop on one side for now.
	_shop_fork_side = &"left" if _rng.randi() % 2 == 0 else &"right"


func _maybe_start_intro() -> void:
	if _intro_handled or GameSession.route_step > 0:
		return
	_intro_handled = true
	_sequence_id += 1
	var id := _sequence_id
	_run_intro(id)


func _run_intro(id: int) -> void:
	await get_tree().create_timer(intro_peace_seconds).timeout
	if id != _sequence_id or GameSession.phase != GameSession.RunPhase.TRAVELLING:
		return
	GameSession.set_phase(GameSession.RunPhase.REST)
	var timer := get_tree().create_timer(intro_rest_seconds)
	var rewards := get_tree().get_first_node_in_group(&"boon_reward_controller") as BoonRewardController
	if rewards:
		await rewards.wait_for_rest_resolution()
	await timer.timeout
	if id == _sequence_id and GameSession.phase == GameSession.RunPhase.REST:
		GameSession.set_phase(GameSession.RunPhase.ROUTE_CHOICE)


func _aligned_special_progress() -> float:
	var target_progress := van_follow.progress + junction_distance
	var first_aligned_progress := (
		_next_segment_progress
		- segment_length
		+ junction_incoming_length
		+ segment_length * 0.5
	)
	var alignment_steps := maxi(
		0,
		ceili((target_progress - first_aligned_progress) / segment_length)
	)
	return first_aligned_progress + alignment_steps * segment_length


func _spawn_special_ahead(scene: PackedScene) -> void:
	if scene == null or is_instance_valid(_active_junction) or _turn_state != TurnState.NONE:
		return
	_turn_state = TurnState.APPROACHING
	_turn_direction = &""

	var special_progress := _aligned_special_progress()
	var final_approach_segment := (
		special_progress - junction_incoming_length - segment_length * 0.5
	)
	_spawn_route_segments_until(final_approach_segment)
	_segment_spawning_paused = true

	_active_junction = scene.instantiate() as Node3D
	corridor_root.add_child(_active_junction)
	_active_junction.global_transform = _sample_route_transform(special_progress)
	_world_pieces.append(_active_junction)
	_approach_stop_progress = special_progress - turn_radius


func _spawn_approaching_junction() -> void:
	_spawn_special_ahead(t_junction_scene)


func _on_route_chosen(direction: StringName, _step: int) -> void:
	if _turn_state != TurnState.APPROACHING or not is_instance_valid(_active_junction):
		return
	_turn_direction = direction
	# Choosing a non-shop fork abandons any unfinished shop visit from a prior pick.
	if direction == _shop_fork_side and shop_scene != null:
		_shop_pending = true
		_shop_bay_side = &"left" if _rng.randi() % 2 == 0 else &"right"
	else:
		if not is_instance_valid(_active_shop):
			_shop_pending = false
			_shop_bay_side = &""
			_shop_attach_segment_index = -1
			_shop_align_progress = INF
	_build_turn_route()


func _update_turn() -> void:
	if _turn_state == TurnState.TURNING:
		if van_follow.progress >= _turn_end_progress:
			_finish_turn()
	elif _turn_state == TurnState.PARKING:
		if van_follow.progress >= _turn_end_progress:
			_finish_park()
	elif _turn_state == TurnState.LEAVING_SHOP:
		if van_follow.progress >= _turn_end_progress:
			_finish_leave_shop()


func _build_turn_route() -> void:
	var van_transform := van_rig.global_transform
	var junction_local := van_transform.affine_inverse() * _active_junction.global_position
	var straight_length := maxf(0.0, -junction_local.z - turn_radius)
	var side := -1.0 if _turn_direction == &"left" else 1.0
	var handle := turn_radius * QUARTER_CIRCLE_HANDLE
	var turn_start := Vector3(0.0, 0.0, -straight_length)
	var turn_end := Vector3(side * turn_radius, 0.0, -straight_length - turn_radius)
	var route_end := turn_end + Vector3(side * route_length, 0.0, 0.0)

	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(Vector3.ZERO)
	curve.add_point(turn_start, Vector3.ZERO, Vector3(0.0, 0.0, -handle))
	curve.add_point(
		turn_end,
		Vector3(-side * handle, 0.0, 0.0),
		Vector3(side * segment_length * 0.25, 0.0, 0.0)
	)
	curve.add_point(
		route_end,
		Vector3(-side * segment_length * 0.25, 0.0, 0.0)
	)

	travel_path.curve = curve
	travel_path.global_transform = van_transform
	van_follow.progress = 0.0
	van_rig.transform = Transform3D.IDENTITY

	_turn_state = TurnState.TURNING
	_approach_stop_progress = INF
	_turn_end_progress = curve.get_closest_offset(turn_end)
	_next_segment_progress = _turn_end_progress + segment_length
	_spawn_route_segments_until(_turn_end_progress + segment_ahead_distance)


func _finish_turn() -> void:
	_turn_state = TurnState.NONE
	_turn_direction = &""
	_active_junction = null
	_turn_end_progress = INF
	_segment_spawning_paused = false
	if _shop_pending and not is_instance_valid(_active_shop):
		var ahead := float(
			_rng.randi_range(SHOP_SPAWN_MIN_SEGMENTS_AHEAD, SHOP_SPAWN_MAX_SEGMENTS_AHEAD)
		)
		_attach_shop_at_progress(van_follow.progress + segment_length * ahead)
	_spawn_segments_ahead()
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)


func _maybe_begin_shop_park() -> void:
	if _turn_state != TurnState.NONE:
		return
	if not is_instance_valid(_active_shop):
		return
	if _shop_align_progress >= INF:
		return
	# Park while the road is still scrolling (combat used to skip this and blow past).
	if GameSession.phase not in [
		GameSession.RunPhase.TRAVELLING,
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.REST,
	]:
		return
	if van_follow.progress < _shop_align_progress - SHOP_PARK_LEAD_IN:
		return
	_build_park_route()


func _build_park_route() -> void:
	if not is_instance_valid(_active_shop):
		return
	var dock := _active_shop.get_node_or_null("DockPoint") as Marker3D
	if dock == null:
		return

	var van_transform := van_rig.global_transform
	var dock_xf := dock.global_transform
	var van_inv := van_transform.affine_inverse()
	var dock_local := van_inv * dock_xf.origin
	# Reverse park: ease past the mouth, then swing rear-first into the bay.
	var pass_point := Vector3(0.0, 0.0, -maxf(2.0, absf(dock_local.z) * 0.15))
	var reverse_point := Vector3(dock_local.x * 0.35, 0.0, pass_point.z * 0.5)

	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	curve.add_point(Vector3.ZERO)
	curve.add_point(pass_point)
	curve.add_point(reverse_point)
	curve.add_point(dock_local)

	travel_path.curve = curve
	travel_path.global_transform = van_transform
	van_follow.progress = 0.0
	van_rig.transform = Transform3D.IDENTITY

	_turn_state = TurnState.PARKING
	_turn_end_progress = curve.get_baked_length()
	_shop_align_progress = INF
	_segment_spawning_paused = true
	_refresh_travel_speed()
	GameSession.set_phase(GameSession.RunPhase.PARKING)


func _finish_park() -> void:
	_turn_state = TurnState.NONE
	_turn_end_progress = INF
	_refresh_travel_speed()
	# Snap nose-to-road using DockPoint facing if available.
	if is_instance_valid(_active_shop):
		var dock := _active_shop.get_node_or_null("DockPoint") as Marker3D
		if dock:
			var dock_xf := dock.global_transform
			travel_path.curve = Curve3D.new()
			travel_path.curve.add_point(Vector3.ZERO)
			travel_path.curve.add_point(Vector3(0.0, 0.0, -1.0))
			travel_path.global_transform = dock_xf
			van_follow.progress = 0.0
			van_rig.transform = Transform3D.IDENTITY
	GameSession.set_phase(GameSession.RunPhase.SHOP)


func _build_leave_shop_route() -> void:
	var van_transform := van_rig.global_transform
	var side := 1.0 if _shop_bay_side == &"right" else -1.0
	# Nose faces the road (-X of a right bay). Pull forward out of the bay, slide to
	# corridor center, then continue along the corridor.
	var pull_out := Vector3(0.0, 0.0, -7.0)
	var center := pull_out + Vector3(-side * 9.0, 0.0, 0.0)
	var corridor_forward := Vector3.ZERO
	if is_instance_valid(_active_shop):
		var shop_z := _active_shop.global_transform.basis.z.normalized()
		var prefer := -van_transform.basis.z
		corridor_forward = shop_z if prefer.dot(shop_z) >= 0.0 else -shop_z
	else:
		corridor_forward = -van_transform.basis.z

	var center_world := van_transform * center
	var road_end_world := center_world + corridor_forward * route_length
	var van_inv := van_transform.affine_inverse()

	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(Vector3.ZERO)
	curve.add_point(pull_out)
	curve.add_point(van_inv * center_world)
	curve.add_point(van_inv * road_end_world)

	travel_path.curve = curve
	travel_path.global_transform = van_transform
	van_follow.progress = 0.0
	van_rig.transform = Transform3D.IDENTITY

	_turn_state = TurnState.LEAVING_SHOP
	_turn_end_progress = curve.get_closest_offset(van_inv * center_world)
	_next_segment_progress = _turn_end_progress + segment_length
	_segment_spawning_paused = false
	_refresh_travel_speed()
	_spawn_route_segments_until(_turn_end_progress + segment_ahead_distance)


func _finish_leave_shop() -> void:
	_turn_state = TurnState.NONE
	_turn_end_progress = INF
	_clear_shop_state()
	_segment_spawning_paused = false
	_refresh_travel_speed()
	_spawn_segments_ahead()
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)


func _clear_shop_state() -> void:
	_active_shop = null
	_shop_pending = false
	_shop_attach_segment_index = -1
	_shop_bay_side = &""
	_shop_align_progress = INF
	_shop_fork_side = &""


func _prune_world() -> void:
	if _turn_state != TurnState.NONE:
		return
	for index in range(_world_pieces.size() - 1, -1, -1):
		var piece := _world_pieces[index]
		if not is_instance_valid(piece):
			_world_pieces.remove_at(index)
			continue
		if piece == _active_shop:
			continue
		if piece.global_position.distance_to(van_rig.global_position) <= world_cull_distance:
			continue
		piece.queue_free()
		_world_pieces.remove_at(index)
