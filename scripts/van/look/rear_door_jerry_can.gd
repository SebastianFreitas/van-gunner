extends RefCounted
## The donor leaf's black jerry can (spec 3): a flat plastic can lying on the molle panel's lower
## hinge-side half, cap at its top latch-side corner, held by two steel straps bolted to the
## panel, with a box collider so it eats cabin space and swings with the door.

const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")

const SIZE := Vector3(0.42, 0.32, 0.16)
const STRAP_W := 0.04
const STRAP_T := 0.008
const FOOT := 0.045
## Ribs, grip and strap legs stand this far clear of the can body (audit: >= 15 mm).
const GAP := 0.016
## Strap x offsets from the can centre.
const STRAP_X: Array[float] = [-0.12, 0.12]
## Standoff of the can's back from the panel plate face (0: it rests on the plate).
const CAN_BACK_Z := _Panels.PLATE_FACE_Z


## The can's centre for a molle plate rect: lower hinge-side corner, clear of the plate edges.
static func centre(plate: Rect2) -> Vector2:
	return Vector2(plate.position.x + 0.14 + SIZE.x * 0.5, plate.position.y + 0.14 + SIZE.y * 0.5)


## XY rect the can and its straps cover (the slot grid skips it).
static func footprint(plate: Rect2) -> Rect2:
	var c := centre(plate)
	var h := Vector2(SIZE.x * 0.5, SIZE.y * 0.5 + STRAP_T + GAP + FOOT)
	return Rect2(c - h, h * 2.0)


## Can, straps and bolts under `parent`; returns the collision box (centre, size) in hinge space.
static func build(parent: Node3D, plate: Rect2, out: Array[Node3D]) -> AABB:
	var c := centre(plate)
	var cz := CAN_BACK_Z - SIZE.z * 0.5
	var face_z := CAN_BACK_Z - SIZE.z
	var black := _Panels.flat(Color(0.05, 0.05, 0.055), 0.92, 0.0)
	var dark := _Panels.flat(Color(0.015, 0.015, 0.02), 0.95, 0.0)
	var strap := _Panels.flat(Color(0.2, 0.17, 0.14), 0.8, 0.25)
	var steel := _Panels.flat(Color(0.3, 0.29, 0.27), 0.75, 0.3)
	_Panels.add(parent, "JerryCan", _Panels.box(SIZE), black, Vector3(c.x, c.y, cz),
			Vector3.ZERO, out)
	# Shoulder step on the top and the cap at the latch-side corner.
	_Panels.add(parent, "JerryCanShoulder", _Panels.box(Vector3(SIZE.x * 0.5, 0.03, SIZE.z * 0.7)),
			black, Vector3(c.x + SIZE.x * 0.2, c.y + SIZE.y * 0.5 + 0.015, cz),
			Vector3.ZERO, out)
	var spout := CylinderMesh.new()
	spout.top_radius = 0.032
	spout.bottom_radius = 0.032
	spout.height = 0.05
	spout.radial_segments = 8
	spout.rings = 1
	_Panels.add(parent, "JerryCanCap", spout, black,
			Vector3(c.x + SIZE.x * 0.38, c.y + SIZE.y * 0.5 + 0.055, cz), Vector3.ZERO, out)
	# Dark grip pad on the hinge side and three moulded ribs across the face.
	_Panels.add(parent, "JerryCanGrip", _Panels.box(Vector3(0.13, 0.07, GAP)), dark,
			Vector3(c.x - SIZE.x * 0.25, c.y + SIZE.y * 0.28, face_z - GAP * 0.5), Vector3.ZERO, out)
	for i: int in 3:
		_Panels.add(parent, "JerryCanRib", _Panels.box(Vector3(SIZE.x * 0.8, 0.03, GAP)),
				black, Vector3(c.x, c.y - 0.02 - float(i) * 0.07, face_z - GAP * 0.5),
				Vector3.ZERO, out)
	for sx: float in STRAP_X:
		_strap(parent, c.x + sx, c.y, cz, face_z, strap, steel, out)
	# The box reaches past the straps (GAP * 2 + STRAP_T off the face) and over the cap.
	var proud := GAP * 2.0 + STRAP_T
	var half := Vector3(SIZE.x * 0.5, SIZE.y * 0.5 + 0.08, (SIZE.z + proud) * 0.5)
	return AABB(Vector3(c.x, c.y, cz - proud * 0.5) - half, half * 2.0)


## One steel strap: over the face, across the top and bottom to foot tabs bolted to the panel.
static func _strap(parent: Node3D, x: float, y: float, cz: float, face_z: float,
		strap: Material, steel: Material, out: Array[Node3D]) -> void:
	var half_y := SIZE.y * 0.5
	_Panels.add(parent, "StrapFace", _Panels.box(Vector3(STRAP_W,
			SIZE.y + 2.0 * (GAP + STRAP_T) + 0.008,
			STRAP_T)), strap, Vector3(x, y, face_z - 2.0 * GAP - STRAP_T * 0.5), Vector3.ZERO, out)
	var bolt := CylinderMesh.new()
	bolt.top_radius = 0.013
	bolt.bottom_radius = 0.013
	bolt.height = 0.012
	bolt.radial_segments = 6
	bolt.rings = 1
	for s: float in [-1.0, 1.0]:
		_Panels.add(parent, "StrapLeg", _Panels.box(Vector3(STRAP_W, STRAP_T, SIZE.z + 0.044)),
				strap, Vector3(x, y + s * (half_y + GAP + STRAP_T * 0.5), cz - 0.014), Vector3.ZERO, out)
		_Panels.add(parent, "StrapFoot", _Panels.box(Vector3(STRAP_W, FOOT, STRAP_T)), strap,
				Vector3(x, y + s * (half_y + GAP + STRAP_T + FOOT * 0.5), CAN_BACK_Z - STRAP_T * 0.5),
				Vector3.ZERO, out)
		_Panels.add(parent, "StrapBolt", bolt, steel, Vector3(x,
				y + s * (half_y + GAP + STRAP_T + FOOT * 0.5), CAN_BACK_Z - STRAP_T - 0.006),
				Vector3(PI * 0.5, 0.0, 0.0), out)
