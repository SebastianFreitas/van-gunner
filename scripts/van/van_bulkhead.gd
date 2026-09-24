class_name VanBulkhead
extends StaticBody3D

## Mid/rear cargo bulkhead: metal frame + diagonal mesh, side doorway.
## Local XY is the bulkhead face; +Z faces the rear of the van.
## Outer edges follow VanSideWall's bowed/tapered profile.

const _VanBulkheadMesh := preload("res://scripts/van/van_bulkhead_mesh.gd")

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
var _mesh_builder: RefCounted


func _init() -> void:
	_mesh_builder = _VanBulkheadMesh.new(self)


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

	var steel: StandardMaterial3D = _mesh_builder.steel_material()
	var mesh_mat: StandardMaterial3D = _mesh_builder.mesh_material()

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
	_mesh_builder.add_curved_wall_post("LeftWallPost", -1.0, steel)
	_mesh_builder.add_curved_wall_post("RightWallPost", 1.0, steel)

	# Doorway post on the panel edge of the opening (straight).
	var opening_post_x := (
		opening_inner + frame_thickness * 0.5
		if opening_side == OpeningSide.RIGHT
		else opening_inner - frame_thickness * 0.5
	)
	_mesh_builder.add_post("OpeningInnerPost", opening_post_x, steel)

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
	_mesh_builder.add_panel_slab(
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
	_mesh_builder.add_curved_header(panel_inner, outer_sign * roof_half, steel)

	# Vertical mid posts for stiffness (stay inside the narrowest panel span).
	var mid_outer := outer_sign * minf(kick_half, roof_half)
	var panel_width_mid := absf(mid_outer - panel_inner)
	var mid_count := maxi(1, int(panel_width_mid / 1.15))
	for i in range(1, mid_count):
		var t := float(i) / float(mid_count)
		var x := lerpf(panel_inner, mid_outer, t)
		_mesh_builder.add_panel_post("MidPost_%d" % i, x, steel)

	# Diagonal expanded-metal style netting above the kick plate.
	_mesh_builder.add_diagonal_mesh(panel_inner, outer_sign, kick_height + frame_thickness, mesh_mat)

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
