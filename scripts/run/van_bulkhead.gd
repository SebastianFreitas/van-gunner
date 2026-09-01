class_name VanBulkhead
extends StaticBody3D

## Mid/rear cargo bulkhead: metal frame + diagonal mesh, side doorway.
## Local XY is the bulkhead face; +Z faces the rear of the van.

enum OpeningSide { LEFT, RIGHT }

@export var opening_side: OpeningSide = OpeningSide.RIGHT
@export var van_half_width := 2.36
@export var opening_width := 1.15
@export var panel_thickness := 0.12
@export var frame_depth := 0.16
@export var frame_thickness := 0.08
@export var kick_height := 0.55
@export var edge_height := 3.02
@export var peak_rise := 0.38
@export var mesh_spacing := 0.22
@export var mesh_bar_size := 0.028
@export var mesh_bar_depth := 0.04
@export var z_position := 1.0
@export var rebuild_on_ready := true

var _built := false


func _ready() -> void:
	position.z = z_position
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

	var steel := _steel_material()
	var mesh_mat := _mesh_material()

	var opening_left: float
	var opening_right: float
	var panel_left: float
	var panel_right: float

	if opening_side == OpeningSide.RIGHT:
		opening_right = van_half_width
		opening_left = van_half_width - opening_width
		panel_left = -van_half_width
		panel_right = opening_left
	else:
		opening_left = -van_half_width
		opening_right = -van_half_width + opening_width
		panel_left = opening_right
		panel_right = van_half_width

	var panel_width := panel_right - panel_left
	var panel_center_x := (panel_left + panel_right) * 0.5

	# Outer wall posts (kiss the side walls).
	_add_post("LeftWallPost", -van_half_width + frame_thickness * 0.5, steel)
	_add_post("RightWallPost", van_half_width - frame_thickness * 0.5, steel)

	# Doorway post on the panel edge of the opening.
	var opening_post_x := (
		opening_left + frame_thickness * 0.5
		if opening_side == OpeningSide.RIGHT
		else opening_right - frame_thickness * 0.5
	)
	_add_post("OpeningInnerPost", opening_post_x, steel)
	# Soft header over the doorway so the opening reads as framed, not a hole.
	var door_header_y := edge_height - frame_thickness * 0.55
	_add_box(
		"DoorHeader",
		Vector3(opening_width, frame_thickness, frame_depth),
		Vector3((opening_left + opening_right) * 0.5, door_header_y, 0.0),
		steel
	)

	# Solid kick plate across the panel.
	_add_box(
		"KickPlate",
		Vector3(panel_width - frame_thickness * 0.5, kick_height, panel_thickness),
		Vector3(panel_center_x, kick_height * 0.5, 0.0),
		steel
	)

	# Top + bottom rails along the mesh panel.
	_add_box(
		"BottomRail",
		Vector3(panel_width, frame_thickness, frame_depth),
		Vector3(panel_center_x, kick_height + frame_thickness * 0.5, 0.0),
		steel
	)

	# Curved top rail following the vault profile.
	_add_curved_header(panel_left, panel_right, steel)

	# Vertical mid posts for stiffness.
	var mid_count := maxi(1, int(panel_width / 1.15))
	for i in range(1, mid_count):
		var t := float(i) / float(mid_count)
		var x := lerpf(panel_left, panel_right, t)
		_add_panel_post("MidPost_%d" % i, x, steel)

	# Diagonal expanded-metal style netting above the kick plate.
	_add_diagonal_mesh(panel_left, panel_right, kick_height + frame_thickness, mesh_mat)

	# Collision for the solid panel span (full height).
	var collision_height := edge_height + peak_rise * 0.35
	var shape := BoxShape3D.new()
	shape.size = Vector3(panel_width, collision_height, maxf(panel_thickness, frame_depth))
	var col := CollisionShape3D.new()
	col.name = "PanelCollision"
	col.shape = shape
	col.position = Vector3(panel_center_x, collision_height * 0.5, 0.0)
	add_child(col)


