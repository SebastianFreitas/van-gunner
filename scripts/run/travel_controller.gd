class_name TravelController
extends Node

enum TurnState {
	NONE,
	APPROACHING,
	TURNING,
	PARKING,
	LEAVING_STOP,
	ELEVATING,
}

const QUARTER_CIRCLE_HANDLE := 0.55228475
const SEGMENT_VARIANT_COUNT := 4
const NEIGHBORHOOD_MIN_LENGTH := 2
const NEIGHBORHOOD_MAX_LENGTH := 5
const SIDE_STREET_CHANCE := 0.26
## Empty corridor tiles required between side-street openings (avoids a thin
## double wall where two branch flank walls meet at the segment seam).
const SIDE_STREET_GAP := 2
const SIDE_STREET_START_SEGMENT := 4
const STOP_SPAWN_MIN_SEGMENTS_AHEAD := 1
const STOP_SPAWN_MAX_SEGMENTS_AHEAD := 2
## Straight reverse after the quarter-circle. Total pass-distance is park radius + this.
const STOP_PARK_REVERSE_STRAIGHT := 8.0
const STOP_CORRIDOR_LATERAL := 9.0
## Tighter than road turns so the van can stop in the 5 m vestibule, before the door.
const STOP_PARK_TURN_RADIUS := 6.0
## Local copies so this file never needs StopElevator / StopVestibule class_names
## at parse time (those scripts also have class_name; Godot can fail the cycle).
const _ELEVATOR_RIDE_SECONDS := 3.2
const _ELEVATOR_DEPTH := 16.0
const _DOOR_OPEN_DURATION := 1.4
const _StopElevator := preload("res://scripts/run/stop_elevator.gd")

## Overwritten in _ready from MetaProgression → GameBalance van speed curve.
## Live value includes temporary driver boosts (raiders read this every frame).
@export var travel_speed := 8.0
@export var segment_scene: PackedScene
@export var t_junction_scene: PackedScene
## 4-way (left / straight / right). Used when the act deck still has 3+ cards
## and No Through Road is not pending.
@export var crossroads_scene: PackedScene
@export var act_statue_scene: PackedScene
## Shared 5 m mouth + roll-up door. Stop interiors instance behind the door.
@export var stop_vestibule_scene: PackedScene
## On-road lift host. Same vestibule + content, dropped under the street.
@export var stop_elevator_scene: PackedScene
@export var segment_length := 20.0
@export var segment_ahead_distance := 80.0
@export var world_cull_distance := 140.0
@export var route_length := 10000.0
@export var intro_peace_seconds := 4.0
@export var intro_rest_seconds := 20.0
## Longer approach = more time to read fork cards before auto-pick.
@export var junction_distance := 100.0
@export var junction_incoming_length := 20.0
@export var turn_radius := 10.0
@export var boost_multiplier := 1.75
@export var boost_duration := 5.0
@export var boost_cooldown := 14.0
## Hold-the-line: raiders close faster until the player shouts let's go.
@export var slow_multiplier := 0.42
@export var slow_cooldown := 14.0
@export var debug_speed_multiplier := 5.0
## Park-in / pull-out as a multiple of live travel speed. 1.65 is 3× the old 0.55 crawl.
@export var park_speed_scale := 1.65

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
## Segments left that must stay closed after a side street.
var _side_street_cooldown := 0
var _rng: RandomNumberGenerator
var _van_velocity := Vector3.ZERO
var _base_travel_speed := 8.0
var _boost_remaining := 0.0
var _boost_cooldown_remaining := 0.0
var _slowing := false
var _slow_cooldown_remaining := 0.0
var _debug_speed_mode := false

## Per-direction stop on the live fork. Every offered road gets one.
var _fork_stops: Dictionary = {}
## First assigned stop this fork — kept for older duck-typed callers.
var _fork_stop: SideStopDefinition
## First assigned stop side this fork — kept for older duck-typed callers.
var _stop_fork_side: StringName = &""
## Player took the stop fork — spawn that bay after the turn.
var _stop_pending := false
var _pending_stop: SideStopDefinition
var _stop_attach_segment_index := -1
var _stop_bay_side: StringName = &""
var _active_stop: Node3D
var _active_stop_def: SideStopDefinition
var _stop_align_progress := INF
var _last_stop_id: StringName = &""
## When true, PathFollow moves backward along the park curve (rear into bay).
var _park_reversing := false
## Debug: next fork offers this stop on every road, then clears.
var _forced_next_stop_id: StringName = &""
var _active_statue: Node3D
var _act_reveal_pending := false

@onready var corridor_root: Node3D = $"../../ExteriorCorridor"
@onready var travel_path: Path3D = $"../../TravelPath"
@onready var van_follow: PathFollow3D = $"../../TravelPath/VanFollow"
@onready var van_rig: Node3D = $"../../TravelPath/VanFollow/VanRig"


