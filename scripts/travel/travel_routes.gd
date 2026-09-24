extends RefCounted

## Owns the travel-path curve building for turns, stop parking and leaving a stop.

## Untyped on purpose: TravelController and ActDeckController avoid class_name cycles,
## so helpers don't name the controller's class either.
var tc: Node


func _init(owner: Node) -> void:
	tc = owner


func on_route_chosen(direction: StringName, _step: int) -> void:
	if tc._turn_state != tc.TurnState.APPROACHING or not is_instance_valid(tc._active_junction):
		return
	tc._turn_direction = direction
	# Choosing a road with no building abandons any unfinished visit from a prior pick.
	var chosen_stop: SideStopDefinition = tc.get_fork_stop_for(direction)
	if chosen_stop != null and chosen_stop.scene != null:
		tc._stop_pending = true
		tc._pending_stop = chosen_stop
		tc._last_stop_id = chosen_stop.id
		tc._stop_bay_side = &"left" if tc._rng.randi() % 2 == 0 else &"right"
	else:
		if not is_instance_valid(tc._active_stop):
			tc._stop_pending = false
			tc._pending_stop = null
			tc._stop_bay_side = &""
			tc._stop_attach_segment_index = -1
			tc._stop_align_progress = INF
	build_turn_route()


func build_turn_route() -> void:
	if tc._turn_direction == &"straight":
		build_straight_route()
		return
	var van_transform: Transform3D = tc.van_rig.global_transform
	var junction_local: Vector3 = van_transform.affine_inverse() * tc._active_junction.global_position
	var straight_length := maxf(0.0, -junction_local.z - tc.turn_radius)
	var side := -1.0 if tc._turn_direction == &"left" else 1.0
	var handle: float = tc.turn_radius * tc.QUARTER_CIRCLE_HANDLE
	var turn_start := Vector3(0.0, 0.0, -straight_length)
	var turn_end := Vector3(side * tc.turn_radius, 0.0, -straight_length - tc.turn_radius)
	var route_end := turn_end + Vector3(side * tc.route_length, 0.0, 0.0)

	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(Vector3.ZERO)
	curve.add_point(turn_start, Vector3.ZERO, Vector3(0.0, 0.0, -handle))
	curve.add_point(
		turn_end,
		Vector3(-side * handle, 0.0, 0.0),
		Vector3(side * tc.segment_length * 0.25, 0.0, 0.0)
	)
	curve.add_point(
		route_end,
		Vector3(-side * tc.segment_length * 0.25, 0.0, 0.0)
	)

	tc._world.begin_new_route()
	tc.travel_path.curve = curve
	tc.travel_path.global_transform = van_transform
	tc.van_follow.progress = 0.0
	tc.van_rig.transform = Transform3D.IDENTITY

	tc._turn_state = tc.TurnState.TURNING
	tc._approach_stop_progress = INF
	tc._turn_end_progress = curve.get_closest_offset(turn_end)
	tc._next_segment_progress = tc._turn_end_progress + tc.segment_length
	tc._world.spawn_route_segments_until(tc._turn_end_progress + tc.segment_ahead_distance)


func build_straight_route() -> void:
	# Stay on the live -Z curve. `through` already ends at the outgoing mouth
	# (~20m past the junction); a full extra tile here left a 10m void.
	var van_transform: Transform3D = tc.van_rig.global_transform
	var junction_local: Vector3 = van_transform.affine_inverse() * tc._active_junction.global_position
	var through := maxf(tc.segment_length, -junction_local.z + 20.0)
	tc._turn_state = tc.TurnState.TURNING
	tc._approach_stop_progress = INF
	tc._turn_end_progress = tc.van_follow.progress + through
	tc._next_segment_progress = tc._turn_end_progress + tc.segment_length * 0.5


func finish_turn() -> void:
	tc._turn_state = tc.TurnState.NONE
	tc._turn_direction = &""
	tc._active_junction = null
	tc._turn_end_progress = INF
	tc._segment_spawning_paused = false
	if tc._stop_pending and not is_instance_valid(tc._active_stop):
		tc._stops.attach_stop_on_upcoming_segment(
			tc._rng.randi_range(tc.STOP_SPAWN_MIN_SEGMENTS_AHEAD, tc.STOP_SPAWN_MAX_SEGMENTS_AHEAD)
		)
	tc._world.spawn_segments_ahead()
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)


func maybe_begin_stop_park() -> void:
	if tc._turn_state != tc.TurnState.NONE:
		return
	if not is_instance_valid(tc._active_stop):
		return
	if tc._stop_align_progress >= INF:
		return
	# Park while the road is still scrolling (combat used to skip this and blow past).
	if GameSession.phase not in [
		GameSession.RunPhase.TRAVELLING,
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.REST,
	]:
		return
	if tc._stops.is_elevator_stop():
		if tc.van_follow.progress < tc._stop_align_progress:
			return
		tc._begin_elevator_descent()
		return
	# Need room for a T-junction quarter-circle plus a short reverse straight.
	if tc.van_follow.progress < (
		tc._stop_align_progress + tc.STOP_PARK_TURN_RADIUS + tc.STOP_PARK_REVERSE_STRAIGHT
	):
		return
	build_park_route()


func stop_mouth_world() -> Vector3:
	var exit_pt := tc._active_stop.get_node_or_null("ExitPoint") as Marker3D
	if exit_pt:
		return exit_pt.global_position
	return tc._active_stop.to_global(Vector3(1.5, 0.0, 0.0))


