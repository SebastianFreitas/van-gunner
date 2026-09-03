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
@export var include_collision := true
@export var detail_seed := 0
@export var rebuild_on_ready := true

## Optional overrides — leave empty to use industrial_surface with zone colors.
@export var road_material: Material
@export var sidewalk_material: Material
@export var curb_material: Material
@export var metal_material: Material
@export var paint_material: Material

var _built := false
var _body: StaticBody3D


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_build()


func _build() -> void:
	if _built:
		return
	_built = true

	if include_collision:
		_body = StaticBody3D.new()
		_body.name = "Surfaces"
		add_child(_body)

	var road_mat := road_material if road_material else _industrial_mat(
		Color(0.13, 0.135, 0.13, 1.0),
		Color(0.04, 0.045, 0.04, 1.0),
		Color(0.22, 0.09, 0.04, 1.0),
		Vector2(4.0, maxf(6.0, span_z * 0.55)),
		0.94
	)
	var walk_mat := sidewalk_material if sidewalk_material else _industrial_mat(
		Color(0.22, 0.21, 0.195, 1.0),
		Color(0.08, 0.075, 0.07, 1.0),
		Color(0.28, 0.12, 0.05, 1.0),
		Vector2(3.0, maxf(4.0, span_z * 0.4)),
		0.9
	)
	var curb_mat := curb_material if curb_material else _std(
		Color(0.34, 0.33, 0.3, 1.0), 0.88, 0.05
	)
	var metal_mat := metal_material if metal_material else _std(
		Color(0.12, 0.125, 0.12, 1.0), 0.55, 0.78
	)
	var paint_mat := paint_material if paint_material else _std(
		Color(0.72, 0.62, 0.18, 1.0), 0.7, 0.05
	)
	var grate_mat := _std(Color(0.06, 0.065, 0.06, 1.0), 0.45, 0.85)
	var dark_mat := _std(Color(0.05, 0.055, 0.05, 1.0), 0.95, 0.1)

	var half_x := span_x * 0.5
	var road_half := half_x - sidewalk_width
	var carriage_half := road_half - gutter_width
	var sidewalk_top := road_surface_y + curb_height
	var slab_bottom := road_surface_y - slab_thickness

	# --- Primary slabs -------------------------------------------------------
	# Carriageway (driveable center). Top at road_surface_y.
	_add_box_centered(
		"Carriageway",
		Vector3(carriage_half * 2.0, slab_thickness, span_z),
		Vector3(0.0, road_surface_y - slab_thickness * 0.5, 0.0),
		road_mat,
		true
	)

	# Sidewalks — raised curb_height above road, same slab bottom so curb face reads.
	var walk_thickness := sidewalk_top - slab_bottom
	var walk_center_x := half_x - sidewalk_width * 0.5
	_add_box_centered(
		"SidewalkLeft",
		Vector3(sidewalk_width, walk_thickness, span_z),
		Vector3(-walk_center_x, slab_bottom + walk_thickness * 0.5, 0.0),
		walk_mat,
		true
	)
	_add_box_centered(
		"SidewalkRight",
		Vector3(sidewalk_width, walk_thickness, span_z),
		Vector3(walk_center_x, slab_bottom + walk_thickness * 0.5, 0.0),
		walk_mat,
		true
	)

	# Gutters (slightly depressed strips between curb and carriageway).
	var gutter_top := road_surface_y - gutter_depth
	var gutter_thickness := gutter_top - slab_bottom
	var gutter_center_x := carriage_half + gutter_width * 0.5
	_add_box_centered(
		"GutterLeft",
		Vector3(gutter_width, gutter_thickness, span_z),
		Vector3(-gutter_center_x, slab_bottom + gutter_thickness * 0.5, 0.0),
		dark_mat,
		true
	)
	_add_box_centered(
		"GutterRight",
		Vector3(gutter_width, gutter_thickness, span_z),
		Vector3(gutter_center_x, slab_bottom + gutter_thickness * 0.5, 0.0),
		dark_mat,
		true
	)

	# Curb stones — thin vertical-looking caps on the sidewalk edge.
	var curb_w := curb_face_depth
	var curb_h := curb_height + 0.02
	var curb_x := road_half - curb_w * 0.5
	_add_box_centered(
		"CurbLeft",
		Vector3(curb_w, curb_h, span_z),
		Vector3(-curb_x, road_surface_y + curb_h * 0.5, 0.0),
		curb_mat,
		false
	)
	_add_box_centered(
		"CurbRight",
		Vector3(curb_w, curb_h, span_z),
		Vector3(curb_x, road_surface_y + curb_h * 0.5, 0.0),
		curb_mat,
		false
	)

	_build_lane_paint(carriage_half, paint_mat)
	_build_expansion_joints(carriage_half, dark_mat)
	_build_drains(carriage_half, grate_mat, metal_mat, dark_mat)
	_build_manholes(carriage_half, metal_mat, dark_mat)
	_build_sidewalk_dressing(half_x, sidewalk_top, metal_mat, curb_mat, dark_mat)


