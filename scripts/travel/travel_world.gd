extends RefCounted

## Owns corridor tile spawning/pruning, side streets, neighborhood variants and act statues.

## No set-pieces on the intro street.
const RARE_START_SEGMENT := 6
const RARE_COOLDOWN := 3

## Untyped on purpose: TravelController and ActDeckController avoid class_name cycles,
## so helpers don't name the controller's class either.
var tc: Node


func _init(owner: Node) -> void:
	tc = owner


func configure_initial_route() -> void:
	begin_new_route()
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -tc.route_length))
	tc.travel_path.curve = curve
	tc.van_follow.progress = 0.0
	tc.van_rig.transform = Transform3D.IDENTITY

	spawn_world_segment(
		Transform3D(
			tc.travel_path.global_basis,
			tc.travel_path.global_position + tc.travel_path.global_basis * Vector3(0.0, 0.0, tc.segment_length)
		)
	)
	tc._next_segment_progress = 0.0
	spawn_route_segments_until(tc.segment_ahead_distance)


func spawn_segments_ahead() -> void:
	if tc._segment_spawning_paused:
		return
	spawn_route_segments_until(tc.van_follow.progress + tc.segment_ahead_distance)


func spawn_route_segments_until(target_progress: float) -> void:
	var route_end: float = tc.travel_path.curve.get_baked_length()
	while tc._next_segment_progress <= target_progress and tc._next_segment_progress < route_end:
		spawn_world_segment(
			sample_route_transform(tc._next_segment_progress),
			tc._next_segment_progress
		)
		tc._next_segment_progress += tc.segment_length


func spawn_world_segment(world_transform: Transform3D, route_progress: float = NAN) -> Node3D:
	var segment := tc.segment_scene.instantiate() as Node3D
	tc.corridor_root.add_child(segment)
	segment.global_transform = world_transform
	if is_finite(route_progress):
		segment.set_meta(&"route_progress", route_progress)
		segment.set_meta(&"route_gen", tc._route_gen)
	if segment.has_method(&"configure"):
		var district := pick_district()
		var seed_value: int = hash([GameSession.run_seed, tc._segment_index])
		var neighborhood_seed: int = hash([GameSession.run_seed, tc._neighborhood_start])
		var allow_rare: bool = tc._segment_index >= RARE_START_SEGMENT and tc._rare_cooldown <= 0
		var took_rare: bool = segment.configure(seed_value, district, neighborhood_seed, allow_rare)
		if took_rare:
			tc._rare_cooldown = RARE_COOLDOWN
		elif tc._rare_cooldown > 0:
			tc._rare_cooldown -= 1
	if segment.has_method(&"apply_side_streets"):
		var side_streets := pick_side_streets()
		segment.apply_side_streets(side_streets.x != 0, side_streets.y != 0)
	tc._world_pieces.append(segment)
	tc._segment_index += 1
	return segment


## First / second / … corridor tile still ahead of the van on the spawn lattice.
func upcoming_corridor_progress(tiles_ahead: int) -> float:
	var progresses: Array[float] = []
	var ahead_of: float = tc.van_follow.progress + 1.0
	for piece in tc._world_pieces:
		if not is_live_route_tile(piece):
			continue
		var tile_progress := float(piece.get_meta(&"route_progress"))
		if tile_progress >= ahead_of:
			progresses.append(tile_progress)
	progresses.sort()
	var index := maxi(tiles_ahead, 1) - 1
	if index < progresses.size():
		return progresses[index]
	if progresses.is_empty():
		return tc._next_segment_progress + tc.segment_length * float(index)
	return progresses[progresses.size() - 1] + tc.segment_length * float(
		index - progresses.size() + 1
	)


func corridor_segment_near_progress(route_progress: float) -> Node3D:
	var best: Node3D
	var best_dist := INF
	for piece in tc._world_pieces:
		if not is_live_route_tile(piece):
			continue
		var dist := absf(float(piece.get_meta(&"route_progress")) - route_progress)
		if dist < best_dist:
			best_dist = dist
			best = piece
	if best == null or best_dist > tc.segment_length * 0.51:
		return null
	return best


func is_live_route_tile(piece: Node3D) -> bool:
	if not is_instance_valid(piece) or not piece.has_meta(&"route_progress"):
		return false
	if int(piece.get_meta(&"route_gen", -1)) != tc._route_gen:
		return false
	var tile_progress := float(piece.get_meta(&"route_progress"))
	var sampled := sample_route_transform(tile_progress)
	var slop: float = tc.segment_length * 0.51
	return piece.global_position.distance_squared_to(sampled.origin) <= slop * slop


func begin_new_route() -> void:
	tc._route_gen += 1


