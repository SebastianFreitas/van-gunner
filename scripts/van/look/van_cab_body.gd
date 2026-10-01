extends RefCounted
## One closed cab body lofted from VanBodyProfile's section: a vertical lower face, a raked
## windshield face with its glass in a sealed pocket, bevelled front corners and a dark back cap,
## as one watertight mesh.

const _SKIN := 0
const _GLASS := 1
const _CAP := 2
## UV modes: metre UVs from two axes (the exterior shader needs them for its normal map).
const _UV_ZY := 0
const _UV_XY := 1
const _UV_XZ := 2
const _UV_NONE := -1
const _FLAT := -1
const _SMOOTH := 0

var _cab: VanCab


func _init(cab: VanCab) -> void:
	_cab = cab


func build(mat: Material) -> void:
	if _cab.profile == null:
		push_warning("VanCabBody: no body profile")
		return
	var outline := _cab.profile.section_points(VanCab.SECTION_STEPS, true)
	if outline.size() < 4:
		push_warning("VanCabBody: body outline has %d points" % outline.size())
		return
	outline[0] = Vector2(outline[0].x, VanCab.BASE_Y)
	outline[1] = Vector2(outline[1].x, VanCab.BASE_Y)
	var belts := _insert_belt(outline)
	var ib_r: int = belts.x
	var ib_l: int = belts.y
	if ib_r < 0 or ib_l < 0:
		push_warning("VanCabBody: no belt points on the outline")
		return

	var inner := _inset_ring(outline)
	var back: Array[Vector3] = []
	var rim: Array[Vector3] = []
	var face: Array[Vector3] = []
	for i in range(outline.size()):
		back.append(Vector3(outline[i].x, outline[i].y, VanCab.BODY_BACK_Z))
		rim.append(Vector3(outline[i].x, outline[i].y,
				VanCab.front_z_at(outline[i].y) + VanCab.CHAMFER))
		face.append(Vector3(inner[i].x, inner[i].y, VanCab.front_z_at(inner[i].y)))

	var skin := SurfaceTool.new()
	skin.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(skin, back, rim)
	_bevel_band(skin, rim, face)
	_lower_face(skin, face, inner, ib_r, ib_l)
	_upper_face(skin, face, inner, ib_r, ib_l)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_pocket(skin, glass)
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	_back_cap(cap, back, outline)

	skin.generate_normals()
	skin.generate_tangents()
	glass.generate_normals()
	cap.generate_normals()
	var mesh := skin.commit()
	glass.commit(mesh)
	cap.commit(mesh)
	mesh.surface_set_material(_SKIN, mat)
	mesh.surface_set_material(_GLASS, VanCab._dark_material(Color(0.015, 0.018, 0.02), 0.3))
	mesh.surface_set_material(_CAP, VanCab._dark_material(Color(0.03, 0.03, 0.03), 0.9))
	_cab._add_mesh("CabBody", mesh, null)


## Adds the belt points on both sides, or snaps a point already within 1 cm of the belt.
## Returns Vector2i(right index, left index), -1 where none was found.
func _insert_belt(outline: PackedVector2Array) -> Vector2i:
	var belt_y := VanCab.BELT_Y
	var bx := _cab.profile.outer_x_at(belt_y)
	var ib_r := -1
	for i in range(1, outline.size() - 1):
		if absf(outline[i].y - belt_y) < 0.01:
			outline[i] = Vector2(bx, belt_y)
			ib_r = i
			break
		if outline[i].y < belt_y and outline[i + 1].y > belt_y:
			outline.insert(i + 1, Vector2(bx, belt_y))
			ib_r = i + 1
			break
	var ib_l := -1
	for i in range(outline.size() - 1, 1, -1):
		if absf(outline[i].y - belt_y) < 0.01:
			outline[i] = Vector2(-bx, belt_y)
			ib_l = i
			break
		if outline[i].y < belt_y and outline[i - 1].y > belt_y:
			outline.insert(i, Vector2(-bx, belt_y))
			ib_l = i
			break
	return Vector2i(ib_r, ib_l)


## The face ring: the outline pulled in along its vertex normals by the bevel, bottom points
## only sideways (the bottom edge is not bevelled).
func _inset_ring(outline: PackedVector2Array) -> PackedVector2Array:
	var n := outline.size()
	var inner := PackedVector2Array()
	for i in range(n):
		if i < 2:
			inner.append(Vector2(outline[i].x - signf(outline[i].x) * VanCab.CHAMFER,
					VanCab.BASE_Y))
			continue
		var prev := outline[(i - 1 + n) % n]
		var next := outline[(i + 1) % n]
		var d0 := outline[i] - prev
		var d1 := next - outline[i]
		var n0 := Vector2(d0.y, -d0.x).normalized()
		var n1 := Vector2(d1.y, -d1.x).normalized()
		inner.append(outline[i] - (n0 + n1).normalized() * VanCab.CHAMFER)
	return inner


