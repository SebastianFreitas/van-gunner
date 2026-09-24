extends RefCounted

## Street furniture/detail builders for RoadFloor: expansion joints, drains,
## manholes and sidewalk dressing. Reads the owning RoadFloor's exports and
## uses its box primitive so built geometry parents/collides the same way.

const RoadFloorMaterials = preload("res://scripts/travel/road_floor_materials.gd")

var road: Node3D  # the RoadFloor; reads its exports and uses its box primitive


func _init(owner: Node3D) -> void:
	road = owner


func build_expansion_joints(
	carriage_width: float,
	carriage_center: float,
	dark_mat: Material
) -> void:
	# Shallow transverse grooves across the carriageway every ~5m.
	var spacing := 5.0
	var joint_w := carriage_width - 0.3
	var joint_d := 0.06
	var joint_h := 0.02
	var z: float = -road.span_z * 0.5 + spacing
	var i := 0
	while z < road.span_z * 0.5 - 1.0:
		road._add_box_centered(
			"ExpansionJoint_%d" % i,
			Vector3(joint_w, joint_h, joint_d),
			Vector3(carriage_center, road.road_surface_y - joint_h * 0.35, z),
			dark_mat,
			false
		)
		z += spacing
		i += 1


func build_drains(
	gutter_inner: float,
	grate_mat: Material,
	metal_mat: Material,
	dark_mat: Material
) -> void:
	if not road.sidewalk_left and not road.sidewalk_right:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = road._seed_value(17)
	var spacing := 5.0
	var z: float = -road.span_z * 0.5 + 2.5
	var i := 0
	while z < road.span_z * 0.5 - 1.5:
		for side: float in [-1.0, 1.0]:
			if side < 0.0 and not road.sidewalk_left:
				continue
			if side > 0.0 and not road.sidewalk_right:
				continue
			var gx: float = side * (gutter_inner + road.gutter_width * 0.5)
			# Frame
			road._add_box_centered(
				"DrainFrame_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(road.gutter_width * 0.92, 0.03, 0.55),
				Vector3(gx, road.road_surface_y - road.gutter_depth + 0.01, z),
				metal_mat,
				false
			)
			# Grate insert
			road._add_box_centered(
				"DrainGrate_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(road.gutter_width * 0.7, 0.025, 0.42),
				Vector3(gx, road.road_surface_y - road.gutter_depth + 0.018, z),
				grate_mat,
				false
			)
			# Slots as thin dark bars
			for slot in range(4):
				var sz: float = z - 0.15 + slot * 0.1
				road._add_box_centered(
					"DrainSlot_%d_%s_%d" % [i, "L" if side < 0.0 else "R", slot],
					Vector3(road.gutter_width * 0.55, 0.02, 0.035),
					Vector3(gx, road.road_surface_y - road.gutter_depth + 0.028, sz),
					dark_mat,
					false
				)
		z += spacing + rng.randf_range(-0.4, 0.4)
		i += 1


