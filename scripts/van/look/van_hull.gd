class_name VanHull
extends Node3D

## The van's outer skin: roof, sides, front face (the step to the cab skin), rear face, sills and
## belly, all meeting the side skin's 0.22 m outer face, painted from the look seed.

const EXTERIOR_SHADER := preload("res://scenes/van/van_exterior.gdshader")

## Builds the truck-body lines (rub rails, belt line, drip rail, corner posts) on the skin.
const _HullLines := preload("res://scripts/van/look/van_hull_lines.gd")

## Closes the rear corner and sill gaps left in the skin above.
const _HullPatches := preload("res://scripts/van/look/van_hull_patches.gd")

## The roof's vertical offset above the wall top (and what `van_armour.gd` still sits against until
## phase 5). Roof, rear, sills, belly and hull lines meet `SIDE_SKIN_OUTER_M` instead.
const SKIN_OFFSET_M := 0.06

## How far the side skin's outer face stands off the liner: the side wall's 0.16 plus 0.06.
## `side_windows.gd` `HINGE_OUT_M` is sized against it.
const SIDE_SKIN_OUTER_M := 0.22

## The fill stands this far in front of the interior front wall's cab-side face and this far
## outside its outline, so the slab never shows and no face lies within the audit's 2 cm.
const FRONT_FILL_GAP_M := 0.025

const SIDE_WALLS_PATH := ^"../../Interior/Shell/SideWalls"

## The shared exterior material; later parts (armour, cab) reuse it.
var material: ShaderMaterial

## Shared body cross-section that the skin and the body lines both sample.
var _profile: VanBodyProfile


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var walls := get_node_or_null(SIDE_WALLS_PATH) as VanSideWall
	if walls == null:
		push_warning("VanHull: no SideWalls at %s" % SIDE_WALLS_PATH)
		return

	_profile = VanBodyProfile.new(walls, walls.get_parent().get_node_or_null(^"Ceiling") as VanCeiling)

	material = ShaderMaterial.new()
	material.shader = EXTERIOR_SHADER
	VanPaintPalette.apply(material, VanPaintPalette.pick(look.rng_for(&"paint")), look.rng_for(&"paint_wear"))
	material.set_shader_parameter(&"seam_spacing_m", 1.2)
	material.set_shader_parameter(&"sill_y_m", -0.25)
	material.set_shader_parameter(&"dirt_band_m", 0.9)

	_build_sides(walls)
	_build_roof(walls)
	_build_rear(walls)
	_build_front(walls)
	_HullPatches.new(self).build(walls, VanWheels.rear_arch_spans(look))
	_HullLines.new(self).build(_profile, walls, material)

	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(&"side_doors"):
			if node.has_method(&"set_exterior_material"):
				node.call(&"set_exterior_material", material)


func _build_sides(walls: VanSideWall) -> void:
	if walls.thickness >= SIDE_SKIN_OUTER_M:
		push_warning("VanHull: side wall thickness %s reaches the skin; no side skins" % walls.thickness)
		return
	# The skin is the layer from the wall's outer face to SIDE_SKIN_OUTER_M. It shares the wall's
	# grid and cuts (identity transform, no shift), so its returns continue the wall's returns
	# edge to edge and no surface has two owners.
	for wall_sign: float in [-1.0, 1.0]:
		var mesh := walls.build_side_panel_mesh(wall_sign, walls.thickness, SIDE_SKIN_OUTER_M, false)
		_add_mesh("SideSkinL" if wall_sign < 0.0 else "SideSkinR", mesh, Vector3.ZERO)


func _build_roof(walls: VanSideWall) -> void:
	var w: float = walls.wall_x_at(walls.wall_height) + SIDE_SKIN_OUTER_M
	var z_min := -walls.span_z * 0.5
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

	# Down-turned lip along both long edges (x = +-w), facing outward, from the roof edge down to
	# the side skin's top edge, so it continues the skin's outer face with no overlap.
	for edge_sign: float in [-1.0, 1.0]:
		var x_edge := edge_sign * w
		var y_top := _roof_y(x_edge, w, walls)
		var y_bot := walls.wall_height
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