func _ready() -> void:
	process_physics_priority = -100
	add_to_group(&"travel_controller")
	_rng = RandomNumberGenerator.new()
	_rng.seed = GameSession.run_seed
	if act_statue_scene == null:
		act_statue_scene = load("res://scenes/corridor/act_statue.tscn") as PackedScene
	_apply_meta_travel_speed()
	_configure_initial_route()
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.route_chosen.connect(_on_route_chosen)
	MetaProgression.van_speed_changed.connect(_on_van_speed_changed)
	if GameSession.phase == GameSession.RunPhase.TRAVELLING:
		_maybe_start_intro()
		_maybe_resume_act_flow()


func _apply_meta_travel_speed() -> void:
	_base_travel_speed = MetaProgression.get_van_speed()
	_refresh_travel_speed()


func _on_van_speed_changed(_level: int, speed: float) -> void:
	_base_travel_speed = speed
	_refresh_travel_speed()


func _refresh_travel_speed() -> void:
	var mult := 1.0
	if _debug_speed_mode:
		mult = debug_speed_multiplier
	elif _boost_remaining > 0.0:
		mult = boost_multiplier
	elif _slowing:
		mult = slow_multiplier
	if _turn_state in [TurnState.PARKING, TurnState.LEAVING_STOP]:
		mult *= park_speed_scale
	travel_speed = _base_travel_speed * mult


func set_debug_speed_mode(enabled: bool) -> void:
	if _debug_speed_mode == enabled:
		return
	_debug_speed_mode = enabled
	_refresh_travel_speed()


func is_debug_speed_mode() -> bool:
	return _debug_speed_mode


func get_debug_time_scale() -> float:
	return debug_speed_multiplier if _debug_speed_mode else 1.0


func scale_debug_wait(seconds: float) -> float:
	if not _debug_speed_mode:
		return seconds
	return maxf(0.1, seconds / debug_speed_multiplier)


func _speed_order_phase_ok() -> bool:
	return (
		GameSession.phase != GameSession.RunPhase.IDLE
		and GameSession.phase != GameSession.RunPhase.GAME_OVER
		and GameSession.phase != GameSession.RunPhase.STOP
		and GameSession.phase != GameSession.RunPhase.PARKING
		and GameSession.phase != GameSession.RunPhase.ACT_REVEAL
		and GameSession.phase != GameSession.RunPhase.BOSS_PICK
	)


func can_boost() -> bool:
	return (
		_boost_remaining <= 0.0
		and _boost_cooldown_remaining <= 0.0
		and _speed_order_phase_ok()
	)


func is_boosting() -> bool:
	return _boost_remaining > 0.0


func get_boost_cooldown_remaining() -> float:
	return maxf(_boost_cooldown_remaining, 0.0)


func get_boost_remaining() -> float:
	return maxf(_boost_remaining, 0.0)


## Temporary overspeed so raiders close slower (or fall behind). Returns false if on cooldown.
## Cab-door ACCELERATE, Shift, and the HUD GO button all share this cooldown.
func try_boost() -> bool:
	if not can_boost():
		return false
	_slowing = false
	_boost_remaining = boost_duration
	_boost_cooldown_remaining = boost_cooldown
	_refresh_travel_speed()
	return true


func can_slow() -> bool:
	return (
		not _slowing
		and _boost_remaining <= 0.0
		and _slow_cooldown_remaining <= 0.0
		and _speed_order_phase_ok()
	)


func is_slowing() -> bool:
	return _slowing


func get_slow_cooldown_remaining() -> float:
	return maxf(_slow_cooldown_remaining, 0.0)


## Drop speed until try_resume_speed(). C / HUD while already slow is let's go, not this.
func try_slow() -> bool:
	if not can_slow():
		return false
	_slowing = true
	_slow_cooldown_remaining = slow_cooldown
	_refresh_travel_speed()
	return true


## Cancel a hold-back. Always free while slowing — cooldown already started on try_slow.
func try_resume_speed() -> bool:
	if not _slowing:
		return false
	_slowing = false
	_refresh_travel_speed()
	return true


func get_stop_fork_side() -> StringName:
	return _stop_fork_side


func get_fork_stop() -> SideStopDefinition:
	return _fork_stop


func get_fork_stop_for(direction: StringName) -> SideStopDefinition:
	if not _fork_stops.has(direction):
		return null
	return _fork_stops[direction] as SideStopDefinition


func get_active_stop() -> SideStopDefinition:
	return _active_stop_def if _active_stop_def else _pending_stop


## Duck-typed alias — older callers still ask for the shop fork.
func get_shop_fork_side() -> StringName:
	return get_stop_fork_side()


func is_stop_docked() -> bool:
	return GameSession.phase == GameSession.RunPhase.STOP


