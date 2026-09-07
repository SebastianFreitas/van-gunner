class_name BreachController
extends Node3D

## Assigns raid slots around the van and interior vital damage targets.

@onready var bench_marker: Marker3D = $BenchAttackMarker


func _ready() -> void:
	add_to_group(&"breach_controller")


func get_vitals() -> Array:
	var result: Array = []
	if get_tree() == null:
		return result
	for node in get_tree().get_nodes_in_group(&"van_vitals"):
		if node and node.has_method("is_alive"):
			result.append(node)
	return result


func pick_vital_near(from_global: Vector3, raider: Node = null) -> Node:
	var nav := _cabin_nav()
	if nav:
		return nav.pick_free_vital_near(from_global, raider)
	var best: Node = null
	var best_d := INF
	for vital in get_vitals():
		if not vital.is_alive():
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


func get_bench_position() -> Vector3:
	var vital := pick_vital_near(global_position)
	if vital and vital.has_method("get_attack_marker"):
		var marker: Node3D = vital.get_attack_marker()
		if marker:
			return marker.global_position
	if bench_marker:
		return bench_marker.global_position
	return global_position


func get_bench_basis() -> Basis:
	var vital := pick_vital_near(global_position)
	if vital and vital.has_method("get_attack_marker"):
		var marker: Node3D = vital.get_attack_marker()
		if marker:
			return marker.global_basis
	if bench_marker:
		return bench_marker.global_basis
	return global_basis


## Average EnemyContainer-local Z of rear-door Outside markers.
## Spawn line sits at this + GameBalance.SPAWN_DISTANCE.
func get_rear_outside_reference_z() -> float:
	var parent_3d := get_parent() as Node3D
	if parent_3d == null:
		return 5.2
	var sum := 0.0
	var count := 0
	for point in _all_points():
		if point.kind != BreachPoint.Kind.REAR_DOOR or point.outside_marker == null:
			continue
		sum += parent_3d.to_local(point.outside_marker.global_position).z
		count += 1
	if count == 0:
		return 5.2
	return sum / float(count)


## True when every door and window can be climbed through.
func all_breaches_passable() -> bool:
	for point in _all_points():
		if not point.is_passable():
			return false
	return true


## Rear + side cargo leaves only. Windows can still be barred.
func all_doors_passable() -> bool:
	for point in _all_points():
		if _is_door_kind(point.kind) and not point.is_passable():
			return false
	return true


## Closed rear doors first (left-to-right), then side cargo doors. Wraps inside
## the current tier so the biker boss alternates leaves instead of camping one.
## Skips a leaf whose window pane is already occupied so Wanjna does not stack.
func next_closed_door(after: BreachPoint) -> BreachPoint:
	var rear := _closed_doors_of(BreachPoint.Kind.REAR_DOOR)
	var pick := _next_vacant_after(rear, after)
	if pick:
		return pick
	var side := _closed_doors_of(BreachPoint.Kind.SIDE_DOOR)
	return _next_vacant_after(side, after)


## Prefer an open door leaf; fall back to any passable window.
func first_passable_door() -> BreachPoint:
	for point in _all_points():
		if _is_door_kind(point.kind) and point.is_passable():
			return point
	for point in _all_points():
		if point.is_passable():
			return point
	return null


## Door mobs: rear doors, then side cargo doors.
## Agile mobs: windows only — rear door panes and side cargo windows.
## Never cross pools (door mobs never get windows; agile never open door leaves).
## A door and its pane still share occupancy — mixed packs cannot stack on one hole.
func assign_breach_point(raider: Node) -> BreachPoint:
	var points := _all_points()
	if points.is_empty():
		return null

	var agile := _is_agile(raider)
	var pool: Array[BreachPoint] = []
	for point in points:
		if agile:
			if _is_agile_kind(point.kind):
				pool.append(point)
		elif _is_door_kind(point.kind):
			pool.append(point)

	if pool.is_empty():
		return null

	var pick: BreachPoint = null
	if agile:
		pick = _pick_agile(pool)
	else:
		pick = _pick_door(pool)

	# Reserve even passable openings so two raiders don't funnel one hole.
	if pick == null or not pick.claim(raider):
		return null
	return pick