## The side and roof loft from the back ring to the bevel's outer ring.
func _loft(st: SurfaceTool, back: Array[Vector3], rim: Array[Vector3]) -> void:
	var n := back.size()
	for i in range(n):
		var j := (i + 1) % n
		var mid_z := (VanCab.BODY_BACK_Z + rim[i].z + rim[j].z) / 3.0
		var group := _FLAT if i == 0 else _SMOOTH
		_quad(st, back[i], back[j], rim[j], rim[i], Vector3(0.0, 1.5, mid_z),
				_UV_XZ if i == 0 else _UV_ZY, group)


func _bevel_band(st: SurfaceTool, rim: Array[Vector3], face: Array[Vector3]) -> void:
	var n := rim.size()
	var inside := Vector3(0.0, 1.5, VanCab.NOSE_Z + 1.5)
	for i in range(n):
		var j := (i + 1) % n
		var mode := _UV_XZ if i == 0 else _UV_ZY
		_quad(st, rim[i], rim[j], face[j], face[i], inside, mode, _FLAT)


## The vertical lower face (plane z = NOSE_Z): left belt point, down the left side, across the
## bottom and up to the right belt point.
func _lower_face(st: SurfaceTool, face: Array[Vector3], inner: PackedVector2Array, ib_r: int,
		ib_l: int) -> void:
	var idx: Array[int] = []
	for i in range(ib_l, face.size()):
		idx.append(i)
	for i in range(0, ib_r + 1):
		idx.append(i)
	var pts := PackedVector2Array()
	for i in idx:
		pts.append(inner[i])
	var tris := Geometry2D.triangulate_polygon(pts)
	if tris.is_empty():
		push_warning("VanCabBody: lower face did not triangulate")
		return
	var inside := Vector3(0.0, 1.0, VanCab.NOSE_Z + 1.0)
	for k in range(0, tris.size(), 3):
		_tri(st, face[idx[tris[k]]], face[idx[tris[k + 1]]], face[idx[tris[k + 2]]], inside,
				_UV_XY, _FLAT)


## The raked face above the belt with the windshield hole, zipped between the outer loop and
## the window loop by angle around the window centre.
func _upper_face(st: SurfaceTool, face: Array[Vector3], inner: PackedVector2Array, ib_r: int,
		ib_l: int) -> void:
	var outer_loop: Array[Vector3] = []
	var outer_2d := PackedVector2Array()
	for i in range(ib_r, ib_l + 1):
		outer_loop.append(face[i])
		outer_2d.append(inner[i])
	var win := _window_corners(false)
	var win_2d := PackedVector2Array()
	for p in win:
		win_2d.append(Vector2(p.x, p.y))
	var shrunk := Geometry2D.offset_polygon(outer_2d, -0.1)
	for p in win_2d:
		var inside_ok := false
		for poly in shrunk:
			if Geometry2D.is_point_in_polygon(p, poly):
				inside_ok = true
		if not inside_ok:
			push_warning("VanCabBody: window corner %s is within 10 cm of the face edge" % p)

	var centre := Vector2(0.0, (VanCab.WS_BOT_Y + VanCab.WS_TOP_Y) * 0.5)
	var ru := _from_min_angle(outer_loop, centre)
	var rw := _from_min_angle(win, centre)
	var au: Array[float] = []
	var aw: Array[float] = []
	for p in ru:
		au.append(_angle(p, centre))
	for p in rw:
		aw.append(_angle(p, centre))
	au.append(au[0] + TAU)
	aw.append(aw[0] + TAU)
	var inside := Vector3(0.0, 2.4, VanCab.NOSE_Z + 1.5)
	var i := 0
	var j := 0
	while i < ru.size() or j < rw.size():
		var next_u := au[i + 1] if i < ru.size() else INF
		var next_w := aw[j + 1] if j < rw.size() else INF
		var uc := ru[i % ru.size()]
		var wc := rw[j % rw.size()]
		var third: Vector3
		if next_u <= next_w:
			i += 1
			third = ru[i % ru.size()]
		else:
			j += 1
			third = rw[j % rw.size()]
		if (wc - uc).cross(third - uc).length() * 0.5 < 1e-6:
			continue
		_tri(st, uc, wc, third, inside, _UV_XY, _FLAT)