func is_shop_docked() -> bool:
	return is_stop_docked()


## True from stop-fork choice until the van has left the bay — blocks wave combat.
func is_stop_visit_active() -> bool:
	if _stop_pending:
		return true
	if is_instance_valid(_active_stop):
		return true
	if _turn_state in [TurnState.PARKING, TurnState.LEAVING_STOP, TurnState.ELEVATING]:
		return true
	return GameSession.phase in [GameSession.RunPhase.PARKING, GameSession.RunPhase.STOP]


func is_shop_visit_active() -> bool:
	return is_stop_visit_active()


func is_act_reveal_active() -> bool:
	return (
		_act_reveal_pending
		or GameSession.phase == GameSession.RunPhase.ACT_REVEAL
		or GameSession.phase == GameSession.RunPhase.BOSS_PICK
		or is_instance_valid(_active_statue)
	)


## Place a roadside statue and hold the van for the act tarot reveal.
func begin_act_statue_stop() -> void:
	_act_reveal_pending = true
	_spawn_act_statue()


func end_act_statue_stop() -> void:
	_act_reveal_pending = false
	_clear_act_statue()


func force_next_stop(stop_id: StringName) -> bool:
	if SideStopRegistry.load_by_id(stop_id) == null:
		return false
	_forced_next_stop_id = stop_id
	return true


func leave_stop() -> void:
	if GameSession.phase != GameSession.RunPhase.STOP:
		return
	if _turn_state == TurnState.ELEVATING:
		return
	if not is_instance_valid(_active_stop):
		_clear_stop_state()
		GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
		return
	var van := get_node("../..")
	if van and van.has_method(&"seal_van_after_stop"):
		van.seal_van_after_stop()
	elif van and van.has_method(&"seal_van_after_shop"):
		van.seal_van_after_shop()
	if _is_elevator_stop():
		_begin_elevator_ascent()
		return
	_build_leave_stop_route()


func leave_shop() -> void:
	leave_stop()


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
	_tick_speed_orders(delta)
	if _turn_state == TurnState.ELEVATING:
		_keep_player_on_van_rig()
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
	if _park_reversing:
		van_follow.progress = maxf(0.0, van_follow.progress - movement)
	else:
		van_follow.progress += movement
	if delta > 0.0:
		_van_velocity = (van_follow.global_position - previous_position) / delta
	else:
		_van_velocity = Vector3.ZERO
	_spawn_segments_ahead()
	_maybe_begin_stop_park()
	_update_turn()
	_prune_world()


func _tick_speed_orders(delta: float) -> void:
	if _boost_remaining > 0.0:
		_boost_remaining = maxf(0.0, _boost_remaining - delta)
		if _boost_remaining <= 0.0:
			_refresh_travel_speed()
	if _boost_cooldown_remaining > 0.0:
		_boost_cooldown_remaining = maxf(0.0, _boost_cooldown_remaining - delta)
	if _slow_cooldown_remaining > 0.0:
		_slow_cooldown_remaining = maxf(0.0, _slow_cooldown_remaining - delta)


func _should_scroll() -> bool:
	# Chill pauses encounters only. IDLE scrolls too so a new game isn't parked
	# while waiting for the cab-door knock to begin the run.
	if _turn_state == TurnState.ELEVATING:
		return false
	if _turn_state == TurnState.LEAVING_STOP:
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
	var dirs := GameSession.get_route_directions()
	var direction: StringName = dirs[_rng.randi() % dirs.size()]
	GameSession.choose_route(direction)


func _spawn_segments_ahead() -> void:
	if _segment_spawning_paused:
		return
	_spawn_route_segments_until(van_follow.progress + segment_ahead_distance)


func _spawn_route_segments_until(target_progress: float) -> void:
	var route_end := travel_path.curve.get_baked_length()
	while _next_segment_progress <= target_progress and _next_segment_progress < route_end:
		_spawn_world_segment(
			_sample_route_transform(_next_segment_progress),
			_next_segment_progress
		)
		_next_segment_progress += segment_length


func _spawn_world_segment(world_transform: Transform3D, route_progress: float = NAN) -> Node3D:
	var segment := segment_scene.instantiate() as Node3D
	corridor_root.add_child(segment)
	segment.global_transform = world_transform
	if is_finite(route_progress):
		segment.set_meta(&"route_progress", route_progress)
	if segment.has_method(&"apply_variant"):
		segment.apply_variant(_pick_segment_variant())
	if segment.has_method(&"apply_side_streets"):
		var side_streets := _pick_side_streets()
		segment.apply_side_streets(side_streets.x != 0, side_streets.y != 0)
	_world_pieces.append(segment)
	_segment_index += 1
	return segment


