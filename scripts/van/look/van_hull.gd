class_name VanHull
extends Node3D

## The van's outer skin: roof, sides, rear face and sills a few cm outside the liners, painted
## from the look seed.

const EXTERIOR_SHADER := preload("res://scenes/van/van_exterior.gdshader")

## How far outside the liners the skin sits.
const SKIN_OFFSET_M := 0.06

const SIDE_WALLS_PATH := ^"../../Interior/Shell/SideWalls"

## The shared exterior material; later parts (armour, cab) reuse it.
var material: ShaderMaterial


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var walls := get_node_or_null(SIDE_WALLS_PATH) as VanSideWall
	if walls == null:
		push_warning("VanHull: no SideWalls at %s" % SIDE_WALLS_PATH)
		return

	material = ShaderMaterial.new()
	material.shader = EXTERIOR_SHADER
	VanPaintPalette.apply(material, VanPaintPalette.pick(look.rng_for(&"paint")), look.rng_for(&"paint_wear"))
	material.set_shader_parameter(&"seam_spacing_m", 1.2)
	material.set_shader_parameter(&"sill_y_m", -0.25)
	material.set_shader_parameter(&"dirt_band_m", 0.9)

	_build_sides(walls)
	_build_roof(walls)
	_build_rear(walls)
	_build_sills(walls)


func _build_sides(walls: VanSideWall) -> void:
	# The wall's mesh instance sits at the identity transform (Shell/SideWalls are unrotated,
	# unoffset children of Interior), so the skin only needs to step out along X.
	for wall_sign: float in [-1.0, 1.0]:
		var mesh := walls.build_side_panel_mesh(wall_sign)
		var pos := Vector3(wall_sign * SKIN_OFFSET_M, 0.0, 0.0)
		_add_mesh("SideSkinL" if wall_sign < 0.0 else "SideSkinR", mesh, pos)


func _build_roof(walls: VanSideWall) -> void:
	var w: float = walls.wall_x_at(walls.wall_height) + SKIN_OFFSET_M
	var z_min := -4.72
	var z_max := 4.78
	var x_segments := 20
	var z_segments := 24

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var verts: Array = []
	for ix in range(x_segments + 1):
		var x := lerpf(-w, w, float(ix) / float(x_segments))
		var y := _roof_y(x, w, walls)
		var col: Array = []
		for iz in range(z_segments + 1):
			var z := lerpf(z_min, z_max, float(iz) / float(z_segments))
			col.append(Vector3(x, y, z))
		verts.append(col)

	# Grid runs (x, z); winding chosen so cross(edge_x, edge_z) points +Y (up and out of the vault).
	for ix in range(x_segments):
		for iz in range(z_segments):
			var v00: Vector3 = verts[ix][iz]
			var v10: Vector3 = verts[ix + 1][iz]
			var v01: Vector3 = verts[ix][iz + 1]
			var v11: Vector3 = verts[ix + 1][iz + 1]
			st.add_vertex(v00)
			st.add_vertex(v10)
			st.add_vertex(v01)
			st.add_vertex(v10)
			st.add_vertex(v11)
			st.add_vertex(v01)

	# Down-turned lip along both long edges (x = +-w), 0.05 m, facing outward.
	for edge_sign: float in [-1.0, 1.0]:
		var x_edge := edge_sign * w
		var y_top := _roof_y(x_edge, w, walls)
		var y_bot := y_top - 0.05
		for iz in range(z_segments):
			var z0 := lerpf(z_min, z_max, float(iz) / float(z_segments))
			var z1 := lerpf(z_min, z_max, float(iz + 1) / float(z_segments))
			var top0 := Vector3(x_edge, y_top, z0)
			var top1 := Vector3(x_edge, y_top, z1)
			var bot0 := Vector3(x_edge, y_bot, z0)
			var bot1 := Vector3(x_edge, y_bot, z1)
			if edge_sign > 0.0:
				st.add_vertex(top0)
				st.add_vertex(top1)
				st.add_vertex(bot0)
				st.add_vertex(top1)
				st.add_vertex(bot1)
				st.add_vertex(bot0)
			else:
				st.add_vertex(top0)
				st.add_vertex(bot0)
				st.add_vertex(top1)
				st.add_vertex(top1)
				st.add_vertex(bot0)
				st.add_vertex(bot1)

	st.generate_normals()
	# No tangents: the exterior shader projects in model space and these meshes carry no UVs.
	_add_mesh("RoofSkin", st.commit())


func _roof_y(x: float, w: float, walls: VanSideWall) -> float:
	var t := x / w
	return walls.wall_height + SKIN_OFFSET_M + 0.38 * (1.0 - t * t)


func _build_rear(walls: VanSideWall) -> void:
	var z := 4.78
	var w: float = walls.wall_x_at(walls.wall_height) + SKIN_OFFSET_M

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Two side posts: inner edge is the door opening (|x| = 2.39), outer edge follows the wall
	# bow. Winding is mirrored between sides so both faces come out +Z (outward).
	var y_steps := 8
	for post_sign: float in [-1.0, 1.0]:
		var x_inner := post_sign * 2.39
		var rows: Array = []
		for iy in range(y_steps + 1):
			var y := lerpf(-0.25, walls.wall_height, float(iy) / float(y_steps))
			var x_outer := post_sign * (walls.wall_x_at(clampf(y, 0.0, walls.wall_height)) + SKIN_OFFSET_M)
			rows.append([Vector3(x_inner, y, z), Vector3(x_outer, y, z)])
		for iy in range(y_steps):
			var in0: Vector3 = rows[iy][0]
			var out0: Vector3 = rows[iy][1]
			var in1: Vector3 = rows[iy + 1][0]
			var out1: Vector3 = rows[iy + 1][1]
			if post_sign > 0.0:
				st.add_vertex(in0)
				st.add_vertex(out0)
				st.add_vertex(in1)
				st.add_vertex(out0)
				st.add_vertex(out1)
				st.add_vertex(in1)
			else:
				st.add_vertex(in0)
				st.add_vertex(in1)
				st.add_vertex(out0)
				st.add_vertex(out0)
				st.add_vertex(in1)
				st.add_vertex(out1)

	# Header above the door opening, up to the roof curve.
	var x_steps := 16
	var header_row: Array = []
	for ix in range(x_steps + 1):
		var x := lerpf(-w, w, float(ix) / float(x_steps))
		var bottom := Vector3(x, 3.1, z)
		var top := Vector3(x, _roof_y(x, w, walls), z)
		header_row.append([bottom, top])
	for ix in range(x_steps):
		var b0: Vector3 = header_row[ix][0]
		var t0: Vector3 = header_row[ix][1]
		var b1: Vector3 = header_row[ix + 1][0]
		var t1: Vector3 = header_row[ix + 1][1]
		st.add_vertex(b0)
		st.add_vertex(b1)
		st.add_vertex(t0)
		st.add_vertex(b1)
		st.add_vertex(t1)
		st.add_vertex(t0)

	st.generate_normals()
	# No tangents: the exterior shader projects in model space and these meshes carry no UVs.
	_add_mesh("RearSkin", st.commit())


func _build_sills(walls: VanSideWall) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.10, 0.28, 9.5)
	for s: float in [-1.0, 1.0]:
		var pos := Vector3(s * (walls.wall_x_at(0.0) + SKIN_OFFSET_M + 0.03), -0.11, 0.03)
		_add_mesh("SillL" if s < 0.0 else "SillR", mesh, pos)


func _add_mesh(mesh_name: String, mesh: Mesh, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi
