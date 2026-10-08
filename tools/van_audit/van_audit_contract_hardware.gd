extends RefCounted
## Van audit contract rules for hardware and exterior parts: window bars, wheels and roof
## rack against the liner, colliders against meshes. Findings go through the contract pass
## (`<rule> <node> expected <a> got <b>`).

## Window bars must reach past every edge of the window cut by at least this: redneck welded
## junk, not tidy. Today's worst is 0.026 (side bars; the rear bars reach 0.125), so the floor is
## a positive 0.01.
const BARS_OVERLAP_MIN := 0.01
## The bars' cabin-most face may sit this far inside the window's wall plane (the liner at the
## window's height for side windows, the opening's centre for the rear leaves). Negative: the
## bars must stand this far outside it. Today's worst is 0.098 outside (rear bars; the side bars
## are 0.111 outside), so the floor is that minus 0.05.
const BARS_PLANE_TOL := -0.048
## An exterior part may reach into the liner envelope by at most this.
const EXTERIOR_INTRUSION_MAX := 0.0
## A collider and a mesh count as touching when their boxes come within this.
const MESH_NEAR_TOL := 0.03
## Exterior parts under VanLook: wheels and axles, roof and rack, armour, the cab.
const EXTERIOR := ["VanLook/Wheels", "VanLook/Roof", "VanLook/Armour", "VanLook/Cab"]
## Shell nodes whose meshes are wall or door surfaces that must have a collider.
const SOLID_MESHES := [
	"Interior/Shell/SideDoors/Left", "Interior/Shell/SideDoors/Right",
	"Interior/Shell/SideWalls/LeftWall", "Interior/Shell/SideWalls/RightWall",
]
## Nodes skipped by rule 4: `{node_path: reason}`.
const EXEMPT := {}

var host: RefCounted


func _init(contract: RefCounted) -> void:
	host = contract


## Runs every hardware rule; `profile` is the van's body profile.
func check(profile: VanBodyProfile) -> void:
	for entry: Dictionary in host._entries():
		var cover: String = entry["cover"]
		if cover.ends_with("Hinge") and not cover.begins_with("Interior/CabDoor"):
			_check_bars(cover + "/IronCross", entry["open"], entry["axis"], profile)
	_check_bar_ids()
	for path: String in EXTERIOR:
		_check_exterior(path, profile)
	_check_collider_meshes()
	_check_mesh_colliders()


## Rules 1 and 2: the bars reach past the window cut on all four in-plane edges and sit on the
## street face of the wall plane.
func _check_bars(path: String, opening: AABB, axis: int, profile: VanBodyProfile) -> void:
	var cross: Node = host._node(path)
	if cross == null:
		return
	var box: AABB = host._mesh_box(cross)
	for a: int in host._plane_axes(axis):
		var low: float = opening.position[a] - box.position[a]
		var high: float = box.end[a] - opening.end[a]
		if low < BARS_OVERLAP_MIN:
			host._emit("BARS_REACH %s axis %d low edge expected >= %.3f got %.3f"
					% [path, a, BARS_OVERLAP_MIN, low])
		if high < BARS_OVERLAP_MIN:
			host._emit("BARS_REACH %s axis %d high edge expected >= %.3f got %.3f"
					% [path, a, BARS_OVERLAP_MIN, high])
	# Street side: +z for the rear leaves, the opening's own x sign for side windows.
	# The side opening box is straight at the floor width, so the wall plane at the window's
	# height comes from the profile.
	var plane: float = opening.get_center().z if axis == 2 			else signf(opening.get_center().x) * profile.inner_x_at(opening.get_center().y)
	var sign_out := 1.0 if axis == 2 else signf(plane)
	var inner: float = box.position[axis] if sign_out > 0.0 else -box.end[axis]
	if inner < sign_out * plane - BARS_PLANE_TOL:
		host._emit("BARS_FACE %s expected >= %.3f got %.3f"
				% [path, sign_out * plane - BARS_PLANE_TOL, inner])