func pick_district() -> int:
	if tc._neighborhood_remaining <= 0:
		tc._neighborhood_variant = tc._rng.randi() % tc.DISTRICT_COUNT
		if (
			tc._last_neighborhood_variant >= 0
			and tc._neighborhood_variant == tc._last_neighborhood_variant
		):
			tc._neighborhood_variant = (tc._neighborhood_variant + 1) % tc.DISTRICT_COUNT
		tc._neighborhood_remaining = tc._rng.randi_range(
			tc.NEIGHBORHOOD_MIN_LENGTH,
			tc.NEIGHBORHOOD_MAX_LENGTH
		)
		tc._last_neighborhood_variant = tc._neighborhood_variant
		tc._neighborhood_start = tc._segment_index
	tc._neighborhood_remaining -= 1
	return tc._neighborhood_variant


func pick_side_streets() -> Vector2i:
	if tc._segment_index < tc.SIDE_STREET_START_SEGMENT:
		return Vector2i.ZERO

	if tc._side_street_cooldown > 0:
		tc._side_street_cooldown -= 1
		return Vector2i.ZERO

	if tc._rng.randf() >= tc.SIDE_STREET_CHANCE:
		return Vector2i.ZERO

	var left := false
	var right := false
	match tc._rng.randi_range(0, 2):
		0:
			left = true
		1:
			right = true
		2:
			left = true
			right = true

	tc._side_street_cooldown = tc.SIDE_STREET_GAP
	return Vector2i(int(left), int(right))


func sample_route_transform(progress: float) -> Transform3D:
	return tc.travel_path.global_transform * tc.travel_path.curve.sample_baked_with_rotation(
		progress,
		true,
		true
	)


func aligned_special_progress() -> float:
	var target_progress: float = tc.van_follow.progress + tc.junction_distance
	var first_aligned_progress: float = (
		tc._next_segment_progress
		- tc.segment_length
		+ tc.junction_incoming_length
		+ tc.segment_length * 0.5
	)
	var alignment_steps := maxi(
		0,
		ceili((target_progress - first_aligned_progress) / tc.segment_length)
	)
	return first_aligned_progress + alignment_steps * tc.segment_length


func spawn_special_ahead(scene: PackedScene) -> void:
	if scene == null or is_instance_valid(tc._active_junction) or tc._turn_state != tc.TurnState.NONE:
		return
	tc._turn_state = tc.TurnState.APPROACHING
	tc._turn_direction = &""

	var special_progress := aligned_special_progress()
	var final_approach_segment: float = (
		special_progress - tc.junction_incoming_length - tc.segment_length * 0.5
	)
	spawn_route_segments_until(final_approach_segment)
	tc._segment_spawning_paused = true

	tc._active_junction = scene.instantiate() as Node3D
	tc.corridor_root.add_child(tc._active_junction)
	tc._active_junction.global_transform = sample_route_transform(special_progress)
	tc._world_pieces.append(tc._active_junction)
	tc._approach_stop_progress = special_progress - tc.turn_radius


func spawn_approaching_junction() -> void:
	var scene: PackedScene = tc.t_junction_scene if GameSession.uses_t_junction() else tc.crossroads_scene
	if scene == null:
		scene = tc.t_junction_scene
	spawn_special_ahead(scene)


func spawn_act_statue() -> void:
	clear_act_statue()
	if tc.act_statue_scene == null or not is_instance_valid(tc.van_rig):
		return
	tc._active_statue = tc.act_statue_scene.instantiate() as Node3D
	if tc._active_statue == null:
		return
	tc.corridor_root.add_child(tc._active_statue)
	# Roadside placeholder just ahead and to the right of the van.
	var offset: Vector3 = tc.van_rig.global_transform.basis * Vector3(4.5, 0.0, -8.0)
	tc._active_statue.global_position = tc.van_rig.global_position + offset
	tc._active_statue.global_basis = tc.van_rig.global_basis
	tc._world_pieces.append(tc._active_statue)


func clear_act_statue() -> void:
	if is_instance_valid(tc._active_statue):
		tc._world_pieces.erase(tc._active_statue)
		tc._active_statue.queue_free()
	tc._active_statue = null


func prune_world() -> void:
	if tc._turn_state != tc.TurnState.NONE:
		return
	for index in range(tc._world_pieces.size() - 1, -1, -1):
		var piece: Node3D = tc._world_pieces[index]
		if not is_instance_valid(piece):
			tc._world_pieces.remove_at(index)
			continue
		if piece == tc._active_stop or piece == tc._active_statue:
			continue
		if piece.global_position.distance_to(tc.van_rig.global_position) <= tc.world_cull_distance:
			continue
		piece.queue_free()
		tc._world_pieces.remove_at(index)
