class_name CabinNav
extends Node3D

## Van-local waypoint graph + occupancy. Raiders stay Node3D; this is how they
## skip the bulkhead net and each other. Do not swap in NavigationAgent3D —
## EnemyContainer rides a PathFollow3D and world navmeshes drift.

const GROUP := &"cabin_nav"
const PASSAGE_SLOT := &"passage"
const WAIT_LEFT := &"wait_left"
const WAIT_RIGHT := &"wait_right"
const WAIT_MID := &"wait_mid"

enum Room { BACK, CABIN }

## Bulkhead face in EnemyContainer space. Rear cargo is past this plus a small slop.
@export var bulkhead_z := 1.0
## Outside markers with z above this are the rear face (no hull-around path).
@export var rear_face_z := 4.5
@export var melee_slot_count := 3
@export var melee_range := 1.2
@export var wait_timeout := 1.0
@export var raider_height := 1.62

@onready var passage_marker: Marker3D = $BulkheadPassage
@onready var back_staging: Marker3D = $BackStaging
@onready var cabin_staging: Marker3D = $CabinStaging
@onready var rear_corner_left: Marker3D = $RearCornerLeft
@onready var rear_corner_right: Marker3D = $RearCornerRight

var _nodes: Dictionary = {}
var _occupants: Dictionary = {}


func _ready() -> void:
	add_to_group(&"cabin_nav")
	call_deferred("_rebuild")


func path_to(from_local: Vector3, to_local: Vector3) -> Array[Vector3]:
	_ensure_graph()
	if _nodes.is_empty():
		return _single_path(from_local, to_local)
	var start_id := _nearest_id(from_local)
	var goal_id := _nearest_id(to_local)
	var ids := _astar(start_id, goal_id)
	var pts: Array[Vector3] = []
	for id in ids:
		pts.append(_node_pos(id))
	pts.append(to_local)
	return _compress(from_local, pts)


func approach_waypoints(from_local: Vector3, breach: BreachPoint) -> Array[Vector3]:
	if breach == null or breach.outside_marker == null:
		return []
	var dest := _to_space(breach.outside_marker)
	dest.y = from_local.y
	if _is_rear_face(breach):
		return _single_path(from_local, dest)
	var side := 1.0 if dest.x >= 0.0 else -1.0
	var corner := (
		rear_corner_right.position if side > 0.0 else rear_corner_left.position
	)
	corner.y = from_local.y
	var along := Vector3(corner.x, from_local.y, dest.z)
	var pts: Array[Vector3] = []
	pts.append(corner)
	pts.append(along)
	pts.append(dest)
	return _compress(from_local, pts)


func staging_local(from_local: Vector3) -> Vector3:
	_ensure_graph()
	var marker := back_staging if room_of(from_local) == Room.BACK else cabin_staging
	if marker == null:
		return from_local
	var p := marker.position
	p.y = from_local.y
	return p


func room_of(local: Vector3) -> Room:
	# Slop so the bulkhead face itself counts as cabin; rear cargo is past the net.
	return Room.BACK if local.z >= bulkhead_z + 0.15 else Room.CABIN


func is_passage_point(local: Vector3) -> bool:
	if passage_marker == null:
		return false
	var p := passage_marker.position
	return Vector2(local.x - p.x, local.z - p.z).length() < 0.28


func claim_passage(raider: Node) -> bool:
	return _claim(PASSAGE_SLOT, raider, 1)


func release_passage(raider: Node) -> void:
	_release_slot(PASSAGE_SLOT, raider)


func try_claim_outside_wait(raider: Node) -> Vector3:
	var left := _wait_pos(WAIT_LEFT)
	var right := _wait_pos(WAIT_RIGHT)
	var mid := _wait_pos(WAIT_MID)
	var order: Array[StringName] = [WAIT_MID, WAIT_LEFT, WAIT_RIGHT]
	var space := _space()
	if space and raider is Node3D:
		var lx: float = (raider as Node3D).position.x
		if lx < 0.0:
			order = [WAIT_LEFT, WAIT_MID, WAIT_RIGHT]
		elif lx > 0.0:
			order = [WAIT_RIGHT, WAIT_MID, WAIT_LEFT]
	for id in order:
		var cap := 4 if id == WAIT_MID else 1
		if _claim(id, raider, cap):
			match id:
				WAIT_LEFT:
					return left
				WAIT_RIGHT:
					return right
				_:
					return mid
	return mid


func release_outside_wait(raider: Node) -> void:
	_release_slot(WAIT_LEFT, raider)
	_release_slot(WAIT_RIGHT, raider)
	_release_slot(WAIT_MID, raider)


func claim_vital(vital: Node, raider: Node) -> bool:
	if vital == null:
		return false
	return _claim(_vital_slot(vital), raider, 1)


