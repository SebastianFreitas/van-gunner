extends RefCounted
## Rear door portal: lays the hinges, window parts and collision out from VanInteriorSize, and
## builds the pressed-steel pillars and header around the smaller door opening.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Flange := preload("res://scripts/van/rear_door_flange.gd")
const WALL_MATERIAL := "res://scenes/van/van_wall_material.tres"
const RAIL_W := 0.25
const HANDLE_INSET := 0.11
## Past the liner on every side, so the steel never leaves a gap against the walls or the vault.
const SIDE_PAD := 0.03
## Header holes: x centre as a share of the half width, half width, half height, and the
## squareness exponent (2 is an oval, 4 a rounded slot).
const HEADER_HOLES: Array[Vector4] = [
	Vector4(-0.62, 0.26, 0.17, 2.0), Vector4(0.3, 0.16, 0.17, 4.0),
	Vector4(0.68, 0.22, 0.17, 2.0),
]
## Pillar holes (right pillar, mirrored for the left): x centre as an offset from the door
## edge, y centre, half width, half height. Blind, cut from the cabin side.
const PILLAR_HOLES: Array[Vector4] = [
	Vector4(0.3, 0.45, 0.13, 0.13), Vector4(0.3, 1.95, 0.12, 0.22), Vector4(0.3, 2.65, 0.12, 0.12),
]
## Squareness exponent per pillar hole (2 oval, 4 rounded slot).
const PILLAR_SQUARE: Array[float] = [2.0, 4.0, 2.0]
## Extra width of a hole's column, so the solid strips beside it stay clear of the rim.
const COLUMN_MARGIN := 0.03
## Pillar pocket: y range, and its inset from the door edge and the wall.
const POCKET_Y0 := 1.0
const POCKET_Y1 := 1.6
const POCKET_INSET := 0.12
const BEAD_R := 0.035


static func build(doors: Node3D, left: Node3D, right: Node3D) -> void:
	_layout(doors, left, -1.0)
	_layout(doors, right, 1.0)
	_blocker(doors)
	var old := doors.get_node_or_null("Portal")
	if old:
		old.free()
	var portal := Node3D.new()
	portal.name = "Portal"
	doors.add_child(portal)
	var mat := load(WALL_MATERIAL) as Material
	var profile := VanBodyProfile.from_interior(doors.get_parent())
	var half := VanInteriorSize.REAR_DOOR_HALF
	var top := VanInteriorSize.REAR_DOOR_TOP
	var lz := left.position.z
	var d := _LeafBuild.STREET_HALF * 2.0
	# Shifted cabin-side so the steel's street face stays 1+ cm behind the skin ring (6.66).
	var z := lz - 0.05
	# 2 cm deeper each side than a leaf, so the steel never shares a face plane with it.
	var pd := d + 0.04
	var z0 := z - pd * 0.5
	var z1 := z + pd * 0.5
	var y_a := _LeafBuild.Y_MIN
	# The back compartment's own outline (wall lean, rounded roof corner, crown), padded.
	var section: PackedVector2Array = Geometry2D.offset_polygon(
			profile.section_points(48), SIDE_PAD)[0]
	_header(portal, mat, section, half, top, z0, z1)
	_Flange.build(portal, mat, half, top, y_a, z0)
	# Pillars: one continuous section each, a recessed pocket stamped in the cabin-side half.
	var pocket_x1 := profile.inner_x_at(POCKET_Y1) + SIDE_PAD - POCKET_INSET
	for s: float in [-1.0, 1.0]:
		var pillar: PackedVector2Array = Geometry2D.intersect_polygons(
				section, _rect(half + 0.02, 9.0, y_a, top))[0]
		var cuts: Array[PackedVector2Array] = [
			_rect(-9.0, 9.0, y_a, POCKET_Y0), _rect(-9.0, 9.0, POCKET_Y1, top),
			_rect(-9.0, half + POCKET_INSET, POCKET_Y0, POCKET_Y1),
			_rect(pocket_x1, 9.0, POCKET_Y0, POCKET_Y1),
		]
		for r in cuts:
			for p in Geometry2D.intersect_polygons(pillar, r):
				_punch(portal, mat, p, 0, s, z0, z)
		_prism(portal, mat, _flip(pillar, s), z, z1)
		for plate in _Flange.corner_plates(half, top, y_a):
			_prism(portal, mat, _flip(plate, s), lz + _Flange.PLATE_Z0, lz + _Flange.PLATE_Z1)
		# Rounds the opening's street side too, so an open leaf shows no square corner. Stops 3 cm
		# short of the street face so it stays 2 cm clear of the closed leaf's skin.
		for fill in _Flange.opening_fills(half, top, y_a):
			_prism(portal, mat, _flip(fill, s), z0 + 0.05, z1 - 0.07)
		_bead(portal, mat, Vector3(s * (half + BEAD_R), (top + y_a) * 0.5, z0), top - y_a, false)
	_bead(portal, mat, Vector3(0, top + 0.01 + BEAD_R, z0), half * 2.0 + BEAD_R * 2.0, true)
	# Centre latch box on the cabin side of the header.
	_box(portal, mat, Vector3(0, top + 0.42, z0 - 0.04), Vector3(0.44, 0.36, 0.08))
	_box(portal, mat, Vector3(0, top + 0.42, z0 - 0.09), Vector3(0.12, 0.2, 0.03))


