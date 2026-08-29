class_name TravelController
extends Node

enum TurnState {
	NONE,
	APPROACHING,
	ROTATING,
}

@export var travel_speed := 8.0
@export var segment_scene: PackedScene
@export var t_junction_scene: PackedScene
@export var segment_length := 20.0
@export var segment_count := 5
@export var intro_peace_seconds := 4.0
@export var intro_rest_seconds := 10.0
@export var junction_spawn_z := -55.0
@export var junction_turn_z := 0.0
@export var turn_rotate_duration := 2.0

var distance := 0.0

var _segments: Array[Node3D] = []
var _segment_offsets: Array[float] = []
var _intro_handled := false
var _sequence_id := 0
var _turn_state := TurnState.NONE
var _turn_direction: StringName = &""
var _active_junction: Node3D
var _turn_tween: Tween

@onready var corridor_root: Node3D = $"../../ExteriorCorridor"


func _ready() -> void:
	_spawn_segments()
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.route_chosen.connect(_on_route_chosen)
	if GameSession.phase == GameSession.RunPhase.TRAVELLING:
		_maybe_start_intro()


func _spawn_segments() -> void:
	for segment in _segments:
		if is_instance_valid(segment):
			segment.queue_free()
	_segments.clear()
	_segment_offsets.clear()
	for index in range(segment_count):
		var segment := segment_scene.instantiate() as Node3D
		corridor_root.add_child(segment)
		var z := float(index - 2) * segment_length
		segment.position = Vector3(0.0, 0.0, z)
		_segments.append(segment)
		_segment_offsets.append(z)


func _process(delta: float) -> void:
	if not _should_scroll():
		return
	var movement := travel_speed * delta
	distance += movement
	if _turn_state != TurnState.ROTATING:
		_scroll_segments(movement)
	_update_turn()


func _should_scroll() -> bool:
	return GameSession.phase in [
		GameSession.RunPhase.TRAVELLING,
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.REST,
		GameSession.RunPhase.TURNING,
		GameSession.RunPhase.ROUTE_CHOICE,
	]


func _scroll_segments(movement: float) -> void:
	for index in range(_segment_offsets.size()):
		_segment_offsets[index] += movement
		_segments[index].position.z = _segment_offsets[index]
		if _segment_offsets[index] > segment_length * 2.5:
			_segment_offsets[index] -= segment_length * segment_count
			_segments[index].position.z = _segment_offsets[index]
	if is_instance_valid(_active_junction):
		_active_junction.position.z += movement


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
	await get_tree().create_timer(intro_rest_seconds).timeout
	if id == _sequence_id and GameSession.phase == GameSession.RunPhase.REST:
		GameSession.set_phase(GameSession.RunPhase.ROUTE_CHOICE)


func _spawn_approaching_junction() -> void:
	if is_instance_valid(_active_junction) or _turn_state != TurnState.NONE:
		return
	_turn_state = TurnState.APPROACHING
	_turn_direction = &""
	_active_junction = t_junction_scene.instantiate() as Node3D
	corridor_root.add_child(_active_junction)
	_active_junction.position = Vector3(0.0, 0.0, junction_spawn_z)


func _on_route_chosen(direction: StringName, _step: int) -> void:
	if _turn_state != TurnState.APPROACHING or not is_instance_valid(_active_junction):
		return
	_turn_direction = direction


func _update_turn() -> void:
	if _turn_state == TurnState.NONE or not is_instance_valid(_active_junction):
		return
	if (
		_turn_state == TurnState.APPROACHING
		and _turn_direction != &""
		and _active_junction.position.z >= junction_turn_z
	):
		_begin_corridor_rotation()


func _begin_corridor_rotation() -> void:
	if _turn_state != TurnState.APPROACHING:
		return
	_turn_state = TurnState.ROTATING
	if _turn_tween:
		_turn_tween.kill()
	# Left branch runs along -X; rotate corridor so it becomes the new forward (-Z).
	var delta_yaw := -PI * 0.5 if _turn_direction == &"left" else PI * 0.5
	_turn_tween = create_tween()
	_turn_tween.tween_property(
		corridor_root,
		"rotation:y",
		corridor_root.rotation.y + delta_yaw,
		turn_rotate_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn_tween.finished.connect(_on_corridor_rotation_finished)


func _on_corridor_rotation_finished() -> void:
	if _turn_state != TurnState.ROTATING:
		return
	_finish_turn()


func _finish_turn() -> void:
	if _turn_tween:
		_turn_tween.kill()
		_turn_tween = null
	corridor_root.rotation.y = 0.0
	if is_instance_valid(_active_junction):
		_active_junction.queue_free()
		_active_junction = null
	_spawn_segments()
	_turn_state = TurnState.NONE
	_turn_direction = &""
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
