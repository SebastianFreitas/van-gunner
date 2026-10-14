extends RefCounted
## Salvage piece 1, wall pieces: the rear-right corner post (with its pressed pocket), the kick box
## and the head panel as bevelled hard-edged prisms in one ArrayMesh, on the rear arch's outline.
## Collision hulls are collected per prism for the owner.

const _Surround := preload("res://scripts/van/rear_door_surround.gd")
const _Press := preload("res://scripts/van/look/van_salvage_piece1_press.gd")
const _Mesh := preload("res://scripts/van/look/van_salvage_piece1_mesh.gd")

const _Flange := preload("res://scripts/van/rear_door_flange.gd")
const _Ramp := preload("res://scripts/van/rear_door_ramp.gd")
const _Head := preload("res://scripts/van/look/van_salvage_piece1_head.gd")
const _Seam :=preload("res://scripts/van/look/van_salvage_piece1_seam.gd")
const _Roof := preload("res://scripts/van/look/van_salvage_piece1_roof.gd")
const _Portal := preload("res://scripts/van/rear_door_portal.gd")
const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")

## The one room-face plane of post, kick box and head panel: the arch's deep-face x, so the arch's
## slope runs straight into the piece.
const ROOM_X := VanInteriorSize.REAR_DOOR_HALF + _Surround.RAMP_OUT
const FLOOR_Y := -0.045
const FRONT_Z := 5.594
## How far the post's rear end sinks into the arch.
const SINK := 0.02
const KICK_Z0 := 4.9
const KICK_BACK_X := 3.42
const KICK_TOP := 1.0
## The ledge's inner edge (offset from the opening) and, 2 cm inside it, the plan outline where the
## post's rear end steps from the deep face to the ledge: x of its flat side below ARC_Y and its
## corner arc about (ARC_CX, ARC_Y). The step face is never coplanar with the ledge's own side.
const RING_O := _Flange.WALL_OFFSET + _Surround.RING_W + _Surround.BEVEL - SINK
const RING_X := VanInteriorSize.REAR_DOOR_HALF + RING_O
const ARC_Y := VanInteriorSize.REAR_DOOR_TOP - _Flange.RADIUS_TOP
const ARC_CX := VanInteriorSize.REAR_DOOR_HALF - _Flange.RADIUS_TOP
const RING_R := _Flange.RADIUS_TOP + RING_O
## The room face above ARC_Y follows the deep face's corner arc (the opening's radius plus RAMP_OUT).
const ARC_R := _Flange.RADIUS_TOP + _Surround.RAMP_OUT
const POCKET_Y0 := _Surround.POCKET_Y0
const POCKET_Y1 := _Surround.POCKET_Y1
const BACK_PAD := 0.03
const SAMPLE_YS := [1.65, 1.95, 2.2, 2.5, 2.8, 3.1, 3.3]
## Axis maps: xy outlines extruded along z, xz outlines extruded along y.
const XY_Z := Basis.IDENTITY
const XZ_Y := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))

## One convex hull point set per prism, for the owner's collision shapes.
var hulls: Array[PackedVector3Array] = []

## Rear ends of the post: inside the ring outline (the arch's deep face) and beyond it (the ledge),
## each sunk SINK into the arch; set from the +x hinge's z by `build_walls`.
var rear_in_z := 0.0
var rear_out_z := 0.0
## The pressed pocket's z range, from the arch's deep face.
var pocket_z0 := 0.0
var pocket_z1 := 0.0
## The room face's fillet into the arch's round, rows F4, F2, F1, F0 as (x, z) on the straight side,
## and each row's normal as (offset, z) components (the arch's own, F4 its profile normal).
var fil_pts := PackedVector2Array()
var fil_n := PackedVector2Array()
## The upper post's room-face polyline (head arc top down to the flat face), for the seam.
var _room_line := PackedVector2Array()
## Head panel outline: nose, base, top corner, then the arc from the top down to the slope's corner.
var head_outline := PackedVector2Array()
## The ring's outer-arc angles, shared by the head arc and the ring clip.
var _ring_angles := PackedFloat32Array()

## The emitters (SurfaceTool, quads, prisms) the builder and its pressing share.
var mesh := _Mesh.new()


func build_walls(profile: VanBodyProfile, hinge_z: float) -> ArrayMesh:
	var z_deep := hinge_z + _Ramp.z_deep_rel()
	rear_in_z = z_deep + SINK
	rear_out_z = z_deep + _Surround.DEPTH - _Surround.LEDGE_DEPTH + SINK
	pocket_z1 = z_deep - _Surround.RAMP_OUT
	pocket_z0 = pocket_z1 - _Surround.POCKET_X1 - SINK
	_fillet_rows(z_deep)
	# The deep face's own +x arc (top down to the flat face), so the room face is the arch's.
	var open := _Surround._opening(VanInteriorSize.REAR_DOOR_HALF, VanInteriorSize.REAR_DOOR_TOP,
			_Surround.RAMP_OUT)
	var arc := open.slice(_Flange.ARC_STEPS + 2, 2 * _Flange.ARC_STEPS + 3)
	# The top runs on along the ring's outer arc up to its top, then drops to the room face's arc top.
	var a_s := asin((arc[0].y - ARC_Y) / RING_R)
	_ring_angles = _Head.angles(a_s)
	head_outline = _Head.outline(arc, _back_x(profile, arc[0].y), _ring_angles, a_s,
			Vector2(ARC_CX, ARC_Y), RING_R)
	hulls.clear()
	mesh.begin()
	var bev := _Surround.BEVEL
	var steps := _Surround.BEVEL_STEPS
	var back :=profile.inner_x_at(0.5) + BACK_PAD
	var press := _Press.new(self)
	# Lower post: one continuous loft through (y, pocket depth) levels, so no layer shares a face.
	var y_b := POCKET_Y0 - bev
	var levels: Array = [[FLOOR_Y, 0.0], [y_b, 0.0]]
	for k in range(1, steps + 1):
		var t := float(k) / float(steps)
		levels.append([y_b + bev * t, bev * (1.0 - sqrt(1.0 - t * t))])
	levels.append([POCKET_Y0, _Surround.POCKET_DEPTH])
	levels.append([POCKET_Y1, _Surround.POCKET_DEPTH])
	for k in range(steps + 1):
		var t2 := 1.0 - float(k) / float(steps)
		levels.append([POCKET_Y1 + bev * float(k) / float(steps),
				bev * (1.0 - sqrt(1.0 - t2 * t2))])
	_loft(levels, back)
	var y_top := POCKET_Y1 + bev
	hulls.append(_hull(_xz(back, 0.0), XZ_Y, FLOOR_Y, y_top))
	mesh.skip = _on_room
	_upper_post(profile, y_top)
	# Kick box and head panel, abutting the post's front face; forward edges bevelled.
	var kick := PackedVector2Array([Vector2(ROOM_X, FLOOR_Y), Vector2(KICK_BACK_X, FLOOR_Y),
			Vector2(KICK_BACK_X, KICK_TOP), Vector2(ROOM_X, KICK_TOP)])
	mesh.solid(_round(kick, [3], bev, steps), XY_Z, KICK_Z0, FRONT_Z, true, false)
	hulls.append(_hull(kick, XY_Z, KICK_Z0, FRONT_Z))
	var head := head_outline
	var rounded := _round(head, [head.size() - 1, 1], bev, steps)
	var filleted := _Roof.split(press.fillet(rounded, 0))
	mesh.skip = press.on_slope
	# The back cap sinks SINK into the post, so no cap is coplanar with the post's front cap.
	mesh.solid(filleted, XY_Z, KICK_Z0, FRONT_Z + SINK, false, false)
	mesh.skip = Callable()
	hulls.append(_hull(head, XY_Z, KICK_Z0, FRONT_Z + SINK))
	press.press_faces(y_b, y_top, filleted[0], rounded[rounded.size() - 1])
	_Roof.new().build(self, filleted, profile)
	return mesh.st.commit()


