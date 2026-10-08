extends RefCounted
## Van audit pass "contract": the van's doors, colliders and blockers must agree with
## VanOpenings. One function per rule; each finding reads `<rule> <node> expected <a> got <b>`.

## Colliders and Blockers must cover the opening's in-plane extent within this.
const COLLIDER_TOL := 0.03
## A collider or Blocker centre may sit this far from the opening's wall plane (the opening's
## centre on the wall-normal axis). Today's worst is 0.115 (side windows) plus 0.035.
const PLANE_TOL := 0.15
## A Blocker may reach into the cabin past the liner by at most this: today's worst (rear,
## 0.17 m) plus 0.05.
const BLOCKER_REACH_MAX := 0.22
## A leaf subtree must cover at least this share of its opening's in-plane area: today's
## worst (side doors, 0.854) minus 0.05.
const COVER_MIN_FRACTION := 0.804
## An outside keep-out rect (rear leaf swing) may reach into the liner by at most this: today's
## worst (LEAF_IN, 0.18 m) plus 0.05.
const KEEP_OUT_INTRUSION_MAX := 0.23
## A breach marker may sit this far outside its opening's in-plane span: today's worst is 0.
const FOOTPRINT_MARGIN := 0.1
## A cling spot's body centre may sit this far past the skin plus BODY_DEPTH.
const CLING_TOL := 0.1
## Player containment may fall short of the liner by at most this (measured on the shape box).
const CONTAIN_TOL := 0.05
## It may overshoot the skin by at most this: today's worst (0.62, the 0.8 m margin around the
## cabin that lets the player step into an open door) plus 0.05.
const CONTAIN_SKIN_TOL := 0.67
## Nodes whose COVER rule is skipped: `{node_path: reason}`.
const EXEMPT := {}

const _Motion := preload("res://scripts/enemies/window_raider_motion.gd")
const _Wall := preload("res://scripts/enemies/window_raider_wall.gd")
const _Markers := preload("res://scripts/enemies/breach_point_markers.gd")
const _Hardware := preload("res://tools/van_audit/van_audit_contract_hardware.gd")

const SHELL := "Interior/Shell/"
const WINDOW_NODES: Array[Array] = [
	["SideWindows/LeftRear", -1, 0], ["SideWindows/LeftFront", -1, 1],
	["SideWindows/RightRear", 1, 0], ["SideWindows/RightFront", 1, 1],
]

var rig: Node3D
var tris: RefCounted
var runner: Node


func _init(rig_node: Node3D) -> void:
	rig = rig_node


## Runs every rule on the current (closed) collection.
func check(collected: RefCounted, audit: Node) -> void:
	tris = collected
	runner = audit
	var profile := VanBodyProfile.from_interior(rig.get_node(^"Interior"))
	for entry in _entries():
		_check_cover(entry)
		_check_collider(entry["collider"], entry["open"], entry["axis"])
	for side in [-1, 1]:
		var door := SHELL + "SideDoors/%s" % ("Left" if side < 0 else "Right")
		var opening := VanOpenings.side_door_aabb(side)
		_check_collider(door + "/Blocker", opening, 0, "BLOCKER")
		_check_reach_door(door + "/Blocker", profile)
	for side in [-1, 1]:
		_check_collider(SHELL + "RearWall/Blocker", VanOpenings.rear_window_aabb(side), 2,
				"BLOCKER", "Left" if side < 0 else "Right")
	_check_reach_rear(SHELL + "RearWall/Blocker")
	var points := _breach_points()
	_check_keep_out(profile, points)
	for point in points:
		_check_breach_markers(profile, point)
	_check_cling(profile)
	_check_nav(profile)
	_check_containment(profile)
	_Hardware.new(self).check(profile)


## Closed leaves: opening AABB, wall-normal axis (0 x, 2 z), leaf subtree root (cover) and
## collider node, all paths from the rig.
func _entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for side in [-1, 1]:
		var door := SHELL + "SideDoors/%s" % ("Left" if side < 0 else "Right")
		out.append({"open": VanOpenings.side_door_aabb(side), "axis": 0, "cover": door,
				"collider": door + "/Interact"})
	for w: Array in WINDOW_NODES:
		var hinge: String = SHELL + String(w[0]) + "/Hinge"
		out.append({"open": VanOpenings.side_window_aabb(int(w[1]), int(w[2])), "axis": 0,
				"cover": hinge, "collider": hinge + "/Interact"})
	for hinge_name in ["LeftHinge", "RightHinge"]:
		var hinge: String = SHELL + "RearWall/" + hinge_name
		var side := -1 if hinge_name == "LeftHinge" else 1
		out.append({"open": VanOpenings.rear_window_aabb(side), "axis": 2, "cover": hinge,
				"collider": hinge + "/Interact"})
	# CabDoor is a recessed barred leaf (cab_door.gd): its whole visible subtree is the leaf.
	out.append({"open": VanOpenings.cab_door_aabb(), "axis": 2, "cover": "Interior/CabDoor",
			"collider": "Interior/CabDoor"})
	return out


