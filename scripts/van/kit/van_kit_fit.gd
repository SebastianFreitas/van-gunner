class_name VanKitFit
extends RefCounted
## Refits the van before the look rebuilds: side walls now, later phases add the rest.

const SIDE_WALLS_PATH := ^"../Interior/Shell/SideWalls"


static func apply(look: Node) -> void:
	var walls := look.get_node_or_null(SIDE_WALLS_PATH) as VanSideWall
	var windows: Array = []
	if walls:
		# One roll for the four side holes, handed in before the walls rebuild.
		windows = VanDonors.roll(look as VanLook).windows
		walls.set_window_cuts(windows)
		walls.rebuild()
	var side_windows := look.get_tree().get_first_node_in_group(&"side_windows")
	if walls and side_windows and side_windows.has_method(&"refit"):
		if side_windows.has_method(&"set_glazing"):
			side_windows.set_glazing(_glazing_by_window(windows, walls))
		side_windows.refit()
	var rear_doors := look.get_tree().get_first_node_in_group(&"rear_doors")
	if rear_doors and rear_doors.has_method(&"refit_windows"):
		var rear: Dictionary = {}
		for entry: Dictionary in windows:
			if entry[&"window_id"] == &"rear_left":
				rear[&"left"] = entry
			elif entry[&"window_id"] == &"rear_right":
				rear[&"right"] = entry
		rear_doors.refit_windows(rear)


## Side windows only: (wall sign, window index by mean z, as the wall holes are keyed) -> glazing.
static func _glazing_by_window(windows: Array, walls: VanSideWall) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in windows:
		var surface: StringName = entry[&"surface"]
		var opening: PackedVector2Array = entry[&"opening"]
		if (surface != &"left_wall" and surface != &"right_wall") or opening.is_empty():
			continue
		var mid_z := 0.0
		for p in opening:
			mid_z += p.x * 0.01 / float(opening.size())
		var idx := 0
		for i in walls.window_centers_z.size():
			if absf(walls.window_centers_z[i] - mid_z) < absf(walls.window_centers_z[idx] - mid_z):
				idx = i
		out[Vector2i(-1 if surface == &"left_wall" else 1, idx)] = entry[&"glazing"]
	return out
