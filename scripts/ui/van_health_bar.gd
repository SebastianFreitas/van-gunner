class_name VanHealthBar
extends Control

## Single hull line: left half = interior vitals (death HP), right half = doors.

const _VITALS := Color(0.86, 0.64, 0.28, 1.0)
const _DOORS := Color(0.42, 0.52, 0.58, 1.0)
const _BG := Color(0.10, 0.10, 0.09, 1.0)
const _DIVIDER := Color(0.06, 0.06, 0.05, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 18)
	GameSession.van_health_changed.connect(_on_changed)
	call_deferred("_bind_doors")


func _exit_tree() -> void:
	if GameSession.van_health_changed.is_connected(_on_changed):
		GameSession.van_health_changed.disconnect(_on_changed)


func _bind_doors() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(&"breach_points"):
		var point := node as BreachPoint
		if point == null or not point.is_door_kind():
			continue
		if not point.health_changed.is_connected(_on_changed):
			point.health_changed.connect(_on_changed)
	queue_redraw()


func _on_changed(_current: float = 0.0, _maximum: float = 0.0) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	draw_rect(rect, _BG)
	var half_w := rect.size.x * 0.5
	var vitals_t := 0.0
	if GameSession.get_max_van_health() > 0.001:
		vitals_t = clampf(
			GameSession.van_health / GameSession.get_max_van_health(), 0.0, 1.0
		)
	var doors_t := _door_integrity()
	if vitals_t > 0.0:
		draw_rect(Rect2(0.0, 0.0, half_w * vitals_t, rect.size.y), _VITALS)
	if doors_t > 0.0:
		draw_rect(
			Rect2(half_w, 0.0, half_w * doors_t, rect.size.y),
			_DOORS
		)
	draw_rect(Rect2(half_w - 1.0, 0.0, 2.0, rect.size.y), _DIVIDER)


func _door_integrity() -> float:
	if not is_inside_tree():
		return 1.0
	var total := 0.0
	var count := 0
	for node: Node in get_tree().get_nodes_in_group(&"breach_points"):
		var point := node as BreachPoint
		if point == null or not point.is_door_kind():
			continue
		count += 1
		if point.max_health > 0.001:
			total += clampf(point.health / point.max_health, 0.0, 1.0)
	if count == 0:
		return 1.0
	return total / float(count)
