class_name EncounterDirector
extends Node

@export var travel_before_encounter := 2.5
## Soft cap: after this, surviving raiders of the current wave retreat.
@export var combat_duration := 18.0
@export var rest_duration := 10.0

@onready var enemy_container: Node3D = $"../../TravelPath/VanFollow/VanRig/EnemyContainer"
@onready var rear_spawn: Marker3D = (
	$"../../TravelPath/VanFollow/VanRig/EnemyContainer/RearSpawnMarker"
)
@onready var breach_controller: BreachController = (
	$"../../TravelPath/VanFollow/VanRig/EnemyContainer/BreachController"
)

var _sequence_id := 0
var _running := false


func _ready() -> void:
	add_to_group(&"encounter_director")
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.chill_mode_changed.connect(_on_chill_mode_changed)
	call_deferred("_sync_spawn_marker_to_balance")
	if GameSession.phase == GameSession.RunPhase.TRAVELLING and _encounters_enabled():
		_schedule_encounter()


## Keep RearSpawnMarker on the balance spawn line for debug / scene intuition.
func _sync_spawn_marker_to_balance() -> void:
	if rear_spawn == null or breach_controller == null:
		return
	var ref_z := breach_controller.get_rear_outside_reference_z()
	rear_spawn.position.z = ref_z + GameBalance.SPAWN_DISTANCE


func _encounters_enabled() -> bool:
	if GameSession.route_step <= 0 or GameSession.chill_mode:
		return false
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_method(&"is_shop_visit_active") and travel.is_shop_visit_active():
		return false
	return true


func _on_chill_mode_changed(enabled: bool) -> void:
	if enabled:
		_cancel_encounters()
	elif GameSession.phase == GameSession.RunPhase.TRAVELLING and not _running and _encounters_enabled():
		_schedule_encounter()


func _cancel_encounters() -> void:
	_sequence_id += 1
	_running = false
	# Chill aborts the async segment; without this, phase stays COMBAT/REST and
	# unchill never re-enters the TRAVELLING encounter loop.
	if GameSession.phase in [GameSession.RunPhase.COMBAT, GameSession.RunPhase.REST]:
		GameSession.set_phase(GameSession.RunPhase.TRAVELLING)


func spawn_debug_raider() -> String:
	var raider := _spawn_raider(0, 1)
	if raider == null:
		return "Failed to spawn raider."
	return "Spawned raider → %s." % (
		String(raider.assigned_breach.point_id) if raider.assigned_breach else "free"
	)


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	if next_phase == GameSession.RunPhase.TRAVELLING and not _running and _encounters_enabled():
		_schedule_encounter()
	elif next_phase in [
		GameSession.RunPhase.GAME_OVER,
		GameSession.RunPhase.PARKING,
		GameSession.RunPhase.SHOP,
	]:
		_cancel_encounters_keep_phase()


func _cancel_encounters_keep_phase() -> void:
	_sequence_id += 1
	_running = false


func _schedule_encounter() -> void:
	_running = true
	_sequence_id += 1
	var id := _sequence_id
	await get_tree().create_timer(travel_before_encounter).timeout
	if id != _sequence_id or GameSession.phase != GameSession.RunPhase.TRAVELLING:
		_running = false
		return
	GameSession.set_phase(GameSession.RunPhase.COMBAT)
	await _run_segment(id)


func _run_segment(id: int) -> void:
	var plan := GameBalance.build_segment_wave_plan(GameSession.route_step)
	for wave_i in plan.size():
		if id != _sequence_id or GameSession.phase == GameSession.RunPhase.GAME_OVER:
			_running = false
			return
		var count: int = plan[wave_i]
		await _run_wave(id, count)
		if id != _sequence_id or GameSession.phase == GameSession.RunPhase.GAME_OVER:
			_running = false
			return
		GameSession.complete_wave()
		var more_waves := wave_i < plan.size() - 1
		if more_waves:
			await get_tree().create_timer(GameBalance.INTER_WAVE_DELAY).timeout

	if id != _sequence_id or GameSession.phase == GameSession.RunPhase.GAME_OVER:
		_running = false
		return

	_running = false
	GameSession.set_phase(GameSession.RunPhase.REST)
	SaveManager.save_active_session()
	await _wait_for_rest_break(rest_duration)
	if id == _sequence_id and GameSession.phase == GameSession.RunPhase.REST:
		GameSession.set_phase(GameSession.RunPhase.ROUTE_CHOICE)