## First / second / … corridor tile still ahead of the van on the spawn lattice.
func _upcoming_corridor_progress(tiles_ahead: int) -> float:
	var progresses: Array[float] = []
	var ahead_of := van_follow.progress + 1.0
	for piece in _world_pieces:
		if not is_instance_valid(piece) or not piece.has_meta(&"route_progress"):
			continue
		var tile_progress := float(piece.get_meta(&"route_progress"))
		if tile_progress >= ahead_of:
			progresses.append(tile_progress)
	progresses.sort()
	var index := maxi(tiles_ahead, 1) - 1
	if index < progresses.size():
		return progresses[index]
	if progresses.is_empty():
		return _next_segment_progress + segment_length * float(index)
	return progresses[progresses.size() - 1] + segment_length * float(
		index - progresses.size() + 1
	)


func _corridor_segment_near_progress(route_progress: float) -> Node3D:
	var best: Node3D
	var best_dist := INF
	for piece in _world_pieces:
		if not is_instance_valid(piece) or not piece.has_meta(&"route_progress"):
			continue
		var dist := absf(float(piece.get_meta(&"route_progress")) - route_progress)
		if dist < best_dist:
			best_dist = dist
			best = piece
	if best == null or best_dist > segment_length * 0.51:
		return null
	return best


func _attach_stop_on_upcoming_segment(tiles_ahead: int) -> void:
	if _pending_stop == null or _pending_stop.scene == null or is_instance_valid(_active_stop):
		return
	if _stop_bay_side != &"left" and _stop_bay_side != &"right":
		_stop_bay_side = &"right" if _rng.randi() % 2 == 0 else &"left"

	var host_progress := _upcoming_corridor_progress(tiles_ahead)
	_spawn_route_segments_until(host_progress)
	var host_segment := _corridor_segment_near_progress(host_progress)
	if host_segment == null:
		# Lattice skipped this slot (straight-through used to leave a 10m void).
		host_segment = _spawn_world_segment(
			_sample_route_transform(host_progress),
			host_progress
		)
		_next_segment_progress = maxf(_next_segment_progress, host_progress + segment_length)

	if _pending_stop.uses_elevator():
		_place_elevator_stop(host_segment, host_progress)
	else:
		_place_bay_stop(host_segment, host_progress)


func _place_bay_stop(host_segment: Node3D, host_progress: float) -> void:
	if host_segment.has_method(&"open_bay"):
		host_segment.open_bay(_stop_bay_side)
	elif host_segment.has_method(&"open_shop_bay"):
		host_segment.open_shop_bay(_stop_bay_side)
	elif host_segment.has_method(&"apply_side_streets"):
		host_segment.apply_side_streets(_stop_bay_side == &"left", _stop_bay_side == &"right")

	if not _spawn_stop_host():
		return
	var side := 1.0 if _stop_bay_side == &"right" else -1.0
	var yaw := 0.0 if _stop_bay_side == &"right" else PI
	var local := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), Vector3(side * 9.0, 0.0, 0.0))
	_active_stop.global_transform = host_segment.global_transform * local
	_finish_stop_attach(host_progress)


func _place_elevator_stop(host_segment: Node3D, host_progress: float) -> void:
	if not _spawn_stop_host():
		return
	# Sit on the travel sample, not the tile mesh — the van stops on the path.
	_active_stop.global_transform = _sample_route_transform(host_progress)
	if _active_stop.has_method(&"bind_host_segment"):
		_active_stop.bind_host_segment(host_segment)
	_finish_stop_attach(host_progress)


func _spawn_stop_host() -> bool:
	_active_stop = _instantiate_stop_host(_pending_stop)
	if _active_stop == null:
		push_error("Side stop '%s' scene failed to instantiate." % String(_pending_stop.id))
		return false
	_active_stop_def = _pending_stop
	corridor_root.add_child(_active_stop)
	return true


func _finish_stop_attach(host_progress: float) -> void:
	if _active_stop.has_method(&"mount_content"):
		_active_stop.mount_content(_pending_stop.scene)
	_world_pieces.append(_active_stop)
	_stop_align_progress = host_progress
	_stop_pending = false
	_stop_attach_segment_index = -1


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

	if _side_street_cooldown > 0:
		_side_street_cooldown -= 1
		return Vector2i.ZERO

	if _rng.randf() >= SIDE_STREET_CHANCE:
		return Vector2i.ZERO

	var left := false
	var right := false
	match _rng.randi_range(0, 2):
		0:
			left = true
		1:
			right = true
		2:
			left = true
			right = true

	_side_street_cooldown = SIDE_STREET_GAP
	return Vector2i(int(left), int(right))


