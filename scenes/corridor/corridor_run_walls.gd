extends RefCounted
## Wall collision for a side whose ground runs recess: one box per run, one closing each step between
## runs and one per tile-end pier, on a StaticBody3D `RunWallsLeft` / `RunWallsRight` under the tile.

## Inner face of a flat wall (box centre x is this plus the run's recess).
const WALL_X := 9.0
## Inner face x of a tile-end pier before its recess is added.
const PIER_X := 8.8
## Box height, tall enough to match the two stacked tscn boxes (y -0.4..39.6).
const HEIGHT := 40.0
## Box centre height.
const CENTER_Y := 19.6
## Wall box thickness.
const THICK := 0.4
## Pier centre distance from the tile centre along z.
const PIER_Z := 9.8
## Pier thickness along z.
const PIER_THICK := 0.3
## Recess difference below which two runs count as one wall.
const EPS := 0.001


## True when the side is one flat run at the plain wall line, which the tscn boxes already cover.
static func is_plain(runs: Array[Vector4]) -> bool:
	return runs.is_empty() or (runs.size() == 1 and runs[0].z == 0.0)


static func body_name(side_idx: int) -> String:
	return "RunWallsLeft" if side_idx == 0 else "RunWallsRight"


## Tile-local boxes: one per run, one closing each step, one pier per recessed tile end.
static func boxes(runs: Array[Vector4], side_sign: float) -> Array[AABB]:
	var out: Array[AABB] = []
	for run: Vector4 in runs:
		var size := Vector3(THICK, HEIGHT, run.y - run.x)
		var centre := Vector3(side_sign * (WALL_X + run.z), CENTER_Y, (run.x + run.y) / 2.0)
		out.append(AABB(centre - size / 2.0, size))
	for i in range(1, runs.size()):
		var a := runs[i - 1].z
		var b := runs[i].z
		if absf(a - b) <= EPS:
			continue
		var zb := runs[i].x
		var size := Vector3(absf(a - b), HEIGHT, THICK)
		var cz := zb - THICK / 2.0 if a < b else zb + THICK / 2.0
		var centre := Vector3(side_sign * (WALL_X + (a + b) / 2.0), CENTER_Y, cz)
		out.append(AABB(centre - size / 2.0, size))
	if runs.is_empty():
		return out
	if runs[0].z > 0.0:
		out.append(_pier(runs[0].z, side_sign, -PIER_Z))
	if runs[-1].z > 0.0:
		out.append(_pier(runs[-1].z, side_sign, PIER_Z))
	return out


static func _pier(r: float, side_sign: float, z: float) -> AABB:
	var size := Vector3(r + THICK, HEIGHT, PIER_THICK)
	var centre := Vector3(side_sign * (PIER_X + (r + THICK) / 2.0), CENTER_Y, z)
	return AABB(centre - size / 2.0, size)


## Replaces the side's RunWalls body. Nothing is built for an open or plain side.
static func rebuild(owner: Node3D, side_idx: int, runs: Array[Vector4], open: bool) -> void:
	var old := owner.get_node_or_null(NodePath(body_name(side_idx)))
	if old != null:
		owner.remove_child(old)
		old.queue_free()
	if open or is_plain(runs):
		return
	var body := StaticBody3D.new()
	body.name = body_name(side_idx)
	body.collision_layer = 1
	body.collision_mask = 1
	for aabb: AABB in boxes(runs, -1.0 if side_idx == 0 else 1.0):
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = aabb.size
		shape.shape = box
		shape.position = aabb.get_center()
		body.add_child(shape)
	owner.add_child(body)