func build_manholes(
	carriage_width: float,
	carriage_center: float,
	metal_mat: Material,
	dark_mat: Material
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = road._seed_value(41)
	var count := maxi(1, int(road.span_z / 10.0))
	var half_w := carriage_width * 0.5
	for i in count:
		var mx := carriage_center + rng.randf_range(-half_w * 0.55, half_w * 0.55)
		# Bias away from exact center so van path stays clean-ish.
		var lateral := mx - carriage_center
		if absf(lateral) < 0.9:
			mx = carriage_center + 1.2 * signf(lateral if lateral != 0.0 else 1.0)
		var mz := rng.randf_range(-road.span_z * 0.4, road.span_z * 0.4)
		var size := rng.randf_range(0.55, 0.72)
		# Recess well
		road._add_box_centered(
			"ManholeWell_%d" % i,
			Vector3(size, 0.04, size),
			Vector3(mx, road.road_surface_y - 0.015, mz),
			dark_mat,
			false
		)
		# Lid
		road._add_box_centered(
			"ManholeLid_%d" % i,
			Vector3(size * 0.92, 0.03, size * 0.92),
			Vector3(mx, road.road_surface_y + 0.005, mz),
			metal_mat,
			false
		)
		# Cross ribs on lid
		road._add_box_centered(
			"ManholeRibX_%d" % i,
			Vector3(size * 0.8, 0.02, 0.05),
			Vector3(mx, road.road_surface_y + 0.02, mz),
			RoadFloorMaterials.std(Color(0.18, 0.185, 0.175, 1.0), 0.5, 0.7),
			false
		)
		road._add_box_centered(
			"ManholeRibZ_%d" % i,
			Vector3(0.05, 0.02, size * 0.8),
			Vector3(mx, road.road_surface_y + 0.02, mz),
			RoadFloorMaterials.std(Color(0.18, 0.185, 0.175, 1.0), 0.5, 0.7),
			false
		)


func build_sidewalk_dressing(
	half_x: float,
	sidewalk_top: float,
	metal_mat: Material,
	curb_mat: Material,
	dark_mat: Material
) -> void:
	if not road.sidewalk_left and not road.sidewalk_right:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = road._seed_value(73)
	var walk_inner: float = half_x - road.sidewalk_width
	var walk_mid: float = half_x - road.sidewalk_width * 0.5
	var half_z: float = road.span_z * 0.5
	var z_min: float = -half_z + maxf(0.0, road.sidewalk_trim_z_neg) + 0.4
	var z_max: float = half_z - maxf(0.0, road.sidewalk_trim_z_pos) - 0.4

	# Utility boxes against the wall line, sparse.
	var z: float = z_min + road.span_z * 0.1
	var i := 0
	while z < z_max - road.span_z * 0.05:
		for side: float in [-1.0, 1.0]:
			if side < 0.0 and not road.sidewalk_left:
				continue
			if side > 0.0 and not road.sidewalk_right:
				continue
			if rng.randf() > 0.55:
				continue
			var bx := side * (half_x - 0.35)
			var bw := rng.randf_range(0.35, 0.55)
			var bh := rng.randf_range(0.55, 0.85)
			var bd := rng.randf_range(0.28, 0.4)
			road._add_box_centered(
				"UtilityBox_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(bw, bh, bd),
				Vector3(bx, sidewalk_top + bh * 0.5, z + rng.randf_range(-0.3, 0.3)),
				metal_mat,
				false
			)
		z += rng.randf_range(4.5, 7.0)
		i += 1

	# Short bollards near curb, sparse along each side.
	z = z_min + road.span_z * 0.05
	i = 0
	while z < z_max:
		for side: float in [-1.0, 1.0]:
			if side < 0.0 and not road.sidewalk_left:
				continue
			if side > 0.0 and not road.sidewalk_right:
				continue
			if rng.randf() > 0.4:
				continue
			var bx := side * (walk_inner + 0.28)
			var h := 0.55
			road._add_box_centered(
				"Bollard_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(0.14, h, 0.14),
				Vector3(bx, sidewalk_top + h * 0.5, z),
				curb_mat,
				false
			)
			road._add_box_centered(
				"BollardCap_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(0.16, 0.04, 0.16),
				Vector3(bx, sidewalk_top + h + 0.02, z),
				metal_mat,
				false
			)
		z += rng.randf_range(5.5, 8.0)
		i += 1

	# Sidewalk slab seams (visual only).
	var seam_spacing := 1.2
	var sz := z_min + seam_spacing * 0.5
	i = 0
	while sz < z_max:
		for side: float in [-1.0, 1.0]:
			if side < 0.0 and not road.sidewalk_left:
				continue
			if side > 0.0 and not road.sidewalk_right:
				continue
			road._add_box_centered(
				"WalkSeam_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(road.sidewalk_width * 0.92, 0.015, 0.04),
				Vector3(side * walk_mid, sidewalk_top + 0.004, sz),
				dark_mat,
				false
			)
		sz += seam_spacing
		i += 1