## The header: the outline above the opening, cut by oval and slot holes, top following the vault.
static func _header(portal: Node3D, mat: Material, section: PackedVector2Array, half: float,
		top: float, z0: float, z1: float) -> void:
	var y0 := top + 0.01
	var header: PackedVector2Array = Geometry2D.intersect_polygons(
			section, _rect(-9.0, 9.0, y0, 9.0))[0]
	var cy := top + 0.42
	var prev := -9.0
	for h in HEADER_HOLES:
		var cx := h.x * half
		var xa := cx - h.y - COLUMN_MARGIN
		var xb := cx + h.y + COLUMN_MARGIN
		for p in Geometry2D.intersect_polygons(header, _rect(prev, xa, y0, 9.0)):
			_prism(portal, mat, p, z0, z1)
		var oval := _ellipse(cx, cy, h.y, h.z, h.w)
		# Blind: a 2 cm floor on the street side, so the holes never open onto the street.
		_prism(portal, mat, oval, z1 - 0.02, z1)
		for p in Geometry2D.clip_polygons(_rect(xa, xb, y0, cy), oval):
			_prism(portal, mat, p, z0, z1)
		for u in Geometry2D.intersect_polygons(header, _rect(xa, xb, cy, 9.0)):
			for p in Geometry2D.clip_polygons(u, oval):
				_prism(portal, mat, p, z0, z1)
		prev = xb
	for p in Geometry2D.intersect_polygons(header, _rect(prev, 9.0, y0, 9.0)):
		_prism(portal, mat, p, z0, z1)


## Extrudes `region` (right pillar coordinates) minus the pillar holes from `i` on, mirrored by `s`.
## Each hole splits the region into side strips and a column, as the header does, so no piece
## ever has a hole inside it.
static func _punch(portal: Node3D, mat: Material, region: PackedVector2Array, i: int, s: float,
		za: float, zb: float) -> void:
	if i >= PILLAR_HOLES.size():
		_prism(portal, mat, _flip(region, s), za, zb)
		return
	var h := PILLAR_HOLES[i]
	var cx := VanInteriorSize.REAR_DOOR_HALF + h.x
	var xa := cx - h.z - COLUMN_MARGIN
	var xb := cx + h.z + COLUMN_MARGIN
	var oval := _ellipse(cx, h.y, h.z, h.w, PILLAR_SQUARE[i])
	var pieces: Array[PackedVector2Array] = []
	pieces.append_array(Geometry2D.intersect_polygons(region, _rect(-9.0, xa, -9.0, 9.0)))
	pieces.append_array(Geometry2D.intersect_polygons(region, _rect(xb, 9.0, -9.0, 9.0)))
	for u in Geometry2D.intersect_polygons(region, _rect(xa, xb, -9.0, h.y)):
		pieces.append_array(Geometry2D.clip_polygons(u, oval))
	for u in Geometry2D.intersect_polygons(region, _rect(xa, xb, h.y, 9.0)):
		pieces.append_array(Geometry2D.clip_polygons(u, oval))
	for p in pieces:
		_punch(portal, mat, p, i + 1, s, za, zb)


static func _rect(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## Mirrors a polygon to the left pillar when `s` is negative.
static func _flip(poly: PackedVector2Array, s: float) -> PackedVector2Array:
	if s > 0.0:
		return poly
	var out := PackedVector2Array()
	for p in poly:
		out.append(Vector2(-p.x, p.y))
	return out


static func _ellipse(cx: float, cy: float, hw: float, hh: float, n: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 32
	for k in range(steps):
		var t := TAU * float(k) / float(steps)
		var c := cos(t)
		var sn := sin(t)
		pts.append(Vector2(cx + hw * signf(c) * pow(absf(c), 2.0 / n),
				cy + hh * signf(sn) * pow(absf(sn), 2.0 / n)))
	return pts


## Extrudes a 2D outline along z from `za` to `zb`, wound clockwise from outside.
static func _prism(parent: Node3D, mat: Material, poly: PackedVector2Array, za: float,
		zb: float) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return
	var area := 0.0
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, idx.size(), 3):
		var p0 := poly[idx[i]]
		var p1 := poly[idx[i + 1]]
		var p2 := poly[idx[i + 2]]
		_tri(st, Vector3(p0.x, p0.y, za), Vector3(p1.x, p1.y, za), Vector3(p2.x, p2.y, za),
				Vector3(0, 0, -1))
		_tri(st, Vector3(p0.x, p0.y, zb), Vector3(p1.x, p1.y, zb), Vector3(p2.x, p2.y, zb),
				Vector3(0, 0, 1))
	for i in range(poly.size()):
		var a2 := poly[i]
		var b2 := poly[(i + 1) % poly.size()]
		var e := b2 - a2
		if e.length() < 0.0001:
			continue
		var n2 := Vector2(e.y, -e.x) if area > 0.0 else Vector2(-e.y, e.x)
		var out := Vector3(n2.x, n2.y, 0.0).normalized()
		var a0 := Vector3(a2.x, a2.y, za)
		var b0 := Vector3(b2.x, b2.y, za)
		var b1 := Vector3(b2.x, b2.y, zb)
		var a1 := Vector3(a2.x, a2.y, zb)
		_tri(st, a0, b0, b1, out)
		_tri(st, a0, b1, a1, out)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	parent.add_child(m)


## One flat triangle; swapped when needed so it is clockwise seen from `out` (Godot's front).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var v: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(out) > 0.0:
		v = [a, c, b]
	for p in v:
		st.set_normal(out)
		st.set_uv(Vector2(p.x / VanInteriorSize.LENGTH + 0.5, p.y / VanInteriorSize.WALL_HEIGHT))
		st.add_vertex(p)


## A rolled edge: a round bead, vertical or (when `horizontal`) along x.
static func _bead(parent: Node3D, mat: Material, pos: Vector3, length: float,
		horizontal: bool) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = BEAD_R
	c.bottom_radius = BEAD_R
	c.height = length
	c.radial_segments = 8
	c.rings = 1
	m.mesh = c
	m.material_override = mat
	m.position = pos
	if horizontal:
		m.rotation_degrees.z = 90.0
	parent.add_child(m)


static func _box(parent: Node3D, mat: Material, pos: Vector3, size: Vector3) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	parent.add_child(m)


## Hinge x, window parts and leaf collision from the interior size; `s` is the hinge side.
static func _layout(_doors: Node3D, hinge: Node3D, s: float) -> void:
	var half := VanInteriorSize.REAR_DOOR_HALF
	hinge.position.x = s * half
	for n in ["WindowFrame", "WindowGlass", "IronCross", "BreakableGlass"]:
		var node := hinge.get_node(n) as Node3D
		node.position.x = -s * _LeafBuild.WINDOW_X
	(hinge.get_node("Handle") as Node3D).position.x = -s * (half - HANDLE_INSET)
	var panel := hinge.get_node("Interact") as Node3D
	panel.position.x = -s * half * 0.5
	_window_collision(hinge, panel, s)
	for n in ["Bottom", "Top"]:
		((panel.get_node(n) as CollisionShape3D).shape as BoxShape3D).size.x = half - 0.01
	var rail_x := half * 0.5 - RAIL_W * 0.5
	(panel.get_node("LeftRail") as Node3D).position.x = -rail_x
	(panel.get_node("RightRail") as Node3D).position.x = rail_x


## Glass collision takes the chamfered window outline, and the steel corner it leaves open gets
## leaf collision of its own, so shots hit the glass only where there is glass.
static func _window_collision(hinge: Node3D, panel: Node3D, s: float) -> void:
	var hole := _LeafBuild.WINDOW_HOLE
	var glass := hinge.get_node("BreakableGlass") as Node3D
	var pts := PackedVector3Array()
	for p in hole:
		for z: float in [_LeafBuild.CABIN_Z, 0.11]:
			pts.append(Vector3(-s * p.x, p.y, z))
	var glass_shape := ConvexPolygonShape3D.new()
	glass_shape.points = pts
	(glass.get_node("Collision") as CollisionShape3D).shape = glass_shape
	# The cut corner is the triangle between the bounding box corner and the chamfer's sharp ends.
	var cut := _LeafBuild.WINDOW_CORNERS
	var corner := PackedVector3Array()
	for p: Vector2 in [cut[3], cut[4], Vector2(cut[3].x, cut[4].y)]:
		for z: float in [_LeafBuild.CABIN_Z, _LeafBuild.STREET_HALF]:
			corner.append(Vector3(-s * p.x, p.y, z))
	var shape := ConvexPolygonShape3D.new()
	shape.points = corner
	var old := panel.get_node_or_null("WindowCorner")
	if old != null:
		old.free()
	var node := CollisionShape3D.new()
	node.name = "WindowCorner"
	node.shape = shape
	node.position = Vector3(glass.position.x - panel.position.x, glass.position.y, 0.0)
	panel.add_child(node)


## The fixed blocker follows the same numbers: leaf halves, pillar fills and the header fill.
static func _blocker(doors: Node3D) -> void:
	var half := VanInteriorSize.REAR_DOOR_HALF
	var profile := VanBodyProfile.from_interior(doors.get_parent())
	var blocker := doors.get_node("Blocker")
	for s: float in [-1.0, 1.0]:
		var side := "Left" if s < 0.0 else "Right"
		for n in ["Bottom", "Top"]:
			var cs := blocker.get_node(side + n) as CollisionShape3D
			cs.position.x = s * half * 0.5
			(cs.shape as BoxShape3D).size.x = half - 0.01
		(blocker.get_node(side + "LeftRail") as Node3D).position.x = s * (half - RAIL_W * 0.5)
		(blocker.get_node(side + "RightRail") as Node3D).position.x = s * (RAIL_W * 0.5 + 0.01)
		for i in range(4):
			var f := blocker.get_node("%sFill%d" % [side, i]) as CollisionShape3D
			var wall := profile.inner_x_at(f.position.y) + 0.05
			(f.shape as BoxShape3D).size.x = wall - half + 0.05
			f.position.x = s * (half - 0.05 + (wall - half + 0.05) * 0.5)
	var top := blocker.get_node("TopFill") as CollisionShape3D
	var tshape := top.shape as BoxShape3D
	tshape.size.x = 2.0 * (profile.inner_x_at(top.position.y) + 0.05)
	top.position.y = VanInteriorSize.REAR_DOOR_TOP + tshape.size.y * 0.5
