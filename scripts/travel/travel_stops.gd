extends RefCounted

## Owns the stop fork, side-stop placement, elevator pad ride and stop-state cleanup.

## Untyped on purpose: TravelController and ActDeckController avoid class_name cycles,
## so helpers don't name the controller's class either.
var tc: Node


func _init(owner: Node) -> void:
	tc = owner


func prepare_stop_fork() -> void:
	# Cards are street modifiers. Every offered road still gets a building.
	tc._fork_stops.clear()
	tc._fork_stop = null
	tc._stop_fork_side = &""
	var used: Array[StringName] = []
	if tc._last_stop_id != &"":
		used.append(tc._last_stop_id)
	var forced: SideStopDefinition = tc._forced_next_stop
	tc._forced_next_stop = null
	for direction in GameSession.get_route_directions():
		var stop: SideStopDefinition = forced
		if stop == null or stop.scene == null:
			stop = SideStopRegistry.pick(tc._rng, used)
		if stop == null or stop.scene == null:
			continue
		tc._fork_stops[direction] = stop
		if stop.id not in used:
			used.append(stop.id)
		if tc._fork_stop == null:
			tc._fork_stop = stop
			tc._stop_fork_side = direction


func attach_stop_on_upcoming_segment(tiles_ahead: int) -> void:
	if tc._pending_stop == null or tc._pending_stop.scene == null or is_instance_valid(tc._active_stop):
		return
	if tc._stop_bay_side != &"left" and tc._stop_bay_side != &"right":
		tc._stop_bay_side = &"right" if tc._rng.randi() % 2 == 0 else &"left"

	var host_progress: float = tc._world.upcoming_corridor_progress(tiles_ahead)
	tc._world.spawn_route_segments_until(host_progress)
	var host_segment: Node3D = tc._world.corridor_segment_near_progress(host_progress)
	if host_segment == null:
		# Lattice skipped this slot (straight-through used to leave a 10m void).
		host_segment = tc._world.spawn_world_segment(
			tc._world.sample_route_transform(host_progress),
			host_progress
		)
		tc._next_segment_progress = maxf(tc._next_segment_progress, host_progress + tc.segment_length)

	if tc._pending_stop.uses_elevator():
		place_elevator_stop(host_segment, host_progress)
	else:
		place_bay_stop(host_segment, host_progress)


func place_bay_stop(host_segment: Node3D, host_progress: float) -> void:
	# Drop any decorative side street on this tile first — a leftover branch
	# next to the vestibule is what made reverse-park look like "another street".
	if host_segment.has_method(&"apply_side_streets"):
		host_segment.apply_side_streets(false, false)
	if host_segment.has_method(&"open_bay"):
		host_segment.open_bay(tc._stop_bay_side)

	if not spawn_stop_host():
		return
	var side := 1.0 if tc._stop_bay_side == &"right" else -1.0
	var yaw := 0.0 if tc._stop_bay_side == &"right" else PI
	var local := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), Vector3(side * 9.0, 0.0, 0.0))
	tc._active_stop.global_transform = host_segment.global_transform * local
	finish_stop_attach(host_progress)


func place_elevator_stop(host_segment: Node3D, host_progress: float) -> void:
	if not spawn_stop_host():
		return
	# Sit on the travel sample, not the tile mesh — the van stops on the path.
	tc._active_stop.global_transform = tc._world.sample_route_transform(host_progress)
	if tc._active_stop.has_method(&"bind_host_segment"):
		tc._active_stop.bind_host_segment(host_segment)
	finish_stop_attach(host_progress)


func spawn_stop_host() -> bool:
	tc._active_stop = instantiate_stop_host(tc._pending_stop)
	if tc._active_stop == null:
		push_error("Side stop '%s' scene failed to instantiate." % String(tc._pending_stop.id))
		return false
	tc._active_stop_def = tc._pending_stop
	tc.corridor_root.add_child(tc._active_stop)
	return true


