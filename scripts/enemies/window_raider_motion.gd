extends RefCounted

## Per-frame chase math for WindowRaider. No await: called straight from _physics_process.

var raider: Node3D  # the WindowRaider; reads/writes its fields when called


func _init(owner: Node3D) -> void:
	raider = owner


func physics_chase_target(delta: float) -> void:
	var parent_3d := raider.get_parent() as Node3D
	if parent_3d == null:
		raider._move_arrived = true
		return
	var target_local: Vector3 = raider._move_target_local
	if raider._move_marker and is_instance_valid(raider._move_marker):
		target_local = parent_3d.to_local(raider._move_marker.global_position)
	var to_target := target_local - raider.position
	to_target.y = 0.0
	var remaining := to_target.length()
	var speed: float = raider._move_speed
	if raider._move_use_van_relative:
		# World chase vs live van speed. Boost → lower/negative closing → gain distance.
		speed = raider.mob_world_speed - raider._current_van_speed()
		raider.approach_speed = speed
	speed = raider._apply_status_move_speed(speed)
	if remaining <= 0.05:
		if speed < 0.0:
			# Van still pulling away — don't latch onto the marker yet.
			return
		raider.position.x = target_local.x
		raider.position.z = target_local.z
		if raider._move_marker and is_instance_valid(raider._move_marker):
			raider.global_transform.basis = raider._move_marker.global_transform.basis
		raider._move_arrived = true
		return
	if is_zero_approx(remaining):
		return
	var direction := to_target / remaining
	if speed > 0.0:
		raider.position += direction * minf(speed * delta, remaining)
	elif speed < 0.0:
		# Fall behind along the approach axis (ready for van-boost distance gains).
		raider.position -= direction * (-speed) * delta


func physics_chase_player(delta: float) -> void:
	var player := raider.get_tree().get_first_node_in_group(&"player") as Node3D
	var parent_3d := raider.get_parent() as Node3D
	if player == null or parent_3d == null:
		raider._move_arrived = true
		return
	var target_local := parent_3d.to_local(player.global_position)
	target_local.y = raider.position.y
	var to_target := target_local - raider.position
	to_target.y = 0.0
	var remaining := to_target.length()
	if remaining <= raider._MELEE_RANGE:
		raider._move_arrived = true
		return
	raider._move_arrived = false
	var speed := GameBalance.MOB_INTERIOR_SPEED
	speed = raider._apply_status_move_speed(speed)
	var step := minf(speed * delta, remaining - raider._MELEE_RANGE + 0.02)
	if remaining > 0.001:
		raider.position += to_target / remaining * step
