class_name VanHullMesh
extends RefCounted

## XY end-cap slabs that follow VanSideWall's bow and VanCeiling's barrel vault.
## Used by rear door leaves (window hole preserved for the existing CSG frame/glass).


static func vault_y(ceiling: VanCeiling, x: float, edge_height: float, peak_rise: float) -> float:
	if ceiling != null:
		return ceiling.vault_y_at(x)
	var half := 2.04
	var t := clampf(absf(x) / half, 0.0, 1.0)
	return edge_height + peak_rise * (1.0 - t * t)


static func wall_half(walls: VanSideWall, y: float, fallback: float) -> float:
	if walls != null:
		return walls.wall_x_at(y)
	return fallback


## Thick panel in the XY plane. `origin` is subtracted so the mesh sits in hinge-local
## space. `interior_is_neg_z` true for rear doors (cabin looks toward -Z of the leaf).
static func build_vaulted_xy_slab(
	walls: VanSideWall,
	ceiling: VanCeiling,
	x_inner: float,
	wall_sign: float,
	y_min: float,
	thickness: float,
	origin: Vector3,
	x_inset: float = 0.03,
	y_inset: float = 0.025,
	seg_x: int = 16,
	seg_y: int = 32,
	hole_poly: PackedVector2Array = PackedVector2Array(),
	hole_center: Vector2 = Vector2.ZERO,
	edge_height_fallback: float = 3.05,
	peak_rise_fallback: float = 0.38,
	bottom_half_fallback: float = 2.42,
	interior_is_neg_z: bool = true
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var y_peak := vault_y(ceiling, 0.0, edge_height_fallback, peak_rise_fallback) - y_inset
	var half_z := thickness * 0.5
	var cabin_z := -half_z if interior_is_neg_z else half_z
	var exterior_z := half_z if interior_is_neg_z else -half_z
	var has_hole := hole_poly.size() >= 3

	var front: Array = []
	var back: Array = []
	var uvs: Array = []
	var solid: Array = []
	## Sampled hole flags (pre-fringe) so window cells stay punched after edge snap.
	var in_hole_grid: Array = []

	for iy in range(seg_y + 1):
		var row_f: Array = []
		var row_b: Array = []
		var row_uv: Array = []
		var row_s: Array = []
		var row_h: Array = []
		var ty := float(iy) / float(seg_y)
		var y := lerpf(y_min, y_peak, ty)
		var x_outer := wall_sign * (wall_half(walls, y, bottom_half_fallback) - x_inset)
		for ix in range(seg_x + 1):
			var tx := float(ix) / float(seg_x)
			var x := lerpf(x_inner, x_outer, tx)
			var y_cap := vault_y(ceiling, x, edge_height_fallback, peak_rise_fallback) - y_inset
			var above_vault := y > y_cap + 0.001
			var y_use := minf(y, y_cap)
			var inside_wall := absf(x) <= wall_half(walls, y_use, bottom_half_fallback) - x_inset + 0.02
			var in_hole := false
			if has_hole:
				in_hole = _point_in_poly(Vector2(x - hole_center.x, y_use - hole_center.y), hole_poly)
			var is_solid := inside_wall and not above_vault and not in_hole
			var local := Vector3(x, y_use, 0.0) - Vector3(origin.x, origin.y, 0.0)
			row_f.append(Vector3(local.x, local.y, cabin_z))
			row_b.append(Vector3(local.x, local.y, exterior_z))
			row_uv.append(Vector2(tx, ty))
			row_s.append(is_solid)
			row_h.append(in_hole)
		front.append(row_f)
		back.append(row_b)
		uvs.append(row_uv)
		solid.append(row_s)
		in_hole_grid.append(row_h)

	# Smooth outer vault/wall fringe and the window lip (metal stays under the frame).
	_project_fringe(
		front, back, solid, walls, ceiling, x_inner, wall_sign, y_min, y_peak,
		x_inset, y_inset, origin, has_hole, hole_poly, hole_center,
		edge_height_fallback, peak_rise_fallback, bottom_half_fallback
	)

	for iy in range(seg_y):
		for ix in range(seg_x):
			# Only skip cells fully inside the window cut — partial overlap keeps
			# the panel lip under the dark frame, matching the old CSG surround.
			if has_hole and _cell_fully_flagged(in_hole_grid, iy, ix):
				continue
			if not _cell_any_solid(solid, iy, ix):
				continue
			_add_slab_cell(st, front, back, uvs, iy, ix, interior_is_neg_z)

	_add_opening_returns(st, front, back, uvs, solid, interior_is_neg_z)
	_add_outer_border(st, front, back, uvs, seg_y, seg_x, interior_is_neg_z)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _cell_any_solid(solid: Array, iy: int, ix: int) -> bool:
	return (
		solid[iy][ix]
		or solid[iy][ix + 1]
		or solid[iy + 1][ix]
		or solid[iy + 1][ix + 1]
	)


static func _cell_fully_flagged(flags: Array, iy: int, ix: int) -> bool:
	return (
		flags[iy][ix]
		and flags[iy][ix + 1]
		and flags[iy + 1][ix]
		and flags[iy + 1][ix + 1]
	)


static func _project_fringe(
	front: Array,
	back: Array,
	solid: Array,
	walls: VanSideWall,
	ceiling: VanCeiling,
	x_inner: float,
	wall_sign: float,
	y_min: float,
	y_peak: float,
	x_inset: float,
	y_inset: float,
	origin: Vector3,
	has_hole: bool,
	hole_poly: PackedVector2Array,
	hole_center: Vector2,
	edge_height_fallback: float,
	peak_rise_fallback: float,
	bottom_half_fallback: float
) -> void:
	var seg_y: int = solid.size() - 1
	var seg_x: int = solid[0].size() - 1
	for iy in range(seg_y + 1):
		for ix in range(seg_x + 1):
			if solid[iy][ix]:
				continue
			if not _has_solid_neighbor(solid, iy, ix):
				continue
			var ty := float(iy) / float(seg_y)
			var y := lerpf(y_min, y_peak, ty)
			var x_outer := wall_sign * (wall_half(walls, y, bottom_half_fallback) - x_inset)
			var tx := float(ix) / float(seg_x)
			var x := lerpf(x_inner, x_outer, tx)
			var y_cap := vault_y(ceiling, x, edge_height_fallback, peak_rise_fallback) - y_inset
			var y_fix := minf(y, y_cap)
			if has_hole and _point_in_poly(Vector2(x - hole_center.x, y_fix - hole_center.y), hole_poly):
				var local := Vector2(x - hole_center.x, y_fix - hole_center.y)
				var nearest := _nearest_on_poly(local, hole_poly)
				x = hole_center.x + nearest.x
				y_fix = hole_center.y + nearest.y
			else:
				# Outer silhouette — sit on the vault (and wall clamp already in x_outer).
				y_fix = y_cap
				var half := wall_half(walls, y_fix, bottom_half_fallback) - x_inset
				if absf(x) > half:
					x = wall_sign * half
			var local_p := Vector3(x, y_fix, 0.0) - Vector3(origin.x, origin.y, 0.0)
			var cz: float = front[iy][ix].z
			var ez: float = back[iy][ix].z
			front[iy][ix] = Vector3(local_p.x, local_p.y, cz)
			back[iy][ix] = Vector3(local_p.x, local_p.y, ez)
			solid[iy][ix] = true


static func _has_solid_neighbor(solid: Array, iy: int, ix: int) -> bool:
	var seg_y: int = solid.size() - 1
	var seg_x: int = solid[0].size() - 1
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dy == 0 and dx == 0:
				continue
			var ny := iy + dy
			var nx := ix + dx
			if ny < 0 or nx < 0 or ny > seg_y or nx > seg_x:
				continue
			if solid[ny][nx]:
				return true
	return false


static func _add_slab_cell(
	st: SurfaceTool,
	front: Array,
	back: Array,
	uvs: Array,
	iy: int,
	ix: int,
	interior_is_neg_z: bool
) -> void:
	var f00: Vector3 = front[iy][ix]
	var f10: Vector3 = front[iy][ix + 1]
	var f01: Vector3 = front[iy + 1][ix]
	var f11: Vector3 = front[iy + 1][ix + 1]
	var b00: Vector3 = back[iy][ix]
	var b10: Vector3 = back[iy][ix + 1]
	var b01: Vector3 = back[iy + 1][ix]
	var b11: Vector3 = back[iy + 1][ix + 1]
	var uv00: Vector2 = uvs[iy][ix]
	var uv10: Vector2 = uvs[iy][ix + 1]
	var uv01: Vector2 = uvs[iy + 1][ix]
	var uv11: Vector2 = uvs[iy + 1][ix + 1]
	if interior_is_neg_z:
		_add_tri(st, f00, uv00, f01, uv01, f10, uv10)
		_add_tri(st, f10, uv10, f01, uv01, f11, uv11)
		_add_tri(st, b00, uv00, b10, uv10, b01, uv01)
		_add_tri(st, b10, uv10, b11, uv11, b01, uv01)
	else:
		_add_tri(st, f00, uv00, f10, uv10, f01, uv01)
		_add_tri(st, f10, uv10, f11, uv11, f01, uv01)
		_add_tri(st, b00, uv00, b01, uv01, b10, uv10)
		_add_tri(st, b10, uv10, b01, uv01, b11, uv11)


static func _add_opening_returns(
	st: SurfaceTool,
	front: Array,
	back: Array,
	uvs: Array,
	solid: Array,
	interior_is_neg_z: bool
) -> void:
	var seg_y: int = solid.size() - 1
	var seg_x: int = solid[0].size() - 1
	for iy in range(seg_y):
		for ix in range(seg_x):
			var s00: bool = solid[iy][ix]
			var s10: bool = solid[iy][ix + 1]
			var s01: bool = solid[iy + 1][ix]
			if s00 != s10:
				_add_return_quad(
					st,
					front[iy][ix + 1], back[iy][ix + 1],
					front[iy + 1][ix + 1], back[iy + 1][ix + 1],
					uvs[iy][ix + 1], uvs[iy + 1][ix + 1],
					s00 == interior_is_neg_z
				)
			if s00 != s01:
				_add_return_quad(
					st,
					front[iy + 1][ix], back[iy + 1][ix],
					front[iy + 1][ix + 1], back[iy + 1][ix + 1],
					uvs[iy + 1][ix], uvs[iy + 1][ix + 1],
					s00 == interior_is_neg_z
				)


static func _add_outer_border(
	st: SurfaceTool,
	front: Array,
	back: Array,
	uvs: Array,
	seg_y: int,
	seg_x: int,
	interior_is_neg_z: bool
) -> void:
	for ix in range(seg_x):
		_add_return_quad(
			st,
			front[0][ix], back[0][ix],
			front[0][ix + 1], back[0][ix + 1],
			uvs[0][ix], uvs[0][ix + 1],
			not interior_is_neg_z
		)
	for ix in range(seg_x):
		_add_return_quad(
			st,
			front[seg_y][ix], back[seg_y][ix],
			front[seg_y][ix + 1], back[seg_y][ix + 1],
			uvs[seg_y][ix], uvs[seg_y][ix + 1],
			interior_is_neg_z
		)
	for iy in range(seg_y):
		_add_return_quad(
			st,
			front[iy][0], back[iy][0],
			front[iy + 1][0], back[iy + 1][0],
			uvs[iy][0], uvs[iy + 1][0],
			interior_is_neg_z
		)
		_add_return_quad(
			st,
			front[iy][seg_x], back[iy][seg_x],
			front[iy + 1][seg_x], back[iy + 1][seg_x],
			uvs[iy][seg_x], uvs[iy + 1][seg_x],
			not interior_is_neg_z
		)


static func _add_return_quad(
	st: SurfaceTool,
	f_a: Vector3, b_a: Vector3,
	f_b: Vector3, b_b: Vector3,
	uv_a: Vector2, uv_b: Vector2,
	flip: bool
) -> void:
	if flip:
		_add_tri(st, f_a, uv_a, b_a, uv_a, f_b, uv_b)
		_add_tri(st, f_b, uv_b, b_a, uv_a, b_b, uv_b)
	else:
		_add_tri(st, f_a, uv_a, f_b, uv_b, b_a, uv_a)
		_add_tri(st, f_b, uv_b, b_b, uv_b, b_a, uv_a)


static func _add_tri(
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


static func _point_in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
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


static func _nearest_on_poly(local: Vector2, poly: PackedVector2Array) -> Vector2:
	var best := local
	var best_d := INF
	var n := poly.size()
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var ab := b - a
		var t := 0.0
		var denom := ab.dot(ab)
		if denom > 0.0000001:
			t = clampf((local - a).dot(ab) / denom, 0.0, 1.0)
		var q := a.lerp(b, t)
		var d := local.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best
