extends RefCounted
## A window breach point's iron bars and glass: lookup, damage stage, break, repair and pane shatter.

var _point: BreachPoint
var _glass_cleared := false
## Last damage stage sent to the window bars (0 sound .. 2 nearly gone).
var _bars_stage := 0


func _init(point: BreachPoint) -> void:
	_point = point


## The window's IronCross (swapped to BrokenIronCross when breached): the `opening_bars` group
## member whose opening_id matches. Null, with an error naming the id, when none or two match.
func find_bars() -> Node:
	var found: Array[Node] = []
	for n in _point.get_tree().get_nodes_in_group(&"opening_bars"):
		if n.get(&"opening_id") == _point.opening_id:
			found.append(n)
	if found.size() != 1:
		push_error(
			"BreachPoint %s: %d bars with opening id '%s'"
			% [_point.name, found.size(), _point.opening_id]
		)
		return null
	return found[0]


## Bend the window bars as HP drops: stage 0 above 2/3, 1 above 1/3, else 2.
func update_stage() -> void:
	if not _is_window():
		return
	if _point.is_breached:
		return
	var frac := _point.health / _point.max_health if _point.max_health > 0.0 else 1.0
	var stage := 0
	if frac <= 1.0 / 3.0:
		stage = 2
	elif frac <= 2.0 / 3.0:
		stage = 1
	if stage == _bars_stage:
		return
	_bars_stage = stage
	var bars := find_bars()
	if bars and bars.has_method(&"set_damage_stage"):
		bars.call(&"set_damage_stage", stage)


func repair_visual() -> void:
	var bars := find_bars()
	if bars == null:
		return
	if bars.has_method("repair_bars"):
		bars.repair_bars()
	elif bars is Node3D:
		(bars as Node3D).visible = true


func break_bars() -> void:
	var bars := find_bars()
	if bars == null:
		return
	if bars.has_method("break_bars"):
		bars.break_bars()
	elif bars is Node3D:
		(bars as Node3D).visible = false


func shatter_glass_if_needed() -> void:
	if _glass_cleared:
		return
	if not _is_window():
		return
	_glass_cleared = true
	var bars := find_bars()
	if bars == null:
		return
	var host := bars.get_parent()
	if host == null:
		return
	var glass := host.get_node_or_null("BreakableGlass")
	if glass == null:
		return
	if glass.has_method("is_intact") and not glass.is_intact():
		return
	if glass.has_method("take_damage"):
		var dmg := 1.0
		if "max_health" in glass:
			dmg = maxf(float(glass.max_health), 1.0)
		glass.take_damage(dmg)


func _is_window() -> bool:
	return _point.kind == BreachPoint.Kind.WINDOW or _point.kind == BreachPoint.Kind.SIDE_DOOR_WINDOW