func _sample_route_transform(progress: float) -> Transform3D:
	return travel_path.global_transform * travel_path.curve.sample_baked_with_rotation(
		progress,
		true,
		true
	)


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	if next_phase in [
		GameSession.RunPhase.IDLE,
		GameSession.RunPhase.GAME_OVER,
		GameSession.RunPhase.STOP,
		GameSession.RunPhase.PARKING,
		GameSession.RunPhase.ACT_REVEAL,
		GameSession.RunPhase.BOSS_PICK,
	]:
		if _slowing:
			_slowing = false
			_refresh_travel_speed()
	if next_phase == GameSession.RunPhase.TRAVELLING:
		_maybe_start_intro()
		_maybe_resume_act_flow()
	elif next_phase == GameSession.RunPhase.ROUTE_CHOICE:
		_prepare_stop_fork()
		_spawn_approaching_junction()


func _prepare_stop_fork() -> void:
	# Cards are street modifiers. Every offered road still gets a building.
	_fork_stops.clear()
	_fork_stop = null
	_stop_fork_side = &""
	var used: Array[StringName] = []
	if _last_stop_id != &"":
		used.append(_last_stop_id)
	var forced := SideStopRegistry.load_by_id(_forced_next_stop_id)
	_forced_next_stop_id = &""
	for direction in GameSession.get_route_directions():
		var stop: SideStopDefinition = forced
		if stop == null or stop.scene == null:
			stop = SideStopRegistry.pick(_rng, used)
		if stop == null or stop.scene == null:
			continue
		_fork_stops[direction] = stop
		if stop.id not in used:
			used.append(stop.id)
		if _fork_stop == null:
			_fork_stop = stop
			_stop_fork_side = direction


func _maybe_start_intro() -> void:
	if _intro_handled or GameSession.route_step > 0:
		return
	_intro_handled = true
	_sequence_id += 1
	var id := _sequence_id
	_run_intro(id)


## After save/load (or exhausted deck mid-street), re-run statue reveal or boss pick.
func _maybe_resume_act_flow() -> void:
	if GameSession.route_step <= 0:
		return
	if is_act_reveal_active():
		return
	if GameSession.needs_boss_pick():
		_sequence_id += 1
		_run_resume_boss_pick(_sequence_id)
		return
	if not GameSession.needs_act_reveal():
		return
	_sequence_id += 1
	_run_resume_act_reveal(_sequence_id)


func _run_resume_boss_pick(id: int) -> void:
	var act_deck := get_tree().get_first_node_in_group(&"act_deck_controller")
	if act_deck and act_deck.has_method(&"begin_boss_pick_if_needed"):
		act_deck.begin_boss_pick_if_needed()
		if act_deck.has_method(&"wait_for_boss_pick_resolution"):
			await act_deck.wait_for_boss_pick_resolution()
	elif GameSession.needs_boss_pick():
		GameSession.commit_boss_picks([])
	if id == _sequence_id and GameSession.phase in [
		GameSession.RunPhase.BOSS_PICK,
		GameSession.RunPhase.TRAVELLING,
	]:
		GameSession.set_phase(GameSession.RunPhase.TRAVELLING)


func _run_resume_act_reveal(id: int) -> void:
	var act_deck := get_tree().get_first_node_in_group(&"act_deck_controller")
	if act_deck and act_deck.has_method(&"begin_reveal_if_needed"):
		act_deck.begin_reveal_if_needed()
		if act_deck.has_method(&"wait_for_reveal_resolution"):
			await act_deck.wait_for_reveal_resolution()
	elif GameSession.needs_act_reveal():
		GameSession.begin_new_act_deck()
	if id == _sequence_id and GameSession.phase in [
		GameSession.RunPhase.ACT_REVEAL,
		GameSession.RunPhase.TRAVELLING,
	]:
		GameSession.set_phase(GameSession.RunPhase.ROUTE_CHOICE)


func _run_intro(id: int) -> void:
	if is_debug_speed_mode():
		var deck := get_tree().get_first_node_in_group(&"act_deck_controller")
		if deck and deck.has_method(&"begin_reveal_if_needed"):
			deck.begin_reveal_if_needed()
			if deck.has_method(&"wait_for_reveal_resolution"):
				await deck.wait_for_reveal_resolution()
		elif GameSession.needs_act_reveal():
			GameSession.begin_new_act_deck()
		if id == _sequence_id:
			GameSession.set_phase(GameSession.RunPhase.ROUTE_CHOICE)
		return
	await get_tree().create_timer(scale_debug_wait(intro_peace_seconds)).timeout
	if id != _sequence_id or GameSession.phase != GameSession.RunPhase.TRAVELLING:
		return
	var act_deck := get_tree().get_first_node_in_group(&"act_deck_controller")
	if act_deck and act_deck.has_method(&"begin_reveal_if_needed"):
		act_deck.begin_reveal_if_needed()
		if act_deck.has_method(&"wait_for_reveal_resolution"):
			await act_deck.wait_for_reveal_resolution()
	elif GameSession.needs_act_reveal():
		GameSession.begin_new_act_deck()
	if id == _sequence_id and GameSession.phase in [
		GameSession.RunPhase.ACT_REVEAL,
		GameSession.RunPhase.TRAVELLING,
	]:
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
	var scene := t_junction_scene if GameSession.uses_t_junction() else crossroads_scene
	if scene == null:
		scene = t_junction_scene
	_spawn_special_ahead(scene)