## The two in-plane axes of a wall whose normal is `axis`.
func _plane_axes(axis: int) -> Array[int]:
	return [1, 2] if axis == 0 else [0, 1]


## Rule 1: the closed leaf subtree overlaps the opening's centre on both in-plane axes and
## covers COVER_MIN_FRACTION of its in-plane area.
func _check_cover(entry: Dictionary) -> void:
	var path: String = entry["cover"]
	if EXEMPT.has(path):
		print("AUDIT VAN CONTRACT: exempt %s (%s)" % [path, EXEMPT[path]])
		return
	var opening: AABB = entry["open"]
	var root := _node(path)
	if root == null:
		return
	var box := _mesh_box(root)
	var centre := opening.get_center()
	var area := 1.0
	var inter := 1.0
	var centred := true
	for a in _plane_axes(entry["axis"]):
		var lo := maxf(box.position[a], opening.position[a])
		var hi := minf(box.end[a], opening.end[a])
		inter *= maxf(hi - lo, 0.0)
		area *= opening.size[a]
		if centre[a] < box.position[a] or centre[a] > box.end[a]:
			centred = false
	var fraction := inter / area
	if not centred or fraction < COVER_MIN_FRACTION:
		_report("COVER", path, opening, box)


## Rule 2: a collider covers the opening in-plane and sits on its wall plane.
func _check_collider(path: String, opening: AABB, axis: int, rule := "COLLIDER",
		prefix := "") -> void:
	var collider := _node(path)
	if collider == null:
		return
	var box := _shape_box(collider, prefix)
	if box.size == Vector3.ZERO:
		_report(rule, path, opening, box)
		return
	var short := 0.0
	for a in _plane_axes(axis):
		short = maxf(short, maxf(box.position[a] - opening.position[a],
				opening.end[a] - box.end[a]))
	var plane := absf(box.get_center()[axis] - opening.get_center()[axis])
	if short > COLLIDER_TOL or plane > PLANE_TOL:
		_report(rule, path, opening, box)


## Rule 3, side doors: the Blocker stays out of the cabin past the liner.
func _check_reach_door(path: String, profile: VanBodyProfile) -> void:
	var blocker := _node(path)
	if blocker == null:
		return
	var box := _shape_box(blocker)
	var inner := minf(absf(box.position.x), absf(box.end.x))
	var liner := 0.0
	for y in [box.position.y, box.end.y]:
		liner = maxf(liner, absf(profile.inner_x_at(y)))
	var reach := liner - inner
	if reach > BLOCKER_REACH_MAX:
		_report_value("BLOCKER_REACH", path, BLOCKER_REACH_MAX, reach)


## Rule 3, rear doors: the Blocker stays out of the cabin past the liner at the rear.
func _check_reach_rear(path: String) -> void:
	var blocker := _node(path)
	if blocker == null:
		return
	var box := _shape_box(blocker)
	var reach := VanInteriorSize.REAR_Z - box.position.z
	if reach > BLOCKER_REACH_MAX:
		_report_value("BLOCKER_REACH", path, BLOCKER_REACH_MAX, reach)


## Widest half-width of the skin over the wall's height.
func _skin_half(profile: VanBodyProfile) -> float:
	var widest := 0.0
	var steps := 16
	for i in range(steps + 1):
		widest = maxf(widest, absf(profile.outer_x_at(profile.wall_height() * i / steps)))
	return widest


## A node's origin in rig space.
func _local(node: Node3D) -> Vector3:
	return rig.global_transform.affine_inverse() * node.global_position


