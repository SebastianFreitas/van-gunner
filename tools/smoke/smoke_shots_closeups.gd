extends RefCounted
## Builds the close-up view list for tools/smoke.py --shots: door and window seams, the side
## doors and windows from inside and outside, and the rear roof line. Every position is
## rig-local and computed from the live van nodes, never a hard-coded van number, so a body
## edit never goes stale here.

const _SideDoors := preload("res://scripts/van/side_doors.gd")
const _SideWindows := preload("res://scripts/van/side_windows.gd")

## SideWindows child node name for each window id (ids are snake_case, node names PascalCase).
const _WINDOW_NODE_NAMES := {
	&"left_rear": "LeftRear",
	&"left_front": "LeftFront",
	&"right_rear": "RightRear",
	&"right_front": "RightFront",
}

const _SEAM_DISTANCE := 2.5
const _SEAM_ANGLE := deg_to_rad(30.0)


## One row per view: {label, from, target, doors, windows}, all rig-local. doors/windows list
## the leaves to open for that view (empty = everything closed).
static func views(rig: Node3D) -> Array[Dictionary]:
	var interior := rig.get_node(^"Interior")
	var profile := VanBodyProfile.from_interior(interior)
	var shell := rig.get_node(^"Interior/Shell")
	var side_doors := shell.get_node(^"SideDoors")
	var side_windows := shell.get_node(^"SideWindows")

	var shell_aabb := _merged_mesh_aabb(shell, rig)
	var rear_z := shell_aabb.position.z + shell_aabb.size.z
	var front_z := shell_aabb.position.z
	var roof := profile.outer_roof_y_at(0.0)

	var result: Array[Dictionary] = []
	var door_centres: Dictionary = {}

	for side in [_SideDoors.SIDE_LEFT, _SideDoors.SIDE_RIGHT]:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var door_node := side_doors.get_node(NodePath(String(side).capitalize()))
		var door_centre := _merged_mesh_aabb(door_node, rig).get_center()
		door_centres[side] = door_centre
		var outer_x := profile.outer_x_at(1.7)
		result.append(_view(
			"door-%s-in-closed" % side, Vector3(s * 0.3, 1.6, door_centre.z + 0.6),
			door_centre, [], []
		))
		result.append(_view(
			"door-%s-in-open" % side, Vector3(s * 0.3, 1.6, door_centre.z + 0.6),
			door_centre, [side], []
		))
		result.append(_view(
			"door-%s-out-closed" % side, Vector3(s * (outer_x + 2.2), 1.7, door_centre.z + 1.2),
			door_centre, [], []
		))
		result.append(_view(
			"door-%s-out-open" % side, Vector3(s * (outer_x + 2.2), 1.7, door_centre.z + 1.2),
			door_centre, [side], []
		))

	for id in _SideWindows.ALL_WINDOWS:
		var s := -1.0 if String(id).begins_with("left") else 1.0
		var window_node := side_windows.get_node(NodePath(_WINDOW_NODE_NAMES[id]))
		var hinge := window_node.get_node(^"Hinge") as Node3D
		var frame_aabb := _merged_mesh_aabb(hinge, rig)
		var centre := rig.to_local(hinge.global_transform.origin)
		centre.x -= s * _SideWindows.HINGE_OUT_M # pivot sits outboard of the liner
		# The hinge sits at the sash's top edge; drop to the frame's middle.
		centre.y -= frame_aabb.size.y * 0.5
		result.append(_view(
			"win-%s-in-closed" % id, Vector3(s * 0.4, centre.y, centre.z + 0.5), centre, [], []
		))
		result.append(_view(
			"win-%s-in-open" % id, Vector3(s * 0.4, centre.y, centre.z + 0.5), centre, [], [id]
		))
		var outer_x := profile.outer_x_at(centre.y + 0.6)
		result.append(_view(
			"win-%s-out-open" % id,
			Vector3(s * (outer_x + 1.6), centre.y + 0.6, centre.z + 0.8), centre, [], [id]
		))

	for side in [_SideDoors.SIDE_LEFT, _SideDoors.SIDE_RIGHT]:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var door_centre: Vector3 = door_centres[side]
		var rear_corner := Vector3(s * profile.outer_x_at(1.5), 1.5, rear_z)
		result.append(_view(
			"seam-rear-corner-%s" % side, _seam_from(rear_corner, s, 1.0), rear_corner, [], []
		))
		var rear_corner_top := Vector3(s * profile.outer_x_at(roof), roof, rear_z)
		result.append(_view(
			"seam-rear-corner-top-%s" % side, _seam_from(rear_corner_top, s, 1.0),
			rear_corner_top, [], []
		))
		var front_seam := Vector3(s * profile.outer_x_at(1.5), 1.5, front_z)
		result.append(_view(
			"seam-front-%s" % side, _seam_from(front_seam, s, -1.0), front_seam, [], []
		))
		var sill := Vector3(s * profile.outer_x_at(0.0), 0.0, door_centre.z)
		result.append(_view("seam-sill-%s" % side, _seam_from(sill, s, 1.0), sill, [], []))
		var roof_edge := Vector3(s * profile.outer_x_at(roof), roof, 0.0)
		result.append(_view(
			"seam-roof-edge-%s" % side, Vector3(roof_edge.x, roof + 2.0, roof_edge.z), roof_edge,
			[], []
		))

	result.append(_view(
		"rear-roof-centre", Vector3(0.0, roof + 1.5, rear_z + 5.0), Vector3(0.0, roof, rear_z),
		[], []
	))
	result.append(_view(
		"rear-roof-quarter",
		Vector3(profile.outer_x_at(roof) + 3.0, roof + 2.0, rear_z + 4.0),
		Vector3(0.0, roof, rear_z), [], []
	))

	return result


