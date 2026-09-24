class_name TravelController
extends Node
## Drives the van's travel state machine: approach, turn, park and leave each stop.

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
const _StopElevator := preload("res://scripts/stops/stop_elevator.gd")
const _TravelWorld := preload("res://scripts/travel/travel_world.gd")
const _TravelRoutes := preload("res://scripts/travel/travel_routes.gd")
const _TravelStops := preload("res://scripts/travel/travel_stops.gd")

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
var _forced_next_stop: SideStopDefinition
var _active_statue: Node3D
var _act_reveal_pending := false
## Bumped whenever the travel curve is replaced. Leftover tiles keep their old
## `route_progress` numbers; without this they look "ahead" on the new lattice
## and a stop can attach to the previous street.
var _route_gen := 0

var _world: _TravelWorld
var _routes: _TravelRoutes
var _stops: _TravelStops

@onready var corridor_root: Node3D = $"../../ExteriorCorridor"
@onready var travel_path: Path3D = $"../../TravelPath"
@onready var van_follow: PathFollow3D = $"../../TravelPath/VanFollow"
@onready var van_rig: Node3D = $"../../TravelPath/VanFollow/VanRig"


func _ready() -> void:
	_world = _TravelWorld.new(self)
	_routes = _TravelRoutes.new(self)
	_stops = _TravelStops.new(self)
	process_physics_priority = -100
	add_to_group(&"travel_controller")
	_rng = RandomNumberGenerator.new()
	_rng.seed = GameSession.run_seed
	if act_statue_scene == null:
		act_statue_scene = load("res://scenes/corridor/act_statue.tscn") as PackedScene
	_apply_meta_travel_speed()
	_world.configure_initial_route()
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.route_chosen.connect(_routes.on_route_chosen)
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


func get_fork_stop_for(direction: StringName) -> SideStopDefinition:
	if not _fork_stops.has(direction):
		return null
	return _fork_stops[direction] as SideStopDefinition


func get_active_stop() -> SideStopDefinition:
	return _active_stop_def if _active_stop_def else _pending_stop


## True from stop-fork choice until the van has left the bay — blocks wave combat.
func is_stop_visit_active() -> bool:
	if _stop_pending:
		return true
	if is_instance_valid(_active_stop):
		return true
	if _turn_state in [TurnState.PARKING, TurnState.LEAVING_STOP, TurnState.ELEVATING]:
		return true
	return GameSession.phase in [GameSession.RunPhase.PARKING, GameSession.RunPhase.STOP]


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
	_world.spawn_act_statue()


func end_act_statue_stop() -> void:
	_act_reveal_pending = false
	_world.clear_act_statue()


func force_next_stop(stop_id: StringName) -> bool:
	return force_stop_def(SideStopRegistry.load_by_id(stop_id))


func force_stop_def(stop: SideStopDefinition) -> bool:
	if stop == null or stop.scene == null:
		return false
	_forced_next_stop = stop
	return true


func leave_stop() -> void:
	if GameSession.phase != GameSession.RunPhase.STOP:
		return
	if _turn_state == TurnState.ELEVATING:
		return
	if not is_instance_valid(_active_stop):
		_stops.clear_stop_state()
		GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
		return
	var van := get_node("../..")
	if van and van.has_method(&"seal_van_after_stop"):
		van.seal_van_after_stop()
	elif van and van.has_method(&"seal_van_after_shop"):
		van.seal_van_after_shop()
	if _stops.is_elevator_stop():
		_begin_elevator_ascent()
		return
	_routes.build_leave_stop_route()


func leave_shop() -> void:
	leave_stop()


func _physics_process(delta: float) -> void:
	_tick_speed_orders(delta)
	if _turn_state == TurnState.ELEVATING:
		_stops.sync_elevator_platform()
		_stops.keep_player_on_van_rig()
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
	_world.spawn_segments_ahead()
	_routes.maybe_begin_stop_park()
	_update_turn()
	_world.prune_world()


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
		_stops.prepare_stop_fork()
		_world.spawn_approaching_junction()


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


func _update_turn() -> void:
	if _turn_state == TurnState.TURNING:
		if van_follow.progress >= _turn_end_progress:
			_routes.finish_turn()
	elif _turn_state == TurnState.PARKING:
		if van_follow.progress <= 0.05:
			_routes.finish_park()
	elif _turn_state == TurnState.LEAVING_STOP:
		if van_follow.progress >= _turn_end_progress:
			_routes.finish_leave_stop()


func _begin_elevator_descent() -> void:
	van_follow.progress = _stop_align_progress
	van_rig.transform = Transform3D.IDENTITY
	_stop_align_progress = INF
	_segment_spawning_paused = true
	_turn_state = TurnState.ELEVATING
	_park_reversing = false
	_refresh_travel_speed()
	GameSession.set_phase(GameSession.RunPhase.PARKING)
	process_physics_priority = 100
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"open_shaft"):
		_active_stop.open_shaft(corridor_root, van_rig.global_position)
	_sequence_id += 1
	_run_elevator_ride(_sequence_id, -_stops.elevator_depth(), true)


func _begin_elevator_ascent() -> void:
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"set_docked"):
		_active_stop.set_docked(false)
	if is_instance_valid(_active_stop) and _active_stop.has_method(&"close_door"):
		_active_stop.close_door()
	_turn_state = TurnState.ELEVATING
	_segment_spawning_paused = true
	_refresh_travel_speed()
	process_physics_priority = 100
	_sequence_id += 1
	_run_elevator_ride(_sequence_id, 0.0, false)


func _run_elevator_ride(id: int, target_offset: float, opening: bool) -> void:
	if not opening:
		await get_tree().create_timer(scale_debug_wait(_DOOR_OPEN_DURATION)).timeout
		if id != _sequence_id:
			return
	var duration := _stops.elevator_ride_seconds()
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(van_follow, "v_offset", target_offset, duration)
	await tween.finished
	if id != _sequence_id:
		return
	if opening:
		_stops.finish_elevator_descent()
	else:
		_stops.finish_elevator_ascent()


func _exit_tree() -> void:
	set_process(false)
	for piece in _world_pieces:
		if is_instance_valid(piece):
			piece.free()
	_world_pieces.clear()
	_active_junction = null
	_active_stop = null
	_active_statue = null
