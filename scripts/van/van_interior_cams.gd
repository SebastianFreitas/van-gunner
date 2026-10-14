class_name VanInteriorCams
extends Node3D
## Fixed Camera3Ds (rig-local) that look at every interior surface of the van: floor, ceiling, walls, doors, bulkhead and corners, for a tooling shooter; never current by itself. "Left" is +x (seen from inside facing the rear doors, right is x < 0). Every position derives from the van's size helpers. Each camera and its target stay in one compartment (mid: front wall to bulkhead, rear: bulkhead to rear doors).

const _NEAR := 0.05
const _FOV := 70.0
## Eye height above the floor, mirrors FpsPlayer.EYE_HEIGHT without a player in the tree.
const _EYE := FpsPlayer.EYE_HEIGHT
## Smallest distance a camera keeps from the bulkhead plane (m), from VanOpenings.
const _BULKHEAD_GAP := 0.3
## Inset of the corner cameras from the walls and ceiling (m).
const _CORNER_INSET := 0.3

## Camera name to [position, target] (rig-local), filled by `refresh`.
var _views: Dictionary = {}
## Camera names in creation order, filled by `refresh`.
var _order: PackedStringArray = PackedStringArray()


func _init() -> void:
	name = &"InteriorCams"


func _ready() -> void:
	refresh()


## Rebuilds every camera's position from the van's size helpers, creating missing cameras.
func refresh() -> void:
	_views.clear()
	_order = PackedStringArray()
	var mid_z := (VanInteriorSize.FRONT_Z + VanOpenings.BULKHEAD_Z) * 0.5
	var rear_z := (VanOpenings.BULKHEAD_Z + VanInteriorSize.REAR_Z) * 0.5
	var wall := VanInteriorSize.BOTTOM_HALF
	var top := VanInteriorSize.WALL_HEIGHT
	var stair := VanFloorHeight.STAIR_END_Z
	_add("floor_mid", Vector3(0.0, _f(0.0, VanInteriorSize.FRONT_Z + 1.0) + 2.6,
			VanInteriorSize.FRONT_Z + 1.0), Vector3(0.0, _f(0.0, mid_z), mid_z))
	_add("floor_rear", Vector3(0.0, _f(0.0, stair) + 2.6, stair),
			Vector3(0.0, _f(0.0, (stair + VanInteriorSize.REAR_Z) * 0.5),
			(stair + VanInteriorSize.REAR_Z) * 0.5))
	_add("ceiling_mid", Vector3(0.0, _f(0.0, mid_z) + 0.6, mid_z), Vector3(0.0, top, mid_z + 0.01))
	_add("ceiling_rear", Vector3(0.0, _f(0.0, rear_z) + 0.6, rear_z),
			Vector3(0.0, top, rear_z + 0.01))
	_add("piece_rear_left", Vector3(-3.0, _EYE, VanOpenings.BULKHEAD_Z + 0.4),
			Vector3(wall - 0.5, _EYE, 5.5))
	_add("salvage_seam", Vector3(0.9, 2.2, 3.9), Vector3(3.0, 2.0, 5.9))
	for side in [1, -1]:
		var tag := "left" if side > 0 else "right"
		for part in ["mid", "rear"]:
			var z := mid_z if part == "mid" else rear_z
			var cam_x := -float(side) * (wall - 0.5)
			var floor_y := _f(cam_x, z)
			_add("wall_%s_%s" % [tag, part], Vector3(cam_x, floor_y + _EYE, z),
					Vector3(float(side) * wall, (floor_y + top) * 0.5, z))
		var door_z := VanOpenings.SIDE_DOOR_Z
		var door_x := -float(side) * 1.0
		_add("side_door_" + tag, Vector3(door_x, _f(door_x, door_z) + _EYE, door_z),
				Vector3(float(side) * wall, VanOpenings.SIDE_DOOR_Y_MIN
				+ VanOpenings.SIDE_DOOR_HEIGHT * 0.5, door_z))
	var door_cam_z := VanOpenings.BULKHEAD_Z + _BULKHEAD_GAP
	_add("rear_doors", Vector3(0.0, _f(0.0, door_cam_z) + _EYE, door_cam_z),
			Vector3(0.0, VanInteriorSize.REAR_DOOR_TOP * 0.5, VanInteriorSize.REAR_Z))
	var bulk_cam_z := VanInteriorSize.REAR_Z - _BULKHEAD_GAP
	_add("bulkhead", Vector3(0.0, _f(0.0, bulk_cam_z) + _EYE, bulk_cam_z),
			Vector3(0.0, (_f(0.0, VanOpenings.BULKHEAD_Z) + top) * 0.5, VanOpenings.BULKHEAD_Z))
	var cab_cam_z := VanOpenings.BULKHEAD_Z - 0.5
	_add("cab_end", Vector3(0.0, _f(0.0, cab_cam_z) + _EYE, cab_cam_z),
			Vector3(0.0, (_f(0.0, VanInteriorSize.FRONT_Z) + top) * 0.5, VanInteriorSize.FRONT_Z))
	var corner_x := VanInteriorSize.TOP_HALF - _CORNER_INSET
	var corner_y := top - _CORNER_INSET
	_add("corner_front_left", Vector3(corner_x, corner_y, VanInteriorSize.FRONT_Z + _CORNER_INSET),
			Vector3(0.0, _f(0.0, mid_z), mid_z))
	_add("corner_rear_right", Vector3(-corner_x, corner_y, VanInteriorSize.REAR_Z - _CORNER_INSET),
			Vector3(0.0, _f(0.0, rear_z), rear_z))
	_add_prop_cams()


