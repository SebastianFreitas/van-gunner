extends RefCounted

## Builds the side door leaf meshes (body, trim, frames, latch) onto SideDoors nodes.

var doors: Node3D  # the owning SideDoors node; reads/writes its fields when called

## Door leaf extents (slightly inset from the wall opening).
const DOOR_HALF_Z := 1.265
const DOOR_THICKNESS := 0.14
const OUTER_SKIN := 0.035

## Recessed panel + trim (from original CSG Panel, local y/z from door center).
const PANEL_CENTER_Y := -0.15
const PANEL_HALF_Z := 1.10
const PANEL_HALF_Y := 1.275
const PANEL_FRAME_INSET := 0.08
const PANEL_RECESS_DEPTH := 0.05
const BELT_Y := -0.05
const BELT_HALF_H := 0.025
const LOWER_CREASE_Y := -0.85
const LOWER_CREASE_HALF_H := 0.02
const PERIMETER_FRAME_INSET := 0.06
const FRAME_THICKNESS := 0.045


func _init(owner: Node3D) -> void:
	doors = owner


func fit_door_leaf(leaf: Node3D, wall_sign: float, walls: VanSideWall) -> void:
	var y_min := walls.door_y_min
	var y_max := walls.door_y_max
	var mid_y := (y_min + y_max) * 0.5
	var x_ref := walls.wall_x_at(mid_y)
	var z_ref := walls.door_center_z
	var z0 := z_ref - DOOR_HALF_Z
	var z1 := z_ref + DOOR_HALF_Z

	leaf.rotation = Vector3.ZERO
	leaf.position = Vector3(wall_sign * x_ref, mid_y, z_ref)

	var door_height := y_max - y_min
	var body_mat := door_body_material(steal_material(leaf, "Panel/Body"), door_height)
	var trim_mat := steal_material(leaf, "Panel/OuterSkin")
	var frame_mat := find_frame_material(trim_mat)

	hide_node(leaf, "Panel")
	free_node(leaf, "CurvedBody")
	free_node(leaf, "CurvedOuter")
	free_node(leaf, "PerimeterFrame")
	free_node(leaf, "PanelFrame")
	free_node(leaf, "RecessedPanel")
	free_node(leaf, "BeltStrip")
	free_node(leaf, "LowerCrease")
	free_node(leaf, "LatchPlate")

	var body := MeshInstance3D.new()
	body.name = "CurvedBody"
	body.mesh = walls.build_curved_shell_mesh(
		wall_sign, y_min, y_max, z0, z1, x_ref, mid_y, z_ref, DOOR_THICKNESS,
		0.0, 28, 16,
		INF, -INF, INF, -INF,
		PackedVector2Array(),
		PackedVector2Array()
	)
	body.material_override = body_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	leaf.add_child(body)

	var outer := MeshInstance3D.new()
	outer.name = "CurvedOuter"
	outer.mesh = walls.build_curved_shell_mesh(
		wall_sign, y_min + 0.02, y_max - 0.02, z0 + 0.02, z1 - 0.02,
		x_ref, mid_y, z_ref, OUTER_SKIN,
		wall_sign * DOOR_THICKNESS, 24, 14,
		INF, -INF, INF, -INF,
		PackedVector2Array(),
		PackedVector2Array()
	)
	outer.material_override = trim_mat
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(outer)

	var door_half_y := (y_max - y_min) * 0.5
	var perimeter_outer := rect_poly(DOOR_HALF_Z - 0.02, door_half_y - 0.02)
	var perimeter_inner := rect_poly(
		DOOR_HALF_Z - 0.02 - PERIMETER_FRAME_INSET,
		door_half_y - 0.02 - PERIMETER_FRAME_INSET
	)
	add_frame_ring(
		leaf, walls, wall_sign, x_ref, mid_y, z_ref, mid_y,
		perimeter_outer, perimeter_inner, frame_mat, "PerimeterFrame", 0.0, 10
	)

	var panel_outer := rect_poly(PANEL_HALF_Z, PANEL_HALF_Y)
	var panel_inner := rect_poly(
		PANEL_HALF_Z - PANEL_FRAME_INSET, PANEL_HALF_Y - PANEL_FRAME_INSET
	)
	add_frame_ring(
		leaf, walls, wall_sign, x_ref, mid_y, z_ref, mid_y + PANEL_CENTER_Y,
		panel_outer, panel_inner, frame_mat, "PanelFrame",
		-wall_sign * PANEL_RECESS_DEPTH * 0.35, 8
	)

	var recessed := MeshInstance3D.new()
	recessed.name = "RecessedPanel"
	recessed.mesh = walls.build_curved_pane_from_poly(
		wall_sign, panel_inner, x_ref, mid_y, z_ref, mid_y + PANEL_CENTER_Y,
		-wall_sign * PANEL_RECESS_DEPTH, 6
	)
	recessed.material_override = body_mat
	recessed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	leaf.add_child(recessed)

	add_trim_strip(
		leaf, walls, wall_sign, x_ref, mid_y, z_ref,
		mid_y + BELT_Y - BELT_HALF_H, mid_y + BELT_Y + BELT_HALF_H,
		z_ref - PANEL_HALF_Z, z_ref + PANEL_HALF_Z,
		-wall_sign * PANEL_RECESS_DEPTH * 0.5, trim_mat, "BeltStrip"
	)
	add_trim_strip(
		leaf, walls, wall_sign, x_ref, mid_y, z_ref,
		mid_y + LOWER_CREASE_Y - LOWER_CREASE_HALF_H, mid_y + LOWER_CREASE_Y + LOWER_CREASE_HALF_H,
		z_ref - PANEL_HALF_Z, z_ref + PANEL_HALF_Z,
		-wall_sign * PANEL_RECESS_DEPTH * 0.5, trim_mat, "LowerCrease"
	)

	add_latch_plate(leaf, walls, wall_sign, x_ref, mid_y, z_ref, trim_mat)

	place_on_curve(leaf.get_node_or_null("Handle") as Node3D, walls, wall_sign, x_ref, mid_y, 1.375, 0.85, 0.12)


