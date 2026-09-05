class_name BikerBoss
extends WindowRaider

## Wanjna: hit-and-run biker. Fast charge, slow axe on a door, peel and weave.
## Never climbs in until every door and window is already passable.

enum BikePhase { IDLE, CHARGE, WINDUP, PEEL, WEAVE, ENTERING, BENCH }

@export var windup_seconds := 2.0
@export var peel_distance := 28.0
@export var peel_speed := 12.0
@export var weave_seconds := 4.0
@export var weave_amplitude := 3.2
@export var weave_frequency := 1.05
@export var charge_speed_mult := 1.85
@export var summon_interval := 5.0
@export var summon_cap := 3

var _bike_phase: BikePhase = BikePhase.IDLE
var _weave_time := 0.0
var _standoff_z := 19.2
var _charge_start_dist := 1.0
var _charge_arrived := true
var _peel_arrived := true


func _ready() -> void:
	super._ready()
	mark_as_boss()


func _physics_process(delta: float) -> void:
	if not _active or is_defeated:
		return
	match _bike_phase:
		BikePhase.CHARGE:
			_physics_charge(delta)
		BikePhase.WINDUP:
			if _attach_marker and is_instance_valid(_attach_marker):
				_snap_to_marker(_attach_marker)
		BikePhase.PEEL:
			_physics_peel(delta)
		BikePhase.WEAVE:
			_physics_weave(delta)
		_:
			super._physics_process(delta)


func begin_assault(breach: BreachPoint, world_speed: float) -> void:
	if _active or is_defeated:
		return
	assigned_breach = breach
	mob_world_speed = world_speed
	approach_speed = world_speed * charge_speed_mult - _current_van_speed()
	_active = true
	var controller := _breach_controller()
	var ref_z := controller.get_rear_outside_reference_z() if controller else 5.2
	_standoff_z = ref_z + peel_distance
	_run_bike_assault()
	_summon_loop()


func _run_assault() -> void:
	# Goon smash-and-climb loop. The bike fight owns begin_assault instead.
	pass


func _clear_motion() -> void:
	super._clear_motion()
	_charge_arrived = true
	_peel_arrived = true


func _run_bike_assault() -> void:
	while _active and is_inside_tree() and not is_defeated:
		var controller := _breach_controller()
		if controller == null:
			return
		if controller.all_breaches_passable():
			await _enter_van()
			return
		var door := controller.next_closed_door(assigned_breach)
		if door == null:
			await _weave_hold()
			continue
		assigned_breach = door
		if not door.is_passable():
			door.claim(self)
		await _charge_to(door)
		if not _active or is_defeated:
			return
		if controller.all_breaches_passable():
			_release_breach()
			await _enter_van()
			return
		if not is_instance_valid(door) or door.is_passable():
			_release_breach()
			continue
		await _windup_and_smash(door)
		if not _active or is_defeated:
			return
		_release_breach()
		await _peel_and_weave()


func _charge_to(door: BreachPoint) -> void:
	_bike_phase = BikePhase.CHARGE
	assault_phase = AssaultPhase.APPROACH
	_attach_marker = null
	_charge_arrived = false
	_weave_time = 0.0
	_move_marker = door.outside_marker
	var parent_3d := get_parent() as Node3D
	if parent_3d and door.outside_marker:
		var target := parent_3d.to_local(door.outside_marker.global_position)
		_charge_start_dist = maxf(position.distance_to(target), 1.0)
	while _active and is_inside_tree() and not is_defeated and not _charge_arrived:
		var controller := _breach_controller()
		if controller and controller.all_breaches_passable():
			_charge_arrived = true
			break
		await get_tree().physics_frame
	_move_marker = null
	_bike_phase = BikePhase.IDLE


func _windup_and_smash(door: BreachPoint) -> void:
	_bike_phase = BikePhase.WINDUP
	assault_phase = AssaultPhase.BREACHING
	_attach_marker = door.outside_marker
	var wait := _scale_wait(windup_seconds)
	if sprite:
		var pulse := create_tween()
		pulse.tween_property(sprite, "scale", Vector3.ONE * 1.18, wait * 0.75)
		pulse.tween_property(sprite, "scale", Vector3.ONE, wait * 0.25)
	await get_tree().create_timer(wait).timeout
	if sprite:
		sprite.scale = Vector3.ONE
	if not _active or is_defeated:
		return
	if is_instance_valid(door) and not door.is_passable():
		var outgoing := _outgoing_damage()
		door.take_damage(outgoing)
		attack_landed.emit(outgoing)
	_attach_marker = null
	_bike_phase = BikePhase.IDLE