func _is_agile(raider: Node) -> bool:
	if raider == null:
		return false
	if raider.is_in_group(&"agile"):
		return true
	var flag = raider.get("is_agile")
	return flag == true


func _is_door_kind(kind: BreachPoint.Kind) -> bool:
	return kind == BreachPoint.Kind.REAR_DOOR or kind == BreachPoint.Kind.SIDE_DOOR


func _is_agile_kind(kind: BreachPoint.Kind) -> bool:
	return kind == BreachPoint.Kind.WINDOW or kind == BreachPoint.Kind.SIDE_DOOR_WINDOW


func _pick_door(pool: Array[BreachPoint]) -> BreachPoint:
	var passable_rear: Array[BreachPoint] = []
	var free_rear: Array[BreachPoint] = []
	var passable_side: Array[BreachPoint] = []
	var free_side: Array[BreachPoint] = []

	for point in pool:
		if not point.has_vacancy():
			continue
		var is_rear := point.kind == BreachPoint.Kind.REAR_DOOR
		if point.is_passable():
			if is_rear:
				passable_rear.append(point)
			else:
				passable_side.append(point)
		elif is_rear:
			free_rear.append(point)
		else:
			free_side.append(point)

	var pick := _pick_random(passable_rear)
	if pick == null:
		pick = _pick_random(free_rear)
	if pick == null:
		pick = _pick_random(passable_side)
	if pick == null:
		pick = _pick_random(free_side)
	return pick


func _pick_agile(pool: Array[BreachPoint]) -> BreachPoint:
	var passable_windows: Array[BreachPoint] = []
	var free_windows: Array[BreachPoint] = []

	for point in pool:
		if not point.has_vacancy():
			continue
		if point.is_passable():
			passable_windows.append(point)
		else:
			free_windows.append(point)

	var pick := _pick_best_priority(passable_windows)
	if pick == null:
		pick = _pick_best_priority(free_windows)
	return pick


func _pick_best_priority(points: Array[BreachPoint]) -> BreachPoint:
	if points.is_empty():
		return null
	points.sort_custom(func(a: BreachPoint, b: BreachPoint) -> bool:
		return a.priority < b.priority
	)
	var best_priority := points[0].priority
	var tied: Array[BreachPoint] = []
	for point in points:
		if point.priority != best_priority:
			break
		tied.append(point)
	return _pick_random(tied)


func _pick_random(points: Array[BreachPoint]) -> BreachPoint:
	if points.is_empty():
		return null
	return points[randi() % points.size()]


func _all_points() -> Array[BreachPoint]:
	var result: Array[BreachPoint] = []
	for node in get_tree().get_nodes_in_group(&"breach_points"):
		if node is BreachPoint:
			result.append(node)
	result.sort_custom(func(a: BreachPoint, b: BreachPoint) -> bool:
		return a.priority < b.priority
	)
	return result


func _closed_doors_of(kind: BreachPoint.Kind) -> Array[BreachPoint]:
	var result: Array[BreachPoint] = []
	for point in _all_points():
		if point.kind != kind or point.is_passable():
			continue
		result.append(point)
	var parent_3d := get_parent() as Node3D
	result.sort_custom(func(a: BreachPoint, b: BreachPoint) -> bool:
		if (
			parent_3d == null
			or a.outside_marker == null
			or b.outside_marker == null
		):
			return String(a.point_id) < String(b.point_id)
		return (
			parent_3d.to_local(a.outside_marker.global_position).x
			< parent_3d.to_local(b.outside_marker.global_position).x
		)
	)
	return result


func _cabin_nav() -> CabinNav:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(&"cabin_nav") as CabinNav


func _next_vacant_after(doors: Array[BreachPoint], after: BreachPoint) -> BreachPoint:
	if doors.is_empty():
		return null
	var start := 0
	if after != null:
		var idx := doors.find(after)
		if idx >= 0:
			start = (idx + 1) % doors.size()
	for i in doors.size():
		var door := doors[(start + i) % doors.size()]
		if door.has_vacancy():
			return door
	return null
