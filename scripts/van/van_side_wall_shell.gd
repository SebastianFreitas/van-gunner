extends RefCounted

## Generic curved-shell / pane / frame-ring mesh builders for VanSideWall: the
## low-level lofting onto the cargo profile, shared by side walls, doors and windows.

var wall: Node3D  # the VanSideWall; reads its exports and profile when called


func _init(owner: Node3D) -> void:
	wall = owner


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
	var half_span: float = wall.span_z * 0.5

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
		var x_face: float = wall_sign * wall._profile_x(y) + x_shift
		var x_inner := x_face - wall_sign * x_ref
		var x_outer := x_inner + wall_sign * shell_thickness
		for iz in range(seg_z + 1):
			var tz := float(iz) / float(seg_z)
			var z := lerpf(z_min, z_max, tz)
			row_i.append(Vector3(x_inner, y - y_ref, z - z_ref))
			row_o.append(Vector3(x_outer, y - y_ref, z - z_ref))
			row_uv.append(Vector2((z + half_span) / wall.span_z, y / wall.wall_height))
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
	var half_span: float = wall.span_z * 0.5
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
			var x_local: float = wall_sign * (wall._profile_x(y) - x_ref) + x_shift
			ring.append(Vector3(x_local, y - y_ref, z - z_ref))
			ring_uv.append(Vector2((z + half_span) / wall.span_z, y / wall.wall_height))

	# Centroid in poly space → curved surface (convex rounded rect).
	var c2 := Vector2.ZERO
	for i in range(n):
		c2 += poly[i]
	c2 /= float(n)
	var cy := poly_center_y + c2.y
	var cz := z_ref + c2.x
	var c := Vector3(wall_sign * (wall._profile_x(cy) - x_ref) + x_shift, cy - y_ref, cz - z_ref)
	var cuv := Vector2((cz + half_span) / wall.span_z, cy / wall.wall_height)

	var m := ring.size()
	for i in range(m):
		var v0: Vector3 = ring[i]
		var v1: Vector3 = ring[(i + 1) % m]
		var uv0: Vector2 = ring_uv[i]
		var uv1: Vector2 = ring_uv[(i + 1) % m]
		add_tri(st, c, cuv, v0, uv0, v1, uv1)
		add_tri(st, c, cuv, v1, uv1, v0, uv0)

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

	var outer_2 := densify_poly(outer_poly, edge_subdiv)
	var inner_2 := densify_poly(inner_poly, edge_subdiv)
	# Same vertex count required for index pairing.
	var count := mini(outer_2.size(), inner_2.size())
	if count < 3:
		return st.commit()

	var half_span: float = wall.span_z * 0.5
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
		var face_x: float = wall_sign * (wall._profile_x(mid_y) - x_ref) + x_shift
		oi.append(Vector3(face_x, oy - y_ref, oz - z_ref))
		ii.append(Vector3(face_x, iy - y_ref, iz - z_ref))
		oo.append(Vector3(face_x + wall_sign * shell_thickness, oy - y_ref, oz - z_ref))
		io.append(Vector3(face_x + wall_sign * shell_thickness, iy - y_ref, iz - z_ref))
		ouv.append(Vector2((oz + half_span) / wall.span_z, oy / wall.wall_height))
		iuv.append(Vector2((iz + half_span) / wall.span_z, iy / wall.wall_height))

	for k in range(count):
		var n := (k + 1) % count
		# Cabin face — smooth along the curve, hard edge vs returns.
		st.set_smooth_group(0)
		if wall_sign > 0.0:
			add_tri(st, oi[k], ouv[k], ii[k], iuv[k], oi[n], ouv[n])
			add_tri(st, oi[n], ouv[n], ii[k], iuv[k], ii[n], iuv[n])
		else:
			add_tri(st, oi[k], ouv[k], oi[n], ouv[n], ii[k], iuv[k])
			add_tri(st, oi[n], ouv[n], ii[n], iuv[n], ii[k], iuv[k])
		# Exterior face.
		st.set_smooth_group(1)
		if wall_sign > 0.0:
			add_tri(st, oo[k], ouv[k], oo[n], ouv[n], io[k], iuv[k])
			add_tri(st, oo[n], ouv[n], io[n], iuv[n], io[k], iuv[k])
		else:
			add_tri(st, oo[k], ouv[k], io[k], iuv[k], oo[n], ouv[n])
			add_tri(st, oo[n], ouv[n], io[k], iuv[k], io[n], iuv[n])
		# Outer / inner returns — flat so corners stay CSG-sharp.
		st.set_smooth_group(-1)
		var panel: Variant = wall._panel_helper()
		panel.add_return_quad(
			st, wall_sign, oi[k], oo[k], oi[n], oo[n], ouv[k], ouv[n], wall_sign < 0.0
		)
		panel.add_return_quad(
			st, wall_sign, ii[k], io[k], ii[n], io[n], iuv[k], iuv[n], wall_sign > 0.0
		)

	st.index()
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func densify_poly(poly: PackedVector2Array, edge_subdiv: int) -> PackedVector2Array:
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
	if has_outer_poly and not wall.point_in_poly(p, outer_poly):
		return false
	if has_hole_poly and wall.point_in_poly(p, hole_poly):
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
		add_tri(st, i00, uv00, i01, uv01, i10, uv10)
		add_tri(st, i10, uv10, i01, uv01, i11, uv11)
		add_tri(st, o00, uv00, o10, uv10, o01, uv01)
		add_tri(st, o10, uv10, o11, uv11, o01, uv01)
	else:
		add_tri(st, i00, uv00, i10, uv10, i01, uv01)
		add_tri(st, i10, uv10, i11, uv11, i01, uv01)
		add_tri(st, o00, uv00, o01, uv01, o10, uv10)
		add_tri(st, o10, uv10, o01, uv01, o11, uv11)


