class_name EncounterDirector
extends Node

@export var travel_before_encounter := 2.5
@export var combat_duration := 6.0
@export var waves_per_route := 10
@export var rest_duration := 10.0
@export var raider_scene: PackedScene

@onready var enemy_container: Node3D = $"../../TravelPath/VanFollow/VanRig/EnemyContainer"
@onready var rear_marker: Marker3D = (
	$"../../TravelPath/VanFollow/VanRig/EnemyContainer/RearAttackMarker"
)
@onready var rear_spawn: Marker3D = (
	$"../../TravelPath/VanFollow/VanRig/EnemyContainer/RearSpawnMarker"
)

var _sequence_id := 0
var _running := false


func _ready() -> void:
	add_to_group(&"encounter_director")
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.chill_mode_changed.connect(_on_chill_mode_changed)
	if GameSession.phase == GameSession.RunPhase.TRAVELLING and _encounters_enabled():
		_schedule_encounter()


func _encounters_enabled() -> bool:
	return GameSession.route_step > 0 and not GameSession.chill_mode


func _on_chill_mode_changed(enabled: bool) -> void:
	if enabled:
		_cancel_encounters()
	elif GameSession.phase == GameSession.RunPhase.TRAVELLING and not _running and _encounters_enabled():
		_schedule_encounter()


func _cancel_encounters() -> void:
	_sequence_id += 1
	_running = false


func spawn_debug_raider() -> String:
	var raider := raider_scene.instantiate() as WindowRaider
	enemy_container.add_child(raider)
	raider.global_transform = rear_marker.global_transform
	raider.attack_landed.connect(GameSession.damage_van)
	raider.activate()
	return "Spawned raider at rear window."


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	if next_phase == GameSession.RunPhase.TRAVELLING and not _running and _encounters_enabled():
		_schedule_encounter()
	elif next_phase == GameSession.RunPhase.GAME_OVER:
		_cancel_encounters()


func _schedule_encounter() -> void:
	_running = true
	_sequence_id += 1
	var id := _sequence_id
	await get_tree().create_timer(travel_before_encounter).timeout
	if id != _sequence_id or GameSession.phase != GameSession.RunPhase.TRAVELLING:
		_running = false
		return
	GameSession.set_phase(GameSession.RunPhase.COMBAT)
	await _run_encounter(id)


func _run_encounter(id: int) -> void:
	var raider := raider_scene.instantiate() as WindowRaider
	enemy_container.add_child(raider)
	raider.global_transform = rear_spawn.global_transform
	raider.approach_speed = GameBalance.get_mob_approach_speed(GameSession.route_step)

	while true:
		if id != _sequence_id or GameSession.phase == GameSession.RunPhase.GAME_OVER:
			if is_instance_valid(raider):
				raider.queue_free()
			return
		if not is_instance_valid(raider) or raider.is_defeated:
			await _complete_wave(id)
			return

		var target := _raider_approach_target()
		var to_target := target - raider.global_position
		var remaining := to_target.length()
		if remaining <= 0.05:
			break

		var delta := get_process_delta_time()
		var step := minf(raider.approach_speed * delta, remaining)
		raider.global_position += to_target.normalized() * step
		await get_tree().process_frame

	var doors := _rear_doors()
	if doors == null or doors.is_passage_open():
		raider.global_transform = rear_marker.global_transform
	else:
		raider.global_position = doors.get_outside_hold_position()
		raider.global_basis = rear_marker.global_basis
	raider.attack_landed.connect(GameSession.damage_van)
	raider.activate()

	var elapsed := 0.0
	while (
		elapsed < combat_duration
		and is_instance_valid(raider)
		and not raider.is_defeated
		and GameSession.phase != GameSession.RunPhase.GAME_OVER
	):
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	if is_instance_valid(raider) and not raider.is_defeated:
		raider.retreat()
	if id == _sequence_id and GameSession.phase != GameSession.RunPhase.GAME_OVER:
		await _complete_wave(id)


func _raider_approach_target() -> Vector3:
	var doors := _rear_doors()
	if doors and not doors.is_passage_open():
		return doors.get_outside_hold_position()
	return rear_marker.global_position


func _rear_doors() -> Node:
	return get_tree().get_first_node_in_group(&"rear_doors")


func _complete_wave(id: int) -> void:
	if id != _sequence_id or GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	GameSession.complete_wave()
	_running = false
	if GameSession.wave_count % waves_per_route != 0:
		GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
		return

	GameSession.set_phase(GameSession.RunPhase.REST)
	SaveManager.save_active_session()
	await _wait_for_rest_break(rest_duration)
	if id == _sequence_id and GameSession.phase == GameSession.RunPhase.REST:
		GameSession.set_phase(GameSession.RunPhase.ROUTE_CHOICE)


func _wait_for_rest_break(min_seconds: float) -> void:
	var timer := get_tree().create_timer(min_seconds)
	var rewards := get_tree().get_first_node_in_group(&"boon_reward_controller") as BoonRewardController
	if rewards:
		await rewards.wait_for_rest_resolution()
	await timer.timeout
