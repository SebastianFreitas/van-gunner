class_name BreachController
extends Node3D

## Assigns raid slots around the van and exposes the bench damage target.

@onready var bench_marker: Marker3D = $BenchAttackMarker


func _ready() -> void:
	add_to_group(&"breach_controller")


func get_bench_position() -> Vector3:
	return bench_marker.global_position


func get_bench_basis() -> Basis:
	return bench_marker.global_basis


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
func next_closed_door(after: BreachPoint) -> BreachPoint:
	var rear := _closed_doors_of(BreachPoint.Kind.REAR_DOOR)
	if not rear.is_empty():
		return _next_after(rear, after)
	var side := _closed_doors_of(BreachPoint.Kind.SIDE_DOOR)
	if not side.is_empty():
		return _next_after(side, after)
	return null


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

	# Reserve closed slots immediately so two spawns don't share one door.
	if pick and not pick.is_passable():
		pick.claim(raider)
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
		var is_rear := point.kind == BreachPoint.Kind.REAR_DOOR
		if point.is_passable():
			if is_rear:
				passable_rear.append(point)
			else:
				passable_side.append(point)
			continue
		if not point.has_vacancy():
			continue
		if is_rear:
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
	if pick == null:
		pick = _least_contested(pool)
	return pick


func _pick_agile(pool: Array[BreachPoint]) -> BreachPoint:
	var passable_windows: Array[BreachPoint] = []
	var free_windows: Array[BreachPoint] = []

	for point in pool:
		if point.is_passable():
			passable_windows.append(point)
			continue
		if not point.has_vacancy():
			continue
		free_windows.append(point)

	var pick := _pick_best_priority(passable_windows)
	if pick == null:
		pick = _pick_best_priority(free_windows)
	if pick == null:
		pick = _least_contested(pool)
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


func _least_contested(points: Array[BreachPoint]) -> BreachPoint:
	if points.is_empty():
		return null
	var sorted := points.duplicate()
	sorted.sort_custom(func(a: BreachPoint, b: BreachPoint) -> bool:
		if a.occupant_count() == b.occupant_count():
			return a.priority < b.priority
		return a.occupant_count() < b.occupant_count()
	)
	return sorted[0]


func _all_points() -> Array[BreachPoint]:
	var result: Array[BreachPoint] = []
	for node in get_tree().get_nodes_in_group(&"breach_points"):
		if node is BreachPoint:
			result.append(node)
	result.sort_custom(func(a: BreachPoint, b: BreachPoint) -> bool:
		return a.priority < b.priority
	)
	return result


func _pick_random(points: Array[BreachPoint]) -> BreachPoint:
	if points.is_empty():
		return null
	return points[randi() % points.size()]


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


func _next_after(doors: Array[BreachPoint], after: BreachPoint) -> BreachPoint:
	if doors.is_empty():
		return null
	if after == null:
		return doors[0]
	var idx := doors.find(after)
	if idx < 0:
		return doors[0]
	return doors[(idx + 1) % doors.size()]
