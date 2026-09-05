class_name RoadFloor
extends Node3D

## Reusable corridor road slab: carriageway + raised sidewalks + curb/gutter
## details. Instance this scene on every tile instead of hand-editing floors.
##
## Coordinate contract (matches legacy corridor floor):
##   - Origin at tile center
##   - Road top surface at y = road_surface_y (default -0.2)
##   - Full footprint: span_x × span_z (default 18 × 20)
##   - Walls sit at x = ±span_x/2

@export var span_x := 18.0
@export var span_z := 20.0
@export var road_surface_y := -0.2
@export var slab_thickness := 0.2
@export var sidewalk_width := 1.75
@export var curb_height := 0.14
@export var curb_face_depth := 0.12
@export var gutter_width := 0.28
@export var gutter_depth := 0.04
## When false, that side becomes continuous carriageway to the tile edge
## (use for side-street / stop-bay openings so we don't stack sidewalk under the branch).
@export var sidewalk_left := true
@export var sidewalk_right := true
## Shorten sidewalk/curb/gutter before the +Z / -Z tile edge so a corner
## return can own the mouth instead of leaving a blunt end-cap.
@export var sidewalk_trim_z_pos := 0.0
@export var sidewalk_trim_z_neg := 0.0
@export var include_collision := true
@export var detail_seed := 0
@export var rebuild_on_ready := true

## Optional overrides — leave empty to use procedural street shaders.
@export var road_material: Material
@export var sidewalk_material: Material
@export var curb_material: Material
@export var metal_material: Material

var _built := false
var _body: StaticBody3D


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()
	_body = null
	_built = false
	_build()


## Hide the slab *and* its walk collision. Visibility alone leaves a street-height
## floor the player stands on while an elevator van drops through it.
func set_enabled(enabled: bool) -> void:
	visible = enabled
	if _body:
		_body.collision_layer = 1 if enabled else 0
		for child in _body.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).disabled = not enabled


## Open a side to continuous road (drops sidewalk/curb/gutter on that edge).
func set_side_openings(left_open: bool, right_open: bool) -> void:
	var want_left := not left_open
	var want_right := not right_open
	if sidewalk_left == want_left and sidewalk_right == want_right and _built:
		return
	sidewalk_left = want_left
	sidewalk_right = want_right
	rebuild()