## The windshield corners, counter-clockwise from bottom-left, on the raked plane or (back)
## at the bottom of the pocket.
func _window_corners(back: bool) -> Array[Vector3]:
	var depth := VanCab.WS_REVEAL if back else 0.0
	var hw := VanCab.WS_HALF_W
	var out: Array[Vector3] = []
	for c: Vector2 in [Vector2(-hw, VanCab.WS_BOT_Y), Vector2(hw, VanCab.WS_BOT_Y),
			Vector2(hw, VanCab.WS_TOP_Y), Vector2(-hw, VanCab.WS_TOP_Y)]:
		out.append(Vector3(c.x, c.y, VanCab.front_z_at(c.y) + depth))
	return out


## Four pocket walls in the skin, and the dark glass as the pocket's bottom.
func _pocket(skin: SurfaceTool, glass: SurfaceTool) -> void:
	var front := _window_corners(false)
	var bottom := _window_corners(true)
	var mid_y := (VanCab.WS_BOT_Y + VanCab.WS_TOP_Y) * 0.5
	var centre := Vector3(0.0, mid_y, VanCab.front_z_at(mid_y))
	for k in range(4):
		var m := (k + 1) % 4
		_quad(skin, front[k], front[m], bottom[m], bottom[k], centre, _UV_XY, _FLAT, true)
	_quad(glass, bottom[0], bottom[1], bottom[2], bottom[3],
			Vector3(0.0, 2.4, VanCab.NOSE_Z + 1.5), _UV_NONE, _FLAT)


func _back_cap(st: SurfaceTool, back: Array[Vector3], outline: PackedVector2Array) -> void:
	var tris := Geometry2D.triangulate_polygon(outline)
	if tris.is_empty():
		push_warning("VanCabBody: back cap did not triangulate")
		return
	var inside := Vector3(0.0, 1.5, VanCab.BODY_BACK_Z - 1.0)
	for k in range(0, tris.size(), 3):
		_tri(st, back[tris[k]], back[tris[k + 1]], back[tris[k + 2]], inside, _UV_NONE, _FLAT)


## The loop rotated to start at its smallest angle around the centre.
func _from_min_angle(loop: Array[Vector3], centre: Vector2) -> Array[Vector3]:
	var start := 0
	for i in range(loop.size()):
		if _angle(loop[i], centre) < _angle(loop[start], centre):
			start = i
	var out: Array[Vector3] = []
	for i in range(loop.size()):
		out.append(loop[(start + i) % loop.size()])
	return out


## Angle around the centre, counter-clockwise from the -x axis, in [0, TAU).
func _angle(p: Vector3, centre: Vector2) -> float:
	return fposmod(atan2(p.y - centre.y, p.x - centre.x) + PI, TAU)


func _vertex(st: SurfaceTool, p: Vector3, uv_mode: int, group: int) -> void:
	st.set_smooth_group(group)
	if uv_mode == _UV_ZY:
		st.set_uv(Vector2(p.z, p.y))
	elif uv_mode == _UV_XY:
		st.set_uv(Vector2(p.x, p.y))
	elif uv_mode == _UV_XZ:
		st.set_uv(Vector2(p.x, p.z))
	st.add_vertex(p)


## One triangle wound to face away from the inside reference (toward it when inward).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, uv_mode: int,
		group: int, inward: bool = false) -> void:
	var facing := (b - a).cross(c - a).normalized().dot(((a + b + c) / 3.0 - inside).normalized())
	if inward:
		facing = -facing
	if facing < 0.0:
		_vertex(st, a, uv_mode, group)
		_vertex(st, c, uv_mode, group)
		_vertex(st, b, uv_mode, group)
	else:
		_vertex(st, a, uv_mode, group)
		_vertex(st, b, uv_mode, group)
		_vertex(st, c, uv_mode, group)


## One quad (two triangles sharing the a-c diagonal) wound like _tri.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3,
		uv_mode: int, group: int, inward: bool = false) -> void:
	var facing := (b - a).cross(c - a).normalized().dot(
			((a + b + c + d) * 0.25 - inside).normalized())
	if inward:
		facing = -facing
	var order: Array[Vector3] = [a, b, c, a, c, d]
	if facing < 0.0:
		order = [a, d, c, a, c, b]
	for p in order:
		_vertex(st, p, uv_mode, group)
