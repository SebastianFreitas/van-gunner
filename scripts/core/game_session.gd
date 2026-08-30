extends Node

signal phase_changed(phase: RunPhase)
signal van_health_changed(current: float, maximum: float)
signal route_chosen(direction: StringName, step: int)
signal wave_changed(wave: int)
signal room_changed(room: StringName)
signal coins_changed(total: int)
signal session_loaded

enum RunPhase {
	IDLE,
	TRAVELLING,
	COMBAT,
	ROUTE_CHOICE,
	TURNING,
	GAME_OVER,
	REST,
}

const MAX_VAN_HEALTH := 100.0

var selected_slot := 0
var run_seed := 0
var route_step := 0
var wave_count := 0
var last_direction: StringName = &"straight"
var current_room: StringName = &"center"
var van_health := MAX_VAN_HEALTH
var phase := RunPhase.IDLE
var coins := 0


func start_new(slot: int) -> void:
	selected_slot = slot
	run_seed = randi()
	route_step = 0
	wave_count = 0
	last_direction = &"straight"
	current_room = &"center"
	van_health = MAX_VAN_HEALTH
	coins = 0
	set_phase(RunPhase.IDLE)
	SaveManager.save_active_session()


func load_from_data(slot: int, data: Dictionary) -> void:
	selected_slot = slot
	run_seed = int(data.get("run_seed", randi()))
	route_step = int(data.get("route_step", 0))
	wave_count = int(data.get("wave_count", 0))
	last_direction = StringName(data.get("last_direction", "straight"))
	van_health = clampf(float(data.get("van_health", MAX_VAN_HEALTH)), 0.0, MAX_VAN_HEALTH)
	coins = maxi(0, int(data.get("coins", 0)))
	var stored_phase := int(data.get("phase", RunPhase.IDLE))
	phase = stored_phase if stored_phase in RunPhase.values() else RunPhase.IDLE
	if phase in [RunPhase.COMBAT, RunPhase.ROUTE_CHOICE, RunPhase.REST, RunPhase.TURNING]:
		phase = RunPhase.TRAVELLING
	van_health_changed.emit(van_health, MAX_VAN_HEALTH)
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


func damage_van(amount: float) -> void:
	if amount <= 0.0 or phase == RunPhase.GAME_OVER:
		return
	van_health = maxf(0.0, van_health - amount)
	van_health_changed.emit(van_health, MAX_VAN_HEALTH)
	if is_zero_approx(van_health):
		set_phase(RunPhase.GAME_OVER)


func heal_van(amount: float) -> void:
	if amount <= 0.0 or phase == RunPhase.GAME_OVER:
		return
	van_health = minf(MAX_VAN_HEALTH, van_health + amount)
	van_health_changed.emit(van_health, MAX_VAN_HEALTH)


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)


func complete_wave() -> void:
	wave_count += 1
	wave_changed.emit(wave_count)


func choose_route(direction: StringName) -> void:
	if phase != RunPhase.ROUTE_CHOICE or direction not in [&"left", &"right"]:
		return
	last_direction = direction
	route_step += 1
	route_chosen.emit(direction, route_step)
	set_phase(RunPhase.TURNING)
	SaveManager.save_active_session()


func to_save_data() -> Dictionary:
	return {
		"version": 1,
		"run_seed": run_seed,
		"route_step": route_step,
		"wave_count": wave_count,
		"last_direction": String(last_direction),
		"van_health": van_health,
		"coins": coins,
		"phase": phase,
		"saved_at": Time.get_datetime_string_from_system(),
	}