func finish_stop_attach(host_progress: float) -> void:
	if tc._active_stop.has_method(&"mount_content"):
		tc._active_stop.mount_content(tc._pending_stop.scene)
	tc._world_pieces.append(tc._active_stop)
	tc._stop_align_progress = host_progress
	tc._stop_pending = false
	tc._stop_attach_segment_index = -1


func instantiate_stop_host(def: SideStopDefinition) -> Node3D:
	if def != null and def.uses_elevator():
		if tc.stop_elevator_scene:
			var elevator := tc.stop_elevator_scene.instantiate() as Node3D
			if elevator:
				return elevator
		return tc._StopElevator.new() as Node3D
	if tc.stop_vestibule_scene:
		var vestibule := tc.stop_vestibule_scene.instantiate() as Node3D
		if vestibule:
			return vestibule
	return def.scene.instantiate() as Node3D


func is_elevator_stop() -> bool:
	return tc._active_stop_def != null and tc._active_stop_def.uses_elevator()


func elevator_ride_seconds() -> float:
	var seconds: float = tc._ELEVATOR_RIDE_SECONDS
	if is_instance_valid(tc._active_stop) and tc._active_stop.has_method(&"ride_seconds"):
		seconds = float(tc._active_stop.ride_seconds())
	return tc.scale_debug_wait(seconds)


func elevator_depth() -> float:
	if is_instance_valid(tc._active_stop) and tc._active_stop.has_method(&"depth"):
		return float(tc._active_stop.depth())
	return tc._ELEVATOR_DEPTH


func sync_elevator_platform() -> void:
	if not is_instance_valid(tc._active_stop):
		return
	if tc._active_stop.has_method(&"sync_platform_offset"):
		tc._active_stop.sync_platform_offset(tc.van_follow.v_offset)


func keep_player_on_van_rig() -> void:
	# CharacterBody3D physics is global. Street-height floors inflate local Y
	# as PathFollow.v_offset drops the van; snap back onto the rig.
	if tc.van_rig == null:
		return
	var player := tc.van_rig.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	player.position.y = 0.0
	player.velocity.y = 0.0
	player.floor_snap_length = 0.0


func finish_elevator_descent() -> void:
	tc._turn_state = tc.TurnState.NONE
	tc.process_physics_priority = -100
	restore_player_floor_snap()
	tc._refresh_travel_speed()
	if is_instance_valid(tc._active_stop) and tc._active_stop.has_method(&"set_docked"):
		tc._active_stop.set_docked(true)
	if is_instance_valid(tc._active_stop) and tc._active_stop.has_method(&"open_door"):
		tc._active_stop.open_door()
	GameSession.set_phase(GameSession.RunPhase.STOP)


func finish_elevator_ascent() -> void:
	tc.van_follow.v_offset = 0.0
	tc.van_rig.transform = Transform3D.IDENTITY
	tc._turn_state = tc.TurnState.NONE
	tc.process_physics_priority = -100
	restore_player_floor_snap()
	tc._segment_spawning_paused = false
	tc._refresh_travel_speed()
	if is_instance_valid(tc._active_stop) and tc._active_stop.has_method(&"restore_road"):
		tc._active_stop.restore_road()
	if is_instance_valid(tc._active_stop):
		tc._world_pieces.erase(tc._active_stop)
		tc._active_stop.queue_free()
	clear_stop_state()
	tc._world.spawn_segments_ahead()
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)


func restore_player_floor_snap() -> void:
	if tc.van_rig == null:
		return
	var player := tc.van_rig.get_node_or_null("Player") as CharacterBody3D
	if player:
		player.floor_snap_length = 0.2


func clear_stop_state() -> void:
	tc.process_physics_priority = -100
	restore_player_floor_snap()
	if is_instance_valid(tc.van_follow):
		tc.van_follow.v_offset = 0.0
	tc._active_stop = null
	tc._active_stop_def = null
	tc._pending_stop = null
	tc._fork_stop = null
	tc._fork_stops.clear()
	tc._stop_pending = false
	tc._stop_attach_segment_index = -1
	tc._stop_bay_side = &""
	tc._stop_align_progress = INF
	tc._stop_fork_side = &""
	tc._park_reversing = false
