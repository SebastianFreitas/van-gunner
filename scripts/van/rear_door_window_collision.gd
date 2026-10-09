extends RefCounted
## A rear leaf's window collision: the BreakableGlass shape from the leaf's hole, and the steel
## fills between the hole and its bounding rect on the Interact body, so shots into the corners
## hit the door and only shots through the hole hit the glass.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
## Glass reaches this far street-ward of the glass node.
const GLASS_FRONT_Z := 0.11
## Donor fills: pieces smaller than this (m2) are the zero-width slivers of tangent edges.
const MIN_FILL_AREA := 0.00005


## `s` is the hinge side (-1 for the x<0 leaf).
static func build(hinge: Node3D, panel: Node3D, s: float, profile: RearDoorProfile) -> void:
	var hole := profile.window_hole
	var glass := hinge.get_node("BreakableGlass") as Node3D
	var pts := PackedVector3Array()
	for p in hole:
		for z: float in [_LeafBuild.CABIN_Z, GLASS_FRONT_Z]:
			pts.append(Vector3(-s * p.x, p.y, z))
	var glass_shape := ConvexPolygonShape3D.new()
	glass_shape.points = pts
	(glass.get_node("Collision") as CollisionShape3D).shape = glass_shape
	for old in panel.get_children():
		if old.name.begins_with("WindowNotch") or old.name == "WindowCorner":
			old.free()
	var at := Vector3(glass.position.x - panel.position.x, glass.position.y, 0.0)
	if profile.is_donor():
		_donor_fills(panel, at, s, hole, profile.window_bounds())
	else:
		_stock_fills(panel, at, s)


## The donor hole's four quadrants of its bounding rect, minus the hole, cut into convex pieces.
static func _donor_fills(panel: Node3D, at: Vector3, s: float, hole: PackedVector2Array,
		bounds: Rect2) -> void:
	var mid := bounds.get_center()
	var index := 0
	for qx: float in [-1.0, 1.0]:
		for qy: float in [-1.0, 1.0]:
			var far := bounds.position if qx < 0.0 else bounds.end
			var corner := Vector2(far.x, bounds.position.y if qy < 0.0 else bounds.end.y)
			var quad := Rect2(mid, Vector2.ZERO).expand(corner)
			var quad_pts := PackedVector2Array([quad.position, Vector2(quad.end.x, quad.position.y),
					quad.end, Vector2(quad.position.x, quad.end.y)])
			for piece in Geometry2D.clip_polygons(quad_pts, hole):
				if absf(_area(piece)) < MIN_FILL_AREA:
					continue
				for convex in Geometry2D.decompose_polygon_in_convex(piece):
					if absf(_area(convex)) < MIN_FILL_AREA:
						continue
					_add_fill(panel, at, s, convex, "WindowNotch%d" % index)
					index += 1


static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		sum += poly[i].cross(poly[(i + 1) % poly.size()])
	return sum * 0.5


static func _add_fill(panel: Node3D, at: Vector3, s: float, poly: PackedVector2Array, label: String) -> void:
	var pts := PackedVector3Array()
	for p: Vector2 in poly:
		for z: float in [_LeafBuild.CABIN_Z, _LeafBuild.STREET_HALF]:
			pts.append(Vector3(-s * p.x, p.y, z))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var node := CollisionShape3D.new()
	node.name = label
	node.shape = shape
	node.position = at
	panel.add_child(node)


## The stock hole: the cut corner is the triangle between the bounding box corner and the
## chamfer's sharp ends, and each rounded corner gets prisms fanned from its sharp corner.
static func _stock_fills(panel: Node3D, at: Vector3, s: float) -> void:
	var cut := _LeafBuild.WINDOW_CORNERS
	_add_fill(panel, at, s, PackedVector2Array([cut[3], cut[4], Vector2(cut[3].x, cut[4].y)]),
			"WindowCorner")
	var corners := _LeafBuild.WINDOW_CORNERS
	var hole := _LeafBuild.WINDOW_HOLE
	var first := 0
	var index := 0
	for i in corners.size():
		var c: Vector2 = corners[i]
		var u: Vector2 = (corners[(i + corners.size() - 1) % corners.size()] - c).normalized()
		var v: Vector2 = (corners[(i + 1) % corners.size()] - c).normalized()
		var half_angle := absf(u.angle_to(v)) * 0.5
		var steps := maxi(3, ceili(float(_LeafBuild.WINDOW_ROUND_STEPS)
				* _arc_sweep(c, u, v, half_angle) / (PI * 0.5)))
		var chunk := 4
		var k := 0
		while k < steps:
			var last := mini(k + chunk, steps)
			var poly := PackedVector2Array([c]) + hole.slice(first + k, first + last + 1)
			_add_fill(panel, at, s, poly, "WindowNotch%d" % index)
			index += 1
			k = last
		first += steps + 1


## Sweep of the fillet arc at a corner with unit edge directions u and v.
static func _arc_sweep(c: Vector2, u: Vector2, v: Vector2, half_angle: float) -> float:
	var centre := c + (u + v).normalized() * (_LeafBuild.WINDOW_ROUND / sin(half_angle))
	var t1 := c + u * (_LeafBuild.WINDOW_ROUND / tan(half_angle))
	var t2 := c + v * (_LeafBuild.WINDOW_ROUND / tan(half_angle))
	return absf(angle_difference((t1 - centre).angle(), (t2 - centre).angle()))