func _on_route_chosen(direction: StringName, _step: int) -> void:
	if _turn_state != TurnState.APPROACHING or not is_instance_valid(_active_junction):
		return
	_turn_direction = direction
	# Choosing a road with no building abandons any unfinished visit from a prior pick.
	var chosen_stop := get_fork_stop_for(direction)
	if chosen_stop != null and chosen_stop.scene != null:
		_stop_pending = true
		_pending_stop = chosen_stop
		_last_stop_id = chosen_stop.id
		_stop_bay_side = &"left" if _rng.randi() % 2 == 0 else &"right"
	else:
		if not is_instance_valid(_active_stop):
			_stop_pending = false
			_pending_stop = null
			_stop_bay_side = &""
			_stop_attach_segment_index = -1
			_stop_align_progress = INF
	_build_turn_route()


func _update_turn() -> void:
	if _turn_state == TurnState.TURNING:
		if van_follow.progress >= _turn_end_progress:
			_finish_turn()
	elif _turn_state == TurnState.PARKING:
		if van_follow.progress <= 0.05:
			_finish_park()
	elif _turn_state == TurnState.LEAVING_STOP:
		if van_follow.progress >= _turn_end_progress:
			_finish_leave_stop()


func _build_turn_route() -> void:
	if _turn_direction == &"straight":
		_build_straight_route()
		return
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


func _build_straight_route() -> void:
	# Stay on the live -Z curve. `through` already ends at the outgoing mouth
	# (~20m past the junction); a full extra tile here left a 10m void.
	var van_transform := van_rig.global_transform
	var junction_local := van_transform.affine_inverse() * _active_junction.global_position
	var through := maxf(segment_length, -junction_local.z + 20.0)
	_turn_state = TurnState.TURNING
	_approach_stop_progress = INF
	_turn_end_progress = van_follow.progress + through
	_next_segment_progress = _turn_end_progress + segment_length * 0.5


func _finish_turn() -> void:
	_turn_state = TurnState.NONE
	_turn_direction = &""
	_active_junction = null
	_turn_end_progress = INF
	_segment_spawning_paused = false
	if _stop_pending and not is_instance_valid(_active_stop):
		_attach_stop_on_upcoming_segment(
			_rng.randi_range(STOP_SPAWN_MIN_SEGMENTS_AHEAD, STOP_SPAWN_MAX_SEGMENTS_AHEAD)
		)
	_spawn_segments_ahead()
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)


func _maybe_begin_stop_park() -> void:
	if _turn_state != TurnState.NONE:
		return
	if not is_instance_valid(_active_stop):
		return
	if _stop_align_progress >= INF:
		return
	# Park while the road is still scrolling (combat used to skip this and blow past).
	if GameSession.phase not in [
		GameSession.RunPhase.TRAVELLING,
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.REST,
	]:
		return
	if _is_elevator_stop():
		if van_follow.progress < _stop_align_progress:
			return
		_begin_elevator_descent()
		return
	# Need room for a T-junction quarter-circle plus a short reverse straight.
	if van_follow.progress < (
		_stop_align_progress + STOP_PARK_TURN_RADIUS + STOP_PARK_REVERSE_STRAIGHT
	):
		return
	_build_park_route()


func _stop_mouth_world() -> Vector3:
	var exit_pt := _active_stop.get_node_or_null("ExitPoint") as Marker3D
	if exit_pt:
		return exit_pt.global_position
	return _active_stop.to_global(Vector3(1.5, 0.0, 0.0))


func _stop_corridor_at_mouth(mouth_world: Vector3) -> Vector3:
	# Project the mouth onto the corridor centerline (bay sits STOP_CORRIDOR_LATERAL out).
	var into_bay := _active_stop.global_transform.basis.x.normalized()
	var corridor_ref := _active_stop.global_position - into_bay * STOP_CORRIDOR_LATERAL
	return mouth_world - into_bay * into_bay.dot(mouth_world - corridor_ref)


func _flatten_local(van_inv: Transform3D, world_pos: Vector3) -> Vector3:
	var local := van_inv * world_pos
	local.y = 0.0
	return local