## Rule 2b: every window breach point finds exactly one `opening_bars` member with its id.
func _check_bar_ids() -> void:
	var bars: Array[Node] = VanAnchors.bars(host.rig.get_tree())
	for point: Node3D in host._breach_points():
		var id: StringName = point.get(&"opening_id")
		if not String(id).contains("window"):
			continue
		var count := 0
		for b in bars:
			if b.get(&"opening_id") == id:
				count += 1
		if count != 1:
			host._emit("BARS_ID %s expected 1 bars with id '%s' got %d" % [point.name, id, count])


## Rule 3: no triangle of an exterior part reaches into the liner envelope by more than
## EXTERIOR_INTRUSION_MAX (depth to the nearest liner face).
func _check_exterior(path: String, profile: VanBodyProfile) -> void:
	var root: Node = host._node(path)
	if root == null:
		return
	var worst := 0.0
	var worst_node := ""
	for t in range(host.tris.count()):
		var node: Node = host.tris.nodes[host.tris.owner_idx[t]]
		if node != root and not root.is_ancestor_of(node):
			continue
		var tb: AABB = host.tris.tri_aabb(t)
		for i in range(8):
			var p := tb.get_endpoint(i)
			var depth := _liner_depth(profile, p)
			if depth > worst:
				worst = depth
				worst_node = String(root.get_path_to(node))
	if worst > EXTERIOR_INTRUSION_MAX:
		host._report_value("EXTERIOR_IN", path + "/" + worst_node, EXTERIOR_INTRUSION_MAX, worst)


## How far a rig-local point is inside the liner envelope (0 outside): the distance to the
## nearest of the side wall, the roof, the cab end and the rear end.
func _liner_depth(profile: VanBodyProfile, p: Vector3) -> float:
	if p.y < 0.0 or p.z < VanInteriorSize.FRONT_Z or p.z > VanInteriorSize.REAR_Z:
		return 0.0
	var side := profile.inner_x_at(p.y) - absf(p.x)
	var roof := profile.roof_y_at(p.x) - p.y
	if side <= 0.0 or roof <= 0.0:
		return 0.0
	return minf(minf(side, roof), minf(p.z - VanInteriorSize.FRONT_Z,
			VanInteriorSize.REAR_Z - p.z))


## Rule 4a: every CollisionShape3D under the shell has a visible triangle within its box.
func _check_collider_meshes() -> void:
	var shell: Node = host._node("Interior/Shell")
	if shell == null:
		return
	for cs: Node in shell.find_children("*", "CollisionShape3D", true, false):
		var path := String(host.rig.get_path_to(cs))
		if EXEMPT.has(path):
			continue
		var box: AABB = host._shape_box(cs)
		if not _any_triangle_near(box):
			host._report("NO_MESH", path, box, AABB())


## Rule 4b: each wall or door surface in SOLID_MESHES has a CollisionShape3D within its box.
func _check_mesh_colliders() -> void:
	var shell: Node = host._node("Interior/Shell")
	if shell == null:
		return
	var shapes: Array[AABB] = []
	for cs: Node in shell.find_children("*", "CollisionShape3D", true, false):
		shapes.append(host._shape_box(cs).grow(MESH_NEAR_TOL))
	for path: String in SOLID_MESHES:
		if EXEMPT.has(path):
			continue
		var root: Node = host._node(path)
		if root == null:
			continue
		var box: AABB = host._mesh_box(root)
		var found := false
		for s in shapes:
			if s.intersects(box):
				found = true
				break
		if not found:
			host._report("NO_COLLIDER", path, box, AABB())


func _any_triangle_near(box: AABB) -> bool:
	var grown := box.grow(MESH_NEAR_TOL)
	for t in range(host.tris.count()):
		if grown.intersects(host.tris.tri_aabb(t)):
			return true
	return false
