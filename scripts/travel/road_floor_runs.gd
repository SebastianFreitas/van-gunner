extends RefCounted

## Sidewalk bed, gutter and road fill builder for RoadFloor: lays the plain walk per side, or one
## set of boxes per facade ground run when a building face is recessed outward.

var road: Node3D  # the RoadFloor; reads its exports and uses its box primitive


func _init(owner: Node3D) -> void:
	road = owner


## Beds for both sides first, then the gutters (with the road fill of each recessed walk run).
func build_sides(
	walk_thickness: float,
	walk_center_x: float,
	walk_span: Vector2,
	gutter_inner: float,
	slab_bottom: float,
	road_mat: Material,
	gutter_mat: Material,
	wreck: bool
) -> void:
	var walk_len: float = walk_span.x
	var walk_cz: float = walk_span.y
	var edge: float = road.span_x * 0.5
	var b: float = road.sidewalk_width
	var road_half := edge - b
	var gutter_top: float = road.road_surface_y - road.gutter_depth
	var gutter_thickness := gutter_top - slab_bottom
	var gutter_center_x: float = gutter_inner + road.gutter_width * 0.5
	var bed_y := slab_bottom + walk_thickness * 0.5
	var gutter_y := slab_bottom + gutter_thickness * 0.5
	# Wrecked: the bed keeps its collision but draws nothing; the soil grid replaces it.
	for side_idx in 2:
		if not (road.sidewalk_left if side_idx == 0 else road.sidewalk_right):
			continue
		var sx := -1.0 if side_idx == 0 else 1.0
		var tag := "Left" if side_idx == 0 else "Right"
		if _is_plain(side_idx):
			road._add_box_centered(
				"Sidewalk" + tag,
				Vector3(b, walk_thickness, walk_len),
				Vector3(sx * walk_center_x, bed_y, walk_cz),
				road.sidewalk_material, true, not wreck
			)
			continue
		var i := -1
		for run: Vector4 in road.ground_runs[side_idx]:
			i += 1
			var clip := _clip(run, walk_cz, walk_len)
			if clip.y < 0.01:
				continue
			var kind := int(run.w)
			var width := b
			var cx := walk_center_x + run.z
			if kind == 1:
				cx = walk_center_x
			elif kind == 2:
				width = b + run.z
				cx = road_half + width * 0.5
			road._add_box_centered(
				"Sidewalk%s%d" % [tag, i],
				Vector3(width, walk_thickness, clip.y),
				Vector3(sx * cx, bed_y, clip.x),
				road.sidewalk_material, true, not wreck
			)
			if kind == 1:
				road._add_box_centered(
					"Plaza%s%d" % [tag, i],
					Vector3(run.z, walk_thickness, clip.y),
					Vector3(sx * (edge + run.z * 0.5), bed_y, clip.x),
					road.sidewalk_material, true, not wreck
				)
	for side_idx in 2:
		if not (road.sidewalk_left if side_idx == 0 else road.sidewalk_right):
			continue
		var sx := -1.0 if side_idx == 0 else 1.0
		var tag := "Left" if side_idx == 0 else "Right"
		if _is_plain(side_idx):
			road._add_box_centered(
				"Gutter" + tag,
				Vector3(road.gutter_width, gutter_thickness, walk_len),
				Vector3(sx * gutter_center_x, gutter_y, walk_cz),
				gutter_mat, true
			)
			continue
		var i := -1
		for run: Vector4 in road.ground_runs[side_idx]:
			i += 1
			var clip := _clip(run, walk_cz, walk_len)
			if clip.y < 0.01:
				continue
			var kind := int(run.w)
			var cx := gutter_center_x + (run.z if kind == 0 else 0.0)
			road._add_box_centered(
				"Gutter%s%d" % [tag, i],
				Vector3(road.gutter_width, gutter_thickness, clip.y),
				Vector3(sx * cx, gutter_y, clip.x),
				gutter_mat, true
			)
			# The moved gutter leaves a hole in the carriageway: fill up to where it starts.
			if kind == 0 and run.z > 0.0:
				road._add_box_centered(
					"RoadFill%s%d" % [tag, i],
					Vector3(run.z, road.slab_thickness, clip.y),
					Vector3(sx * (gutter_inner + run.z * 0.5),
						road.road_surface_y - road.slab_thickness * 0.5, clip.x),
					road_mat, true, true
				)


## A side is plain when it has no runs or one run that is not recessed.
func _is_plain(side_idx: int) -> bool:
	var runs: Array = road.ground_runs[side_idx]
	return runs.is_empty() or (runs.size() == 1 and (runs[0] as Vector4).z == 0.0)


## The run clipped to the walk span as (centre z, length).
func _clip(run: Vector4, walk_cz: float, walk_len: float) -> Vector2:
	var z0 := maxf(run.x, walk_cz - walk_len * 0.5)
	var z1 := minf(run.y, walk_cz + walk_len * 0.5)
	return Vector2((z0 + z1) * 0.5, z1 - z0)