func _build_park_route() -> void:
	if not is_instance_valid(_active_stop):
		return
	var dock := _active_stop.get_node_or_null("DockPoint") as Marker3D
	if dock == null:
		return

	# Same C as _build_turn_route, mirrored onto +Z (bay is behind after overshoot),
	# then stored dock→van and driven with progress counting down so the nose stays
	# road-facing. Handles are the T-turn controls transferred (not flipped) so the
	# arc stays a C — flipping them was what made the serpent S.
	var van_transform := van_rig.global_transform
	var van_inv := van_transform.affine_inverse()
	var side := 1.0 if _stop_bay_side == &"right" else -1.0
	var park_radius := STOP_PARK_TURN_RADIUS
	var handle := park_radius * QUARTER_CIRCLE_HANDLE

	var mouth_z := _flatten_local(van_inv, _stop_corridor_at_mouth(_stop_mouth_world())).z
	mouth_z = maxf(mouth_z, park_radius + STOP_PARK_REVERSE_STRAIGHT)
	# Use the real dock — do not push the van past the vestibule door.
	var dock_lat := maxf(
		absf(_flatten_local(van_inv, dock.global_position).x),
		park_radius + 2.0
	)

	var straight_length := mouth_z - park_radius
	var turn_start := Vector3(0.0, 0.0, straight_length)
	var turn_end := Vector3(side * park_radius, 0.0, straight_length + park_radius)
	var dock_pos := Vector3(side * dock_lat, 0.0, mouth_z)
	var bay_out := dock_lat - park_radius

	# Forward T into the bay would be: van → turn_start → turn_end → dock with
	#   turn_start.out = (0,0,handle), turn_end.in = (-side*handle, 0, 0)
	# Reversed path keeps those same control points on the shared segments.
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(dock_pos, Vector3.ZERO, Vector3(-side * bay_out * 0.25, 0.0, 0.0))
	curve.add_point(
		turn_end,
		Vector3(side * bay_out * 0.25, 0.0, 0.0),
		Vector3(-side * handle, 0.0, 0.0)
	)
	curve.add_point(
		turn_start,
		Vector3(0.0, 0.0, handle),
		Vector3.ZERO
	)
	curve.add_point(Vector3.ZERO)

	travel_path.curve = curve
	travel_path.global_transform = van_transform
	van_follow.progress = curve.get_baked_length()
	van_rig.transform = Transform3D.IDENTITY

	_park_reversing = true
	_turn_state = TurnState.PARKING
	_turn_end_progress = 0.0
	_stop_align_progress = INF
	_segment_spawning_paused = true
	_refresh_travel_speed()
	GameSession.set_phase(GameSession.RunPhase.PARKING)


func _finish_park() -> void:
	_park_reversing = false
	_turn_state = TurnState.NONE
	_turn_end_progress = INF
	van_follow.progress = 0.0
	_refresh_travel_speed()
	# Open after the reverse-park finishes so the gate stays shut while docking.
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"open_door"):
		_active_stop.open_door()
	GameSession.set_phase(GameSession.RunPhase.STOP)


func _instantiate_stop_host(def: SideStopDefinition) -> Node3D:
	if def != null and def.uses_elevator():
		if stop_elevator_scene:
			var elevator := stop_elevator_scene.instantiate() as Node3D
			if elevator:
				return elevator
		return _StopElevator.new() as Node3D
	if stop_vestibule_scene:
		var vestibule := stop_vestibule_scene.instantiate() as Node3D
		if vestibule:
			return vestibule
	return def.scene.instantiate() as Node3D


func _is_elevator_stop() -> bool:
	return _active_stop_def != null and _active_stop_def.uses_elevator()


func _elevator_ride_seconds() -> float:
	var seconds := _ELEVATOR_RIDE_SECONDS
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"ride_seconds"):
		seconds = float(_active_stop.ride_seconds())
	return scale_debug_wait(seconds)


func _elevator_depth() -> float:
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"depth"):
		return float(_active_stop.depth())
	return _ELEVATOR_DEPTH


func _begin_elevator_descent() -> void:
	van_follow.progress = _stop_align_progress
	van_rig.transform = Transform3D.IDENTITY
	_stop_align_progress = INF
	_segment_spawning_paused = true
	_turn_state = TurnState.ELEVATING
	_park_reversing = false
	_refresh_travel_speed()
	GameSession.set_phase(GameSession.RunPhase.PARKING)
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"open_shaft"):
		_active_stop.open_shaft()
	_sequence_id += 1
	_run_elevator_ride(_sequence_id, -_elevator_depth(), true)


func _begin_elevator_ascent() -> void:
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"set_docked"):
		_active_stop.set_docked(false)
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"close_door"):
		_active_stop.close_door()
	_turn_state = TurnState.ELEVATING
	_segment_spawning_paused = true
	_refresh_travel_speed()
	_sequence_id += 1
	_run_elevator_ride(_sequence_id, 0.0, false)