## The rear face is a closed ring around the door opening. The opening follows the rear door
## leaves' outline (bottom Y_MIN, liner - 0.03 at the sides, vault - 0.025 on top) 2 cm out (D12),
## so the skin never lies behind a leaf and z-fights it. The opening is lined by a reveal from the
## skin back to the liner's end at z 4.70, so its rim is closed (D4).
func _build_rear(walls: VanSideWall) -> void:
	var z := 4.78
	var w: float = walls.wall_x_at(walls.wall_height) + SIDE_SKIN_OUTER_M
	var ceiling := _profile.ceiling
	var y_join := _rear_join_y(walls, ceiling)
	var x_join: float = walls.wall_x_at(y_join) - 0.01
	var x_bottom: float = walls.wall_x_at(0.0) - 0.01
	var x_bottom_out: float = walls.wall_x_at(0.0) + SIDE_SKIN_OUTER_M
	var steps := 8

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Bottom strip, inner y 0.0 to outer y -0.25, same x fractions.
	for i in range(steps):
		var f0 := float(i) / float(steps)
		var f1 := float(i + 1) / float(steps)
		_rear_quad(st,
				Vector3(lerpf(-x_bottom, x_bottom, f0), 0.0, z),
				Vector3(lerpf(-x_bottom, x_bottom, f1), 0.0, z),
				Vector3(lerpf(-x_bottom_out, x_bottom_out, f0), -0.25, z),
				Vector3(lerpf(-x_bottom_out, x_bottom_out, f1), -0.25, z))

	# Sides, inner 0 to the join, outer -0.25 to the wall top, same fraction along.
	for side: float in [-1.0, 1.0]:
		for i in range(steps):
			var f0 := float(i) / float(steps)
			var f1 := float(i + 1) / float(steps)
			_rear_quad(st,
					_rear_side_point(walls, side, lerpf(0.0, y_join, f0), false, z),
					_rear_side_point(walls, side, lerpf(0.0, y_join, f1), false, z),
					_rear_side_point(walls, side, lerpf(-0.25, walls.wall_height, f0), true, z),
					_rear_side_point(walls, side, lerpf(-0.25, walls.wall_height, f1), true, z))
		# Wedge between the side strip's end and the top strip's end at this corner.
		var join := Vector3(side * x_join, y_join, z)
		var wall_top := Vector3(side * w, walls.wall_height, z)
		_rear_tri(st, join, wall_top, Vector3(side * w, _roof_y(side * w, w, walls), z))

	# Top, inner vault arc to outer roof curve, same x fractions across.
	var top_steps := 16
	for i in range(top_steps):
		var f0 := float(i) / float(top_steps)
		var f1 := float(i + 1) / float(top_steps)
		var xo0 := lerpf(-w, w, f0)
		var xo1 := lerpf(-w, w, f1)
		_rear_quad(st,
				_rear_top_point(ceiling, lerpf(-x_join, x_join, f0), z),
				_rear_top_point(ceiling, lerpf(-x_join, x_join, f1), z),
				Vector3(xo0, _roof_y(xo0, w, walls), z),
				Vector3(xo1, _roof_y(xo1, w, walls), z))

	# Reveal along the sides and top, from the ring's inner edge back to the liner's end.
	var z_back: float = walls.span_z * 0.5
	for side: float in [-1.0, 1.0]:
		for i in range(steps):
			_rear_reveal_quad(st,
					_rear_side_point(walls, side, lerpf(0.0, y_join, float(i) / steps), false, z),
					_rear_side_point(walls, side, lerpf(0.0, y_join, float(i + 1) / steps),
							false, z), z_back)
	for i in range(top_steps):
		_rear_reveal_quad(st,
				_rear_top_point(ceiling, lerpf(-x_join, x_join, float(i) / top_steps), z),
				_rear_top_point(ceiling, lerpf(-x_join, x_join, float(i + 1) / top_steps), z),
				z_back)

	st.generate_normals()
	# No tangents: the exterior shader projects in model space and these meshes carry no UVs.
	_add_mesh("RearSkin", st.commit())