func release_vital(raider: Node) -> void:
	for key in _occupants.keys():
		var id := key as StringName
		if String(id).begins_with("vital_"):
			_release_slot(id, raider)


func is_vital_free(vital: Node, raider: Node) -> bool:
	if vital == null:
		return false
	return _has_vacancy(_vital_slot(vital), raider, 1)


func pick_free_vital_near(from_global: Vector3, raider: Node = null) -> Node:
	var best: Node = null
	var best_d := INF
	if get_tree() == null:
		return null
	for vital in get_tree().get_nodes_in_group(&"van_vitals"):
		if vital == null or not vital.has_method("is_alive") or not vital.is_alive():
			continue
		if not is_vital_free(vital, raider):
			continue
		var marker: Node3D = (
			vital.get_attack_marker()
			if vital.has_method("get_attack_marker")
			else vital
		)
		if marker == null:
			continue
		var d := Vector2(
			from_global.x - marker.global_position.x,
			from_global.z - marker.global_position.z
		).length()
		if d < best_d:
			best_d = d
			best = vital
	return best


func try_claim_melee(raider: Node, player: Node3D) -> Dictionary:
	if player == null:
		return {"ok": false, "local": Vector3.ZERO}
	var pts := _melee_points(player)
	for i in pts.size():
		var id := _melee_id(i)
		if _holds(id, raider):
			return {"ok": true, "local": pts[i]}
	for i in pts.size():
		if _claim(_melee_id(i), raider, 1):
			return {"ok": true, "local": pts[i]}
	return {"ok": false, "local": Vector3.ZERO}


func release_melee(raider: Node) -> void:
	for i in melee_slot_count:
		_release_slot(_melee_id(i), raider)


func release_all(raider: Node) -> void:
	for key in _occupants.keys():
		_release_slot(key as StringName, raider)


func _ensure_graph() -> void:
	if _nodes.is_empty():
		_rebuild()


func _rebuild() -> void:
	_nodes.clear()
	_add_node(&"back_staging", _marker_pos(back_staging))
	_add_node(&"cabin_staging", _marker_pos(cabin_staging))
	_add_node(&"passage", _marker_pos(passage_marker))
	_link(&"back_staging", &"passage")
	_link(&"passage", &"cabin_staging")

	if get_tree():
		for node in get_tree().get_nodes_in_group(&"breach_points"):
			if not (node is BreachPoint):
				continue
			var breach := node as BreachPoint
			if breach.entry_marker == null:
				continue
			var pos := _to_space(breach.entry_marker)
			var id := breach.point_id
			if id == &"":
				id = StringName(breach.name)
			_add_node(id, pos)
			var staging := (
				&"back_staging" if room_of(pos) == Room.BACK else &"cabin_staging"
			)
			_link(id, staging)
		for vital in get_tree().get_nodes_in_group(&"van_vitals"):
			if vital == null:
				continue
			var marker: Node3D = (
				vital.get_attack_marker()
				if vital.has_method("get_attack_marker")
				else vital
			)
			if marker == null:
				continue
			var pos := _to_space(marker)
			var id := _vital_slot(vital)
			_add_node(id, pos)
			var staging := (
				&"back_staging" if room_of(pos) == Room.BACK else &"cabin_staging"
			)
			_link(id, staging)


func _add_node(id: StringName, pos: Vector3) -> void:
	if id == &"":
		return
	if _nodes.has(id):
		_nodes[id]["pos"] = pos
		return
	_nodes[id] = {"pos": pos, "neighbors": []}


func _link(a: StringName, b: StringName) -> void:
	if not _nodes.has(a) or not _nodes.has(b) or a == b:
		return
	var na: Array = _nodes[a]["neighbors"]
	var nb: Array = _nodes[b]["neighbors"]
	if not na.has(b):
		na.append(b)
	if not nb.has(a):
		nb.append(a)


func _astar(start_id: StringName, goal_id: StringName) -> Array[StringName]:
	var empty: Array[StringName] = []
	if start_id == &"" or goal_id == &"":
		return empty
	if start_id == goal_id:
		return [start_id]
	if not _nodes.has(start_id) or not _nodes.has(goal_id):
		return empty
	var open: Array[StringName] = [start_id]
	var came := {}
	var gscore := {start_id: 0.0}
	var closed := {}
	while not open.is_empty():
		var current := _lowest_f(open, gscore, goal_id)
		if current == goal_id:
			return _reconstruct(came, current)
		open.erase(current)
		closed[current] = true
		var neighbors: Array = _nodes[current]["neighbors"]
		for nb in neighbors:
			var nid := nb as StringName
			if closed.has(nid):
				continue
			var tentative := float(gscore[current]) + _dist(current, nid)
			if not gscore.has(nid) or tentative < float(gscore[nid]):
				came[nid] = current
				gscore[nid] = tentative
				if nid not in open:
					open.append(nid)
	return [start_id]


