extends RefCounted
## Cabin-face fittings of the donor rear leaf (spec 3): vent plate, molle panel with rails and a
## jerry can that stands into the cabin and blocks the player. The bays come from the leaf
## profile's cabin openings, so they always match the pressed body.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Skeleton := preload("res://scripts/van/rear_door_skeleton.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Can := preload("res://scripts/van/look/rear_door_jerry_can.gd")
const _Hinges := preload("res://scripts/van/look/rear_door_donor_hinges.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")
## Collision stays this far inside the opening's edges.
const CLEAR := 0.02
## How far the panel's rails and bolts stand into the cabin from the bay floor.
const PANEL_STAND := 0.05


## Builds the donor leaf's fittings under `hinge` and returns every node added.
static func build(hinge: Node3D, rng: RandomNumberGenerator) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var bays := _bays(hinge)
	if bays.size() < 2:
		return out
	_Panels.build_vent(hinge, bays[0], out)
	var plate := _Panels.molle_plate(bays[1])
	var can_rect := _Can.footprint(plate).grow(0.02)
	_Panels.build_molle(hinge, bays[1], [can_rect], rng, out)
	var can_box := _Can.build(hinge, plate, out)
	var body := StaticBody3D.new()
	body.name = "DonorCabinBody"
	body.collision_layer = 1
	body.collision_mask = 0
	hinge.add_child(body)
	out.append(body)
	_add_box(body, can_box)
	var inner := plate.grow(-CLEAR)
	var z0 := _Panels.PANEL_Z
	_add_box(body, AABB(Vector3(inner.position.x, inner.position.y, z0 - PANEL_STAND),
			Vector3(inner.size.x, inner.size.y, PANEL_STAND)))
	var rect := _leaf_rect(hinge)
	_Hinges.build(hinge, rect, rng, out)
	_Welds.build(hinge, rect, _LeafBuild.profile_for(true), rng, out)
	return out


## The leaf rect in hinge-local XY, the one the skin was pressed from.
static func _leaf_rect(hinge: Node3D) -> Rect2:
	return Rect2(0.0, _LeafBuild.Y_MIN - hinge.position.y, VanInteriorSize.REAR_DOOR_HALF
			- _LeafBuild.CENTER_GAP, VanInteriorSize.REAR_DOOR_TOP - _LeafBuild.Y_MIN)


## The vent bay and molle bay as hinge-local rects (bounds of the profile's two openings).
static func _bays(hinge: Node3D) -> Array[Rect2]:
	var profile := _LeafBuild.profile_for(true)
	var hy := hinge.position.y
	var rect := Rect2(0.0, _LeafBuild.Y_MIN - hy, VanInteriorSize.REAR_DOOR_HALF
			- _LeafBuild.CENTER_GAP, VanInteriorSize.REAR_DOOR_TOP - _LeafBuild.Y_MIN)
	var win := PackedVector2Array()
	for p: Vector2 in profile.window_hole:
		win.append(p + Vector2(_LeafBuild.WINDOW_X, VanOpenings.REAR_WINDOW_Y - hy))
	var out: Array[Rect2] = []
	for poly: PackedVector2Array in profile.cabin_openings(rect, win, _Skeleton.WIN_SLOPE):
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p: Vector2 in poly:
			lo = lo.min(p)
			hi = hi.max(p)
		out.append(Rect2(lo, hi - lo))
	return out


static func _add_box(body: StaticBody3D, box: AABB) -> void:
	var shape := BoxShape3D.new()
	shape.size = box.size
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = box.get_center()
	body.add_child(node)