## L-shaped sidewalk + curb return at one footprint corner.
## `corner_x` / `corner_z` are ±1 selecting the corner; `extent_*` is how far the
## pad reaches inward from that edge (usually the adjoining sidewalk widths).
## `outward` reaches past the tile edge onto adjoining stem/branch slabs.
## Parents meshes under `host` so junction tiles can keep returns if this floor rebuilds.
func spawn_corner_return(
	host: Node3D,
	corner_x: float,
	corner_z: float,
	extent_x: float,
	extent_z: float,
	name_prefix: String = "Corner",
	outward: float = 0.25
) -> void:
	var sx := signf(corner_x)
	var sz := signf(corner_z)
	if sx == 0.0 or sz == 0.0:
		return
	var in_x := maxf(0.05, extent_x)
	var in_z := maxf(0.05, extent_z)
	var out := maxf(0.02, outward)
	var ex := in_x + out
	var ez := in_z + out

	var walk_mat := sidewalk_material if sidewalk_material else _sidewalk_mat(
		Vector2(maxf(0.5, in_x), maxf(0.5, in_z))
	)
	var curb_mat := curb_material if curb_material else _std(
		Color(0.3, 0.29, 0.265, 1.0), 0.9, 0.02
	)

	var half_x := span_x * 0.5
	var half_z := span_z * 0.5
	var sidewalk_top := road_surface_y + curb_height
	var slab_bottom := road_surface_y - slab_thickness
	var walk_thickness := sidewalk_top - slab_bottom
	var walk_y := slab_bottom + walk_thickness * 0.5

	var edge_x := sx * half_x
	var edge_z := sz * half_z
	# Inward by in_*, outward past the tile edge by out (covers trimmed end-caps).
	var pad_cx := edge_x - sx * (in_x - out) * 0.5
	var pad_cz := edge_z - sz * (in_z - out) * 0.5

	_add_box_centered_to(
		host,
		"%sWalk" % name_prefix,
		Vector3(ex, walk_thickness, ez),
		Vector3(pad_cx, walk_y, pad_cz),
		walk_mat,
		true
	)

	var curb_w := curb_face_depth
	var curb_h := curb_height + 0.02
	var curb_y := road_surface_y + curb_h * 0.5
	# Inner faces of the L (toward carriageway), flush with inward extents.
	var inner_x := edge_x - sx * in_x
	var inner_z := edge_z - sz * in_z

	# Curb strip parallel to Z (faces the road along ±X).
	_add_box_centered_to(
		host,
		"%sCurbZ" % name_prefix,
		Vector3(curb_w, curb_h, in_z + out * 0.5),
		Vector3(inner_x + sx * curb_w * 0.5, curb_y, edge_z - sz * (in_z - out * 0.5) * 0.5),
		curb_mat,
		false
	)
	# Curb strip parallel to X (faces the road along ±Z); shorten so corner doesn't double up.
	_add_box_centered_to(
		host,
		"%sCurbX" % name_prefix,
		Vector3(in_x + out * 0.5 - curb_w, curb_h, curb_w),
		Vector3(
			edge_x - sx * (in_x - out * 0.5 + curb_w) * 0.5,
			curb_y,
			inner_z + sz * curb_w * 0.5
		),
		curb_mat,
		false
	)


func _build() -> void:
	if _built:
		return
	_built = true

	if include_collision:
		_body = StaticBody3D.new()
		_body.name = "Surfaces"
		add_child(_body)

	var half_x := span_x * 0.5
	var road_half := half_x - sidewalk_width
	var gutter_inner := road_half - gutter_width
	var sidewalk_top := road_surface_y + curb_height
	var slab_bottom := road_surface_y - slab_thickness

	# Carriageway grows to the tile edge on any side without a sidewalk.
	var left_bound := -half_x if not sidewalk_left else -gutter_inner
	var right_bound := half_x if not sidewalk_right else gutter_inner
	var carriage_width := maxf(0.5, right_bound - left_bound)
	var carriage_center := (left_bound + right_bound) * 0.5

	var road_mat := road_material if road_material else _asphalt_mat(
		Vector2(carriage_width, span_z)
	)
	var walk_mat := sidewalk_material if sidewalk_material else _sidewalk_mat(
		Vector2(sidewalk_width, span_z)
	)
	var curb_mat := curb_material if curb_material else _std(
		Color(0.3, 0.29, 0.265, 1.0), 0.9, 0.02
	)
	var metal_mat := metal_material if metal_material else _std(
		Color(0.1, 0.105, 0.1, 1.0), 0.62, 0.72
	)
	var grate_mat := _std(Color(0.05, 0.055, 0.05, 1.0), 0.5, 0.8)
	var dark_mat := _std(Color(0.04, 0.042, 0.038, 1.0), 0.96, 0.08)

	# --- Primary slabs -------------------------------------------------------
	_add_box_centered(
		"Carriageway",
		Vector3(carriage_width, slab_thickness, span_z),
		Vector3(carriage_center, road_surface_y - slab_thickness * 0.5, 0.0),
		road_mat,
		true
	)

	var walk_thickness := sidewalk_top - slab_bottom
	var walk_center_x := half_x - sidewalk_width * 0.5
	var walk_span := _sidewalk_span_z()
	var walk_len: float = walk_span.x
	var walk_cz: float = walk_span.y
	if sidewalk_left:
		_add_box_centered(
			"SidewalkLeft",
			Vector3(sidewalk_width, walk_thickness, walk_len),
			Vector3(-walk_center_x, slab_bottom + walk_thickness * 0.5, walk_cz),
			walk_mat,
			true
		)
	if sidewalk_right:
		_add_box_centered(
			"SidewalkRight",
			Vector3(sidewalk_width, walk_thickness, walk_len),
			Vector3(walk_center_x, slab_bottom + walk_thickness * 0.5, walk_cz),
			walk_mat,
			true
		)

	var gutter_top := road_surface_y - gutter_depth
	var gutter_thickness := gutter_top - slab_bottom
	var gutter_center_x := gutter_inner + gutter_width * 0.5
	if sidewalk_left:
		_add_box_centered(
			"GutterLeft",
			Vector3(gutter_width, gutter_thickness, walk_len),
			Vector3(-gutter_center_x, slab_bottom + gutter_thickness * 0.5, walk_cz),
			dark_mat,
			true
		)
	if sidewalk_right:
		_add_box_centered(
			"GutterRight",
			Vector3(gutter_width, gutter_thickness, walk_len),
			Vector3(gutter_center_x, slab_bottom + gutter_thickness * 0.5, walk_cz),
			dark_mat,
			true
		)

	var curb_w := curb_face_depth
	var curb_h := curb_height + 0.02
	var curb_x := road_half - curb_w * 0.5
	if sidewalk_left:
		_add_box_centered(
			"CurbLeft",
			Vector3(curb_w, curb_h, walk_len),
			Vector3(-curb_x, road_surface_y + curb_h * 0.5, walk_cz),
			curb_mat,
			false
		)
	if sidewalk_right:
		_add_box_centered(
			"CurbRight",
			Vector3(curb_w, curb_h, walk_len),
			Vector3(curb_x, road_surface_y + curb_h * 0.5, walk_cz),
			curb_mat,
			false
		)

	_build_expansion_joints(carriage_width, carriage_center, dark_mat)
	_build_drains(gutter_inner, grate_mat, metal_mat, dark_mat)
	_build_manholes(carriage_width, carriage_center, metal_mat, dark_mat)
	_build_sidewalk_dressing(half_x, sidewalk_top, metal_mat, curb_mat, dark_mat)