## Fills fil_pts and fil_n: the arch's own _round at the deep face's corner (reversed, so it starts
## on the room face), its last row being the arch's t1 row with the arch's normal.
func _fillet_rows(z_deep: float) -> void:
	var z_in := z_deep - _Ramp.z_deep_rel() + _LeafBuild.CABIN_Z
	var prof := _Ramp._profile(z_in, z_deep, z_deep + _Surround.DEPTH - _Surround.LEDGE_DEPTH)
	var pn := _Ramp._profile_normals(prof)
	var c1 := Vector2(_Surround.RAMP_OUT, z_deep)
	var f := _Ramp._round(Vector2(_Surround.RAMP_OUT, z_deep - 1.0), c1, prof[0])
	f[4] = prof[1]
	fil_pts.clear()
	fil_n.clear()
	for k: int in [4, 2, 1, 0]:
		var t := float(k) / 4.0
		var tg := 2.0 * (1.0 - t) * (c1 - f[0]) + 2.0 * t * (f[4] - c1)
		var n := Vector2(-tg.y, tg.x).normalized()
		fil_pts.append(Vector2(VanInteriorSize.REAR_DOOR_HALF + f[k].x, f[k].y))
		fil_n.append(pn[1] if k == 4 else (Vector2(-1.0, 0.0) if k == 0 else n))


## True when every point lies on the room-face plane (a flat quad the sheets replace).
func _on_room(pts: Array) -> bool:
	return pts.all(func(p: Vector3) -> bool: return absf(p.x - ROOM_X) < 0.0001)


## True when the quad's first edge runs between two points of the room polyline.
func _on_line(pts: Array) -> bool:
	var hits := 0
	for k in 2:
		var p: Vector3 = pts[k]
		for q in _room_line:
			if q.distance_to(Vector2(p.x, p.y)) < 0.0005:
				hits += 1
				break
	return hits == 2


## A point on the corner arc about (ARC_CX, ARC_Y) at radius `r` and angle `a`.
func _arc_pt(r: float, a: float) -> Vector2:
	return Vector2(ARC_CX + r * cos(a), ARC_Y + r * sin(a))


## The upper post's back x at height `y`: the live wall plus the portal ledge's side pad and SINK,
## so the back stays 2 cm out of the ledge side face's plane.
func _back_x(profile: VanBodyProfile, y: float) -> float:
	return profile.inner_x_at(y) + _Portal.SIDE_PAD + SINK


## Post above the pocket: back follows the live wall profile, rear face on the ring's deep
## part inside the ring outline and on the ledge outside it.
func _upper_post(profile: VanBodyProfile, y0: float) -> void:
	var post := PackedVector2Array([Vector2(ROOM_X, y0),
			Vector2(_back_x(profile, y0), y0)])
	for y: float in SAMPLE_YS:
		post.append(Vector2(_back_x(profile, y), y))
	post.append(head_outline[2])
	# The room face above ARC_Y: the head panel's arc vertices and the point where its bevel ends,
	# so the shared edge has no T-junction, then on down the arc to where the flat face begins.
	var n := head_outline.size()
	var top_end := n - (_Flange.ARC_STEPS + 1)
	for i in range(3, top_end):
		post.append(head_outline[i])
	var line_from := post.size()
	for i in range(top_end, n - 1):
		post.append(head_outline[i])
	var corner := head_outline[n - 1]
	var prev := head_outline[n - 2]
	post.append(corner + (prev - corner).normalized() * minf(_Surround.BEVEL, prev.distance_to(corner) * 0.5))
	post.append(corner)
	_room_line = post.slice(line_from)
	_room_line.append(Vector2(ROOM_X, y0))
	var ring := PackedVector2Array([Vector2(2.0, 1.0), Vector2(RING_X, 1.0),
			Vector2(RING_X, ARC_Y)])
	for a in _ring_angles:
		ring.append(_arc_pt(RING_R, a))
	ring.append(Vector2(_Head.TAB_X, ARC_Y + RING_R))
	# Inside the ring the room polyline (arc quads too) is the seam's: it fillets into the arch.
	# The top quad ending at the line's head[3] end is the seam's too: it splits at the rows' vertices.
	var top: Array = []
	mesh.skip = func(pts: Array) -> bool:
		if _on_line(pts):
			return true
		for k in 2:
			var p: Vector3 = pts[k]
			if Vector2(p.x, p.y).distance_to(_room_line[0]) < 0.0005 and top.is_empty():
				top.assign(pts)
				return true
		return false
	for p in Geometry2D.intersect_polygons(post, ring):
		mesh.solid(p, XY_Z, FRONT_Z, rear_in_z, false, false)
		hulls.append(_hull(p, XY_Z, FRONT_Z, rear_in_z))
	_Seam.new(self).build(_room_line, top)
	mesh.skip = _on_room
	for p in Geometry2D.clip_polygons(post, ring):
		mesh.solid(p, XY_Z, FRONT_Z, rear_out_z, false, false)
		hulls.append(_hull(p, XY_Z, FRONT_Z, rear_out_z))