func place_on_curve(
	node: Node3D,
	walls: VanSideWall,
	wall_sign: float,
	x_ref: float,
	y_ref: float,
	world_y: float,
	local_z: float,
	into_cabin: float
) -> void:
	if node == null:
		return
	# Keep any facing rotation; only rewrite translation onto the curve.
	var node_basis := node.transform.basis
	var local_x := walls.local_x_on_wall(wall_sign, world_y, x_ref) - wall_sign * into_cabin
	node.transform = Transform3D(node_basis, Vector3(local_x, world_y - y_ref, local_z))


func hide_node(parent: Node, path: String) -> void:
	var node := parent.get_node_or_null(path) as Node3D
	if node:
		node.visible = false


func free_node(parent: Node, path: String) -> void:
	var node := parent.get_node_or_null(path)
	if node:
		node.free()


func steal_material(parent: Node, path: String) -> Material:
	var node := parent.get_node_or_null(path)
	if node == null:
		return null
	if node is GeometryInstance3D and (node as GeometryInstance3D).material_override:
		return (node as GeometryInstance3D).material_override
	if node.get("material") != null:
		return node.get("material") as Material
	return null


func door_body_material(source: Material, door_height: float) -> Material:
	if source is ShaderMaterial:
		var mat := (source as ShaderMaterial).duplicate()
		mat.set_shader_parameter("wall_size_m", Vector2(DOOR_HALF_Z * 2.0, door_height))
		mat.set_shader_parameter("panel_spacing_m", 0.85)
		mat.set_shader_parameter("rib_spacing_m", 0.28)
		mat.set_shader_parameter("kick_height_m", 0.32)
		mat.set_shader_parameter("belt_y_m", 1.42)
		mat.set_shader_parameter("waist_y_m", 2.05)
		return mat
	return source


func find_frame_material(fallback: Material) -> Material:
	var windows := doors.get_parent().get_node_or_null("SideWindows")
	if windows:
		var stolen := steal_material(windows, "LeftRear/Hinge/WindowFrame/Outer")
		if stolen:
			return stolen
	return fallback


func rect_poly(half_z: float, half_y: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_z, -half_y), Vector2(half_z, -half_y),
		Vector2(half_z, half_y), Vector2(-half_z, half_y),
	])


func add_frame_ring(
	parent: Node3D,
	walls: VanSideWall,
	wall_sign: float,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	poly_center_y: float,
	outer_poly: PackedVector2Array,
	inner_poly: PackedVector2Array,
	mat: Material,
	node_name: String,
	x_shift: float,
	edge_subdiv: int
) -> void:
	var frame := MeshInstance3D.new()
	frame.name = node_name
	frame.mesh = walls.build_curved_frame_ring_mesh(
		wall_sign, outer_poly, inner_poly,
		x_ref, y_ref, z_ref, poly_center_y, FRAME_THICKNESS, x_shift, edge_subdiv
	)
	frame.material_override = mat
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(frame)


func add_trim_strip(
	parent: Node3D,
	walls: VanSideWall,
	wall_sign: float,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	y0: float,
	y1: float,
	z0: float,
	z1: float,
	x_shift: float,
	mat: Material,
	node_name: String
) -> void:
	var strip := MeshInstance3D.new()
	strip.name = node_name
	strip.mesh = walls.build_curved_shell_mesh(
		wall_sign, y0, y1, z0, z1, x_ref, y_ref, z_ref, FRAME_THICKNESS,
		x_shift, 4, 16,
		INF, -INF, INF, -INF,
		PackedVector2Array(),
		PackedVector2Array()
	)
	strip.material_override = mat
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(strip)


func add_latch_plate(
	leaf: Node3D,
	walls: VanSideWall,
	wall_sign: float,
	x_ref: float,
	mid_y: float,
	z_ref: float,
	trim_mat: Material
) -> void:
	# Exterior latch backing plate beside the handle (cargo sliding-door look).
	var plate_y0 := mid_y + 0.95
	var plate_y1 := mid_y + 1.55
	var plate_z0 := z_ref + 0.55
	var plate_z1 := z_ref + 1.15
	var plate := MeshInstance3D.new()
	plate.name = "LatchPlate"
	plate.mesh = walls.build_curved_shell_mesh(
		wall_sign, plate_y0, plate_y1, plate_z0, plate_z1,
		x_ref, mid_y, z_ref, 0.012,
		wall_sign * (DOOR_THICKNESS + OUTER_SKIN * 0.5), 6, 8,
		INF, -INF, INF, -INF,
		PackedVector2Array(),
		PackedVector2Array()
	)
	plate.material_override = trim_mat
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(plate)