## Rebuilds one `prop_<name>` camera per interactive prop under the rig's Interior/Props from its
## live transform, and frees the ones left from an earlier refresh.
func _add_prop_cams() -> void:
	for child in get_children():
		if String(child.name).begins_with("prop_"):
			remove_child(child)
			child.free()
	var rig := get_parent()
	var props := rig.get_node_or_null(^"Interior/Props") if rig != null else null
	if props == null:
		return
	for prop in props.get_children():
		var prop3 := prop as Node3D
		if prop3 == null or not (prop3 is Interactable or _has_vital(prop3)):
			continue
		var view := _prop_view(prop3)
		if not view.is_empty():
			_add("prop_" + String(prop3.name).to_snake_case(), view[0], view[1])


## True when a direct child of `prop` is a van vital (the `van_vitals` group).
func _has_vital(prop: Node) -> bool:
	for child in prop.get_children():
		if child.is_in_group(&"van_vitals"):
			return true
	return false


## [camera position, target] in front of `prop`, or [] when it has no visuals.
func _prop_view(prop: Node3D) -> Array:
	var to_prop := prop.global_transform.affine_inverse()
	var box := AABB()
	var found := false
	# Meshes only: a work lamp's range and a particle volume would stretch the box far past the prop.
	for node in prop.find_children("*", "MeshInstance3D", true, false):
		var vis := node as MeshInstance3D
		var local_box: AABB = (to_prop * vis.global_transform) * vis.get_aabb()
		box = local_box if not found else box.merge(local_box)
		found = true
	if not found:
		return []
	var rel := global_transform.affine_inverse() * prop.global_transform
	var center := rel * box.get_center()
	var ax := rel.basis.x.length()
	var az := rel.basis.z.length()
	var size_x := box.size.x * ax
	var size_z := box.size.z * az
	var rh := maxf(size_x, size_z) * 0.5
	var ry := box.size.y * rel.basis.y.length() * 0.5
	var bulk := VanOpenings.BULKHEAD_Z
	var is_mid := center.z < bulk
	var z_min := (VanInteriorSize.FRONT_Z if is_mid else bulk + _BULKHEAD_GAP)
	var z_max := (bulk - _BULKHEAD_GAP if is_mid else VanInteriorSize.REAR_Z)
	var comp := Vector3(0.0, 0.0, ((VanInteriorSize.FRONT_Z if is_mid else bulk)
			+ (bulk if is_mid else VanInteriorSize.REAR_Z)) * 0.5)
	var front := Vector3.ZERO
	var thin := minf(size_x, size_z)
	var wide := maxf(size_x, size_z)
	if wide > 0.0 and thin / wide <= 1.0 / 1.5:
		front = _flat(rel.basis.x if size_x < size_z else rel.basis.z)
		if front.dot(_flat(comp - center)) < 0.0:
			front = -front
	else:
		var want := _flat(comp - rel.origin)
		var best := -INF
		for axis in [rel.basis.x, -rel.basis.x, rel.basis.z, -rel.basis.z]:
			var cand := _flat(axis)
			if cand.dot(want) > best:
				best = cand.dot(want)
				front = cand
	var dist := maxf(1.2, 1.25 * maxf(rh / 0.70, ry / 0.35))
	var at := center + front * dist
	var lim_x := VanInteriorSize.BOTTOM_HALF - 0.2
	at.x = clampf(at.x, -lim_x, lim_x)
	at.z = clampf(at.z, z_min + (0.2 if is_mid else 0.0),
			z_max - (0.0 if is_mid else 0.2))
	var top := VanInteriorSize.WALL_HEIGHT
	at.y = clampf(center.y, _f(at.x, at.z) + 0.3, top - 0.2)
	if Vector2(at.x - center.x, at.z - center.z).length() < 0.6:
		at.y = top - 0.3
	return [at, center]


