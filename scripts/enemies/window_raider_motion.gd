extends RefCounted

## Per-frame chase math for WindowRaider. No await: called straight from _physics_process.

## Origin above the feet: the sprite's bottom row sits this far under the raider's origin.
const FEET_DROP := 1.62
## Origin y that stands the loper's feet on the road (VanRig space) while it is outside.
const ROAD_ORIGIN_Y := VanWheels.ROAD_Y + FEET_DROP
## Horizontal metres over which the loper hops from the road up onto the van floor as it climbs in.
const HOP_RUN := 1.3

var raider: Node3D  # the WindowRaider; reads/writes its fields when called


func _init(owner: Node3D) -> void:
	raider = owner


func _walks_on_road() -> bool:
	return not raider.is_agile and not raider.is_boss


## Outside, the loper runs and claws at the doors from the street.
func keep_feet_on_road() -> void:
	if not _walks_on_road():
		return
	var phase: int = raider.assault_phase
	if phase == WindowRaider.AssaultPhase.APPROACH or phase == WindowRaider.AssaultPhase.BREACHING:
		raider.position.y = ROAD_ORIGIN_Y


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
			keep_feet_on_road()
			return
		raider.position.x = target_local.x
		raider.position.z = target_local.z
		if _walks_on_road() and raider.assault_phase == WindowRaider.AssaultPhase.ENTERING:
			raider.position.y = target_local.y
		else:
			keep_feet_on_road()
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
	if _walks_on_road():
		if raider.assault_phase == WindowRaider.AssaultPhase.ENTERING:
			var hop := smoothstep(0.0, 1.0, 1.0 - clampf(remaining / HOP_RUN, 0.0, 1.0))
			raider.position.y = lerpf(ROAD_ORIGIN_Y, target_local.y, hop)
		else:
			keep_feet_on_road()


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
