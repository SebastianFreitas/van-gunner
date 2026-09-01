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


## Prefer open/breached rear doors, then free rear to smash, then windows.
func assign_breach_point(raider: Node) -> BreachPoint:
	var points := _all_points()
	if points.is_empty():
		return null

	var passable_rear: Array[BreachPoint] = []
	var free_rear: Array[BreachPoint] = []
	var passable_windows: Array[BreachPoint] = []
	var free_windows: Array[BreachPoint] = []

	for point in points:
		var is_rear := point.kind == BreachPoint.Kind.REAR_DOOR
		if point.is_passable():
			if is_rear:
				passable_rear.append(point)
			else:
				passable_windows.append(point)
			continue
		if not point.has_vacancy():
			continue
		if is_rear:
			free_rear.append(point)
		else:
			free_windows.append(point)

	var pick := _pick_random(passable_rear)
	if pick == null:
		pick = _pick_random(free_rear)
	if pick == null:
		pick = _pick_random(passable_windows)
	if pick == null:
		pick = _pick_random(free_windows)
	if pick == null:
		# Everything busy — send them to the least-contested slot so swarms keep moving.
		points.sort_custom(func(a: BreachPoint, b: BreachPoint) -> bool:
			if a.occupant_count() == b.occupant_count():
				return a.priority < b.priority
			return a.occupant_count() < b.occupant_count()
		)
		pick = points[0]

	# Reserve closed slots immediately so two spawns don't share one rear door.
	if pick and not pick.is_passable():
		pick.claim(raider)
	return pick


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
