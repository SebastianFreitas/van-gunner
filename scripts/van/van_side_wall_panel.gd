extends RefCounted

## This wall's own side panel mesh: openings, reveals, returns, and the cut queries
## that decide which cells are punched for the side doors and windows.

const _Shell := preload("res://scripts/van/van_side_wall_shell.gd")

var wall: Node3D  # the VanSideWall; reads its exports and profile when called
var _x_from := 0.0  ## Offset off the liner of the mesh's inner face for the current build.
var _x_to := 0.0  ## Offset off the liner of the mesh's outer face for the current build.
var _inner_face := true  ## Whether the current build emits the cabin-side face.
## How far a reveal's cabin edge stands proud of the liner face (cabin side) when the build
## emits that face, so the reveal overlaps the face's flat grid rows instead of meeting them edge to edge.
const REVEAL_LIP_M := 0.004


func _init(owner: Node3D) -> void:
	wall = owner


## Which parts of the panel a build emits: grid faces, opening returns/reveals, or both.
enum Part { ALL, FACES, RETURNS }


func build_side_mesh(
	wall_sign: float, x_from: float = 0.0, x_to: float = -1.0, inner_face: bool = true,
	part: int = Part.ALL
) -> ArrayMesh:
	_x_from = x_from
	_x_to = wall.thickness if x_to < 0.0 else x_to
	_inner_face = inner_face
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_z: float = wall.span_z * 0.5
	var z_lo: float = wall.center_z - half_z
	var z_hi: float = wall.center_z + half_z
	var verts: Array = []
	var uvs: Array = []
	var solid: Array = []

	for iy in range(wall.y_segments + 1):
		var row_v: Array = []
		var row_uv: Array = []
		var row_solid: Array = []
		var ty := float(iy) / float(wall.y_segments)
		var y: float = ty * wall.wall_height
		var x_inner: float = wall_sign * (wall._profile_x(y) + _x_from)
		for iz in range(wall.z_segments + 1):
			var tz := float(iz) / float(wall.z_segments)
			var z := lerpf(z_lo, z_hi, tz)
			row_v.append(Vector3(x_inner, y, z))
			row_uv.append(Vector2(tz, ty))
			row_solid.append(not is_open(y, z))
		verts.append(row_v)
		uvs.append(row_uv)
		solid.append(row_solid)

	# Outer skin (thin shell so openings have depth).
	var outer: Array = []
	for iy in range(wall.y_segments + 1):
		var row: Array = []
		var y: float = float(iy) / float(wall.y_segments) * wall.wall_height
		var x_inner: float = wall_sign * (wall._profile_x(y) + _x_from)
		var x_outer: float = x_inner + wall_sign * (_x_to - _x_from)
		for iz in range(wall.z_segments + 1):
			var z := lerpf(z_lo, z_hi, float(iz) / float(wall.z_segments))
			row.append(Vector3(x_outer, y, z))
		outer.append(row)

	# Pull fringe verts onto the rounded WindowCut so the liner opening matches
	# the rear door CSG silhouette instead of a stair-stepped rect.
	project_window_cut_fringe(wall_sign, verts, outer, solid)

	# Interior face (normals toward cabin); the hull skin's outer layer has none.
	for iy in range(wall.y_segments if _inner_face and part != Part.RETURNS else 0):
		for iz in range(wall.z_segments):
			var y0: float = float(iy) / float(wall.y_segments) * wall.wall_height
			var y1: float = float(iy + 1) / float(wall.y_segments) * wall.wall_height
			var z0 := lerpf(z_lo, z_hi, float(iz) / float(wall.z_segments))
			var z1 := lerpf(z_lo, z_hi, float(iz + 1) / float(wall.z_segments))
			# Door bay: punch by cell center. Windows: only punch cells fully inside
			# the rounded cut so wall metal stays under the frame lip (rear-door look).
			if is_door_bay_open((y0 + y1) * 0.5, (z0 + z1) * 0.5):
				continue
			if cell_fully_in_window_cut(y0, y1, z0, z1):
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
				_Shell.add_tri(st, v00, uv00, v01, uv01, v10, uv10)
				_Shell.add_tri(st, v10, uv10, v01, uv01, v11, uv11)
			else:
				_Shell.add_tri(st, v00, uv00, v10, uv10, v01, uv01)
				_Shell.add_tri(st, v10, uv10, v11, uv11, v01, uv01)

	for iy in range(wall.y_segments if part != Part.RETURNS else 0):
		for iz in range(wall.z_segments):
			var y0: float = float(iy) / float(wall.y_segments) * wall.wall_height
			var y1: float = float(iy + 1) / float(wall.y_segments) * wall.wall_height
			var z0 := lerpf(z_lo, z_hi, float(iz) / float(wall.z_segments))
			var z1 := lerpf(z_lo, z_hi, float(iz + 1) / float(wall.z_segments))
			if is_door_bay_open((y0 + y1) * 0.5, (z0 + z1) * 0.5):
				continue
			if cell_fully_in_window_cut(y0, y1, z0, z1):
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
				_Shell.add_tri(st, v00, uv00, v10, uv10, v01, uv01)
				_Shell.add_tri(st, v10, uv10, v11, uv11, v01, uv01)
			else:
				_Shell.add_tri(st, v00, uv00, v01, uv01, v10, uv10)
				_Shell.add_tri(st, v10, uv10, v01, uv01, v11, uv11)

	if part != Part.FACES:
		# Returns around cutouts, plus reveals (grid returns are edge-on looking out).
		add_opening_returns(st, wall_sign, verts, outer, uvs, solid)
		add_window_opening_reveals(st, wall_sign)
		add_door_opening_reveals(st, wall_sign)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Cross-section faces on each window cut perimeter — visible when the sash is open.
