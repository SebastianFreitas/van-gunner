class_name VanSideWall
extends Node3D

## Curved cargo-van side liners: wider at the floor, bowed out at the waist,
## tapering in toward the roof — with punched openings for windows / side doors.

@export var wall_height := 3.08
@export var span_z := 9.4
@export var bottom_half_width := 2.42
@export var top_half_width := 2.00
## Extra outward bulge at mid-height (meters). Makes the body read as curved, not a flat lean.
@export var bow_out := 0.18
@export var thickness := 0.10
@export var y_segments := 56
@export var z_segments := 112
@export var wall_material: Material
@export var rebuild_on_ready := true

## Window cut AABB (CSG WindowCut) — used for rails / broad checks.
@export var window_half_height := 0.707
@export var window_half_length := 1.222
@export var window_center_y := 1.775
@export var window_centers_z: PackedFloat32Array = PackedFloat32Array([2.835, -0.375])

## Exact CSG WindowCut outline (z_off, y_off from window center). Wall metal
## forms the surround; the dark frame outer sits over this lip like rear doors.
var WINDOW_CUT_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-0.983, -0.707), Vector2(-1.142, -0.636), Vector2(-1.222, -0.519),
	Vector2(-1.222, 0.519), Vector2(-1.142, 0.636), Vector2(-0.983, 0.707),
	Vector2(0.983, 0.707), Vector2(1.142, 0.636), Vector2(1.222, 0.519),
	Vector2(1.222, -0.519), Vector2(1.142, -0.636), Vector2(0.983, -0.707),
])

## Side-door openings (match SideDoors layout).
@export var door_half_length := 1.30
@export var door_center_z := -3.485
@export var door_y_min := 0.02
@export var door_y_max := 3.05

var _built := false


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_build()


func wall_x_at(y: float) -> float:
	return _profile_x(y)


func lean_angle_at(y: float) -> float:
	## Radians: rotation around Z for a right-side panel at height y (left uses negative).
	var eps := 0.02
	var x0 := _profile_x(y - eps)
	var x1 := _profile_x(y + eps)
	return atan2(x0 - x1, eps * 2.0)


## Local X so a child of a node at (±x_ref, y_ref, z_ref) sits on the interior face.
func local_x_on_wall(wall_sign: float, world_y: float, x_ref: float) -> float:
	return wall_sign * (_profile_x(world_y) - x_ref)


## Point-in-polygon for window outlines. Poly is Vector2(z_off, y_off) from the
## window/door-window center — same coords as the original CSGPolygon2D shapes.
func point_in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
	var n := poly.size()
	if n < 3:
		return false
	var inside := false
	var j := n - 1
	for i in range(n):
		var pi: Vector2 = poly[i]
		var pj: Vector2 = poly[j]
		if ((pi.y > p.y) != (pj.y > p.y)) and (
			p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y + 0.0000001) + pi.x
		):
			inside = not inside
		j = i
	return inside


