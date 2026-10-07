class_name VanHull
extends Node3D

## The van's outer skin: roof, sides, front face (the step to the cab skin), rear face, sills and
## belly, all meeting the side skin's 0.22 m outer face, painted from the look seed.

const EXTERIOR_SHADER := preload("res://scenes/van/van_exterior.gdshader")

## Builds the truck-body lines (rub rails, belt line, drip rail, corner posts) on the skin.
const _HullLines := preload("res://scripts/van/look/van_hull_lines.gd")

## Closes the rear corner and sill gaps left in the skin above.
const _HullPatches := preload("res://scripts/van/look/van_hull_patches.gd")

## Closes the front of the box behind the bolted-on cab: roof-step strip, corners and the fill.
const _HullFront := preload("res://scripts/van/look/van_hull_front.gd")

## The roof's vertical offset above the wall top (and what `van_armour.gd` still sits against until
## phase 5). Roof, rear, sills, belly and hull lines meet `SIDE_SKIN_OUTER_M` instead.
const SKIN_OFFSET_M := 0.06

## How far the side skin's outer face stands off the liner: the side wall's 0.16 plus 0.06.
## `side_windows.gd` `HINGE_OUT_M` is sized against it.
const SIDE_SKIN_OUTER_M := VanBodyProfile.WALL_THICKNESS

## Rear end of the roof skin along z; the roof edge seal spans the same range.
const ROOF_Z_MAX := VanInteriorSize.REAR_Z + 0.08

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
	_build_roof()
	_build_rear(walls)
	_HullFront.new(self).build(walls)
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
		_add_mesh("SideSkinL" if wall_sign < 0.0 else "SideSkinR",
				_fit_skin_to_profile(mesh), Vector3.ZERO)


