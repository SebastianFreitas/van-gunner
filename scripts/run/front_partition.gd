extends StaticBody3D

## Front cargo partition: wall panels flanking the decorative cab door.
## Outer edges follow VanSideWall's bow; tops follow VanCeiling's vault.
## Visual only for the panels — CabDoor keeps the driver interact.

const PARTITION_Z := -4.65
const DOOR_HALF_W := 0.775
const PANEL_THICKNESS := 0.2
const Y_MIN := 0.02
const CENTER_GAP := 0.01

@onready var _left_panel: MeshInstance3D = $LeftPanel
@onready var _right_panel: MeshInstance3D = $RightPanel
@onready var _left_collision: CollisionShape3D = $LeftCollision
@onready var _right_collision: CollisionShape3D = $RightCollision


func _ready() -> void:
	_fit_to_hull()


func _fit_to_hull() -> void:
	var shell := get_parent().get_node_or_null("Shell")
	if shell == null:
		return
	var walls := shell.get_node_or_null("SideWalls") as VanSideWall
	var ceiling := shell.get_node_or_null("Ceiling") as VanCeiling
	var mat := _wall_material(walls, ceiling)

	_apply_panel(_left_panel, _left_collision, walls, ceiling, mat, -1.0)
	_apply_panel(_right_panel, _right_collision, walls, ceiling, mat, 1.0)


func _apply_panel(
	panel: MeshInstance3D,
	collision: CollisionShape3D,
	walls: VanSideWall,
	ceiling: VanCeiling,
	mat: Material,
	wall_sign: float
) -> void:
	if panel == null:
		return
	var x_inner := wall_sign * (DOOR_HALF_W + CENTER_GAP)
	var mesh := VanHullMesh.build_vaulted_xy_slab(
		walls, ceiling,
		x_inner, wall_sign, Y_MIN, PANEL_THICKNESS, Vector3.ZERO,
		0.02, 0.02, 12, 28,
		PackedVector2Array(), Vector2.ZERO,
		3.05, 0.38, 2.42,
		false
	)
	panel.position = Vector3(0.0, 0.0, PARTITION_Z)
	panel.mesh = mesh
	panel.material_override = mat
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	if collision == null:
		return
	var floor_half := VanHullMesh.wall_half(walls, 0.0, 2.42)
	var y_peak := VanHullMesh.vault_y(ceiling, 0.0, 3.05, 0.38)
	var max_half := floor_half
	if walls != null:
		for i in range(9):
			max_half = maxf(max_half, walls.wall_x_at(y_peak * float(i) / 8.0))
	var outer := wall_sign * max_half
	var width := absf(outer - x_inner)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, y_peak - Y_MIN, PANEL_THICKNESS)
	collision.shape = shape
	collision.position = Vector3(
		(x_inner + outer) * 0.5,
		(Y_MIN + y_peak) * 0.5,
		PARTITION_Z
	)


func _wall_material(walls: VanSideWall, ceiling: VanCeiling) -> Material:
	var source: Material = null
	if walls != null and walls.wall_material != null:
		source = walls.wall_material
	if source == null and _left_panel != null:
		source = _left_panel.material_override

	var y_peak := VanHullMesh.vault_y(ceiling, 0.0, 3.05, 0.38)
	var floor_half := VanHullMesh.wall_half(walls, 0.0, 2.42)
	var panel_width := floor_half - DOOR_HALF_W
	var panel_height := y_peak - Y_MIN

	if source is ShaderMaterial:
		var mat := (source as ShaderMaterial).duplicate()
		mat.set_shader_parameter("wall_size_m", Vector2(panel_width, panel_height))
		mat.set_shader_parameter("panel_spacing_m", 1.15)
		mat.set_shader_parameter("rib_spacing_m", 0.42)
		mat.set_shader_parameter("kick_height_m", 0.38)
		mat.set_shader_parameter("belt_y_m", 0.96)
		mat.set_shader_parameter("waist_y_m", 1.48)
		return mat
	return source