## Curved YZ shell following the cargo profile.
## Optional rectangular hole, or packed polys (Vector2(z_off, y_off) from z_ref /
## poly_center_y) for rounded outer silhouette + rounded glass cut.
## Vertex space: local_x = wall_sign*(profile(y)-x_ref) + x_shift, local_y = y-y_ref, local_z = z-z_ref.
func build_curved_shell_mesh(
	wall_sign: float,
	y_min: float,
	y_max: float,
	z_min: float,
	z_max: float,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	shell_thickness: float,
	x_shift: float = 0.0,
	seg_y: int = 16,
	seg_z: int = 12,
	hole_y_min: float = INF,
	hole_y_max: float = -INF,
	hole_z_min: float = INF,
	hole_z_max: float = -INF,
	outer_poly: PackedVector2Array = PackedVector2Array(),
	hole_poly: PackedVector2Array = PackedVector2Array(),
	poly_center_y: float = INF
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_rect_hole := hole_y_min < hole_y_max and hole_z_min < hole_z_max
	var has_outer_poly := outer_poly.size() >= 3
	var has_hole_poly := hole_poly.size() >= 3
	var poly_cy := poly_center_y if poly_center_y < INF else (y_min + y_max) * 0.5
	var half_span := span_z * 0.5

	var inner: Array = []
	var outer: Array = []
	var uvs: Array = []
	var solid: Array = []

	for iy in range(seg_y + 1):
		var row_i: Array = []
		var row_o: Array = []
		var row_uv: Array = []
		var row_s: Array = []
		var ty := float(iy) / float(seg_y)
		var y := lerpf(y_min, y_max, ty)
		var x_face := wall_sign * _profile_x(y) + x_shift
		var x_inner := x_face - wall_sign * x_ref
		var x_outer := x_inner + wall_sign * shell_thickness
		for iz in range(seg_z + 1):
			var tz := float(iz) / float(seg_z)
			var z := lerpf(z_min, z_max, tz)
			row_i.append(Vector3(x_inner, y - y_ref, z - z_ref))
			row_o.append(Vector3(x_outer, y - y_ref, z - z_ref))
			row_uv.append(Vector2((z + half_span) / span_z, y / wall_height))
			row_s.append(_shell_point_solid(
				y, z, z_ref, poly_cy,
				has_outer_poly, outer_poly, has_hole_poly, hole_poly,
				has_rect_hole, hole_y_min, hole_y_max, hole_z_min, hole_z_max
			))
		inner.append(row_i)
		outer.append(row_o)
		uvs.append(row_uv)
		solid.append(row_s)

	for iy in range(seg_y):
		for iz in range(seg_z):
			var y_mid := lerpf(y_min, y_max, (float(iy) + 0.5) / float(seg_y))
			var z_mid := lerpf(z_min, z_max, (float(iz) + 0.5) / float(seg_z))
			if not _shell_point_solid(
				y_mid, z_mid, z_ref, poly_cy,
				has_outer_poly, outer_poly, has_hole_poly, hole_poly,
				has_rect_hole, hole_y_min, hole_y_max, hole_z_min, hole_z_max
			):
				continue
			_add_shell_cell(st, wall_sign, inner, outer, uvs, iy, iz)

	if has_rect_hole or has_outer_poly or has_hole_poly:
		_add_shell_hole_returns(st, wall_sign, inner, outer, uvs, solid)

	# Rectangular outer edge returns only when the silhouette is the AABB itself.
	if not has_outer_poly:
		_add_shell_border_returns(st, wall_sign, inner, outer, uvs, seg_y, seg_z)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Thin curved pane (glass) — single sheet, no thickness returns.
func build_curved_pane_mesh(
	wall_sign: float,
	y_min: float,
	y_max: float,
	z_min: float,
	z_max: float,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	x_shift: float = 0.0,
	seg_y: int = 12,
	seg_z: int = 10
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_span := span_z * 0.5
	var verts: Array = []
	var uvs: Array = []

	for iy in range(seg_y + 1):
		var row_v: Array = []
		var row_uv: Array = []
		var y := lerpf(y_min, y_max, float(iy) / float(seg_y))
		var x_local := wall_sign * (_profile_x(y) - x_ref) + x_shift
		for iz in range(seg_z + 1):
			var z := lerpf(z_min, z_max, float(iz) / float(seg_z))
			row_v.append(Vector3(x_local, y - y_ref, z - z_ref))
			row_uv.append(Vector2((z + half_span) / span_z, y / wall_height))
		verts.append(row_v)
		uvs.append(row_uv)

	for iy in range(seg_y):
		for iz in range(seg_z):
			var v00: Vector3 = verts[iy][iz]
			var v10: Vector3 = verts[iy][iz + 1]
			var v01: Vector3 = verts[iy + 1][iz]
			var v11: Vector3 = verts[iy + 1][iz + 1]
			var uv00: Vector2 = uvs[iy][iz]
			var uv10: Vector2 = uvs[iy][iz + 1]
			var uv01: Vector2 = uvs[iy + 1][iz]
			var uv11: Vector2 = uvs[iy + 1][iz + 1]
			# Double-sided so glass reads from cabin and exterior.
			_add_tri(st, v00, uv00, v01, uv01, v10, uv10)
			_add_tri(st, v10, uv10, v01, uv01, v11, uv11)
			_add_tri(st, v00, uv00, v10, uv10, v01, uv01)
			_add_tri(st, v10, uv10, v11, uv11, v01, uv01)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Curved glass pane clipped to a rounded CSG-style polygon (Vector2(z_off, y_off)).
func build_curved_pane_from_poly(
	wall_sign: float,
	poly: PackedVector2Array,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	poly_center_y: float,
	x_shift: float = 0.0,
	edge_subdiv: int = 4
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_span := span_z * 0.5
	var ring: Array[Vector3] = []
	var ring_uv: Array[Vector2] = []
	var n := poly.size()
	if n < 3:
		return st.commit()

	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		for s in range(edge_subdiv):
			var t := float(s) / float(edge_subdiv)
			var p := a.lerp(b, t)
			var y := poly_center_y + p.y
			var z := z_ref + p.x
			var x_local := wall_sign * (_profile_x(y) - x_ref) + x_shift
			ring.append(Vector3(x_local, y - y_ref, z - z_ref))
			ring_uv.append(Vector2((z + half_span) / span_z, y / wall_height))

	# Centroid in poly space → curved surface (convex rounded rect).
	var c2 := Vector2.ZERO
	for i in range(n):
		c2 += poly[i]
	c2 /= float(n)
	var cy := poly_center_y + c2.y
	var cz := z_ref + c2.x
	var c := Vector3(wall_sign * (_profile_x(cy) - x_ref) + x_shift, cy - y_ref, cz - z_ref)
	var cuv := Vector2((cz + half_span) / span_z, cy / wall_height)

	var m := ring.size()
	for i in range(m):
		var v0: Vector3 = ring[i]
		var v1: Vector3 = ring[(i + 1) % m]
		var uv0: Vector2 = ring_uv[i]
		var uv1: Vector2 = ring_uv[(i + 1) % m]
		_add_tri(st, c, cuv, v0, uv0, v1, uv1)
		_add_tri(st, c, cuv, v1, uv1, v0, uv0)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Thin CSG-style frame ring: loft outer→inner polys onto the wall curve.
## Matches the extruded WindowFrame (Outer − InnerCut) silhouette.
## Each spoke keeps a flat cross-section (same face X for outer+inner) so the
## border reads like rear CSG — slim, sharp — not a bowed "inflated tire".
func build_curved_frame_ring_mesh(
	wall_sign: float,
	outer_poly: PackedVector2Array,
	inner_poly: PackedVector2Array,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	poly_center_y: float,
	shell_thickness: float,
	x_shift: float = 0.0,
	edge_subdiv: int = 8
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if outer_poly.size() < 3 or inner_poly.size() < 3:
		return st.commit()

	var outer_2 := _densify_poly(outer_poly, edge_subdiv)
	var inner_2 := _densify_poly(inner_poly, edge_subdiv)
	# Same vertex count required for index pairing.
	var count := mini(outer_2.size(), inner_2.size())
	if count < 3:
		return st.commit()

	var half_span := span_z * 0.5
	var oi: Array[Vector3] = []
	var oo: Array[Vector3] = []
	var ii: Array[Vector3] = []
	var io: Array[Vector3] = []
	var ouv: Array[Vector2] = []
	var iuv: Array[Vector2] = []

	for k in range(count):
		var op: Vector2 = outer_2[k]
		var ip: Vector2 = inner_2[k]
		var oy := poly_center_y + op.y
		var oz := z_ref + op.x
		var iy := poly_center_y + ip.y
		var iz := z_ref + ip.x
		# Flat CSG face across the border width — bend only along the perimeter.
		var mid_y := (oy + iy) * 0.5
		var face_x := wall_sign * (_profile_x(mid_y) - x_ref) + x_shift
		oi.append(Vector3(face_x, oy - y_ref, oz - z_ref))
		ii.append(Vector3(face_x, iy - y_ref, iz - z_ref))
		oo.append(Vector3(face_x + wall_sign * shell_thickness, oy - y_ref, oz - z_ref))
		io.append(Vector3(face_x + wall_sign * shell_thickness, iy - y_ref, iz - z_ref))
		ouv.append(Vector2((oz + half_span) / span_z, oy / wall_height))
		iuv.append(Vector2((iz + half_span) / span_z, iy / wall_height))

	for k in range(count):
		var n := (k + 1) % count
		# Cabin face — smooth along the curve, hard edge vs returns.
		st.set_smooth_group(0)
		if wall_sign > 0.0:
			_add_tri(st, oi[k], ouv[k], ii[k], iuv[k], oi[n], ouv[n])
			_add_tri(st, oi[n], ouv[n], ii[k], iuv[k], ii[n], iuv[n])
		else:
			_add_tri(st, oi[k], ouv[k], oi[n], ouv[n], ii[k], iuv[k])
			_add_tri(st, oi[n], ouv[n], ii[n], iuv[n], ii[k], iuv[k])
		# Exterior face.
		st.set_smooth_group(1)
		if wall_sign > 0.0:
			_add_tri(st, oo[k], ouv[k], oo[n], ouv[n], io[k], iuv[k])
			_add_tri(st, oo[n], ouv[n], io[n], iuv[n], io[k], iuv[k])
		else:
			_add_tri(st, oo[k], ouv[k], io[k], iuv[k], oo[n], ouv[n])
			_add_tri(st, oo[n], ouv[n], io[k], iuv[k], io[n], iuv[n])
		# Outer / inner returns — flat so corners stay CSG-sharp.
		st.set_smooth_group(-1)
		_add_return_quad(st, wall_sign, oi[k], oo[k], oi[n], oo[n], ouv[k], ouv[n], wall_sign < 0.0)
		_add_return_quad(st, wall_sign, ii[k], io[k], ii[n], io[n], iuv[k], iuv[n], wall_sign > 0.0)

	st.index()
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _densify_poly(poly: PackedVector2Array, edge_subdiv: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	var steps := maxi(edge_subdiv, 1)
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		for s in range(steps):
			out.append(a.lerp(b, float(s) / float(steps)))
	return out


func _shell_point_solid(
	y: float,
	z: float,
	z_ref: float,
	poly_cy: float,
	has_outer_poly: bool,
	outer_poly: PackedVector2Array,
	has_hole_poly: bool,
	hole_poly: PackedVector2Array,
	has_rect_hole: bool,
	hole_y_min: float,
	hole_y_max: float,
	hole_z_min: float,
	hole_z_max: float
) -> bool:
	var p := Vector2(z - z_ref, y - poly_cy)
	if has_outer_poly and not point_in_poly(p, outer_poly):
		return false
	if has_hole_poly and point_in_poly(p, hole_poly):
		return false
	if has_rect_hole and not has_hole_poly:
		if y > hole_y_min and y < hole_y_max and z > hole_z_min and z < hole_z_max:
			return false
	return true


func _add_shell_cell(
	st: SurfaceTool,
	wall_sign: float,
	inner: Array,
	outer: Array,
	uvs: Array,
	iy: int,
	iz: int
) -> void:
	var i00: Vector3 = inner[iy][iz]
	var i10: Vector3 = inner[iy][iz + 1]
	var i01: Vector3 = inner[iy + 1][iz]
	var i11: Vector3 = inner[iy + 1][iz + 1]
	var o00: Vector3 = outer[iy][iz]
	var o10: Vector3 = outer[iy][iz + 1]
	var o01: Vector3 = outer[iy + 1][iz]
	var o11: Vector3 = outer[iy + 1][iz + 1]
	var uv00: Vector2 = uvs[iy][iz]
	var uv10: Vector2 = uvs[iy][iz + 1]
	var uv01: Vector2 = uvs[iy + 1][iz]
	var uv11: Vector2 = uvs[iy + 1][iz + 1]
	if wall_sign > 0.0:
		_add_tri(st, i00, uv00, i01, uv01, i10, uv10)
		_add_tri(st, i10, uv10, i01, uv01, i11, uv11)
		_add_tri(st, o00, uv00, o10, uv10, o01, uv01)
		_add_tri(st, o10, uv10, o11, uv11, o01, uv01)
	else:
		_add_tri(st, i00, uv00, i10, uv10, i01, uv01)
		_add_tri(st, i10, uv10, i11, uv11, i01, uv01)
		_add_tri(st, o00, uv00, o01, uv01, o10, uv10)
		_add_tri(st, o10, uv10, o01, uv01, o11, uv11)


func _add_shell_hole_returns(
	st: SurfaceTool,
	wall_sign: float,
	inner: Array,
	outer: Array,
	uvs: Array,
	solid: Array
) -> void:
	var y_n: int = solid.size() - 1
	var z_n: int = solid[0].size() - 1
	for iy in range(y_n):
		for iz in range(z_n):
			var s00: bool = solid[iy][iz]
			var s10: bool = solid[iy][iz + 1]
			var s01: bool = solid[iy + 1][iz]
			if s00 != s10:
				_add_return_quad(
					st, wall_sign,
					inner[iy][iz + 1], outer[iy][iz + 1],
					inner[iy + 1][iz + 1], outer[iy + 1][iz + 1],
					uvs[iy][iz + 1], uvs[iy + 1][iz + 1],
					s00
				)
			if s00 != s01:
				_add_return_quad(
					st, wall_sign,
					inner[iy + 1][iz], outer[iy + 1][iz],
					inner[iy + 1][iz + 1], outer[iy + 1][iz + 1],
					uvs[iy + 1][iz], uvs[iy + 1][iz + 1],
					s00
				)


func _add_shell_border_returns(
	st: SurfaceTool,
	wall_sign: float,
	inner: Array,
	outer: Array,
	uvs: Array,
	seg_y: int,
	seg_z: int
) -> void:
	# Bottom and top edges.
	for iz in range(seg_z):
		_add_return_quad(
			st, wall_sign,
			inner[0][iz], outer[0][iz],
			inner[0][iz + 1], outer[0][iz + 1],
			uvs[0][iz], uvs[0][iz + 1],
			wall_sign > 0.0
		)
		_add_return_quad(
			st, wall_sign,
			inner[seg_y][iz], outer[seg_y][iz],
			inner[seg_y][iz + 1], outer[seg_y][iz + 1],
			uvs[seg_y][iz], uvs[seg_y][iz + 1],
			wall_sign < 0.0
		)
	# Z-min and Z-max edges.
	for iy in range(seg_y):
		_add_return_quad(
			st, wall_sign,
			inner[iy][0], outer[iy][0],
			inner[iy + 1][0], outer[iy + 1][0],
			uvs[iy][0], uvs[iy + 1][0],
			wall_sign < 0.0
		)
		_add_return_quad(
			st, wall_sign,
			inner[iy][seg_z], outer[iy][seg_z],
			inner[iy + 1][seg_z], outer[iy + 1][seg_z],
			uvs[iy][seg_z], uvs[iy + 1][seg_z],
			wall_sign > 0.0
		)


func _build() -> void:
	if _built:
		return
	_built = true

	var mat := wall_material if wall_material else _default_wall_material()
	_add_side(&"LeftWall", -1.0, mat)
	_add_side(&"RightWall", 1.0, mat)
	_add_cargo_rails(mat)


func _add_side(side_name: StringName, wall_sign: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = String(side_name)
	mi.mesh = _build_side_mesh(wall_sign)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _build_side_mesh(wall_sign: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_z := span_z * 0.5
	var verts: Array = []
	var uvs: Array = []
	var solid: Array = []

	for iy in range(y_segments + 1):
		var row_v: Array = []
		var row_uv: Array = []
		var row_solid: Array = []
		var ty := float(iy) / float(y_segments)
		var y := ty * wall_height
		var x_inner := wall_sign * _profile_x(y)
		for iz in range(z_segments + 1):
			var tz := float(iz) / float(z_segments)
			var z := lerpf(-half_z, half_z, tz)
			row_v.append(Vector3(x_inner, y, z))
			row_uv.append(Vector2(tz, ty))
			row_solid.append(not _is_open(y, z))
		verts.append(row_v)
		uvs.append(row_uv)
		solid.append(row_solid)

	# Outer skin (thin shell so openings have depth).
	var outer: Array = []
	for iy in range(y_segments + 1):
		var row: Array = []
		var y := float(iy) / float(y_segments) * wall_height
		var x_inner := wall_sign * _profile_x(y)
		var x_outer := x_inner + wall_sign * thickness
		for iz in range(z_segments + 1):
			var z := lerpf(-half_z, half_z, float(iz) / float(z_segments))
			row.append(Vector3(x_outer, y, z))
		outer.append(row)

	# Pull fringe verts onto the rounded WindowCut so the liner opening matches
	# the rear door CSG silhouette instead of a stair-stepped rect.
	_project_window_cut_fringe(wall_sign, verts, outer, solid)

	# Interior face (normals toward cabin).
	for iy in range(y_segments):
		for iz in range(z_segments):
			var y0 := float(iy) / float(y_segments) * wall_height
			var y1 := float(iy + 1) / float(y_segments) * wall_height
			var z0 := lerpf(-half_z, half_z, float(iz) / float(z_segments))
			var z1 := lerpf(-half_z, half_z, float(iz + 1) / float(z_segments))
			# Door bay: punch by cell center. Windows: only punch cells fully inside
			# the rounded cut so wall metal stays under the frame lip (rear-door look).
			if _is_door_bay_open((y0 + y1) * 0.5, (z0 + z1) * 0.5):
				continue
			if _cell_fully_in_window_cut(y0, y1, z0, z1):
				continue
			var v00: Vector3 = verts[iy][iz]
			var v10: Vector3 = verts[iy][iz + 1]
			var v01: Vector3 = verts[iy + 1][iz]
			var v11: Vector3 = verts[iy + 1][iz + 1]
			var uv00: Vector2 = uvs[iy][iz]
			var uv10: Vector2 = uvs[iy][iz + 1]
			var uv01: Vector2 = uvs[iy + 1][iz]
			var uv11: Vector2 = uvs[iy + 1][iz + 1]
			if wall_sign > 0.0:
				# Right wall: wind so normals face -X (into room).
				_add_tri(st, v00, uv00, v01, uv01, v10, uv10)
				_add_tri(st, v10, uv10, v01, uv01, v11, uv11)
			else:
				_add_tri(st, v00, uv00, v10, uv10, v01, uv01)
				_add_tri(st, v10, uv10, v11, uv11, v01, uv01)

	for iy in range(y_segments):
		for iz in range(z_segments):
			var y0 := float(iy) / float(y_segments) * wall_height
			var y1 := float(iy + 1) / float(y_segments) * wall_height
			var z0 := lerpf(-half_z, half_z, float(iz) / float(z_segments))
			var z1 := lerpf(-half_z, half_z, float(iz + 1) / float(z_segments))
			if _is_door_bay_open((y0 + y1) * 0.5, (z0 + z1) * 0.5):
				continue
			if _cell_fully_in_window_cut(y0, y1, z0, z1):
				continue
			var v00: Vector3 = outer[iy][iz]
			var v10: Vector3 = outer[iy][iz + 1]
			var v01: Vector3 = outer[iy + 1][iz]
			var v11: Vector3 = outer[iy + 1][iz + 1]
			var uv00: Vector2 = uvs[iy][iz]
			var uv10: Vector2 = uvs[iy][iz + 1]
			var uv01: Vector2 = uvs[iy + 1][iz]
			var uv11: Vector2 = uvs[iy + 1][iz + 1]
			if wall_sign > 0.0:
				_add_tri(st, v00, uv00, v10, uv10, v01, uv01)
				_add_tri(st, v10, uv10, v11, uv11, v01, uv01)
			else:
				_add_tri(st, v00, uv00, v01, uv01, v10, uv10)
				_add_tri(st, v10, uv10, v01, uv01, v11, uv11)

	# Opening returns (thickness around cutouts).
	_add_opening_returns(st, wall_sign, verts, outer, uvs, solid)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _add_opening_returns(
	st: SurfaceTool,
	wall_sign: float,
	inner: Array,
	outer: Array,
	uvs: Array,
	solid: Array
) -> void:
	for iy in range(y_segments):
		for iz in range(z_segments):
			var s00: bool = solid[iy][iz]
			var s10: bool = solid[iy][iz + 1]
			var s01: bool = solid[iy + 1][iz]
			# Vertical edge along +Z of cell when solidity changes across z.
			if s00 != s10:
				_add_return_quad(
					st, wall_sign,
					inner[iy][iz + 1], outer[iy][iz + 1],
					inner[iy + 1][iz + 1], outer[iy + 1][iz + 1],
					uvs[iy][iz + 1], uvs[iy + 1][iz + 1],
					s00
				)
			# Horizontal edge along +Y of cell when solidity changes across y.
			if s00 != s01:
				_add_return_quad(
					st, wall_sign,
					inner[iy + 1][iz], outer[iy + 1][iz],
					inner[iy + 1][iz + 1], outer[iy + 1][iz + 1],
					uvs[iy + 1][iz], uvs[iy + 1][iz + 1],
					s00
				)


func _add_return_quad(
	st: SurfaceTool,
	wall_sign: float,
	i_a: Vector3, o_a: Vector3,
	i_b: Vector3, o_b: Vector3,
	uv_a: Vector2, uv_b: Vector2,
	solid_on_neg: bool
) -> void:
	# Bridge inner→outer along the cut. Winding depends on which side is solid.
	if solid_on_neg == (wall_sign > 0.0):
		_add_tri(st, i_a, uv_a, o_a, uv_a, i_b, uv_b)
		_add_tri(st, i_b, uv_b, o_a, uv_a, o_b, uv_b)
	else:
		_add_tri(st, i_a, uv_a, i_b, uv_b, o_a, uv_a)
		_add_tri(st, i_b, uv_b, o_b, uv_b, o_a, uv_a)


func _add_cargo_rails(mat: Material) -> void:
	# Lower tie rail sits under the windows — run full length except the door bay.
	_add_rail_segments(mat, 0.72, _solid_z_ranges_below_windows())
	# Mid belt rail only on solid spans between openings.
	_add_rail_segments(mat, 1.52, _solid_z_ranges_mid())


func _add_rail_segments(mat: Material, rail_y: float, ranges: Array) -> void:
	var x := _profile_x(rail_y)
	var lean := lean_angle_at(rail_y)
	var idx := 0
	for span in ranges:
		var z0: float = span[0]
		var z1: float = span[1]
		var length: float = z1 - z0
		if length < 0.35:
			continue
		var z_mid := (z0 + z1) * 0.5
		for wall_sign in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			rail.name = "CargoRail_%s_%d" % ["L" if wall_sign < 0.0 else "R", idx]
			var box := BoxMesh.new()
			box.size = Vector3(0.045, 0.06, length)
			rail.mesh = box
			rail.material_override = mat
			# Sit just proud of the interior face.
			rail.position = Vector3(wall_sign * (x - wall_sign * 0.025), rail_y, z_mid)
			rail.rotation.z = wall_sign * lean
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(rail)
		idx += 1


func _solid_z_ranges_below_windows() -> Array:
	# Full cargo length minus side-door bay.
	var half := span_z * 0.5
	var door0 := door_center_z - door_half_length
	var door1 := door_center_z + door_half_length
	return [[-half + 0.1, door0 - 0.04], [door1 + 0.04, half - 0.1]]


func _solid_z_ranges_mid() -> Array:
	var half := span_z * 0.5
	var cuts: Array = []
	for cz in window_centers_z:
		cuts.append([cz - window_half_length, cz + window_half_length])
	cuts.append([door_center_z - door_half_length, door_center_z + door_half_length])
	cuts.sort_custom(func(a, b): return a[0] < b[0])

	var ranges: Array = []
	var cursor := -half + 0.1
	for cut in cuts:
		var c0: float = cut[0]
		var c1: float = cut[1]
		if c0 > cursor + 0.3:
			ranges.append([cursor, c0 - 0.03])
		cursor = maxf(cursor, c1 + 0.03)
	if cursor < half - 0.4:
		ranges.append([cursor, half - 0.1])
	return ranges


func _profile_x(y: float) -> float:
	var t := clampf(y / maxf(wall_height, 0.001), 0.0, 1.0)
	# Ease taper toward the roof so the upper third reads clearly narrower.
	var taper_t := t * t
	var taper := lerpf(bottom_half_width, top_half_width, taper_t)
	var bow := bow_out * sin(PI * t)
	return taper + bow


func _is_open(y: float, z: float) -> bool:
	return _is_door_bay_open(y, z) or _in_window_cut(y, z)


func _is_door_bay_open(y: float, z: float) -> bool:
	return y >= door_y_min and y <= door_y_max and absf(z - door_center_z) <= door_half_length


func _in_window_cut(y: float, z: float) -> bool:
	for cz in window_centers_z:
		if point_in_poly(Vector2(z - cz, y - window_center_y), WINDOW_CUT_POLY):
			return true
	return false


## Only punch a wall cell when every corner is inside the rounded cut — keeps
## liner metal under the frame lip the way the rear door panel surrounds its pane.
func _cell_fully_in_window_cut(y0: float, y1: float, z0: float, z1: float) -> bool:
	return (
		_in_window_cut(y0, z0)
		and _in_window_cut(y0, z1)
		and _in_window_cut(y1, z0)
		and _in_window_cut(y1, z1)
	)


func _project_window_cut_fringe(wall_sign: float, verts: Array, outer: Array, solid: Array) -> void:
	for iy in range(y_segments + 1):
		for iz in range(z_segments + 1):
			if solid[iy][iz]:
				continue
			if not _has_solid_neighbor(solid, iy, iz):
				continue
			var y: float = verts[iy][iz].y
			var z: float = verts[iy][iz].z
			# Door-bay fringe must stay open. Snapping those verts onto the nearest
			# WindowCut stretches liner UVs from the door seam into the adjacent
			# sash — the dark blob between side door and front window.
			if _is_door_bay_open(y, z):
				continue
			# nearest returns Vector2(world_y, world_z)
			var p := _nearest_on_window_cut(y, z)
			var wy := p.x
			var wz := p.y
			var x := wall_sign * _profile_x(wy)
			verts[iy][iz] = Vector3(x, wy, wz)
			outer[iy][iz] = Vector3(x + wall_sign * thickness, wy, wz)
			solid[iy][iz] = true


func _has_solid_neighbor(solid: Array, iy: int, iz: int) -> bool:
	for dy in range(-1, 2):
		for dz in range(-1, 2):
			if dy == 0 and dz == 0:
				continue
			var ny := iy + dy
			var nz := iz + dz
			if ny < 0 or nz < 0 or ny > y_segments or nz > z_segments:
				continue
			if solid[ny][nz]:
				return true
	return false


func _nearest_on_window_cut(y: float, z: float) -> Vector2:
	## Returns Vector2(world_y, world_z) on the nearest WindowCut edge.
	var best := Vector2(y, z)
	var best_d := INF
	for cz in window_centers_z:
		var local := Vector2(z - cz, y - window_center_y)
		var n := WINDOW_CUT_POLY.size()
		for i in range(n):
			var a: Vector2 = WINDOW_CUT_POLY[i]
			var b: Vector2 = WINDOW_CUT_POLY[(i + 1) % n]
			var ab := b - a
			var t := 0.0
			var denom := ab.dot(ab)
			if denom > 0.0000001:
				t = clampf((local - a).dot(ab) / denom, 0.0, 1.0)
			var q := a.lerp(b, t)
			var d := local.distance_squared_to(q)
			if d < best_d:
				best_d = d
				best = Vector2(window_center_y + q.y, cz + q.x)
	return best


func _add_tri(
	st: SurfaceTool,
	a: Vector3, uva: Vector2,
	b: Vector3, uvb: Vector2,
	c: Vector3, uvc: Vector2
) -> void:
	st.set_uv(uva)
	st.add_vertex(a)
	st.set_uv(uvb)
	st.add_vertex(b)
	st.set_uv(uvc)
	st.add_vertex(c)


func _default_wall_material() -> ShaderMaterial:
	var sh := load("res://scenes/van/van_wall.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("wall_size_m", Vector2(span_z, wall_height))
	return mat
