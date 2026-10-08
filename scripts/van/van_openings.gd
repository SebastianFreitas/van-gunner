class_name VanOpenings
extends RefCounted
## The side door, side window, cab and rear window hole sizes (rig-local metres); the shell builders read these. The rear door size and the rear window x live in `VanInteriorSize`.

## Outer skin thickness beyond the inner liner.
const SKIN := VanBodyProfile.WALL_THICKNESS

## Side door: opening half length along z, centre z, floor and head heights, and the sliding
## leaf's blocker length.
const SIDE_DOOR_HALF := 1.235
const SIDE_DOOR_Z := -3.164
const SIDE_DOOR_Y_MIN := 0.02
const SIDE_DOOR_HEIGHT := 3.05
const SIDE_DOOR_LEAF_LEN := 2.53

## Side windows: centre height, centre z (rear, front) and half size (z, y).
const SIDE_WINDOW_Y := 1.775
const SIDE_WINDOW_Z_REAR := 4.342
const SIDE_WINDOW_Z_FRONT := -0.45
const SIDE_WINDOW_HALF_Z := 1.222
const SIDE_WINDOW_HALF_Y := 0.707

## Cab door in the front wall: half width and head height.
const CAB_DOOR_HALF := 0.775
const CAB_DOOR_HEIGHT := 2.30
## Front wall cab-side and interior faces.
const CAB_WALL_BACK_Z := VanInteriorSize.FRONT_Z - 0.05
const CAB_WALL_FACE_Z := VanInteriorSize.FRONT_Z + 0.15

## Rear window: centre height, half size (x, y) and the z span of the leaf's hole (the leaf
## reaches from 0.17 cabin side of the 6.59 hinge to 0.04 under its street face at 0.08).
const REAR_WINDOW_Y := 1.775
const REAR_WINDOW_HALF_X := 0.99
const REAR_WINDOW_HALF_Y := 0.775
const REAR_WINDOW_Z_MIN := 6.42
const REAR_WINDOW_DEPTH := 0.21

## Bulkhead between the cab and the back room.
const BULKHEAD_Z := 1.0


## Side window centres, rear first.
static func side_window_centers_z() -> PackedFloat32Array:
	return PackedFloat32Array([SIDE_WINDOW_Z_REAR, SIDE_WINDOW_Z_FRONT])


## Wall slab x range for one side (liner at the floor out to the skin).
static func _wall_x_range(side: int) -> Vector2:
	var a := float(side) * VanInteriorSize.BOTTOM_HALF
	var b := float(side) * (VanInteriorSize.BOTTOM_HALF + SKIN)
	return Vector2(minf(a, b), maxf(a, b))


static func side_door_aabb(side: int) -> AABB:
	var x := _wall_x_range(side)
	return AABB(Vector3(x.x, SIDE_DOOR_Y_MIN, SIDE_DOOR_Z - SIDE_DOOR_HALF),
			Vector3(x.y - x.x, SIDE_DOOR_HEIGHT - SIDE_DOOR_Y_MIN, SIDE_DOOR_HALF * 2.0))


## Window `index` 0 is the rear one, 1 the front one.
static func side_window_aabb(side: int, index: int) -> AABB:
	var x := _wall_x_range(side)
	var z: float = side_window_centers_z()[index]
	return AABB(Vector3(x.x, SIDE_WINDOW_Y - SIDE_WINDOW_HALF_Y, z - SIDE_WINDOW_HALF_Z),
			Vector3(x.y - x.x, SIDE_WINDOW_HALF_Y * 2.0, SIDE_WINDOW_HALF_Z * 2.0))


## Bounding box of the leaf's window hole; its centre sits REAR_DOOR_HALF - REAR_WINDOW_X from
## the middle, on the hinge side's leaf.
static func rear_window_aabb(side: int) -> AABB:
	var cx := float(side) * (VanInteriorSize.REAR_DOOR_HALF - VanInteriorSize.REAR_WINDOW_X)
	return AABB(Vector3(cx - REAR_WINDOW_HALF_X, REAR_WINDOW_Y - REAR_WINDOW_HALF_Y,
			REAR_WINDOW_Z_MIN),
			Vector3(REAR_WINDOW_HALF_X * 2.0, REAR_WINDOW_HALF_Y * 2.0, REAR_WINDOW_DEPTH))


static func cab_door_aabb() -> AABB:
	return AABB(Vector3(-CAB_DOOR_HALF, 0.0, CAB_WALL_BACK_Z),
			Vector3(CAB_DOOR_HALF * 2.0, CAB_DOOR_HEIGHT, CAB_WALL_FACE_Z - CAB_WALL_BACK_Z))