func _build_expansion_joints(
	carriage_width: float,
	carriage_center: float,
	dark_mat: Material
) -> void:
	# Shallow transverse grooves across the carriageway every ~5m.
	var spacing := 5.0
	var joint_w := carriage_width - 0.3
	var joint_d := 0.06
	var joint_h := 0.02
	var z := -span_z * 0.5 + spacing
	var i := 0
	while z < span_z * 0.5 - 1.0:
		_add_box_centered(
			"ExpansionJoint_%d" % i,
			Vector3(joint_w, joint_h, joint_d),
			Vector3(carriage_center, road_surface_y - joint_h * 0.35, z),
			dark_mat,
			false
		)
		z += spacing
		i += 1


func _build_drains(
	gutter_inner: float,
	grate_mat: Material,
	metal_mat: Material,
	dark_mat: Material
) -> void:
	if not sidewalk_left and not sidewalk_right:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value(17)
	var spacing := 5.0
	var z := -span_z * 0.5 + 2.5
	var i := 0
	while z < span_z * 0.5 - 1.5:
		for side: float in [-1.0, 1.0]:
			if side < 0.0 and not sidewalk_left:
				continue
			if side > 0.0 and not sidewalk_right:
				continue
			var gx := side * (gutter_inner + gutter_width * 0.5)
			# Frame
			_add_box_centered(
				"DrainFrame_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(gutter_width * 0.92, 0.03, 0.55),
				Vector3(gx, road_surface_y - gutter_depth + 0.01, z),
				metal_mat,
				false
			)
			# Grate insert
			_add_box_centered(
				"DrainGrate_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(gutter_width * 0.7, 0.025, 0.42),
				Vector3(gx, road_surface_y - gutter_depth + 0.018, z),
				grate_mat,
				false
			)
			# Slots as thin dark bars
			for slot in range(4):
				var sz := z - 0.15 + slot * 0.1
				_add_box_centered(
					"DrainSlot_%d_%s_%d" % [i, "L" if side < 0.0 else "R", slot],
					Vector3(gutter_width * 0.55, 0.02, 0.035),
					Vector3(gx, road_surface_y - gutter_depth + 0.028, sz),
					dark_mat,
					false
				)
		z += spacing + rng.randf_range(-0.4, 0.4)
		i += 1


