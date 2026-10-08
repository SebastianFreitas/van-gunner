class_name VanAnchors
extends RefCounted
## Finds the van's parts by group, so tools survive a remodel of the node tree. Every lookup
## that fails prints an error naming what was looked up and returns null or an empty array.


## The van's visual rig (group `van_rig`).
static func rig(tree: SceneTree) -> Node3D:
	return _one(tree, &"van_rig")


## The shell scene root: the parent of the side-door group node.
static func shell(tree: SceneTree) -> Node3D:
	var doors := side_doors(tree)
	return doors.get_parent() as Node3D if doors != null else null


## The SideDoors node (group `side_doors`).
static func side_doors(tree: SceneTree) -> Node3D:
	return _one(tree, &"side_doors")


## The SideWindows node (group `side_windows`).
static func side_windows(tree: SceneTree) -> Node3D:
	return _one(tree, &"side_windows")


## The rear wall node holding the rear doors (group `rear_doors`).
static func rear_doors(tree: SceneTree) -> Node3D:
	return _one(tree, &"rear_doors")


## The side walls node (group `side_walls`).
static func side_walls(tree: SceneTree) -> VanSideWall:
	return _one(tree, &"side_walls") as VanSideWall


## The ceiling node (group `van_ceiling`).
static func ceiling(tree: SceneTree) -> VanCeiling:
	return _one(tree, &"van_ceiling") as VanCeiling


## The window bars of one opening (group `opening_bars`, matched by `opening_id`), or all
## bars when `opening_id` is empty.
static func bars(tree: SceneTree, opening_id: StringName = &"") -> Array[Node]:
	var found: Array[Node] = []
	for n in tree.get_nodes_in_group(&"opening_bars"):
		if opening_id == &"" or n.get(&"opening_id") == opening_id:
			found.append(n)
	if found.is_empty():
		push_error("VanAnchors: no opening_bars member for opening id '%s'" % opening_id)
	return found


## Every breach point (group `breach_points`).
static func breach_points(tree: SceneTree) -> Array[Node]:
	var found: Array[Node] = tree.get_nodes_in_group(&"breach_points")
	if found.is_empty():
		push_error("VanAnchors: no node in group 'breach_points'")
	return found


static func _one(tree: SceneTree, group: StringName) -> Node3D:
	var node := tree.get_first_node_in_group(group) as Node3D
	if node == null:
		push_error("VanAnchors: no Node3D in group '%s'" % group)
	return node