## `v` flattened to the horizontal plane and normalised (zero stays zero).
func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


## The camera names, sorted.
func names() -> PackedStringArray:
	var found := _order.duplicate()
	found.sort()
	return found


## The camera called `cam_name`, or null.
func camera(cam_name: String) -> Camera3D:
	return get_node_or_null(NodePath(cam_name)) as Camera3D


## One line per view: its name, position and the point it looks at.
func describe() -> String:
	var lines := PackedStringArray()
	for cam_name in _order:
		var view: Array = _views[cam_name]
		lines.append("%s at %s looks at %s" % [cam_name, view[0], view[1]])
	return "\n".join(lines)


## The floor height at (x, z).
func _f(x: float, z: float) -> float:
	return VanFloorHeight.at(x, z)


## Creates or moves the camera `cam_name` to `at` looking at `target`, and checks the pair.
func _add(cam_name: String, at: Vector3, target: Vector3) -> void:
	var cam := camera(cam_name)
	if cam == null:
		cam = Camera3D.new()
		cam.name = cam_name
		cam.near = _NEAR
		cam.fov = _FOV
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		add_child(cam)
	_views[cam_name] = [at, target]
	_order.append(cam_name)
	_check(cam_name, at, target)
	if at.is_equal_approx(target):
		return
	# FORWARD as up keeps look_at valid for the near-vertical views, UP for the rest.
	var dir := (target - at).normalized()
	var up := Vector3.FORWARD if absf(dir.y) > 0.9 else Vector3.UP
	cam.transform = Transform3D(Basis.looking_at(dir, up), at)


## `push_error`s a camera outside its compartment box, a target in the other compartment, or a
## camera on its target.
func _check(cam_name: String, at: Vector3, target: Vector3) -> void:
	var bulk := VanOpenings.BULKHEAD_Z
	var is_mid := at.z < bulk
	var z_min := VanInteriorSize.FRONT_Z if is_mid else bulk
	var z_max := bulk if is_mid else VanInteriorSize.REAR_Z
	var floor_y := _f(at.x, at.z)
	if absf(at.x) >= VanInteriorSize.BOTTOM_HALF or at.y <= floor_y \
			or at.y >= VanInteriorSize.WALL_HEIGHT or at.z <= VanInteriorSize.FRONT_Z \
			or at.z >= VanInteriorSize.REAR_Z or absf(at.z - bulk) < _BULKHEAD_GAP - 0.001:
		push_error("VanInteriorCams: %s at %s is outside its compartment" % [cam_name, at])
	if target.z < z_min - 0.001 or target.z > z_max + 0.001:
		push_error("VanInteriorCams: %s target %s is in the other compartment" % [cam_name, target])
	if at.is_equal_approx(target):
		push_error("VanInteriorCams: %s sits on its target" % cam_name)