func add_window_opening_reveals(st: SurfaceTool, wall_sign: float) -> void:
	const EDGE_SUBDIV := 16
	var n_poly: int = wall.WINDOW_CUT_POLY.size()
	if n_poly < 3:
		return
	for cz in wall.window_centers_z:
		for i in range(n_poly):
			var a: Vector2 = wall.WINDOW_CUT_POLY[i]
			var b: Vector2 = wall.WINDOW_CUT_POLY[(i + 1) % n_poly]
			var inward_2d: Vector2 = wall._shell_helper().poly_edge_inward(a, b, wall.WINDOW_CUT_POLY)
			for s in range(EDGE_SUBDIV):
				var la := a.lerp(b, float(s) / float(EDGE_SUBDIV))
				var lb := a.lerp(b, float(s + 1) / float(EDGE_SUBDIV))
				var wy: float = wall.window_center_y
				add_reveal_edge(
					st, wall_sign, Vector2(wy + la.y, cz + la.x), Vector2(wy + lb.y, cz + lb.x), inward_2d
				)


## Liner x offset of a reveal's cabin edge at y: the lesser of the curve and the face grid's
## flat row chord, less REVEAL_LIP_M when this build emits the cabin face (an outer-layer
## build keeps the curve so its reveals never overlap the liner's coplanar ones).
func reveal_inner_profile_x(y: float) -> float:
	var exact: float = wall._profile_x(y)
	if not _inner_face:
		return exact + _x_from
	var h: float = wall.wall_height / float(wall.y_segments)
	var i := clampi(int(floor(y / h)), 0, wall.y_segments - 1)
	var t := clampf((y - float(i) * h) / h, 0.0, 1.0)
	var chord := lerpf(wall._profile_x(float(i) * h), wall._profile_x(float(i + 1) * h), t)
	return minf(exact, chord) + _x_from - REVEAL_LIP_M


## One reveal quad between two (y, z) points on an opening's edge, cabin edge lipped.
func add_reveal_edge(
	st: SurfaceTool, wall_sign: float, a: Vector2, b: Vector2, inward_2d: Vector2
) -> void:
	var half_span: float = wall.span_z * 0.5
	var i_a := Vector3(wall_sign * reveal_inner_profile_x(a.x), a.x, a.y)
	var o_a := Vector3(wall_sign * (wall._profile_x(a.x) + _x_to), a.x, a.y)
	var i_b := Vector3(wall_sign * reveal_inner_profile_x(b.x), b.x, b.y)
	var o_b := Vector3(wall_sign * (wall._profile_x(b.x) + _x_to), b.x, b.y)
	var uva := Vector2((a.y + half_span - wall.center_z) / wall.span_z, a.x / wall.wall_height)
	var uvb := Vector2((b.y + half_span - wall.center_z) / wall.span_z, b.x / wall.wall_height)
	add_reveal_quad(st, i_a, o_a, i_b, o_b, uva, uvb, inward_2d)