## Rule 4, keep-outs: the body rect encloses the skin footprint; any other rect that reaches past
## the skin footprint (the rear leaf swing) enters the liner by at most KEEP_OUT_INTRUSION_MAX;
## no Outside marker lies inside such a rect (that is the opening's approach lane).
func _check_keep_out(profile: VanBodyProfile, points: Array[Node3D]) -> void:
	var skin := Rect2(-_skin_half(profile), VanInteriorSize.FRONT_Z,
			_skin_half(profile) * 2.0, VanInteriorSize.REAR_Z + VanOpenings.SKIN
			- VanInteriorSize.FRONT_Z)
	var liner := Rect2(-VanInteriorSize.BOTTOM_HALF, VanInteriorSize.FRONT_Z,
			VanInteriorSize.BOTTOM_HALF * 2.0, VanInteriorSize.REAR_Z - VanInteriorSize.FRONT_Z)
	var rects: Array[Rect2] = _Motion.OUTSIDE_KEEP_OUT
	for i in rects.size():
		var rect := rects[i]
		var name := "OUTSIDE_KEEP_OUT[%d]" % i
		if i == 0:
			if not rect.encloses(skin):
				_report_rect("KEEP_OUT_SKIN", name, skin, rect)
			continue
		if skin.encloses(rect):
			continue
		var cut := rect.intersection(liner)
		var depth := minf(cut.size.x, cut.size.y) if cut.has_area() else 0.0
		if depth > KEEP_OUT_INTRUSION_MAX:
			_report_value("KEEP_OUT_LINER", name, KEEP_OUT_INTRUSION_MAX, depth)
		for point in points:
			var p := _local(point.get_node(^"Outside") as Node3D)
			if rect.has_point(Vector2(p.x, p.z)):
				_emit("KEEP_OUT_LANE %s covers Outside of %s at [%.3f,%.3f]" % [
						name, point.name, p.x, p.z])


## Breach points with an opening id, from the rig's live nodes.
func _breach_points() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in rig.find_children("*", "Node3D", true, false):
		if node.is_in_group(&"breach_points") and String(node.get(&"opening_id")) != "":
			out.append(node)
	return out


## Rule 5: the Outside marker lies outside the skin and the Entry inside the liner, both within
## the opening's in-plane span plus FOOTPRINT_MARGIN.
func _check_breach_markers(profile: VanBodyProfile, point: Node3D) -> void:
	var id := String(point.get(&"opening_id"))
	var side := -1 if id.ends_with("_l") or id.contains("_l_") else 1
	var rear := id.begins_with("rear")
	var span := Vector2.ZERO
	if id.begins_with("side_door"):
		var b := VanOpenings.side_door_aabb(side)
		span = Vector2(b.position.z, b.end.z)
	elif id.begins_with("window_"):
		var b := VanOpenings.side_window_aabb(side, int(id.get_slice("_", 2)))
		span = Vector2(b.position.z, b.end.z)
	elif id.begins_with("rear_door"):
		span = Vector2(minf(0.0, side * VanInteriorSize.REAR_DOOR_HALF),
				maxf(0.0, side * VanInteriorSize.REAR_DOOR_HALF))
	elif id.begins_with("rear_window"):
		var b := VanOpenings.rear_window_aabb(side)
		span = Vector2(b.position.x, b.end.x)
	var out := _local(point.get_node(^"Outside") as Node3D)
	var entry := _local(point.get_node(^"Entry") as Node3D)
	var along := func(p: Vector3) -> float: return p.x if rear else p.z
	for pair in [["Outside", out], ["Entry", entry]]:
		var p: Vector3 = pair[1]
		var a: float = along.call(p)
		var inside_skin := p.z <= VanInteriorSize.REAR_Z + VanOpenings.SKIN if rear \
				else absf(p.x) <= profile.outer_x_at(p.y)
		var inside_liner := p.z <= VanInteriorSize.REAR_Z if rear \
				else absf(p.x) <= profile.inner_x_at(p.y)
		var wrong := inside_skin if pair[0] == "Outside" else not inside_liner
		if wrong:
			_emit("BREACH_SIDE %s/%s expected %s got [%.3f,%.3f,%.3f]" % [point.name, pair[0],
					"outside the skin" if pair[0] == "Outside" else "inside the liner",
					p.x, p.y, p.z])
		if a < span.x - FOOTPRINT_MARGIN or a > span.y + FOOTPRINT_MARGIN:
			_emit("BREACH_FOOTPRINT %s/%s expected %.3f..%.3f got %.3f" % [point.name,
					pair[0], span.x, span.y, a])


## Rule 6, cling spots: on the side wall, between the cab end and the rear, a body depth off the
## skin.
func _check_cling(profile: VanBodyProfile) -> void:
	var spots: Array[Vector3] = _Wall.CLING_SPOTS
	for i in spots.size():
		var p: Vector3 = _Wall.cling_point(i)
		var reach := absf(p.x) - profile.outer_x_at(p.y - 0.66)
		if p.z < VanInteriorSize.FRONT_Z or p.z > VanInteriorSize.REAR_Z \
				or absf(reach - _Wall.BODY_DEPTH) > CLING_TOL or signf(p.x) != signf(spots[i].x):
			_emit("CLING CLING_SPOTS[%d] expected z %.2f..%.2f, %.3f off the skin got [%.3f,%.3f,%.3f]"
					% [i, VanInteriorSize.FRONT_Z, VanInteriorSize.REAR_Z, _Wall.BODY_DEPTH,
					p.x, p.y, p.z])