## The front face closes the whole front of the box at the side skin's front returns' z: the strip
## over the roof step between the skin (0.22 m off the liner) and the cab skin (0.12 m off), whose
## inner edge lies on the cab outline's top and outer edge on the roof curve, a quad per corner
## down to the returns' top edge (y = wall height), and a fill that sits 2.5 cm in front of the
## interior front wall's cab-side face (z -4.75) and 2.5 cm outside its outline, with a band along
## its sides and top back to the returns at `z`, because the bolted-on truck cab (x +-1.95, roof
## 3.05) no longer covers the slab.
func _build_front(walls: VanSideWall) -> void:
	var z := -walls.span_z * 0.5
	var w: float = walls.wall_x_at(walls.wall_height) + SIDE_SKIN_OUTER_M
	var xc: float = _profile.outer_x_at(walls.wall_height)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top_steps := 16
	for i in range(top_steps):
		var f0 := float(i) / float(top_steps)
		var f1 := float(i + 1) / float(top_steps)
		var xi0 := lerpf(-xc, xc, f0)
		var xi1 := lerpf(-xc, xc, f1)
		var xo0 := lerpf(-w, w, f0)
		var xo1 := lerpf(-w, w, f1)
		var in0 := Vector3(xi0, _profile.outer_roof_y_at(xi0), z)
		var in1 := Vector3(xi1, _profile.outer_roof_y_at(xi1), z)
		var out0 := Vector3(xo0, _roof_y(xo0, w, walls), z)
		var out1 := Vector3(xo1, _roof_y(xo1, w, walls), z)
		_rear_tri(st, in0, in1, out0, Vector3.FORWARD)
		_rear_tri(st, in1, out1, out0, Vector3.FORWARD)

	# Corners: from the wall top's cab point and skin edge up to the strip's ends.
	for side: float in [-1.0, 1.0]:
		var cab_wall := Vector3(side * xc, walls.wall_height, z)
		var cab_top := Vector3(side * xc, _profile.outer_roof_y_at(side * xc), z)
		var skin_wall := Vector3(side * w, walls.wall_height, z)
		var skin_top := Vector3(side * w, _roof_y(side * w, w, walls), z)
		_rear_tri(st, cab_wall, skin_wall, cab_top, Vector3.FORWARD)
		_rear_tri(st, skin_wall, skin_top, cab_top, Vector3.FORWARD)

	# The fill: stands in front of the interior front wall's slab (so it never shows) and closes
	# its sides and top back to the returns, since the bolted-on cab is smaller than the box.
	var zf := VanFrontWall.BACK_Z - FRONT_FILL_GAP_M
	var g := FRONT_FILL_GAP_M
	var h: float = walls.wall_height
	var rows := 12
	var pts := PackedVector2Array()
	pts.append(Vector2(_profile.outer_x_at(0.0) + g, VanCab.BASE_Y))
	for i in range(1, rows + 1):
		var y := h * float(i) / float(rows)
		pts.append(Vector2(_profile.outer_x_at(y) + g, y))
	if _profile.outer_roof_y_at(xc) > h + 0.001:
		pts.append(Vector2(xc + g, _profile.outer_roof_y_at(xc) + g))
	for i in range(top_steps - 1, 0, -1):
		var x := lerpf(-xc, xc, float(i) / float(top_steps))
		pts.append(Vector2(x, _profile.outer_roof_y_at(x) + g))
	if _profile.outer_roof_y_at(-xc) > h + 0.001:
		pts.append(Vector2(-(xc + g), _profile.outer_roof_y_at(-xc) + g))
	for i in range(rows, 0, -1):
		var y := h * float(i) / float(rows)
		pts.append(Vector2(-(_profile.outer_x_at(y) + g), y))
	pts.append(Vector2(-(_profile.outer_x_at(0.0) + g), VanCab.BASE_Y))
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	c /= float(pts.size())
	for k in range(pts.size()):
		var p := pts[k]
		var q := pts[(k + 1) % pts.size()]
		_rear_tri(st, Vector3(c.x, c.y, zf), Vector3(p.x, p.y, zf), Vector3(q.x, q.y, zf),
				Vector3.FORWARD)
	# The band: from the fill back to the returns along the sides and top (not the open bottom).
	for k in range(pts.size() - 1):
		var p := pts[k]
		var q := pts[k + 1]
		var e := q - p
		var nrm := Vector2(e.y, -e.x)
		if nrm.dot((p + q) * 0.5 - c) < 0.0:
			nrm = -nrm
		var out := Vector3(nrm.x, nrm.y, 0.0).normalized()
		var pf := Vector3(p.x, p.y, zf)
		var qf := Vector3(q.x, q.y, zf)
		var qb := Vector3(q.x, q.y, z)
		var pb := Vector3(p.x, p.y, z)
		_rear_tri(st, pf, qf, qb, out)
		_rear_tri(st, pf, qb, pb, out)

	st.generate_normals()
	# No tangents: the exterior shader projects in model space and these meshes carry no UVs.
	_add_mesh("FrontSkin", st.commit())


