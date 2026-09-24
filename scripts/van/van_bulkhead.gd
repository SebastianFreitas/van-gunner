class_name VanBulkhead
extends StaticBody3D

## Mid/rear cargo bulkhead: metal frame + diagonal mesh, side doorway.
## Local XY is the bulkhead face; +Z faces the rear of the van.
## Outer edges follow VanSideWall's bowed/tapered profile.

enum OpeningSide { LEFT, RIGHT }

@export var opening_side: OpeningSide = OpeningSide.LEFT
@export var van_half_width := 2.36
@export var opening_width := 1.55
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
@export var wall_post_segments := 14
@export var rebuild_on_ready := true

var _built := false
var _side_walls: VanSideWall = null


func _ready() -> void:
	position.z = z_position
	_side_walls = _find_side_walls()
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_side_walls = _find_side_walls()
	_build()


func _find_side_walls() -> VanSideWall:
	var parent := get_parent()
	if parent == null:
		return null
	var shell := parent.get_node_or_null("Shell")
	if shell == null:
		return null
	return shell.get_node_or_null("SideWalls") as VanSideWall


## Interior half-width of the cargo liner at height y.
func _wall_half(y: float) -> float:
	if _side_walls != null:
		return _side_walls.wall_x_at(y)
	return van_half_width


## Half-span used by the vault curve — matches the wall at roof height.
func _vault_half() -> float:
	return _wall_half(edge_height)


func _build() -> void:
	if _built:
		return
	_built = true

	var steel := _steel_material()
	var mesh_mat := _mesh_material()

	var floor_half := _wall_half(0.0)
	var roof_half := _vault_half()
	var kick_half := _wall_half(kick_height)

	var opening_inner: float
	var panel_inner: float
	var outer_sign: float

	if opening_side == OpeningSide.RIGHT:
		opening_inner = floor_half - opening_width
		panel_inner = opening_inner
		outer_sign = -1.0
	else:
		opening_inner = -floor_half + opening_width
		panel_inner = opening_inner
		outer_sign = 1.0

	# Outer wall posts follow the bowed liner.
	_add_curved_wall_post("LeftWallPost", -1.0, steel)
	_add_curved_wall_post("RightWallPost", 1.0, steel)

	# Doorway post on the panel edge of the opening (straight).
	var opening_post_x := (
		opening_inner + frame_thickness * 0.5
		if opening_side == OpeningSide.RIGHT
		else opening_inner - frame_thickness * 0.5
	)
	_add_post("OpeningInnerPost", opening_post_x, steel)

	# Soft header over the doorway — outer end rides the wall curve.
	var door_header_y := edge_height - frame_thickness * 0.55
	var door_wall_sign := -outer_sign
	var door_outer := door_wall_sign * (_wall_half(door_header_y) - frame_thickness * 0.15)
	_add_box(
		"DoorHeader",
		Vector3(absf(opening_inner - door_outer), frame_thickness, frame_depth),
		Vector3((door_outer + opening_inner) * 0.5, door_header_y, 0.0),
		steel
	)

	# Solid kick plate across the panel (trapezoid following the wall).
	_add_panel_slab(
		"KickPlate",
		panel_inner,
		outer_sign,
		0.0,
		kick_height,
		panel_thickness,
		steel,
		frame_thickness * 0.25
	)

	# Bottom rail along the mesh panel at kick height.
	var bottom_outer := outer_sign * (kick_half - frame_thickness * 0.15)
	var bottom_width := absf(bottom_outer - panel_inner)
	_add_box(
		"BottomRail",
		Vector3(bottom_width, frame_thickness, frame_depth),
		Vector3((panel_inner + bottom_outer) * 0.5, kick_height + frame_thickness * 0.5, 0.0),
		steel
	)

	# Curved top rail following the vault; outer end meets the wall at roof width.
	_add_curved_header(panel_inner, outer_sign * roof_half, steel)

	# Vertical mid posts for stiffness (stay inside the narrowest panel span).
	var mid_outer := outer_sign * minf(kick_half, roof_half)
	var panel_width_mid := absf(mid_outer - panel_inner)
	var mid_count := maxi(1, int(panel_width_mid / 1.15))
	for i in range(1, mid_count):
		var t := float(i) / float(mid_count)
		var x := lerpf(panel_inner, mid_outer, t)
		_add_panel_post("MidPost_%d" % i, x, steel)

	# Diagonal expanded-metal style netting above the kick plate.
	_add_diagonal_mesh(panel_inner, outer_sign, kick_height + frame_thickness, mesh_mat)

	# Collision for the solid panel span (full height) — use max width so nothing leaks.
	var max_half := floor_half
	if _side_walls != null:
		for i in range(9):
			max_half = maxf(max_half, _wall_half(edge_height * float(i) / 8.0))
	var col_outer := outer_sign * max_half
	var collision_height := edge_height + peak_rise * 0.35
	var col_width := absf(col_outer - panel_inner)
	var shape := BoxShape3D.new()
	shape.size = Vector3(col_width, collision_height, maxf(panel_thickness, frame_depth))
	var col := CollisionShape3D.new()
	col.name = "PanelCollision"
	col.shape = shape
	col.position = Vector3((panel_inner + col_outer) * 0.5, collision_height * 0.5, 0.0)
	add_child(col)


func _vault_y(x: float) -> float:
	var half := maxf(_vault_half(), 0.05)
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


func _add_curved_wall_post(node_name: String, wall_sign: float, material: Material) -> void:
	var segs := maxi(wall_post_segments, 4)
	var inset := frame_thickness * 0.5
	var y_top_limit := _vault_y(wall_sign * (_vault_half() - inset))
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := lerpf(0.0, y_top_limit, t0)
		var y1 := lerpf(0.0, y_top_limit, t1)
		var x0 := wall_sign * (_wall_half(y0) - inset)
		var x1 := wall_sign * (_wall_half(y1) - inset)
		# Clip the upper end if it would poke through the vault.
		if y0 >= _vault_y(x0) - 0.01:
			continue
		if y1 > _vault_y(x1):
			y1 = _vault_y(x1)
			x1 = wall_sign * (_wall_half(y1) - inset)
		var dx := x1 - x0
		var dy := y1 - y0
		var length := sqrt(dx * dx + dy * dy)
		if length < 0.02:
			continue
		# Box local +Y along the wall tangent. RotZ maps (0,1) → (-sin θ, cos θ),
		# so θ = atan2(-dx, dy) aims +Y at (dx, dy).
		var angle := atan2(-dx, dy)
		_add_box(
			"%s_%d" % [node_name, i],
			Vector3(frame_thickness, length + 0.006, frame_depth),
			Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0),
			material,
			Vector3(0.0, 0.0, angle)
		)


func _add_panel_post(node_name: String, x: float, material: Material) -> void:
	var top := _vault_y(x)
	var height := top - kick_height
	if height < 0.05:
		return
	_add_box(
		node_name,
		Vector3(frame_thickness * 0.75, height, frame_depth * 0.85),
		Vector3(x, kick_height + height * 0.5, 0.0),
		material
	)


func _add_panel_slab(
	node_name: String,
	inner_x: float,
	outer_sign: float,
	y0: float,
	y1: float,
	depth: float,
	material: Material,
	x_inset: float
) -> void:
	## Horizontal strips so the outer edge follows the wall bow.
	var segs := 6
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var ya := lerpf(y0, y1, t0)
		var yb := lerpf(y0, y1, t1)
		var y := (ya + yb) * 0.5
		var h := absf(yb - ya) + 0.002
		var outer_x := outer_sign * (_wall_half(y) - x_inset)
		var width := absf(outer_x - inner_x)
		if width < 0.04:
			continue
		_add_box(
			"%s_%d" % [node_name, i],
			Vector3(width, h, depth),
			Vector3((inner_x + outer_x) * 0.5, y, 0.0),
			material
		)


func _add_curved_header(inner_x: float, outer_x: float, material: Material) -> void:
	var left_x := minf(inner_x, outer_x)
	var right_x := maxf(inner_x, outer_x)
	var segments := 10
	var y_off := frame_thickness * 0.45
	for i in range(segments):
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var x0 := lerpf(left_x, right_x, t0)
		var x1 := lerpf(left_x, right_x, t1)
		var y0 := _vault_y(x0) - y_off
		var y1 := _vault_y(x1) - y_off
		var dx := x1 - x0
		var dy := y1 - y0
		var length := sqrt(dx * dx + dy * dy)
		if length < 0.01:
			continue
		# Box local +X is the long axis for the rail — rotate from +X onto the vault tangent.
		var angle := atan2(dy, dx)
		_add_box(
			"TopRail_%d" % i,
			Vector3(length + 0.008, frame_thickness, frame_depth),
			Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0),
			material,
			Vector3(0.0, 0.0, angle)
		)


func _add_diagonal_mesh(
	inner_x: float,
	outer_sign: float,
	bottom_y: float,
	material: Material
) -> void:
	var inset := frame_thickness * 0.65
	bottom_y += inset * 0.35

	# Bounding rect uses the widest wall half in the mesh band so cells stay uniform.
	var max_half := 0.0
	var max_top := _vault_y(0.0) - frame_thickness - inset * 0.25
	for i in range(12):
		var y := lerpf(bottom_y, max_top, float(i) / 11.0)
		max_half = maxf(max_half, _wall_half(y))

	var left_x: float
	var right_x: float
	if outer_sign > 0.0:
		left_x = inner_x + inset
		right_x = max_half - inset
	else:
		left_x = -max_half + inset
		right_x = inner_x - inset

	var width := right_x - left_x
	if width <= 0.08:
		return

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
			var vault_ok := minf(limit0, limit1)
			if y0 < vault_ok:
				if y1 <= vault_ok + 0.03 and _mesh_segment_ok(x0, y0, x1, y1, inset):
					_add_segment("MeshFwd_%d" % index, Vector3(x0, y0, 0.0), Vector3(x1, y1, 0.0), material)
					index += 1
				if y0 <= vault_ok + 0.03 and _mesh_segment_ok(x0, y1, x1, y0, inset):
					_add_segment("MeshBack_%d" % index, Vector3(x0, y1, 0.0), Vector3(x1, y0, 0.0), material)
					index += 1


func _mesh_point_inside(x: float, y: float, inset: float) -> bool:
	return absf(x) <= _wall_half(y) - inset + 0.02


func _mesh_segment_ok(x0: float, y0: float, x1: float, y1: float, inset: float) -> bool:
	# Keep bars that mostly sit inside the wall profile.
	var mid_x := (x0 + x1) * 0.5
	var mid_y := (y0 + y1) * 0.5
	return (
		_mesh_point_inside(mid_x, mid_y, inset)
		and (_mesh_point_inside(x0, y0, inset) or _mesh_point_inside(x1, y1, inset))
	)


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
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	# Interior layer geometry still casts DoorSpill shadows; the mesh partition
	# should not occlude that light (only the outer shell should).
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