## Moves the skin's outer-layer vertices onto the profile's outer outline. The wall grid offsets the
## liner by a flat 0.22, but the outer outline has its own corner arc up to the roof, so without
## this the skin top (x 2.77) sat 0.34 m inside the roof's lower edge (x 3.11) and left it open.
func _fit_skin_to_profile(mesh: ArrayMesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(verts.size()):
		var v := verts[i]
		var side := signf(v.x)
		# The liner face is 0.16 off the profile and the skin 0.22; only the skin moves.
		if absf(v.x) - _profile.inner_x_at(v.y) > 0.19:
			verts[i] = Vector3(side * _profile.outer_x_at(v.y), v.y, v.z)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var fitted := ArrayMesh.new()
	fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return fitted


func _build_roof() -> void:
	var z_min := VanInteriorSize.FRONT_Z
	var z_max := ROOF_Z_MAX
	var z_segments := 24

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# The roof runs along the shared upper outline (side skin top, corner arc, crown), so the roof,
	# the rear face and the side skin meet on one edge.
	var outline := _upper_outline()
	for j in range(outline.size() - 1):
		var p0 := outline[j]
		var p1 := outline[j + 1]
		var d := p1 - p0
		if d.length() < 0.0001:
			continue
		var facing := Vector3(d.y, -d.x, 0.0)
		for iz in range(z_segments):
			var z0 := lerpf(z_min, z_max, float(iz) / float(z_segments))
			var z1 := lerpf(z_min, z_max, float(iz + 1) / float(z_segments))
			var v00 := Vector3(p0.x, p0.y, z0)
			var v10 := Vector3(p1.x, p1.y, z0)
			var v01 := Vector3(p0.x, p0.y, z1)
			var v11 := Vector3(p1.x, p1.y, z1)
			_rear_tri(st, v00, v10, v01, facing)
			_rear_tri(st, v10, v11, v01, facing)

	st.generate_normals()
	# No tangents: the exterior shader projects in model space and these meshes carry no UVs.
	_add_mesh("RoofSkin", st.commit())


## Outer roof height at lateral `x`: the profile's outer roof (markers on the crown use it; the
## skin follows the same profile). The other arguments are kept for the callers' signature.
static func roof_y_at(x: float, _half_w: float, _wall_height: float) -> float:
	return VanBodyProfile.new().outer_roof_y_at(x)


## Skin outer x at height `y` for the given side walls: where hull attachments sit on the skin.
static func skin_outer_x_at(walls: VanSideWall, y: float) -> float:
	return VanBodyProfile.new(walls).outer_x_at(y)


## The skin above the wall top as a CCW XY polyline from the right wall top (x = +w) up the
## corner arc, across the crown and down to the left wall top. It is the profile's outer outline.
func _upper_outline() -> PackedVector2Array:
	var h := _profile.wall_height()
	var h_out := h + VanBodyProfile.ROOF_THICKNESS
	var edge := _profile.outer_x_at(h_out)
	var side_steps := 8
	var crown_steps := 16
	var right := PackedVector2Array()
	for i in range(side_steps + 1):
		var y := lerpf(h, h_out, float(i) / float(side_steps))
		right.append(Vector2(_profile.outer_x_at(y), y))
	var pts := PackedVector2Array(right)
	for i in range(crown_steps + 1):
		var x := edge * (1.0 - 2.0 * float(i) / float(crown_steps))
		pts.append(Vector2(x, _profile.outer_roof_y_at(x)))
	for i in range(side_steps, -1, -1):
		pts.append(Vector2(-right[i].x, right[i].y))
	return pts


## The rear face is a closed ring around the door opening. The opening is the rear door leaves'
## rectangle (hinge x, REAR_DOOR_TOP) 2 cm out (D12), so the skin never lies behind a leaf and
## z-fights it, and covers the portal's pillars and header from outside. The opening is lined by a
## reveal from the skin back to the liner's end at the back compartment end, so its rim is closed
## (D4).
func _build_rear(walls: VanSideWall) -> void:
	var z := ROOF_Z_MAX
	var y_join := VanInteriorSize.REAR_DOOR_TOP - 0.02
	var x_join := VanInteriorSize.REAR_DOOR_HALF - 0.04
	var x_bottom := x_join
	var x_bottom_out := _profile.outer_x_at(0.0)
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
					Vector3(side * x_join, lerpf(0.0, y_join, f0), z),
					Vector3(side * x_join, lerpf(0.0, y_join, f1), z),
					_rear_side_point(walls, side, lerpf(-0.25, walls.wall_height, f0), z),
					_rear_side_point(walls, side, lerpf(-0.25, walls.wall_height, f1), z))

	# The floor deck ends 2 cm behind the ring's plane, so a plate 2 cm past its end hides it.
	var z_deck := VanInteriorSize.CENTER_Z + VanInteriorSize.FLOOR_LENGTH * 0.5 + 0.02
	for side: float in [-1.0, 1.0]:
		var xi := side * (x_join - 0.04)
		var xo := side * (VanInteriorSize.FLOOR_WIDTH * 0.5 + 0.04)
		_rear_quad(st, Vector3(xi, 0.02, z_deck), Vector3(xo, 0.02, z_deck),
				Vector3(xi, -0.28, z_deck), Vector3(xo, -0.28, z_deck))

	# Top, the opening's flat top edge to the upper outline (arc and crown), same fractions across.
	var outline := _upper_outline()
	var top_steps := outline.size() - 1
	for i in range(top_steps):
		var f0 := float(i) / float(top_steps)
		var f1 := float(i + 1) / float(top_steps)
		_rear_quad(st,
				Vector3(lerpf(x_join, -x_join, f0), y_join, z),
				Vector3(lerpf(x_join, -x_join, f1), y_join, z),
				Vector3(outline[i].x, outline[i].y, z),
				Vector3(outline[i + 1].x, outline[i + 1].y, z))

	# Reveal along the sides and top, from the ring's inner edge back to the liner's end.
	var z_back: float = VanInteriorSize.REAR_Z
	for side: float in [-1.0, 1.0]:
		for i in range(steps):
			_rear_reveal_quad(st,
					Vector3(side * x_join, lerpf(0.0, y_join, float(i) / steps), z),
					Vector3(side * x_join, lerpf(0.0, y_join, float(i + 1) / steps), z), z_back)
	for i in range(top_steps):
		_rear_reveal_quad(st,
				Vector3(lerpf(-x_join, x_join, float(i) / top_steps), y_join, z),
				Vector3(lerpf(-x_join, x_join, float(i + 1) / top_steps), y_join, z), z_back)

	st.generate_normals()
	# No tangents: the exterior shader projects in model space and these meshes carry no UVs.
	_add_mesh("RearSkin", st.commit())


## A point on the rear ring's outer edge: the outer skin face at height `y`.
func _rear_side_point(walls: VanSideWall, side: float, y: float, z: float) -> Vector3:
	return Vector3(side * _profile.outer_x_at(clampf(y, 0.0, walls.wall_height)), y, z)


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