## Height where the opening's side edge (liner - 0.01) meets its top edge (vault - 0.005).
func _rear_join_y(walls: VanSideWall, ceiling: VanCeiling) -> float:
	var lo := 0.0
	var hi: float = walls.wall_height
	if _rear_gap(walls, ceiling, hi) > 0.0:
		return hi
	for _i in range(24):
		var mid := 0.5 * (lo + hi)
		if _rear_gap(walls, ceiling, mid) > 0.0:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)


## Vault edge above height `y` on the opening's side edge; positive while the side is still free.
func _rear_gap(walls: VanSideWall, ceiling: VanCeiling, y: float) -> float:
	var x: float = walls.wall_x_at(y) - 0.01
	return VanHullMesh.vault_y(ceiling, x, 3.05, 0.38) - 0.005 - y


## A point on the rear ring's side edge: outer skin face when `outer`, else the opening's edge.
func _rear_side_point(walls: VanSideWall, side: float, y: float, outer: bool, z: float) -> Vector3:
	if outer:
		return Vector3(side * (walls.wall_x_at(clampf(y, 0.0, walls.wall_height))
				+ SIDE_SKIN_OUTER_M), y, z)
	return Vector3(side * (walls.wall_x_at(y) - 0.01), y, z)


## A point on the opening's top edge (vault - 0.005).
func _rear_top_point(ceiling: VanCeiling, x: float, z: float) -> Vector3:
	return Vector3(x, VanHullMesh.vault_y(ceiling, x, 3.05, 0.38) - 0.005, z)


## Two triangles for the quad in0-in1 (inner edge) and out0-out1 (outer edge).
func _rear_quad(st: SurfaceTool, in0: Vector3, in1: Vector3, out0: Vector3, out1: Vector3) -> void:
	_rear_tri(st, in0, in1, out0)
	_rear_tri(st, in1, out1, out0)


## A reveal quad from the ring's inner edge a-b (z of the skin) back to `z_back`, facing the
## opening's centre so its front face is what you see looking into the slot.
func _rear_reveal_quad(st: SurfaceTool, a: Vector3, b: Vector3, z_back: float) -> void:
	var a2 := Vector3(a.x, a.y, z_back)
	var b2 := Vector3(b.x, b.y, z_back)
	var mid := (a + b) * 0.5
	var inward := Vector3(0.0, 1.5, mid.z) - mid
	_rear_tri(st, a, b, a2, inward)
	_rear_tri(st, b, b2, a2, inward)


## One triangle, wound so its front face (clockwise seen from `facing`) is the `facing` side.
func _rear_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		facing: Vector3 = Vector3.BACK) -> void:
	if (b - a).cross(c - a).dot(facing) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


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