## One row per gap-light view: {label, from, target, mode, doors}, all rig-local. Read with
## gaplight on (`mode` "on": from the cabin) or out (`mode` "out": from the street). `doors`
## lists the side doors to open (only the control opens one).
static func gap_views(rig: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var interior := rig.get_node_or_null(^"Interior")
	var shell := rig.get_node_or_null(^"Interior/Shell")
	if interior == null or shell == null:
		return result
	var side_doors := shell.get_node_or_null(^"SideDoors")
	var hinge := shell.get_node_or_null(^"RearWall/LeftHinge") as Node3D
	var ceiling := shell.get_node_or_null(^"Ceiling") as VanCeiling
	if side_doors == null or hinge == null or ceiling == null:
		return result
	var sides: Array[StringName] = [_SideDoors.SIDE_LEFT, _SideDoors.SIDE_RIGHT]
	var boxes: Dictionary = {}
	for side in sides:
		var door_node := side_doors.get_node_or_null(NodePath(String(side).capitalize()))
		if door_node == null:
			return result
		boxes[side] = _merged_mesh_aabb(door_node, rig)
	var profile := VanBodyProfile.from_interior(interior)
	var rz := hinge.position.z - 0.08
	var oz := hinge.position.z + 0.08
	var vy := ceiling.vault_y_at(0.0)
	var none: Array[StringName] = []
	var left_box: AABB = boxes[_SideDoors.SIDE_LEFT]
	result.append(_gap_view(
		"gap-control-door-open", Vector3(-0.3, 1.6, left_box.get_center().z + 0.6),
		left_box.get_center(), "on", [_SideDoors.SIDE_LEFT]
	))
	result.append(_gap_view("gap-rear-in-whole", Vector3(0, 1.6, rz - 4.0),
		Vector3(0, 1.55, rz), "on", none))
	result.append(_gap_view("gap-rear-in-header", Vector3(0, vy - 0.12, rz - 1.5),
		Vector3(0, vy - 0.02, rz), "on", none))
	result.append(_gap_view("gap-rear-in-sill", Vector3(0, 0.10, rz - 1.5),
		Vector3(0, 0.015, rz), "on", none))
	result.append(_gap_view("gap-rear-in-centre", Vector3(0, 1.6, rz - 1.2),
		Vector3(0, 1.6, rz), "on", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var ix := profile.inner_x_at(1.6)
		result.append(_gap_view("gap-rear-in-hinge-%s" % side,
			Vector3(s * (ix - 0.10), 1.6, rz - 1.2), Vector3(s * (ix - 0.025), 1.6, rz),
			"on", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var d1: Vector3 = (boxes[side] as AABB).end
		for row in [["front", d1.z - 0.6], ["rear", 2.35]]:
			var z: float = row[1]
			result.append(_gap_view("gap-ceiling-%s-%s" % [side, row[0]],
				Vector3(s * 2.25, 1.0, z), Vector3(s * profile.inner_x_at(3.05), 3.05, z),
				"on", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var box: AABB = boxes[side]
		var dc := box.get_center()
		result.append(_gap_view("gap-door-%s-in-whole" % side, Vector3(-s * 1.2, 1.6, dc.z),
			dc, "on", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var box: AABB = boxes[side]
		var dc := box.get_center()
		var d1 := box.end
		result.append(_gap_view("gap-door-%s-in-header" % side,
			Vector3(s * 0.8, d1.y + 0.01, dc.z), Vector3(dc.x, d1.y + 0.01, dc.z), "on", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var box: AABB = boxes[side]
		var dc := box.get_center()
		var d0 := box.position
		result.append(_gap_view("gap-door-%s-in-threshold" % side,
			Vector3(s * 0.8, d0.y - 0.01, dc.z), Vector3(dc.x, d0.y - 0.01, dc.z), "on", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var box: AABB = boxes[side]
		var dc := box.get_center()
		var d0 := box.position
		var d1 := box.end
		var ix := profile.inner_x_at(1.6)
		result.append(_gap_view("gap-door-%s-in-jamb-front" % side,
			Vector3(s * 0.8, 1.6, d0.z + 0.10), Vector3(s * ix, 1.6, d0.z - 0.005), "on", none))
		result.append(_gap_view("gap-door-%s-in-jamb-rear" % side,
			Vector3(s * 0.8, 1.6, d1.z + 0.01), Vector3(dc.x, 1.6, d1.z + 0.01), "on", none))
	result.append(_gap_view("gap-rear-out-whole", Vector3(0, 1.7, oz + 5.0),
		Vector3(0, 1.55, oz), "out", none))
	result.append(_gap_view("gap-rear-out-header", Vector3(0, vy - 0.12, oz + 2.0),
		Vector3(0, vy - 0.02, oz), "out", none))
	result.append(_gap_view("gap-rear-out-sill", Vector3(0, 0.10, oz + 2.0),
		Vector3(0, 0.015, oz), "out", none))
	result.append(_gap_view("gap-rear-out-centre", Vector3(0, 1.6, oz + 1.5),
		Vector3(0, 1.6, oz), "out", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var ix := profile.inner_x_at(1.6)
		result.append(_gap_view("gap-rear-out-hinge-%s" % side,
			Vector3(s * (ix - 0.08), 1.6, oz + 1.5), Vector3(s * (ix - 0.02), 1.6, oz),
			"out", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var box: AABB = boxes[side]
		var dc := box.get_center()
		result.append(_gap_view("gap-door-%s-out-whole" % side,
			Vector3(s * (profile.outer_x_at(1.7) + 2.2), 1.7, dc.z), dc, "out", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var box: AABB = boxes[side]
		var dc := box.get_center()
		var d1 := box.end
		var cx := s * (profile.outer_x_at(1.7) + 1.5)
		result.append(_gap_view("gap-door-%s-out-header" % side,
			Vector3(cx, d1.y + 0.01, dc.z), Vector3(dc.x, d1.y + 0.01, dc.z), "out", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var box: AABB = boxes[side]
		var dc := box.get_center()
		var d0 := box.position
		var cx := s * (profile.outer_x_at(1.7) + 1.5)
		result.append(_gap_view("gap-door-%s-out-threshold" % side,
			Vector3(cx, d0.y - 0.01, dc.z), Vector3(dc.x, d0.y - 0.01, dc.z), "out", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		var box: AABB = boxes[side]
		var dc := box.get_center()
		var d0 := box.position
		var d1 := box.end
		var cx := s * (profile.outer_x_at(1.7) + 1.5)
		result.append(_gap_view("gap-door-%s-out-jamb-front" % side,
			Vector3(cx, 1.6, d0.z - 0.01), Vector3(dc.x, 1.6, d0.z - 0.01), "out", none))
		result.append(_gap_view("gap-door-%s-out-jamb-rear" % side,
			Vector3(cx, 1.6, d1.z + 0.01), Vector3(dc.x, 1.6, d1.z + 0.01), "out", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		for row in [["front", -0.375], ["rear", 2.835]]:
			var wz: float = row[1]
			result.append(_gap_view("gap-win-%s-%s" % [side, row[0]],
				Vector3(-s * 0.6, 1.6, wz), Vector3(s * profile.inner_x_at(1.775), 1.775, wz),
				"on", none))
	for side in sides:
		var s := -1.0 if side == _SideDoors.SIDE_LEFT else 1.0
		result.append(_gap_view("gap-floor-%s" % side, Vector3(s * 0.8, 1.2, 3.0),
			Vector3(s * profile.inner_x_at(0.0), 0.0, 3.0), "on", none))
	return result


## A camera 2.5 m from `point`, tilted 30 degrees off straight-on toward the van's front
## (`z_sign` -1.0) or rear (`z_sign` 1.0).
static func _seam_from(point: Vector3, side_sign: float, z_sign: float) -> Vector3:
	var outward := Vector3(side_sign, 0.0, 0.0)
	var along := Vector3(0.0, 0.0, z_sign)
	var dir := (outward * cos(_SEAM_ANGLE) + along * sin(_SEAM_ANGLE)).normalized()
	return point + dir * _SEAM_DISTANCE


static func _view(
	label: String, from: Vector3, target: Vector3, doors: Array[StringName],
	windows: Array[StringName]
) -> Dictionary:
	return {"label": label, "from": from, "target": target, "doors": doors, "windows": windows}


static func _gap_view(
	label: String, from: Vector3, target: Vector3, mode: String, doors: Array[StringName]
) -> Dictionary:
	return {"label": label, "from": from, "target": target, "mode": mode, "doors": doors}


## Merges every descendant MeshInstance3D's AABB into one AABB in `rig`-local space.
static func _merged_mesh_aabb(node: Node, rig: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var to_rig := rig.global_transform.affine_inverse() * mesh.global_transform
		for i in 8:
			var point := to_rig * mesh.get_aabb().get_endpoint(i)
			if first:
				result = AABB(point, Vector3.ZERO)
				first = false
			else:
				result = result.expand(point)
	return result
