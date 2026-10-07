extends RefCounted

## Per-frame chase math for WindowRaider. No await: called straight from _physics_process.

## Origin above the feet: the sprite's bottom row sits this far under the raider's origin.
const FEET_DROP := 1.62
## Origin y that stands the loper's feet on the road (VanRig space) while it is outside.
const ROAD_ORIGIN_Y := VanWheels.ROAD_Y + FEET_DROP
## Horizontal metres over which the loper hops from the road up onto the van floor as it climbs in.
const HOP_RUN := 1.3
## Half the loper's 1.54 m card plus 8 cm: the card faces the camera, so it can swing
## this far toward any wall.
const CLEARANCE := 0.85
## Van parts the loper's card may not swing into, as xz rects (Rect2 x = van x,
## Rect2 y = van z): the body from the front bumper to the rear bumper, both rear-door
## leaves' swing (open 110 degrees), the rear and front wheels.
const OUTSIDE_KEEP_OUT: Array[Rect2] = [
	Rect2(-3.72, -8.6, 7.44, 15.48), Rect2(-3.3, 6.48, 1.0, 2.4),
	Rect2(2.3, 6.48, 1.0, 2.4), Rect2(-3.4, 2.45, 6.8, 3.8), Rect2(-3.45, -8.1, 6.9, 1.7),
]
## The cabin interior shrunk by CLEARANCE: walls at x +/-3.39, cab wall z -4.7, rear
## doors' inner face z 6.51.
const INTERIOR_HALF_X := VanInteriorSize.BOTTOM_HALF - CLEARANCE
const INTERIOR_MIN_Z := -3.85
const INTERIOR_MAX_Z := 5.66

var raider: Node3D  # the WindowRaider; reads/writes its fields when called


func _init(owner: Node3D) -> void:
	raider = owner


## The window loper runs on the road while approaching and leaves it in JUMPING, GRIPPING
## and CLIMBING; the door loper walks the road throughout; the boss never does.
func _walks_on_road() -> bool:
	return not raider.is_boss and (
		not raider.is_agile or raider.assault_phase == WindowRaider.AssaultPhase.APPROACH
	)


## Outside, the loper runs and claws at the doors from the street.
func keep_feet_on_road() -> void:
	if not _walks_on_road():
		return
	var phase: int = raider.assault_phase
	if phase == WindowRaider.AssaultPhase.APPROACH or phase == WindowRaider.AssaultPhase.BREACHING:
		raider.position.y = ROAD_ORIGIN_Y
		raider.position = _push_out(raider.position)


## Where the loper may stand for its phase: outside it stays off the van's body, door leaves
## and wheels, inside it stays off the cabin walls. The window loper only floats at its
## marker in BREACHING, so only road walkers are pushed out; every non-boss raider is clamped inside.
## Other phases and the boss pass.
func clear_point(p: Vector3) -> Vector3:
	if raider.is_boss:
		return p
	var phase: int = raider.assault_phase
	if phase == WindowRaider.AssaultPhase.APPROACH or phase == WindowRaider.AssaultPhase.BREACHING:
		return _push_out(p) if _walks_on_road() else p
	if (
		phase == WindowRaider.AssaultPhase.ATTACKING_BENCH
		or phase == WindowRaider.AssaultPhase.ATTACKING_PLAYER
	):
		return _clamp_in(p)
	return p


func _push_out(p: Vector3) -> Vector3:
	for _pass in 4:
		var moved := false
		for rect in OUTSIDE_KEEP_OUT:
			var grown := rect.grow(CLEARANCE)
			# Strictly inside: a point on the border already counts as clear.
			if (
				p.x <= grown.position.x or p.x >= grown.end.x
				or p.z <= grown.position.y or p.z >= grown.end.y
			):
				continue
			var to_left := p.x - grown.position.x
			var to_right := grown.end.x - p.x
			var to_front := p.z - grown.position.y
			var to_back := grown.end.y - p.z
			var best := minf(minf(to_left, to_right), minf(to_front, to_back))
			if best == to_left:
				p.x = grown.position.x
			elif best == to_right:
				p.x = grown.end.x
			elif best == to_front:
				p.z = grown.position.y
			else:
				p.z = grown.end.y
			moved = true
		if not moved:
			break
	return p


func _clamp_in(p: Vector3) -> Vector3:
	p.x = clampf(p.x, -INTERIOR_HALF_X, INTERIOR_HALF_X)
	p.z = clampf(p.z, INTERIOR_MIN_Z, INTERIOR_MAX_Z)
	return p


func physics_chase_target(delta: float) -> void:
	var parent_3d := raider.get_parent() as Node3D
	if parent_3d == null:
		raider._move_arrived = true
		return
	var target_local: Vector3 = raider._move_target_local
	if raider._move_marker and is_instance_valid(raider._move_marker):
		target_local = parent_3d.to_local(raider._move_marker.global_position)
	target_local = clear_point(target_local)
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
	target_local = clear_point(target_local)
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