func _build_manholes(
	carriage_width: float,
	carriage_center: float,
	metal_mat: Material,
	dark_mat: Material
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value(41)
	var count := maxi(1, int(span_z / 10.0))
	var half_w := carriage_width * 0.5
	for i in count:
		var mx := carriage_center + rng.randf_range(-half_w * 0.55, half_w * 0.55)
		# Bias away from exact center so van path stays clean-ish.
		var lateral := mx - carriage_center
		if absf(lateral) < 0.9:
			mx = carriage_center + 1.2 * signf(lateral if lateral != 0.0 else 1.0)
		var mz := rng.randf_range(-span_z * 0.4, span_z * 0.4)
		var size := rng.randf_range(0.55, 0.72)
		# Recess well
		_add_box_centered(
			"ManholeWell_%d" % i,
			Vector3(size, 0.04, size),
			Vector3(mx, road_surface_y - 0.015, mz),
			dark_mat,
			false
		)
		# Lid
		_add_box_centered(
			"ManholeLid_%d" % i,
			Vector3(size * 0.92, 0.03, size * 0.92),
			Vector3(mx, road_surface_y + 0.005, mz),
			metal_mat,
			false
		)
		# Cross ribs on lid
		_add_box_centered(
			"ManholeRibX_%d" % i,
			Vector3(size * 0.8, 0.02, 0.05),
			Vector3(mx, road_surface_y + 0.02, mz),
			_std(Color(0.18, 0.185, 0.175, 1.0), 0.5, 0.7),
			false
		)
		_add_box_centered(
			"ManholeRibZ_%d" % i,
			Vector3(0.05, 0.02, size * 0.8),
			Vector3(mx, road_surface_y + 0.02, mz),
			_std(Color(0.18, 0.185, 0.175, 1.0), 0.5, 0.7),
			false
		)


func _build_sidewalk_dressing(
	half_x: float,
	sidewalk_top: float,
	metal_mat: Material,
	curb_mat: Material,
	dark_mat: Material
) -> void:
	if not sidewalk_left and not sidewalk_right:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value(73)
	var walk_inner := half_x - sidewalk_width
	var walk_mid := half_x - sidewalk_width * 0.5
	var half_z := span_z * 0.5
	var z_min := -half_z + maxf(0.0, sidewalk_trim_z_neg) + 0.4
	var z_max := half_z - maxf(0.0, sidewalk_trim_z_pos) - 0.4

	# Utility boxes against the wall line, sparse.
	var z := z_min + span_z * 0.1
	var i := 0
	while z < z_max - span_z * 0.05:
		for side: float in [-1.0, 1.0]:
			if side < 0.0 and not sidewalk_left:
				continue
			if side > 0.0 and not sidewalk_right:
				continue
			if rng.randf() > 0.55:
				continue
			var bx := side * (half_x - 0.35)
			var bw := rng.randf_range(0.35, 0.55)
			var bh := rng.randf_range(0.55, 0.85)
			var bd := rng.randf_range(0.28, 0.4)
			_add_box_centered(
				"UtilityBox_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(bw, bh, bd),
				Vector3(bx, sidewalk_top + bh * 0.5, z + rng.randf_range(-0.3, 0.3)),
				metal_mat,
				false
			)
		z += rng.randf_range(4.5, 7.0)
		i += 1

	# Short bollards near curb, sparse along each side.
	z = z_min + span_z * 0.05
	i = 0
	while z < z_max:
		for side: float in [-1.0, 1.0]:
			if side < 0.0 and not sidewalk_left:
				continue
			if side > 0.0 and not sidewalk_right:
				continue
			if rng.randf() > 0.4:
				continue
			var bx := side * (walk_inner + 0.28)
			var h := 0.55
			_add_box_centered(
				"Bollard_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(0.14, h, 0.14),
				Vector3(bx, sidewalk_top + h * 0.5, z),
				curb_mat,
				false
			)
			_add_box_centered(
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
			if side < 0.0 and not sidewalk_left:
				continue
			if side > 0.0 and not sidewalk_right:
				continue
			_add_box_centered(
				"WalkSeam_%d_%s" % [i, "L" if side < 0.0 else "R"],
				Vector3(sidewalk_width * 0.92, 0.015, 0.04),
				Vector3(side * walk_mid, sidewalk_top + 0.004, sz),
				dark_mat,
				false
			)
		sz += seam_spacing
		i += 1


func _add_box_centered(
	node_name: String,
	size: Vector3,
	pos: Vector3,
	material: Material,
	collide: bool
) -> void:
	_add_box_centered_to(self, node_name, size, pos, material, collide, _body)


func _add_box_centered_to(
	host: Node3D,
	node_name: String,
	size: Vector3,
	pos: Vector3,
	material: Material,
	collide: bool,
	collision_body: StaticBody3D = null
) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = box
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	host.add_child(mi)

	var body := collision_body
	if body == null and collide and include_collision:
		body = host.get_node_or_null("CornerSurfaces") as StaticBody3D
		if body == null:
			body = StaticBody3D.new()
			body.name = "CornerSurfaces"
			host.add_child(body)

	if collide and include_collision and body:
		var col := CollisionShape3D.new()
		col.name = "%sCollision" % node_name
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = pos
		body.add_child(col)


func _seed_value(salt: int) -> int:
	if detail_seed != 0:
		return int(detail_seed) ^ salt
	# Stable per footprint so tiled segments don't shimmer when rebuilt.
	return hash(Vector3(span_x, span_z, float(salt)))


## Returns (length along Z, center Z) for sidewalk/curb/gutter after end trims.
func _sidewalk_span_z() -> Vector2:
	var half_z := span_z * 0.5
	var z_neg := -half_z + maxf(0.0, sidewalk_trim_z_neg)
	var z_pos := half_z - maxf(0.0, sidewalk_trim_z_pos)
	var length := maxf(0.05, z_pos - z_neg)
	return Vector2(length, (z_neg + z_pos) * 0.5)


## Trim sidewalk/curb ends then rebuild (for junction / side-street mouths).
func set_sidewalk_end_trims(trim_z_pos: float, trim_z_neg: float) -> void:
	var want_pos := maxf(0.0, trim_z_pos)
	var want_neg := maxf(0.0, trim_z_neg)
	if (
		is_equal_approx(sidewalk_trim_z_pos, want_pos)
		and is_equal_approx(sidewalk_trim_z_neg, want_neg)
		and _built
	):
		return
	sidewalk_trim_z_pos = want_pos
	sidewalk_trim_z_neg = want_neg
	rebuild()


func _asphalt_mat(_surface_size_m: Vector2) -> ShaderMaterial:
	var shader := load("res://scenes/corridor/asphalt_surface.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("washout", 0.32)
	mat.set_shader_parameter("trash", 1.0)
	mat.set_shader_parameter("roughness_value", 0.94)
	return mat


func _sidewalk_mat(surface_size_m: Vector2) -> ShaderMaterial:
	var shader := load("res://scenes/corridor/sidewalk_surface.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("surface_size_m", surface_size_m)
	mat.set_shader_parameter("slab_spacing_m", 1.2)
	mat.set_shader_parameter("washout", 0.5)
	mat.set_shader_parameter("trash", 0.65)
	mat.set_shader_parameter("roughness_value", 0.92)
	return mat


func _std(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
