class_name TravelController
extends Node

enum TurnState {
	NONE,
	APPROACHING,
	TURNING,
}

const QUARTER_CIRCLE_HANDLE := 0.55228475
const SEGMENT_VARIANT_COUNT := 4
const NEIGHBORHOOD_MIN_LENGTH := 2
const NEIGHBORHOOD_MAX_LENGTH := 5
const SIDE_STREET_RUN_CHANCE := 0.26
const SIDE_STREET_RUN_MIN := 2
const SIDE_STREET_RUN_MAX := 4
const SIDE_STREET_START_SEGMENT := 4

## Overwritten in _ready from MetaProgression → GameBalance van speed curve.
## Live value includes temporary driver boosts (raiders read this every frame).
@export var travel_speed := 8.0
@export var segment_scene: PackedScene
@export var t_junction_scene: PackedScene
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
	travel_speed = _base_travel_speed * mult


func can_boost() -> bool:
	return (
		_boost_remaining <= 0.0
		and _boost_cooldown_remaining <= 0.0
		and GameSession.phase != GameSession.RunPhase.IDLE
		and GameSession.phase != GameSession.RunPhase.GAME_OVER
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
	return GameSession.phase in [
		GameSession.RunPhase.IDLE,
		GameSession.RunPhase.TRAVELLING,
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.REST,
		GameSession.RunPhase.TURNING,
		GameSession.RunPhase.ROUTE_CHOICE,
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
		_spawn_approaching_junction()


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


func _spawn_approaching_junction() -> void:
	if is_instance_valid(_active_junction) or _turn_state != TurnState.NONE:
		return
	_turn_state = TurnState.APPROACHING
	_turn_direction = &""

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
	var junction_progress := first_aligned_progress + alignment_steps * segment_length
	var final_approach_segment := (
		junction_progress - junction_incoming_length - segment_length * 0.5
	)
	_spawn_route_segments_until(final_approach_segment)
	_segment_spawning_paused = true

	_active_junction = t_junction_scene.instantiate() as Node3D
	corridor_root.add_child(_active_junction)
	_active_junction.global_transform = _sample_route_transform(junction_progress)
	_world_pieces.append(_active_junction)
	_approach_stop_progress = junction_progress - turn_radius


func _on_route_chosen(direction: StringName, _step: int) -> void:
	if _turn_state != TurnState.APPROACHING or not is_instance_valid(_active_junction):
		return
	_turn_direction = direction
	_build_turn_route()


func _update_turn() -> void:
	if _turn_state != TurnState.TURNING:
		return
	if van_follow.progress >= _turn_end_progress:
		_finish_turn()


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
	_spawn_segments_ahead()
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)


func _prune_world() -> void:
	if _turn_state != TurnState.NONE:
		return
	for index in range(_world_pieces.size() - 1, -1, -1):
		var piece := _world_pieces[index]
		if not is_instance_valid(piece):
			_world_pieces.remove_at(index)
			continue
		if piece.global_position.distance_to(van_rig.global_position) <= world_cull_distance:
			continue
		piece.queue_free()
		_world_pieces.remove_at(index)
