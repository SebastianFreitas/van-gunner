extends Interactable

## Decorative cab-facing door at the front partition.
## Looks like a side cargo door (same liner shader + dark trim) but does not open —
## interaction talks to the driver / leaves the shop (same accelerate cooldown as Shift).
## Mesh follows the vaulted hull.

const PARTITION_Z := -4.65
const DOOR_HALF_W := 0.775
const DOOR_THICKNESS := 0.22
const Y_MIN := 0.02
const TRIM_INSET := 0.06
const TRIM_DEPTH := 0.03
const BELT_Y := 1.375
const BELT_HALF_H := 0.025
const LOWER_CREASE_Y := 0.55
const LOWER_CREASE_HALF_H := 0.02

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _collision: CollisionShape3D = $Collision


func _ready() -> void:
	_fit_to_hull()


func _fit_to_hull() -> void:
	var shell := get_parent().get_node_or_null("Shell")
	if shell == null:
		return
	var walls := shell.get_node_or_null("SideWalls") as VanSideWall
	var ceiling := shell.get_node_or_null("Ceiling") as VanCeiling

	position = Vector3(0.0, 0.0, PARTITION_Z)

	var body_mat := _door_body_material(walls, ceiling)
	var trim_mat := _trim_material(shell)
	var y_peak := VanHullMesh.vault_y(ceiling, 0.0, 3.05, 0.38)

	if _mesh:
		_mesh.position = Vector3.ZERO
		_mesh.mesh = VanHullMesh.build_vaulted_xy_slab(
			walls, ceiling,
			-DOOR_HALF_W, 1.0, Y_MIN, DOOR_THICKNESS, Vector3.ZERO,
			0.0, 0.02, 14, 28,
			PackedVector2Array(), Vector2.ZERO,
			3.05, 0.38, 2.42,
			false,
			DOOR_HALF_W
		)
		_mesh.material_override = body_mat
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	for child_name in ["FrameLeft", "FrameRight", "FrameBottom", "FrameTop", "BeltStrip", "LowerCrease"]:
		_free_child(child_name)

	var frame_top := y_peak - 0.04
	_add_vertical_trim("FrameLeft", trim_mat, -DOOR_HALF_W + TRIM_INSET * 0.5, Y_MIN + TRIM_INSET, frame_top)
	_add_vertical_trim("FrameRight", trim_mat, DOOR_HALF_W - TRIM_INSET * 0.5, Y_MIN + TRIM_INSET, frame_top)
	_add_horizontal_trim(
		"FrameBottom", trim_mat,
		Y_MIN + TRIM_INSET * 0.5, TRIM_INSET * 0.7,
		DOOR_HALF_W - TRIM_INSET
	)
	_add_horizontal_trim(
		"FrameTop", trim_mat,
		frame_top - TRIM_INSET * 0.35, TRIM_INSET * 0.7,
		DOOR_HALF_W - TRIM_INSET
	)
	_add_horizontal_trim("BeltStrip", trim_mat, BELT_Y, BELT_HALF_H * 2.0, DOOR_HALF_W - TRIM_INSET * 1.5)
	_add_horizontal_trim(
		"LowerCrease", trim_mat, LOWER_CREASE_Y, LOWER_CREASE_HALF_H * 2.0,
		DOOR_HALF_W - TRIM_INSET * 1.5
	)

	if _collision:
		var shape := BoxShape3D.new()
		shape.size = Vector3(DOOR_HALF_W * 2.0, y_peak - Y_MIN, DOOR_THICKNESS)
		_collision.shape = shape
		_collision.position = Vector3(0.0, (Y_MIN + y_peak) * 0.5, 0.0)


func _add_vertical_trim(node_name: String, mat: Material, x: float, y0: float, y1: float) -> void:
	var height := absf(y1 - y0)
	var box := BoxMesh.new()
	box.size = Vector3(TRIM_INSET, height, TRIM_DEPTH)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = box
	mi.position = Vector3(x, (y0 + y1) * 0.5, DOOR_THICKNESS * 0.5 + TRIM_DEPTH * 0.5)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _add_horizontal_trim(
	node_name: String,
	mat: Material,
	y_center: float,
	height: float,
	half_w: float
) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(half_w * 2.0, height, TRIM_DEPTH)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = box
	mi.position = Vector3(0.0, y_center, DOOR_THICKNESS * 0.5 + TRIM_DEPTH * 0.5)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _free_child(node_name: String) -> void:
	var node := get_node_or_null(node_name)
	if node:
		node.free()


func _door_body_material(walls: VanSideWall, ceiling: VanCeiling) -> Material:
	# Same cargo-liner shader the side doors use.
	var source: Material = null
	if walls != null and walls.wall_material != null:
		source = walls.wall_material
	else:
		var side_doors := get_parent().get_node_or_null("Shell/SideDoors")
		if side_doors:
			var side_body := side_doors.get_node_or_null("Left/Panel/Body")
			if side_body and side_body.get("material") != null:
				source = side_body.get("material") as Material
	if source == null and _mesh != null:
		source = _mesh.material_override

	var y_peak := VanHullMesh.vault_y(ceiling, 0.0, 3.05, 0.38)
	var door_height := y_peak - Y_MIN
	if source is ShaderMaterial:
		var mat := (source as ShaderMaterial).duplicate()
		mat.set_shader_parameter("wall_size_m", Vector2(DOOR_HALF_W * 2.0, door_height))
		mat.set_shader_parameter("panel_spacing_m", 0.85)
		mat.set_shader_parameter("rib_spacing_m", 0.28)
		mat.set_shader_parameter("kick_height_m", 0.32)
		mat.set_shader_parameter("belt_y_m", 1.42)
		mat.set_shader_parameter("waist_y_m", 2.05)
		return mat
	return source


func _trim_material(shell: Node) -> Material:
	var side_doors := shell.get_node_or_null("SideDoors")
	if side_doors:
		var skin := side_doors.get_node_or_null("Left/Panel/OuterSkin")
		if skin and skin.get("material") != null:
			return skin.get("material") as Material
	var walls := shell.get_node_or_null("SideWalls") as VanSideWall
	if walls != null and walls.door_jamb_material != null:
		return walls.door_jamb_material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.09, 0.09, 1)
	mat.metallic = 0.65
	mat.roughness = 0.4
	return mat


func get_interaction_prompt() -> String:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return "THE DRIVER DOESN'T ANSWER"
	if GameSession.phase == GameSession.RunPhase.STOP:
		return "E  TELL DRIVER TO CONTINUE"
	return "E  TALK TO THE DRIVER"


func interact(_actor: Node3D) -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	if GameSession.phase == GameSession.RunPhase.STOP:
		var travel := get_tree().get_first_node_in_group(&"travel_controller")
		if travel and travel.has_method(&"leave_stop"):
			travel.leave_stop()
		elif travel and travel.has_method(&"leave_shop"):
			travel.leave_shop()
		return
	var host := owner
	if host and host.has_method(&"open_driver_talk"):
		host.open_driver_talk()