## Rule 7, cabin nav markers: passage and both staging points inside the liner on their side of
## the bulkhead; the rear corners outside the skin and behind the rear face.
func _check_nav(profile: VanBodyProfile) -> void:
	var nav := rig.get_node_or_null(^"EnemyContainer/CabinNav")
	if nav == null:
		_emit("missing node EnemyContainer/CabinNav")
		return
	var bulk: float = nav.get(&"bulkhead_z")
	for entry in [["BulkheadPassage", 0], ["BackStaging", 1], ["CabinStaging", -1]]:
		var p := _local(nav.get_node(String(entry[0])) as Node3D)
		var side_ok := true
		if int(entry[1]) != 0:
			side_ok = (p.z - bulk) * int(entry[1]) > 0.0
		if absf(p.x) > profile.inner_x_at(p.y) or p.z < VanInteriorSize.FRONT_Z \
				or p.z > VanInteriorSize.REAR_Z or not side_ok:
			_emit("NAV %s expected inside the liner (bulkhead z %.2f) got [%.3f,%.3f,%.3f]" % [
					entry[0], bulk, p.x, p.y, p.z])
	for corner in ["RearCornerLeft", "RearCornerRight"]:
		var p := _local(nav.get_node(corner) as Node3D)
		if absf(p.x) <= profile.outer_x_at(p.y) or p.z <= VanInteriorSize.REAR_Z:
			_emit("NAV %s expected outside the skin and behind the rear got [%.3f,%.3f,%.3f]" % [
					corner, p.x, p.y, p.z])


## Rule 8, player containment: its shape box covers the liner and is no wider than the skin.
func _check_containment(profile: VanBodyProfile) -> void:
	var node := _node("Interior/PlayerContainment")
	if node == null:
		return
	var box := _shape_box(node)
	var skin := _skin_half(profile)
	var liner := VanInteriorSize.BOTTOM_HALF
	var short := maxf(maxf(box.position.x + liner, liner - box.end.x),
			maxf(box.position.z - VanInteriorSize.FRONT_Z, VanInteriorSize.REAR_Z - box.end.z))
	var over := maxf(maxf(-skin - box.position.x, box.end.x - skin),
			box.end.z - (VanInteriorSize.REAR_Z + VanOpenings.SKIN))
	if short > CONTAIN_TOL:
		_report_value("CONTAIN_LINER", node.name, CONTAIN_TOL, short)
	if over > CONTAIN_SKIN_TOL:
		_report_value("CONTAIN_SKIN", node.name, CONTAIN_SKIN_TOL, over)


func _report_rect(rule: String, node: String, expected: Rect2, got: Rect2) -> void:
	_emit("%s %s expected %s got %s" % [rule, node, expected, got])


## The node at `path` from the rig; a missing one is a finding, never a silent empty box.
func _node(path: String) -> Node:
	var node := rig.get_node_or_null(NodePath(path))
	if node == null:
		_emit("missing node " + path)
	return node


## Union of the triangle AABBs under `root`, rig-local.
func _mesh_box(root: Node) -> AABB:
	var box := AABB()
	var started := false
	if root == null:
		return box
	for t in range(tris.count()):
		var node: Node = tris.nodes[tris.owner_idx[t]]
		if node != root and not root.is_ancestor_of(node):
			continue
		var tb: AABB = tris.tri_aabb(t)
		box = tb if not started else box.merge(tb)
		started = true
	return box


## Union of every CollisionShape3D under `root` (or `root` itself), rig-local.
func _shape_box(root: Node, prefix := "") -> AABB:
	var box := AABB()
	var started := false
	if root == null:
		return box
	var shapes: Array[Node] = root.find_children("*", "CollisionShape3D", true, false)
	if root is CollisionShape3D:
		shapes.append(root)
	for node in shapes:
		var cs := node as CollisionShape3D
		if cs.shape == null or not String(cs.name).begins_with(prefix):
			continue
		var local: AABB = cs.shape.get_debug_mesh().get_aabb()
		var xform: Transform3D = rig.global_transform.affine_inverse() * cs.global_transform
		var sb: AABB = xform * local
		box = sb if not started else box.merge(sb)
		started = true
	return box


func _report(rule: String, node: String, expected: AABB, got: AABB) -> void:
	_emit("%s %s expected %s got %s" % [rule, node, _fmt(expected), _fmt(got)])


func _report_value(rule: String, node: String, expected: float, got: float) -> void:
	_emit("%s %s expected <= %.3f got %.3f" % [rule, node, expected, got])


func _emit(text: String) -> void:
	runner.add_finding("CONTRACT", text)
	print("AUDIT VAN CONTRACT: " + text)


func _fmt(box: AABB) -> String:
	return "[%.3f,%.3f,%.3f..%.3f,%.3f,%.3f]" % [box.position.x, box.position.y,
			box.position.z, box.end.x, box.end.y, box.end.z]