func _vault_y(x: float) -> float:
	var half := van_half_width
	var t := clampf(absf(x) / half, 0.0, 1.0)
	return edge_height + peak_rise * (1.0 - t * t)


func _add_post(node_name: String, x: float, material: Material) -> void:
	var top := _vault_y(x)
	_add_box(
		node_name,
		Vector3(frame_thickness, top, frame_depth),
		Vector3(x, top * 0.5, 0.0),
		material
	)


func _add_panel_post(node_name: String, x: float, material: Material) -> void:
	var top := _vault_y(x)
	var height := top - kick_height
	_add_box(
		node_name,
		Vector3(frame_thickness * 0.75, height, frame_depth * 0.85),
		Vector3(x, kick_height + height * 0.5, 0.0),
		material
	)


func _add_curved_header(left_x: float, right_x: float, material: Material) -> void:
	var segments := 10
	for i in range(segments):
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var x0 := lerpf(left_x, right_x, t0)
		var x1 := lerpf(left_x, right_x, t1)
		var x := (x0 + x1) * 0.5
		var y := _vault_y(x) - frame_thickness * 0.45
		var width := absf(x1 - x0) + 0.01
		_add_box(
			"TopRail_%d" % i,
			Vector3(width, frame_thickness, frame_depth),
			Vector3(x, y, 0.0),
			material
		)


func _add_diagonal_mesh(left_x: float, right_x: float, bottom_y: float, material: Material) -> void:
	var inset := frame_thickness * 0.65
	left_x += inset
	right_x -= inset
	bottom_y += inset * 0.35
	var width := right_x - left_x
	if width <= 0.08:
		return

	# Uniform lattice in a bounding rect, then drop segments that poke past the vault.
	var max_top := _vault_y((left_x + right_x) * 0.5) - frame_thickness - inset * 0.25
	var cols := maxi(2, int(ceil(width / mesh_spacing)))
	var rows := maxi(2, int(ceil((max_top - bottom_y) / mesh_spacing)))
	var cell_w := width / float(cols)
	var cell_h := (max_top - bottom_y) / float(rows)
	var index := 0

	for col in range(cols):
		for row in range(rows):
			var x0 := left_x + float(col) * cell_w
			var x1 := x0 + cell_w
			var y0 := bottom_y + float(row) * cell_h
			var y1 := y0 + cell_h
			var limit0 := _vault_y(x0) - frame_thickness - inset * 0.25
			var limit1 := _vault_y(x1) - frame_thickness - inset * 0.25
			if y0 < minf(limit0, limit1):
				if y1 <= minf(limit0, limit1) + 0.03:
					_add_segment("MeshFwd_%d" % index, Vector3(x0, y0, 0.0), Vector3(x1, y1, 0.0), material)
					index += 1
				if y0 <= minf(limit0, limit1) + 0.03:
					_add_segment("MeshBack_%d" % index, Vector3(x0, y1, 0.0), Vector3(x1, y0, 0.0), material)
					index += 1

func _add_segment(node_name: String, a: Vector3, b: Vector3, material: Material) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.02:
		return
	var mid := (a + b) * 0.5
	var angle := atan2(delta.y, delta.x)
	_add_box(
		node_name,
		Vector3(length, mesh_bar_size, mesh_bar_depth),
		mid,
		material,
		Vector3(0.0, 0.0, angle)
	)


func _add_box(
	node_name: String,
	size: Vector3,
	pos: Vector3,
	material: Material,
	euler: Vector3 = Vector3.ZERO
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = euler
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.23, 0.24, 1.0)
	mat.metallic = 0.78
	mat.roughness = 0.42
	return mat


func _mesh_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.125, 0.13, 1.0)
	mat.metallic = 0.88
	mat.roughness = 0.38
	return mat
