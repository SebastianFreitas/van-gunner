extends RefCounted

## A* pathfinding and slot geometry over CabinNav's waypoint graph.

var nav: Node3D  # the owning CabinNav node; reads/writes its fields when called


func _init(owner: Node3D) -> void:
	nav = owner


func astar(start_id: StringName, goal_id: StringName) -> Array[StringName]:
	var empty: Array[StringName] = []
	if start_id == &"" or goal_id == &"":
		return empty
	if start_id == goal_id:
		return [start_id]
	if not nav._nodes.has(start_id) or not nav._nodes.has(goal_id):
		return empty
	var open: Array[StringName] = [start_id]
	var came := {}
	var gscore := {start_id: 0.0}
	var closed := {}
	while not open.is_empty():
		var current := lowest_f(open, gscore, goal_id)
		if current == goal_id:
			return reconstruct(came, current)
		open.erase(current)
		closed[current] = true
		var neighbors: Array = nav._nodes[current]["neighbors"]
		for nb in neighbors:
			var nid := nb as StringName
			if closed.has(nid):
				continue
			var tentative := float(gscore[current]) + dist(current, nid)
			if not gscore.has(nid) or tentative < float(gscore[nid]):
				came[nid] = current
				gscore[nid] = tentative
				if nid not in open:
					open.append(nid)
	return [start_id]


func lowest_f(open: Array[StringName], gscore: Dictionary, goal_id: StringName) -> StringName:
	var best := open[0]
	var best_f := float(gscore[best]) + dist(best, goal_id)
	for i in range(1, open.size()):
		var id := open[i]
		var f := float(gscore[id]) + dist(id, goal_id)
		if f < best_f:
			best_f = f
			best = id
	return best


func reconstruct(came: Dictionary, current: StringName) -> Array[StringName]:
	var path: Array[StringName] = [current]
	while came.has(current):
		current = came[current]
		path.push_front(current)
	return path


func nearest_id(local: Vector3) -> StringName:
	var best := &""
	var best_d := INF
	for key in nav._nodes.keys():
		var id := key as StringName
		var d := xz(node_pos(id), local)
		if d < best_d:
			best_d = d
			best = id
	return best


func node_pos(id: StringName) -> Vector3:
	if not nav._nodes.has(id):
		return Vector3.ZERO
	return nav._nodes[id]["pos"] as Vector3


func dist(a: StringName, b: StringName) -> float:
	return xz(node_pos(a), node_pos(b))


static func xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func compress(from_local: Vector3, pts: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var prev := from_local
	for p in pts:
		var a := Vector3(p.x, from_local.y, p.z)
		if xz(prev, a) > 0.18:
			out.append(a)
			prev = a
	return out


func single_path(from_local: Vector3, dest: Vector3) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	pts.append(dest)
	return compress(from_local, pts)


func is_rear_face(breach: BreachPoint) -> bool:
	if breach == null or breach.outside_marker == null:
		return true
	return to_space(breach.outside_marker).z >= nav.rear_face_z


func to_space(node: Node3D) -> Vector3:
	var space: Node3D = nav._space()
	if space == null or node == null:
		return node.global_position if node else Vector3.ZERO
	return space.to_local(node.global_position)


func marker_pos(marker: Marker3D) -> Vector3:
	if marker == null:
		return Vector3.ZERO
	return marker.position


func wait_pos(id: StringName) -> Vector3:
	match id:
		nav.WAIT_LEFT:
			return marker_pos(nav.rear_corner_left)
		nav.WAIT_RIGHT:
			return marker_pos(nav.rear_corner_right)
		_:
			return Vector3(0.0, nav.raider_height, 8.0)


func melee_points(player: Node3D) -> Array[Vector3]:
	var pl := to_space(player)
	pl.y = nav.raider_height
	var room: CabinNav.Room = nav.room_of(pl)
	var result: Array[Vector3] = []
	for i in nav.melee_slot_count:
		var ang := TAU * float(i) / float(nav.melee_slot_count) + 0.4
		var p: Vector3 = pl + Vector3(cos(ang), 0.0, sin(ang)) * nav.melee_range
		p.y = nav.raider_height
		if nav.room_of(p) != room:
			p = pl + Vector3(cos(ang), 0.0, sin(ang)) * (nav.melee_range * 0.45)
			p.y = nav.raider_height
		result.append(p)
	return result


func melee_id(index: int) -> StringName:
	return StringName("melee_%d" % index)


func vital_slot(vital: Node) -> StringName:
	var key := &"vital"
	if vital and "vital_id" in vital and vital.vital_id != &"":
		key = vital.vital_id
	elif vital:
		key = StringName(vital.name)
	return StringName("vital_%s" % String(key))