## Quad bridging inner→outer along an opening edge; normal faces into the hole.
func add_reveal_quad(
	st: SurfaceTool,
	i_a: Vector3, o_a: Vector3, i_b: Vector3, o_b: Vector3,
	uva: Vector2, uvb: Vector2,
	inward_2d: Vector2
) -> void:
	var inward_3d := Vector3(0.0, inward_2d.y, inward_2d.x)
	var thick := o_a - i_a
	var tangent := i_b - i_a
	var n := thick.cross(tangent)
	if n.dot(inward_3d) < 0.0:
		_Shell.add_tri(st, i_a, uva, o_a, uva, o_b, uvb)
		_Shell.add_tri(st, i_a, uva, o_b, uvb, i_b, uvb)
	else:
		_Shell.add_tri(st, i_a, uva, i_b, uvb, o_b, uvb)
		_Shell.add_tri(st, i_a, uva, o_b, uvb, o_a, uva)


## Cross-section faces on the door hole perimeter — visible when looking out.
func add_door_opening_reveals(st: SurfaceTool, wall_sign: float) -> void:
	var z0: float = wall.door_center_z - wall.door_half_length
	var z1: float = wall.door_center_z + wall.door_half_length
	var segs_z := 32
	var segs_y := 32

	for iz in range(segs_z):
		var za := lerpf(z0, z1, float(iz) / float(segs_z))
		var zb := lerpf(z0, z1, float(iz + 1) / float(segs_z))
		var y_top: float = wall.door_y_max
		# Top lintel — normal points down into the opening.
		add_reveal_edge(st, wall_sign, Vector2(y_top, za), Vector2(y_top, zb), Vector2(0.0, -1.0))

	for iz in range(segs_z):
		var za := lerpf(z0, z1, float(iz) / float(segs_z))
		var zb := lerpf(z0, z1, float(iz + 1) / float(segs_z))
		var y_bot: float = wall.door_y_min
		# Bottom sill — normal points up into the opening.
		add_reveal_edge(st, wall_sign, Vector2(y_bot, za), Vector2(y_bot, zb), Vector2(0.0, 1.0))

	for iy in range(segs_y):
		var ya: float = lerpf(wall.door_y_min, wall.door_y_max, float(iy) / float(segs_y))
		var yb: float = lerpf(wall.door_y_min, wall.door_y_max, float(iy + 1) / float(segs_y))
		# Forward jamb — normal points into the opening (-Z).
		add_reveal_edge(st, wall_sign, Vector2(ya, z1), Vector2(yb, z1), Vector2(-1.0, 0.0))

	for iy in range(segs_y):
		var ya: float = lerpf(wall.door_y_min, wall.door_y_max, float(iy) / float(segs_y))
		var yb: float = lerpf(wall.door_y_min, wall.door_y_max, float(iy + 1) / float(segs_y))
		# Rear jamb — normal points into the opening (+Z).
		add_reveal_edge(st, wall_sign, Vector2(ya, z0), Vector2(yb, z0), Vector2(1.0, 0.0))


func add_opening_returns(
	st: SurfaceTool,
	wall_sign: float,
	inner: Array,
	outer: Array,
	uvs: Array,
	solid: Array
) -> void:
	for iy in range(wall.y_segments):
		for iz in range(wall.z_segments):
			var s00: bool = solid[iy][iz]
			var s10: bool = solid[iy][iz + 1]
			var s01: bool = solid[iy + 1][iz]
			# Vertical edge along +Z of cell when solidity changes across z.
			if s00 != s10:
				add_return_quad(
					st, wall_sign,
					inner[iy][iz + 1], outer[iy][iz + 1],
					inner[iy + 1][iz + 1], outer[iy + 1][iz + 1],
					uvs[iy][iz + 1], uvs[iy + 1][iz + 1],
					not s00  # the edge runs along y, not z, which flips add_return_quad's winding
				)
			# Horizontal edge along +Y of cell when solidity changes across y.
			if s00 != s01:
				add_return_quad(
					st, wall_sign,
					inner[iy + 1][iz], outer[iy + 1][iz],
					inner[iy + 1][iz + 1], outer[iy + 1][iz + 1],
					uvs[iy + 1][iz], uvs[iy + 1][iz + 1],
					s00
				)