## xz outline of the lower post; `depth` > 0 stamps the pocket into the room face.
func _xz(back: float, depth: float, full := false) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(ROOM_X, FRONT_Z), Vector2(back, FRONT_Z),
			Vector2(back, rear_out_z), Vector2(RING_X, rear_out_z), Vector2(RING_X, rear_in_z)])
	if depth <= 0.0 and not full:
		pts.append(Vector2(ROOM_X, rear_in_z))
		return pts
	pts.append_array(fil_pts)
	pts.append_array(PackedVector2Array([Vector2(ROOM_X, pocket_z1),
			Vector2(ROOM_X + depth, pocket_z1), Vector2(ROOM_X + depth, pocket_z0),
			Vector2(ROOM_X, pocket_z0)]))
	return _round(pts, [12, 9], minf(_Surround.BEVEL, depth), _Surround.BEVEL_STEPS)


## Lofts the lower post's xz outline through `levels` ([y, pocket depth]); the caps use the plain
## outline and the sides keep the pocket's vertex count at every level.
func _loft(levels: Array, back: float) -> void:
	var flat := _xz(back, 0.0)
	for end in 2:
		var y: float = levels[0][0] if end == 0 else levels[levels.size() - 1][0]
		var idx := Geometry2D.triangulate_polygon(flat)
		var cap_n := Vector3(0, -1 if end == 0 else 1, 0)
		for i in range(0, idx.size(), 3):
			mesh.tri(mesh.pt(XZ_Y, flat[idx[i]], y), mesh.pt(XZ_Y, flat[idx[i + 1]], y),
					mesh.pt(XZ_Y, flat[idx[i + 2]], y), cap_n)
	for r in range(levels.size() - 1):
		var pa := _xz(back, levels[r][1], true)
		var pb := _xz(back, levels[r + 1][1], true)
		for i in pa.size():
			var j := (i + 1) % pa.size()
			var a0 := mesh.pt(XZ_Y, pa[i], levels[r][0])
			var b0 := mesh.pt(XZ_Y, pa[j], levels[r][0])
			var b1 := mesh.pt(XZ_Y, pb[j], levels[r + 1][0])
			var a1 := mesh.pt(XZ_Y, pb[i], levels[r + 1][0])
			# The fillet strips (polygon indices 5..8) carry the arch's own normals.
			if i >= 5 and i <= 7:
				var ni := Vector3(fil_n[i - 5].x, 0.0, fil_n[i - 5].y)
				var nj := Vector3(fil_n[j - 5].x, 0.0, fil_n[j - 5].y)
				mesh.tri_n(a0, b0, b1, ni, nj, nj)
				mesh.tri_n(a0, b1, a1, ni, nj, ni)
				continue
			for t: Array in [[a0, b0, b1], [a0, b1, a1]]:
				if r == 0 and _on_room(t):
					continue
				var n: Vector3 = -(t[1] - t[0]).cross(t[2] - t[0])
				if n.length() > 0.000001:
					mesh.tri(t[0], t[1], t[2], n.normalized())


## Hull points of an outline extruded between w0 and w1 (unbevelled).
func _hull(poly: PackedVector2Array, m: Basis, w0: float, w1: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for p in poly:
		pts.append(m * Vector3(p.x, p.y, w0))
		pts.append(m * Vector3(p.x, p.y, w1))
	return pts


## Replaces each convex corner in `idx` (descending) with a quadratic arc of up to `r`.
func _round(poly: PackedVector2Array, idx: Array, r: float, steps: int) -> PackedVector2Array:
	var out := poly
	for i: int in idx:
		var n := out.size()
		var p := out[i]
		var a := out[(i + n - 1) % n]
		var b := out[(i + 1) % n]
		var s := p + (a - p).normalized() * minf(r, a.distance_to(p) * 0.5)
		var e := p + (b - p).normalized() * minf(r, b.distance_to(p) * 0.5)
		var arc := PackedVector2Array()
		for k in range(steps + 1):
			var t := float(k) / float(steps)
			arc.append(s * (1.0 - t) * (1.0 - t) + p * 2.0 * t * (1.0 - t) + e * t * t)
		var next := PackedVector2Array()
		next.append_array(out.slice(0, i))
		next.append_array(arc)
		next.append_array(out.slice(i + 1))
		out = next
	return out