func _run_wave(id: int, count: int) -> void:
	var raiders: Array[WindowRaider] = []
	for slot in count:
		if slot > 0:
			var delay := randf_range(GameBalance.SPAWN_DELAY_MIN, GameBalance.SPAWN_DELAY_MAX)
			await get_tree().create_timer(delay).timeout
			if id != _sequence_id or GameSession.phase == GameSession.RunPhase.GAME_OVER:
				return
		var raider := _spawn_raider(slot, count)
		if raider:
			raiders.append(raider)

	if raiders.is_empty():
		return

	# Approach is unpaid — wave can end early if the pack dies on the way.
	while (
		_any_approaching(raiders)
		and GameSession.phase != GameSession.RunPhase.GAME_OVER
		and id == _sequence_id
	):
		await get_tree().process_frame

	if id != _sequence_id or GameSession.phase == GameSession.RunPhase.GAME_OVER:
		_despawn_raiders(raiders)
		return
	if not _any_alive(raiders):
		return

	var elapsed := 0.0
	var timeout := combat_duration + maxf(0.0, float(count - 1) * 4.0)
	while (
		elapsed < timeout
		and _any_alive(raiders)
		and GameSession.phase != GameSession.RunPhase.GAME_OVER
		and id == _sequence_id
	):
		elapsed += get_process_delta_time()
		await get_tree().process_frame

	if id != _sequence_id or GameSession.phase == GameSession.RunPhase.GAME_OVER:
		_despawn_raiders(raiders)
		return

	for raider in raiders:
		if is_instance_valid(raider) and not raider.is_defeated:
			raider.retreat()


func _spawn_raider(slot: int, count: int) -> WindowRaider:
	var enemy_def := GameBalance.pick_spawn_enemy()
	if enemy_def == null or enemy_def.scene == null:
		return null
	var raider := enemy_def.scene.instantiate() as WindowRaider
	if raider == null:
		return null
	raider.is_agile = enemy_def.is_agile
	enemy_container.add_child(raider)
	# Place on the balance spawn line in EnemyContainer space (+Z = behind van).
	# Mob world speed is derived so that at the expected upgraded van speed,
	# rear-door paths take act_engagement_seconds. Live closing tracks travel_speed.
	var ref_z := breach_controller.get_rear_outside_reference_z()
	var jitter := GameBalance.spawn_offset_for_slot(slot, count)
	var local_pos := Vector3(
		jitter.x,
		rear_spawn.position.y,
		ref_z + GameBalance.SPAWN_DISTANCE + jitter.z
	)
	raider.transform = Transform3D(rear_spawn.transform.basis, local_pos)
	var world_speed := GameBalance.get_mob_world_speed(GameSession.route_step)
	var breach := breach_controller.assign_breach_point(raider)
	if breach:
		raider.begin_assault(breach, world_speed)
	else:
		raider.mob_world_speed = world_speed
		raider.approach_speed = GameBalance.get_closing_speed(
			GameSession.route_step, MetaProgression.get_van_speed()
		)
		raider.activate()
	return raider


func _any_alive(raiders: Array[WindowRaider]) -> bool:
	for raider in raiders:
		if is_instance_valid(raider) and not raider.is_defeated:
			return true
	return false


func _any_approaching(raiders: Array[WindowRaider]) -> bool:
	for raider in raiders:
		if (
			is_instance_valid(raider)
			and not raider.is_defeated
			and raider.assault_phase == WindowRaider.AssaultPhase.APPROACH
		):
			return true
	return false


func _despawn_raiders(raiders: Array[WindowRaider]) -> void:
	for raider in raiders:
		if is_instance_valid(raider):
			raider.queue_free()


func _wait_for_rest_break(min_seconds: float) -> void:
	var timer := get_tree().create_timer(min_seconds)
	var rewards := get_tree().get_first_node_in_group(&"boon_reward_controller") as BoonRewardController
	if rewards:
		await rewards.wait_for_rest_resolution()
	await timer.timeout
