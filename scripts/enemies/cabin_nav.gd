class_name CabinNav
extends Node3D

## Van-local waypoint graph + occupancy. Raiders stay Node3D; this is how they
## skip the bulkhead net and each other. Do not swap in NavigationAgent3D —
## EnemyContainer rides a PathFollow3D and world navmeshes drift.

const PASSAGE_SLOT := &"passage"
const WAIT_LEFT := &"wait_left"
const WAIT_RIGHT := &"wait_right"
const WAIT_MID := &"wait_mid"

## A* pathfinding and slot geometry over the waypoint graph. RefCounted, bound to this node.
const _CabinNavPaths := preload("res://scripts/enemies/cabin_nav_paths.gd")

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

var _paths: _CabinNavPaths


func _init() -> void:
	_paths = _CabinNavPaths.new(self)


func _ready() -> void:
	add_to_group(&"cabin_nav")
	call_deferred("_rebuild")


func path_to(from_local: Vector3, target_local: Vector3) -> Array[Vector3]:
	_ensure_graph()
	if _nodes.is_empty():
		return _paths.single_path(from_local, target_local)
	var start_id := _paths.nearest_id(from_local)
	var goal_id := _paths.nearest_id(target_local)
	var ids := _paths.astar(start_id, goal_id)
	var pts: Array[Vector3] = []
	for id in ids:
		pts.append(_paths.node_pos(id))
	pts.append(target_local)
	return _paths.compress(from_local, pts)


func approach_waypoints(from_local: Vector3, breach: BreachPoint) -> Array[Vector3]:
	if breach == null or breach.outside_marker == null:
		return []
	var dest := _paths.to_space(breach.outside_marker)
	dest.y = from_local.y
	if _paths.is_rear_face(breach):
		return _paths.single_path(from_local, dest)
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
	return _paths.compress(from_local, pts)


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
	var left := _paths.wait_pos(WAIT_LEFT)
	var right := _paths.wait_pos(WAIT_RIGHT)
	var mid := _paths.wait_pos(WAIT_MID)
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
	return _claim(_paths.vital_slot(vital), raider, 1)


func release_vital(raider: Node) -> void:
	for key in _occupants.keys():
		var id := key as StringName
		if String(id).begins_with("vital_"):
			_release_slot(id, raider)


func is_vital_free(vital: Node, raider: Node) -> bool:
	if vital == null:
		return false
	return _has_vacancy(_paths.vital_slot(vital), raider, 1)


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
	var pts := _paths.melee_points(player)
	for i in pts.size():
		var id := _paths.melee_id(i)
		if _holds(id, raider):
			return {"ok": true, "local": pts[i]}
	for i in pts.size():
		if _claim(_paths.melee_id(i), raider, 1):
			return {"ok": true, "local": pts[i]}
	return {"ok": false, "local": Vector3.ZERO}


func release_melee(raider: Node) -> void:
	for i in melee_slot_count:
		_release_slot(_paths.melee_id(i), raider)


func release_all(raider: Node) -> void:
	for key in _occupants.keys():
		_release_slot(key as StringName, raider)


func _ensure_graph() -> void:
	if _nodes.is_empty():
		_rebuild()


func _rebuild() -> void:
	_nodes.clear()
	_add_node(&"back_staging", _paths.marker_pos(back_staging))
	_add_node(&"cabin_staging", _paths.marker_pos(cabin_staging))
	_add_node(&"passage", _paths.marker_pos(passage_marker))
	_link(&"back_staging", &"passage")
	_link(&"passage", &"cabin_staging")

	if get_tree():
		for node in get_tree().get_nodes_in_group(&"breach_points"):
			if not (node is BreachPoint):
				continue
			var breach := node as BreachPoint
			if breach.entry_marker == null:
				continue
			var pos := _paths.to_space(breach.entry_marker)
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
			var pos := _paths.to_space(marker)
			var id := _paths.vital_slot(vital)
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