func add_return_quad(
	st: SurfaceTool,
	wall_sign: float,
	i_a: Vector3, o_a: Vector3,
	i_b: Vector3, o_b: Vector3,
	uv_a: Vector2, uv_b: Vector2,
	solid_on_neg: bool
) -> void:
	# Bridge inner→outer along the cut. Winding depends on which side is solid.
	if solid_on_neg == (wall_sign > 0.0):
		_Shell.add_tri(st, i_a, uv_a, o_a, uv_a, i_b, uv_b)
		_Shell.add_tri(st, i_b, uv_b, o_a, uv_a, o_b, uv_b)
	else:
		_Shell.add_tri(st, i_a, uv_a, i_b, uv_b, o_a, uv_a)
		_Shell.add_tri(st, i_b, uv_b, o_b, uv_b, o_a, uv_a)


func is_open(y: float, z: float) -> bool:
	return is_door_bay_open(y, z) or in_window_cut(y, z)


func is_door_bay_open(y: float, z: float) -> bool:
	return (
		y >= wall.door_y_min and y <= wall.door_y_max
		and absf(z - wall.door_center_z) <= wall.door_half_length
	)


func in_window_cut(y: float, z: float) -> bool:
	for cz in wall.window_centers_z:
		if wall.point_in_poly(Vector2(z - cz, y - wall.window_center_y), wall.WINDOW_CUT_POLY):
			return true
	return false


## Only punch a wall cell when every corner is inside the rounded cut — keeps
## liner metal under the frame lip the way the rear door panel surrounds its pane.
func cell_fully_in_window_cut(y0: float, y1: float, z0: float, z1: float) -> bool:
	return (
		in_window_cut(y0, z0)
		and in_window_cut(y0, z1)
		and in_window_cut(y1, z0)
		and in_window_cut(y1, z1)
	)


func project_window_cut_fringe(wall_sign: float, verts: Array, outer: Array, solid: Array) -> void:
	for iy in range(wall.y_segments + 1):
		for iz in range(wall.z_segments + 1):
			if solid[iy][iz]:
				continue
			if not has_solid_neighbor(solid, iy, iz):
				continue
			var y: float = verts[iy][iz].y
			var z: float = verts[iy][iz].z
			# Door-bay fringe must stay open. Snapping those verts onto the nearest
			# WindowCut stretches liner UVs from the door seam into the adjacent
			# sash — the dark blob between side door and front window.
			if is_door_bay_open(y, z):
				continue
			# nearest returns Vector2(world_y, world_z)
			var p := nearest_on_window_cut(y, z)
			var wy := p.x
			var wz := p.y
			var x: float = wall_sign * (wall._profile_x(wy) + _x_from)
			verts[iy][iz] = Vector3(x, wy, wz)
			outer[iy][iz] = Vector3(x + wall_sign * (_x_to - _x_from), wy, wz)
			solid[iy][iz] = true


func has_solid_neighbor(solid: Array, iy: int, iz: int) -> bool:
	for dy in range(-1, 2):
		for dz in range(-1, 2):
			if dy == 0 and dz == 0:
				continue
			var ny := iy + dy
			var nz := iz + dz
			if ny < 0 or nz < 0 or ny > wall.y_segments or nz > wall.z_segments:
				continue
			if solid[ny][nz]:
				return true
	return false


func nearest_on_window_cut(y: float, z: float) -> Vector2:
	## Returns Vector2(world_y, world_z) on the nearest WindowCut edge.
	var best := Vector2(y, z)
	var best_d := INF
	for cz in wall.window_centers_z:
		var local := Vector2(z - cz, y - wall.window_center_y)
		var n: int = wall.WINDOW_CUT_POLY.size()
		for i in range(n):
			var a: Vector2 = wall.WINDOW_CUT_POLY[i]
			var b: Vector2 = wall.WINDOW_CUT_POLY[(i + 1) % n]
			var ab := b - a
			var t := 0.0
			var denom := ab.dot(ab)
			if denom > 0.0000001:
				t = clampf((local - a).dot(ab) / denom, 0.0, 1.0)
			var q := a.lerp(b, t)
			var d := local.distance_squared_to(q)
			if d < best_d:
				best_d = d
				best = Vector2(wall.window_center_y + q.y, cz + q.x)
	return best