func stop_corridor_at_mouth(mouth_world: Vector3) -> Vector3:
	# Project the mouth onto the corridor centerline (bay sits STOP_CORRIDOR_LATERAL out).
	var into_bay: Vector3 = tc._active_stop.global_transform.basis.x.normalized()
	var corridor_ref: Vector3 = tc._active_stop.global_position - into_bay * tc.STOP_CORRIDOR_LATERAL
	return mouth_world - into_bay * into_bay.dot(mouth_world - corridor_ref)


func flatten_local(van_inv: Transform3D, world_pos: Vector3) -> Vector3:
	var local := van_inv * world_pos
	local.y = 0.0
	return local


func build_park_route() -> void:
	if not is_instance_valid(tc._active_stop):
		return
	var dock := tc._active_stop.get_node_or_null("DockPoint") as Marker3D
	if dock == null:
		return

	# Same C as build_turn_route, mirrored onto +Z (bay is behind after overshoot),
	# then stored dock→van and driven with progress counting down so the nose stays
	# road-facing. Handles are the T-turn controls transferred (not flipped) so the
	# arc stays a C — flipping them was what made the serpent S.
	var van_transform: Transform3D = tc.van_rig.global_transform
	var van_inv: Transform3D = van_transform.affine_inverse()
	var park_radius: float = tc.STOP_PARK_TURN_RADIUS
	var handle: float = park_radius * tc.QUARTER_CIRCLE_HANDLE
	var dock_local := flatten_local(van_inv, dock.global_position)
	# Aim at the real bay, not the fork's remembered left/right — after a turn
	# those can disagree with van-local +X.
	var side := signf(dock_local.x)
	if is_zero_approx(side):
		side = 1.0 if tc._stop_bay_side == &"right" else -1.0
	tc._stop_bay_side = &"right" if side > 0.0 else &"left"

	var mouth_z := flatten_local(van_inv, stop_corridor_at_mouth(stop_mouth_world())).z
	mouth_z = maxf(mouth_z, park_radius + tc.STOP_PARK_REVERSE_STRAIGHT)
	# Real dock lateral. Do not clamp outward — that shoved the van 1–2 m past
	# the marker and into the roll-up.
	var dock_lat := maxf(absf(dock_local.x), park_radius)

	var straight_length := mouth_z - park_radius
	var turn_start := Vector3(0.0, 0.0, straight_length)
	var turn_end := Vector3(side * park_radius, 0.0, straight_length + park_radius)
	var dock_pos := Vector3(side * dock_lat, 0.0, mouth_z)
	var bay_out := dock_lat - park_radius

	# Forward T into the bay would be: van → turn_start → turn_end → dock with
	#   turn_start.out = (0,0,handle), turn_end.in = (-side*handle, 0, 0)
	# Reversed path keeps those same control points on the shared segments.
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(dock_pos, Vector3.ZERO, Vector3(-side * bay_out * 0.25, 0.0, 0.0))
	curve.add_point(
		turn_end,
		Vector3(side * bay_out * 0.25, 0.0, 0.0),
		Vector3(-side * handle, 0.0, 0.0)
	)
	curve.add_point(
		turn_start,
		Vector3(0.0, 0.0, handle),
		Vector3.ZERO
	)
	curve.add_point(Vector3.ZERO)

	tc._world.begin_new_route()
	tc.travel_path.curve = curve
	tc.travel_path.global_transform = van_transform
	tc.van_follow.progress = curve.get_baked_length()
	tc.van_rig.transform = Transform3D.IDENTITY

	tc._park_reversing = true
	tc._turn_state = tc.TurnState.PARKING
	tc._turn_end_progress = 0.0
	tc._stop_align_progress = INF
	tc._segment_spawning_paused = true
	tc._refresh_travel_speed()
	GameSession.set_phase(GameSession.RunPhase.PARKING)


func finish_park() -> void:
	tc._park_reversing = false
	tc._turn_state = tc.TurnState.NONE
	tc._turn_end_progress = INF
	tc.van_follow.progress = 0.0
	tc._refresh_travel_speed()
	# Open after the reverse-park finishes so the gate stays shut while docking.
	if is_instance_valid(tc._active_stop) and tc._active_stop.has_method(&"open_door"):
		tc._active_stop.open_door()
	GameSession.set_phase(GameSession.RunPhase.STOP)


func build_leave_stop_route() -> void:
	# Mirror the reverse-park: same curve, forward progress (dock → corridor mouth).
	tc._park_reversing = false
	if is_instance_valid(tc._active_stop) and tc._active_stop.has_method(&"close_door"):
		tc._active_stop.close_door()

	var curve: Curve3D = tc.travel_path.curve
	if curve == null or curve.point_count < 2:
		tc._stops.clear_stop_state()
		GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
		return

	var corridor_join: float = curve.get_closest_offset(Vector3.ZERO)
	var last_pos: Vector3 = curve.get_point_position(curve.point_count - 1)
	if last_pos.is_equal_approx(Vector3.ZERO):
		curve.add_point(Vector3(0.0, 0.0, -tc.route_length))

	tc._world.begin_new_route()
	tc.van_follow.progress = 0.0
	tc.van_rig.transform = Transform3D.IDENTITY

	tc._turn_state = tc.TurnState.LEAVING_STOP
	tc._turn_end_progress = corridor_join
	tc._next_segment_progress = corridor_join + tc.segment_length
	tc._segment_spawning_paused = false
	tc._refresh_travel_speed()
	tc._world.spawn_route_segments_until(corridor_join + tc.segment_ahead_distance)


func finish_leave_stop() -> void:
	tc._turn_state = tc.TurnState.NONE
	tc._turn_end_progress = INF
	tc._stops.clear_stop_state()
	tc._segment_spawning_paused = false
	tc._refresh_travel_speed()
	tc._world.spawn_segments_ahead()
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
