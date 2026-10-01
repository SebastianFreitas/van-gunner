extends RefCounted
## Builds the rear leaves' curved bodies, their liner material and the centre-seam astragal (D55).

const _WindowLip := preload("res://scripts/van/rear_window_lip.gd")
const DOOR_SHADER := preload("res://scenes/van/van_rear_door.gdshader")
const DOOR_THICKNESS := 0.16
const CENTER_GAP := 0.012
const Y_MIN := 0.02
## Window cut polygon (XY offsets from window center) — matches CSG WindowCut.
static var WINDOW_HOLE: PackedVector2Array = PackedVector2Array([
	Vector2(-0.79, -0.775), Vector2(-0.92, -0.7), Vector2(-0.99, -0.575),
	Vector2(-0.99, 0.575), Vector2(-0.92, 0.7), Vector2(-0.79, 0.775),
	Vector2(0.79, 0.775), Vector2(0.92, 0.7), Vector2(0.99, 0.575),
	Vector2(0.99, -0.575), Vector2(0.92, -0.7), Vector2(0.79, -0.775),
])
## Astragal: a trim strip on the left leaf's cabin face covering the 2.4 cm centre seam, 10 cm wide
## (vangapfix D24). The lift keeps its street face 1.1 cm clear of the handle mounts (D28).
const ASTRAGAL_HALF_W := 0.05
const ASTRAGAL_T := 0.012
const ASTRAGAL_LIFT := 0.036
const ASTRAGAL_END_GAP := 0.0


static func build(doors: Node3D, left: Node3D, right: Node3D) -> void:
	var walls := doors.get_parent().get_node_or_null("SideWalls") as VanSideWall
	var ceiling := doors.get_parent().get_node_or_null("Ceiling") as VanCeiling
	# One canonical left leaf — mirror for the right so bow/normals match.
	var mesh := _build_left_leaf_mesh(left, walls, ceiling)
	var mat := _door_body_material(left, ceiling)
	_apply_leaf(left, mesh, mat, false)
	_apply_leaf(right, mesh, mat, true)
	_WindowLip.build(left, left, false)
	_WindowLip.build(left, right, true)
	_add_astragal(left, ceiling)


static func _build_left_leaf_mesh(
		left: Node3D, walls: VanSideWall, ceiling: VanCeiling) -> ArrayMesh:
	var hinge_x := absf(left.position.x) if left else 2.39
	var hinge_y := left.position.y if left else 1.55
	var wall_sign := -1.0
	var x_inner := wall_sign * CENTER_GAP
	var origin := Vector3(wall_sign * hinge_x, hinge_y, 0.0)
	# World-space window center from the original CSG layout (left leaf).
	var hole_center := Vector2(wall_sign * 1.075, 1.775)
	return VanHullMesh.build_vaulted_xy_slab(
		walls, ceiling,
		x_inner, wall_sign, Y_MIN, DOOR_THICKNESS, origin,
		0.03, 0.025, 16, 32,
		WINDOW_HOLE, hole_center,
		3.05, 0.38, 2.42,
		true, INF, true
	)


static func _apply_leaf(hinge: Node3D, mesh: ArrayMesh, mat: Material, mirror_x: bool) -> void:
	if hinge == null or mesh == null:
		return
	# Hinge / window frame / glass / handle locals stay put — body only.
	var panel := hinge.get_node_or_null("Panel") as Node3D
	if panel:
		panel.visible = false

	var existing := hinge.get_node_or_null("CurvedBody")
	if existing:
		existing.free()

	var body := MeshInstance3D.new()
	body.name = "CurvedBody"
	body.mesh = mesh
	body.material_override = mat
	if mirror_x:
		# Flips geometry + normals together (avoids the right-leaf winding bug).
		body.scale = Vector3(-1.0, 1.0, 1.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hinge.add_child(body)
	hinge.move_child(body, 0)


static func _door_body_material(left: Node3D, ceiling: VanCeiling) -> ShaderMaterial:
	var hinge_x := absf(left.position.x) if left else 2.39
	var y_peak := VanHullMesh.vault_y(ceiling, 0.0, 3.05, 0.38)
	var mat := ShaderMaterial.new()
	mat.shader = DOOR_SHADER
	mat.set_shader_parameter("leaf_width_m", hinge_x - CENTER_GAP)
	mat.set_shader_parameter("leaf_height_m", y_peak - Y_MIN)
	return mat


static func _add_astragal(left: Node3D, ceiling: VanCeiling) -> void:
	if left == null:
		return
	var existing := left.get_node_or_null("Astragal")
	if existing:
		existing.free()
	var hinge_x := absf(left.position.x)
	var hinge_y := left.position.y
	var y_bot := Y_MIN + ASTRAGAL_END_GAP
	# 0.025 is the slab's y_inset; the leaf top follows the vault.
	var y_top := VanHullMesh.vault_y(ceiling, ASTRAGAL_HALF_W, 3.05, 0.38) - 0.025 \
			- ASTRAGAL_END_GAP
	var strip := MeshInstance3D.new()
	strip.name = "Astragal"
	var box := BoxMesh.new()
	box.size = Vector3(ASTRAGAL_HALF_W * 2.0, y_top - y_bot, ASTRAGAL_T)
	strip.mesh = box
	strip.position = Vector3(
		hinge_x,
		(y_bot + y_top) * 0.5 - hinge_y,
		-DOOR_THICKNESS * 0.5 - ASTRAGAL_LIFT - ASTRAGAL_T * 0.5
	)
	var mount := left.get_node_or_null("Handle/Mount")
	if mount:
		strip.material_override = mount.get("material") as Material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	left.add_child(strip)