func _peel_and_weave() -> void:
	await _peel_to_standoff()
	if not _active or is_defeated:
		return
	_bike_phase = BikePhase.WEAVE
	_weave_time = 0.0
	var elapsed := 0.0
	while _active and is_inside_tree() and not is_defeated and elapsed < weave_seconds:
		var controller := _breach_controller()
		if controller and controller.all_breaches_passable():
			break
		elapsed += get_physics_process_delta_time()
		await get_tree().physics_frame
	_bike_phase = BikePhase.IDLE


func _weave_hold() -> void:
	if absf(position.z - _standoff_z) > 0.5:
		await _peel_to_standoff()
	if not _active or is_defeated:
		return
	_bike_phase = BikePhase.WEAVE
	_weave_time = 0.0
	while _active and is_inside_tree() and not is_defeated:
		var controller := _breach_controller()
		if controller == null:
			break
		if controller.all_breaches_passable() or not controller.all_doors_passable():
			break
		await get_tree().physics_frame
	_bike_phase = BikePhase.IDLE


func _peel_to_standoff() -> void:
	_bike_phase = BikePhase.PEEL
	_peel_arrived = false
	var controller := _breach_controller()
	var ref_z := controller.get_rear_outside_reference_z() if controller else 5.2
	_standoff_z = ref_z + peel_distance
	while _active and is_inside_tree() and not is_defeated and not _peel_arrived:
		await get_tree().physics_frame
	_bike_phase = BikePhase.IDLE


func _enter_van() -> void:
	_bike_phase = BikePhase.ENTERING
	assault_phase = AssaultPhase.ENTERING
	_attach_marker = null
	_move_marker = null
	_release_breach()
	var controller := _breach_controller()
	var door: BreachPoint = controller.first_passable_door() if controller else assigned_breach
	var interior_speed := GameBalance.MOB_INTERIOR_SPEED
	if door:
		assigned_breach = door
		await _move_to_marker(door.entry_marker, interior_speed, false)
		if not _active or is_defeated:
			return
	_bike_phase = BikePhase.BENCH
	await _run_interior_combat()


func _summon_loop() -> void:
	_try_summon()
	while _active and is_inside_tree() and not is_defeated:
		await get_tree().create_timer(_scale_wait(summon_interval)).timeout
		if not _active or is_defeated:
			return
		_try_summon()


func _try_summon() -> void:
	if _alive_add_count() >= summon_cap:
		return
	var director := get_tree().get_first_node_in_group(&"encounter_director")
	if director and director.has_method(&"spawn_agile_raider"):
		director.spawn_agile_raider()


func _alive_add_count() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node == self:
			continue
		if bool(node.get("is_boss")):
			continue
		if bool(node.get("is_defeated")):
			continue
		n += 1
	return n


func _physics_charge(delta: float) -> void:
	var parent_3d := get_parent() as Node3D
	if parent_3d == null or not is_instance_valid(_move_marker):
		_charge_arrived = true
		return
	var target_local := parent_3d.to_local(_move_marker.global_position)
	var remaining := position.distance_to(target_local)
	var speed := mob_world_speed * charge_speed_mult - _current_van_speed()
	approach_speed = speed
	var progress := 1.0 - clampf(remaining / _charge_start_dist, 0.0, 1.0)
	var amp := weave_amplitude * (1.0 - progress)
	_weave_time += delta
	var woven := target_local
	woven.x += _weave_offset(_weave_time, amp)
	var to_woven := woven - position
	var woven_dist := to_woven.length()
	if remaining <= 0.05:
		if speed < 0.0:
			return
		position = target_local
		global_transform.basis = _move_marker.global_transform.basis
		_charge_arrived = true
		return
	if speed > 0.0 and woven_dist > 0.001:
		position += to_woven / woven_dist * minf(speed * delta, woven_dist)
	elif speed < 0.0:
		var to_real := target_local - position
		var real_dist := to_real.length()
		if real_dist > 0.001:
			position -= to_real / real_dist * (-speed) * delta


func _physics_peel(delta: float) -> void:
	var target := Vector3(0.0, position.y, _standoff_z)
	var to_target := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var remaining := to_target.length()
	if remaining <= 0.08:
		position.x = target.x
		position.z = target.z
		_peel_arrived = true
		return
	position += to_target / remaining * minf(peel_speed * delta, remaining)


func _physics_weave(delta: float) -> void:
	_weave_time += delta
	position.x = _weave_offset(_weave_time, weave_amplitude)
	position.z = _standoff_z


func _weave_offset(t: float, amp: float) -> float:
	var omega := TAU * weave_frequency
	return sin(t * omega) * amp + sin(t * omega * 2.3) * amp * 0.4


func _scale_wait(seconds: float) -> float:
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_method(&"scale_debug_wait"):
		return travel.scale_debug_wait(seconds)
	return seconds