func _keep_player_on_van_rig() -> void:
	# CharacterBody3D physics is global. Street-height floors inflate local Y
	# as PathFollow.v_offset drops the van; snap back onto the rig.
	if van_rig == null:
		return
	var player := van_rig.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	if absf(player.position.y) <= 0.5:
		return
	player.position.y = 0.0
	player.velocity.y = 0.0


func _run_elevator_ride(id: int, target_offset: float, opening: bool) -> void:
	if not opening:
		await get_tree().create_timer(scale_debug_wait(_DOOR_OPEN_DURATION)).timeout
		if id != _sequence_id:
			return
	var duration := _elevator_ride_seconds()
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"tween_platform_to"):
		_active_stop.tween_platform_to(target_offset, duration)
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(van_follow, "v_offset", target_offset, duration)
	await tween.finished
	if id != _sequence_id:
		return
	if opening:
		_finish_elevator_descent()
	else:
		_finish_elevator_ascent()


func _finish_elevator_descent() -> void:
	_turn_state = TurnState.NONE
	_refresh_travel_speed()
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"set_docked"):
		_active_stop.set_docked(true)
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"open_door"):
		_active_stop.open_door()
	GameSession.set_phase(GameSession.RunPhase.STOP)


func _finish_elevator_ascent() -> void:
	van_follow.v_offset = 0.0
	van_rig.transform = Transform3D.IDENTITY
	_turn_state = TurnState.NONE
	_segment_spawning_paused = false
	_refresh_travel_speed()
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"restore_road"):
		_active_stop.restore_road()
	if is_instance_valid(_active_stop):
		_world_pieces.erase(_active_stop)
		_active_stop.queue_free()
	_clear_stop_state()
	_spawn_segments_ahead()
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)


func _build_leave_stop_route() -> void:
	# Mirror the reverse-park: same curve, forward progress (dock → corridor mouth).
	_park_reversing = false
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"close_door"):
		_active_stop.close_door()

	var curve := travel_path.curve
	if curve == null or curve.point_count < 2:
		_clear_stop_state()
		GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
		return

	var corridor_join := curve.get_closest_offset(Vector3.ZERO)
	var last_pos := curve.get_point_position(curve.point_count - 1)
	if last_pos.is_equal_approx(Vector3.ZERO):
		curve.add_point(Vector3(0.0, 0.0, -route_length))

	van_follow.progress = 0.0
	van_rig.transform = Transform3D.IDENTITY

	_turn_state = TurnState.LEAVING_STOP
	_turn_end_progress = corridor_join
	_next_segment_progress = corridor_join + segment_length
	_segment_spawning_paused = false
	_refresh_travel_speed()
	_spawn_route_segments_until(corridor_join + segment_ahead_distance)


func _finish_leave_stop() -> void:
	_turn_state = TurnState.NONE
	_turn_end_progress = INF
	_clear_stop_state()
	_segment_spawning_paused = false
	_refresh_travel_speed()
	_spawn_segments_ahead()
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)


func _clear_stop_state() -> void:
	if is_instance_valid(van_follow):
		van_follow.v_offset = 0.0
	_active_stop = null
	_active_stop_def = null
	_pending_stop = null
	_fork_stop = null
	_fork_stops.clear()
	_stop_pending = false
	_stop_attach_segment_index = -1
	_stop_bay_side = &""
	_stop_align_progress = INF
	_stop_fork_side = &""
	_park_reversing = false


func _spawn_act_statue() -> void:
	_clear_act_statue()
	if act_statue_scene == null or not is_instance_valid(van_rig):
		return
	_active_statue = act_statue_scene.instantiate() as Node3D
	if _active_statue == null:
		return
	corridor_root.add_child(_active_statue)
	# Roadside placeholder just ahead and to the right of the van.
	var offset := van_rig.global_transform.basis * Vector3(4.5, 0.0, -8.0)
	_active_statue.global_position = van_rig.global_position + offset
	_active_statue.global_basis = van_rig.global_basis
	_world_pieces.append(_active_statue)


func _clear_act_statue() -> void:
	if is_instance_valid(_active_statue):
		_world_pieces.erase(_active_statue)
		_active_statue.queue_free()
	_active_statue = null


func _prune_world() -> void:
	if _turn_state != TurnState.NONE:
		return
	for index in range(_world_pieces.size() - 1, -1, -1):
		var piece := _world_pieces[index]
		if not is_instance_valid(piece):
			_world_pieces.remove_at(index)
			continue
		if piece == _active_stop or piece == _active_statue:
			continue
		if piece.global_position.distance_to(van_rig.global_position) <= world_cull_distance:
			continue
		piece.queue_free()
		_world_pieces.remove_at(index)


func _exit_tree() -> void:
	set_process(false)
	for piece in _world_pieces:
		if is_instance_valid(piece):
			piece.free()
	_world_pieces.clear()
	_active_junction = null
	_active_stop = null
	_active_statue = null
