extends Node

signal phase_changed(phase: RunPhase)
signal van_health_changed(current: float, maximum: float)
signal route_chosen(direction: StringName, step: int)
signal wave_changed(wave: int)
signal room_changed(room: StringName)
signal coins_changed(total: int)
signal enemy_defeated(enemy: Node)
signal session_loaded
signal chill_mode_changed(enabled: bool)
signal area_changed(area: ItemDefinition.BoonPool)

enum RunPhase {
	IDLE,
	TRAVELLING,
	COMBAT,
	ROUTE_CHOICE,
	TURNING,
	GAME_OVER,
	REST,
}

const BASE_MAX_VAN_HEALTH := 100.0

var selected_slot := 0
var run_seed := 0
var route_step := 0
var wave_count := 0
var last_direction: StringName = &"straight"
var current_room: StringName = &"center"
var van_max_health := BASE_MAX_VAN_HEALTH
var van_health := BASE_MAX_VAN_HEALTH
var phase := RunPhase.IDLE
var coins := 0
var chill_mode := false
var current_area: ItemDefinition.BoonPool = ItemDefinition.BoonPool.GENERAL

const _LEFT_AREA_CYCLE: Array[ItemDefinition.BoonPool] = [
	ItemDefinition.BoonPool.FIRE,
	ItemDefinition.BoonPool.COLD,
	ItemDefinition.BoonPool.POISON,
	ItemDefinition.BoonPool.PHYSICAL,
]
const _RIGHT_AREA_CYCLE: Array[ItemDefinition.BoonPool] = [
	ItemDefinition.BoonPool.PHYSICAL,
	ItemDefinition.BoonPool.POISON,
	ItemDefinition.BoonPool.COLD,
	ItemDefinition.BoonPool.FIRE,
]


func start_new(slot: int) -> void:
	selected_slot = slot
	run_seed = randi()
	route_step = 0
	wave_count = 0
	last_direction = &"straight"
	current_room = &"center"
	van_max_health = BASE_MAX_VAN_HEALTH
	van_health = BASE_MAX_VAN_HEALTH
	coins = 0
	current_area = ItemDefinition.BoonPool.GENERAL
	set_chill_mode(false)
	set_phase(RunPhase.IDLE)
	SaveManager.save_active_session()


func load_from_data(slot: int, data: Dictionary) -> void:
	selected_slot = slot
	run_seed = int(data.get("run_seed", randi()))
	route_step = int(data.get("route_step", 0))
	wave_count = int(data.get("wave_count", 0))
	last_direction = StringName(data.get("last_direction", "straight"))
	van_max_health = clampf(
		float(data.get("van_max_health", BASE_MAX_VAN_HEALTH)),
		BASE_MAX_VAN_HEALTH,
		9999.0
	)
	van_health = clampf(float(data.get("van_health", van_max_health)), 0.0, van_max_health)
	coins = maxi(0, int(data.get("coins", 0)))
	set_chill_mode(false)
	var stored_phase := int(data.get("phase", RunPhase.IDLE))
	phase = (stored_phase as RunPhase) if stored_phase in RunPhase.values() else RunPhase.IDLE
	if phase in [RunPhase.COMBAT, RunPhase.ROUTE_CHOICE, RunPhase.REST, RunPhase.TURNING]:
		phase = RunPhase.TRAVELLING
	van_health_changed.emit(van_health, van_max_health)
	wave_changed.emit(wave_count)
	coins_changed.emit(coins)
	phase_changed.emit(phase)
	session_loaded.emit()


func begin_run() -> void:
	if phase != RunPhase.IDLE:
		return
	set_phase(RunPhase.TRAVELLING)
	SaveManager.save_active_session()


func set_room(room: StringName) -> void:
	if current_room == room:
		return
	current_room = room
	room_changed.emit(room)


func set_phase(next_phase: RunPhase) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)


func set_chill_mode(enabled: bool) -> void:
	if chill_mode == enabled:
		return
	chill_mode = enabled
	chill_mode_changed.emit(enabled)


func get_max_van_health() -> float:
	return van_max_health


func add_max_van_health(amount: float) -> void:
	if is_zero_approx(amount):
		return
	van_max_health = maxf(BASE_MAX_VAN_HEALTH, van_max_health + amount)
	if amount > 0.0:
		van_health += amount
	else:
		van_health = minf(van_health, van_max_health)
	van_health_changed.emit(van_health, van_max_health)


func damage_van(amount: float) -> void:
	if amount <= 0.0 or phase == RunPhase.GAME_OVER:
		return
	van_health = maxf(0.0, van_health - amount)
	van_health_changed.emit(van_health, van_max_health)
	if is_zero_approx(van_health):
		set_phase(RunPhase.GAME_OVER)


func is_van_at_full_health() -> bool:
	return van_health >= van_max_health - 0.001


func heal_van(amount: float) -> void:
	if amount <= 0.0 or phase == RunPhase.GAME_OVER:
		return
	van_health = minf(van_max_health, van_health + amount)
	van_health_changed.emit(van_health, van_max_health)


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)


func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


func notify_enemy_defeated(enemy: Node) -> void:
	if enemy:
		enemy_defeated.emit(enemy)


func complete_wave() -> void:
	wave_count += 1
	wave_changed.emit(wave_count)


func choose_route(direction: StringName) -> void:
	if phase != RunPhase.ROUTE_CHOICE or direction not in [&"left", &"right"]:
		return
	last_direction = direction
	route_step += 1
	current_area = _resolve_area_for_fork(direction, route_step)
	area_changed.emit(current_area)
	route_chosen.emit(direction, route_step)
	set_phase(RunPhase.TURNING)
	SaveManager.save_active_session()


func get_rest_area() -> ItemDefinition.BoonPool:
	if route_step <= 0:
		return ItemDefinition.BoonPool.GENERAL
	return current_area


func _resolve_area_for_fork(direction: StringName, step: int) -> ItemDefinition.BoonPool:
	var index := (step - 1) % 4
	if direction == &"left":
		return _LEFT_AREA_CYCLE[index]
	return _RIGHT_AREA_CYCLE[index]


func to_save_data() -> Dictionary:
	return {
		"version": 1,
		"run_seed": run_seed,
		"route_step": route_step,
		"wave_count": wave_count,
		"last_direction": String(last_direction),
		"van_health": van_health,
		"van_max_health": van_max_health,
		"coins": coins,
		"phase": phase,
		"saved_at": Time.get_datetime_string_from_system(),
	}