func _add_shell_hole_returns(
	st: SurfaceTool,
	wall_sign: float,
	inner: Array,
	outer: Array,
	uvs: Array,
	solid: Array
) -> void:
	var panel: Variant = wall._panel_helper()
	var y_n: int = solid.size() - 1
	var z_n: int = solid[0].size() - 1
	for iy in range(y_n):
		for iz in range(z_n):
			var s00: bool = solid[iy][iz]
			var s10: bool = solid[iy][iz + 1]
			var s01: bool = solid[iy + 1][iz]
			if s00 != s10:
				panel.add_return_quad(
					st, wall_sign, inner[iy][iz + 1], outer[iy][iz + 1],
					inner[iy + 1][iz + 1], outer[iy + 1][iz + 1],
					uvs[iy][iz + 1], uvs[iy + 1][iz + 1], s00
				)
			if s00 != s01:
				panel.add_return_quad(
					st, wall_sign, inner[iy + 1][iz], outer[iy + 1][iz],
					inner[iy + 1][iz + 1], outer[iy + 1][iz + 1],
					uvs[iy + 1][iz], uvs[iy + 1][iz + 1], s00
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
	var panel: Variant = wall._panel_helper()
	# Bottom and top edges.
	for iz in range(seg_z):
		panel.add_return_quad(
			st, wall_sign, inner[0][iz], outer[0][iz],
			inner[0][iz + 1], outer[0][iz + 1],
			uvs[0][iz], uvs[0][iz + 1], wall_sign > 0.0
		)
		panel.add_return_quad(
			st, wall_sign, inner[seg_y][iz], outer[seg_y][iz],
			inner[seg_y][iz + 1], outer[seg_y][iz + 1],
			uvs[seg_y][iz], uvs[seg_y][iz + 1], wall_sign < 0.0
		)
	# Z-min and Z-max edges.
	for iy in range(seg_y):
		panel.add_return_quad(
			st, wall_sign, inner[iy][0], outer[iy][0],
			inner[iy + 1][0], outer[iy + 1][0],
			uvs[iy][0], uvs[iy + 1][0], wall_sign < 0.0
		)
		panel.add_return_quad(
			st, wall_sign, inner[iy][seg_z], outer[iy][seg_z],
			inner[iy + 1][seg_z], outer[iy + 1][seg_z],
			uvs[iy][seg_z], uvs[iy + 1][seg_z], wall_sign > 0.0
		)


static func add_tri(
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


func poly_edge_inward(a: Vector2, b: Vector2, poly: PackedVector2Array) -> Vector2:
	var edge := b - a
	var n := Vector2(-edge.y, edge.x)
	if not wall.point_in_poly((a + b) * 0.5 + n * 0.01, poly):
		n = -n
	return n
