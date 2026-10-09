extends RefCounted
## Derives a breach point's Outside and Entry marker transforms from its VanOpenings opening.

## Opening ids: side_door_l/r, window_l_0/1 and window_r_0/1 (0 = rear window), rear_door_l/r,
## rear_window_l/r. Left is -x.

## Marker height for door and side-window points (the raider's claws stand on the floor).
const MARKER_Y := 1.62
## Outside margin past the outer skin (side door, side window) and the rear face.
const SIDE_DOOR_OUT := 0.59
const SIDE_WINDOW_OUT := 0.04
const REAR_DOOR_OUT := 0.5
const REAR_WINDOW_OUT := 0.45
## Entry margin inside the liner (side) or in from the rear face / window hole (rear).
const SIDE_IN := 0.67
const REAR_DOOR_IN := 0.8
const REAR_WINDOW_IN := 0.64


## Returns [outside, entry] van-local transforms, or an empty array for an unknown id.
static func transforms(id: StringName) -> Array[Transform3D]:
	var s := String(id)
	var side := -1.0 if s.ends_with("_l") or s.contains("_l_") else 1.0
	var out: Array[Transform3D] = []
	if s.begins_with("side_door"):
		var b := VanOpenings.side_door_aabb(int(side))
		out = _side(side, b.get_center().z, SIDE_DOOR_OUT)
	elif s.begins_with("window_"):
		var b := VanOpenings.side_window_aabb(int(side), int(s.get_slice("_", 2)))
		out = _side(side, b.get_center().z, SIDE_WINDOW_OUT)
	elif s.begins_with("rear_door"):
		var cx := side * VanInteriorSize.REAR_DOOR_HALF * 0.5
		out = _rear(cx, MARKER_Y, VanInteriorSize.REAR_Z + REAR_DOOR_OUT,
				VanInteriorSize.REAR_Z - REAR_DOOR_IN)
	elif s.begins_with("rear_window"):
		var b := VanOpenings.rear_window_aabb(int(side))
		out = _rear(b.get_center().x, b.get_center().y, b.end.z + REAR_WINDOW_OUT,
				b.position.z - REAR_WINDOW_IN)
	return out


static func _side(side: float, z: float, out_margin: float) -> Array[Transform3D]:
	var basis := Basis(Vector3.UP, side * PI * 0.5)
	var outer_x := side * (VanInteriorSize.BOTTOM_HALF + VanOpenings.SKIN + out_margin)
	var inner_x := side * (VanInteriorSize.BOTTOM_HALF - SIDE_IN)
	return [Transform3D(basis, Vector3(outer_x, MARKER_Y, z)),
			Transform3D(basis, Vector3(inner_x, MARKER_Y + VanFloorHeight.at(inner_x, z), z))]


static func _rear(x: float, y: float, out_z: float, in_z: float) -> Array[Transform3D]:
	var basis := Basis(Vector3.UP, PI)
	return [Transform3D(basis, Vector3(x, y, out_z)), Transform3D(basis, Vector3(x, y, in_z))]