func _build_lane_paint(carriage_half: float, paint_mat: Material) -> void:
	# Broken center line — thin raised paint bars along Z.
	var dash_len := 1.4
	var gap := 1.1
	var paint_h := 0.012
	var paint_w := 0.12
	var z := -span_z * 0.5 + dash_len * 0.5 + 0.4
	var i := 0
	while z < span_z * 0.5 - dash_len * 0.5:
		_add_box_centered(
			"CenterDash_%d" % i,
			Vector3(paint_w, paint_h, dash_len),
			Vector3(0.0, road_surface_y + paint_h * 0.5, z),
			paint_mat,
			false
		)
		z += dash_len + gap
		i += 1

	# Edge lines just inside gutters (solid, thinner).
	var edge_x := carriage_half - 0.18
	_add_box_centered(
		"EdgeLineLeft",
		Vector3(0.08, paint_h, span_z * 0.92),
		Vector3(-edge_x, road_surface_y + paint_h * 0.5, 0.0),
		paint_mat,
		false
	)
	_add_box_centered(
		"EdgeLineRight",
		Vector3(0.08, paint_h, span_z * 0.92),
		Vector3(edge_x, road_surface_y + paint_h * 0.5, 0.0),
		paint_mat,
		false
	)


func _build_expansion_joints(carriage_half: float, dark_mat: Material) -> void:
	# Shallow transverse grooves across the carriageway every ~5m.
	var spacing := 5.0
	var joint_w := carriage_half * 2.0 - 0.3
	var joint_d := 0.06
	var joint_h := 0.02
	var z := -span_z * 0.5 + spacing
	var i := 0
	while z < span_z * 0.5 - 1.0:
		_add_box_centered(
			"ExpansionJoint_%d" % i,
			Vector3(joint_w, joint_h, joint_d),
			Vector3(0.0, road_surface_y - joint_h * 0.35, z),
			dark_mat,
			false
		)
		z += spacing
		i += 1


func _build_drains(
	carriage_half: float,
	grate_mat: Material,
	metal_mat: Material,
	dark_mat: Material
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value(17)
	var spacing := 5.0
	var z := -span_z * 0.5 + 2.5
	var i := 0
	while z < span_z * 0.5 - 1.5:
		for side: float in [-1.0, 1.0]:
			var gx := side * (carriage_half + gutter_width * 0.5)
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


func _build_manholes(carriage_half: float, metal_mat: Material, dark_mat: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value(41)
	var count := maxi(1, int(span_z / 10.0))
	for i in count:
		var mx := rng.randf_range(-carriage_half * 0.55, carriage_half * 0.55)
		# Bias away from exact center so van path stays clean-ish.
		if absf(mx) < 0.9:
			mx = 1.2 * signf(mx if mx != 0.0 else 1.0)
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
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value(73)
	var walk_inner := half_x - sidewalk_width
	var walk_mid := half_x - sidewalk_width * 0.5

	# Utility boxes against the wall line, sparse.
	var z := -span_z * 0.35
	var i := 0
	while z < span_z * 0.4:
		for side: float in [-1.0, 1.0]:
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
	z = -span_z * 0.4
	i = 0
	while z < span_z * 0.4:
		for side: float in [-1.0, 1.0]:
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
	var sz := -span_z * 0.5 + seam_spacing
	i = 0
	while sz < span_z * 0.5 - 0.4:
		for side: float in [-1.0, 1.0]:
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
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = box
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)

	if collide and include_collision and _body:
		var col := CollisionShape3D.new()
		col.name = "%sCollision" % node_name
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = pos
		_body.add_child(col)


func _seed_value(salt: int) -> int:
	if detail_seed != 0:
		return int(detail_seed) ^ salt
	# Stable per footprint so tiled segments don't shimmer when rebuilt.
	return hash(Vector3(span_x, span_z, float(salt)))


func _industrial_mat(
	base: Color,
	seam: Color,
	rust: Color,
	tile_count: Vector2,
	roughness: float
) -> ShaderMaterial:
	var shader := load("res://scenes/corridor/industrial_surface.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("seam_color", seam)
	mat.set_shader_parameter("rust_color", rust)
	mat.set_shader_parameter("tile_count", tile_count)
	mat.set_shader_parameter("roughness_value", roughness)
	return mat


func _std(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