func _lowest_f(open: Array[StringName], gscore: Dictionary, goal_id: StringName) -> StringName:
	var best := open[0]
	var best_f := float(gscore[best]) + _dist(best, goal_id)
	for i in range(1, open.size()):
		var id := open[i]
		var f := float(gscore[id]) + _dist(id, goal_id)
		if f < best_f:
			best_f = f
			best = id
	return best


func _reconstruct(came: Dictionary, current: StringName) -> Array[StringName]:
	var path: Array[StringName] = [current]
	while came.has(current):
		current = came[current]
		path.push_front(current)
	return path


func _nearest_id(local: Vector3) -> StringName:
	var best := &""
	var best_d := INF
	for key in _nodes.keys():
		var id := key as StringName
		var d := _xz(_node_pos(id), local)
		if d < best_d:
			best_d = d
			best = id
	return best


func _node_pos(id: StringName) -> Vector3:
	if not _nodes.has(id):
		return Vector3.ZERO
	return _nodes[id]["pos"] as Vector3


func _dist(a: StringName, b: StringName) -> float:
	return _xz(_node_pos(a), _node_pos(b))


func _xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _compress(from_local: Vector3, pts: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var prev := from_local
	for p in pts:
		var a := Vector3(p.x, from_local.y, p.z)
		if _xz(prev, a) > 0.18:
			out.append(a)
			prev = a
	return out


func _single_path(from_local: Vector3, dest: Vector3) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	pts.append(dest)
	return _compress(from_local, pts)


func _is_rear_face(breach: BreachPoint) -> bool:
	if breach == null or breach.outside_marker == null:
		return true
	return _to_space(breach.outside_marker).z >= rear_face_z


func _to_space(node: Node3D) -> Vector3:
	var space := _space()
	if space == null or node == null:
		return node.global_position if node else Vector3.ZERO
	return space.to_local(node.global_position)


func _marker_pos(marker: Marker3D) -> Vector3:
	if marker == null:
		return Vector3.ZERO
	return marker.position


func _wait_pos(id: StringName) -> Vector3:
	match id:
		WAIT_LEFT:
			return _marker_pos(rear_corner_left)
		WAIT_RIGHT:
			return _marker_pos(rear_corner_right)
		_:
			return Vector3(0.0, raider_height, 8.0)


func _melee_points(player: Node3D) -> Array[Vector3]:
	var pl := _to_space(player)
	pl.y = raider_height
	var room := room_of(pl)
	var result: Array[Vector3] = []
	for i in melee_slot_count:
		var ang := TAU * float(i) / float(melee_slot_count) + 0.4
		var p := pl + Vector3(cos(ang), 0.0, sin(ang)) * melee_range
		p.y = raider_height
		if room_of(p) != room:
			p = pl + Vector3(cos(ang), 0.0, sin(ang)) * (melee_range * 0.45)
			p.y = raider_height
		result.append(p)
	return result


func _melee_id(index: int) -> StringName:
	return StringName("melee_%d" % index)


func _vital_slot(vital: Node) -> StringName:
	var key := &"vital"
	if vital and "vital_id" in vital and vital.vital_id != &"":
		key = vital.vital_id
	elif vital:
		key = StringName(vital.name)
	return StringName("vital_%s" % String(key))


func _claim(slot: StringName, raider: Node, capacity: int) -> bool:
	if raider == null:
		return false
	_prune(slot)
	var list: Array = _occupants.get(slot, [])
	if raider in list:
		return true
	if list.size() >= capacity:
		return false
	list.append(raider)
	_occupants[slot] = list
	return true


func _release_slot(slot: StringName, raider: Node) -> void:
	if not _occupants.has(slot):
		return
	var list: Array = _occupants[slot]
	list.erase(raider)
	if list.is_empty():
		_occupants.erase(slot)
	else:
		_occupants[slot] = list


func _holds(slot: StringName, raider: Node) -> bool:
	_prune(slot)
	var list: Array = _occupants.get(slot, [])
	return raider in list


func _has_vacancy(slot: StringName, raider: Node, capacity: int) -> bool:
	_prune(slot)
	var list: Array = _occupants.get(slot, [])
	return raider in list or list.size() < capacity


func _prune(slot: StringName) -> void:
	if not _occupants.has(slot):
		return
	var list: Array = _occupants[slot]
	for i in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[i]):
			list.remove_at(i)
	if list.is_empty():
		_occupants.erase(slot)
	else:
		_occupants[slot] = list


func _space() -> Node3D:
	return get_parent() as Node3D
