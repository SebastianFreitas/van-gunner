extends RefCounted
## Poses the side doors and windows into closed / half / open states directly, with no
## tweens and no gameplay calls, so the audit's flicker/clip/opening checks can look at
## every pose (vanfix spec 1-2). Reads exported distances and angles from the scene's own
## door and window nodes rather than duplicating their numbers.

const WINDOW_NAMES: Dictionary = {
	&"win_left_rear": "LeftRear",
	&"win_left_front": "LeftFront",
	&"win_right_rear": "RightRear",
	&"win_right_front": "RightFront",
}
const FRONT_WINDOWS: Array[StringName] = [&"win_left_front", &"win_right_front"]

var _doors: Node3D  # untyped SideDoors owner; side_doors.gd has no class_name (cycle rule)
var _windows: Node3D  # untyped SideWindows owner; side_windows.gd has no class_name

var _door_leaf: Dictionary = {}  # side (&"left"/&"right") -> Node3D
var _door_grip: Dictionary = {}
var _door_mount: Dictionary = {}
var _door_leaf_closed: Dictionary = {}  # side -> Vector3 local position
var _door_grip_closed: Dictionary = {}
var _door_mount_closed: Dictionary = {}

var _win_hinge: Dictionary = {}  # label -> Node3D
var _win_hinge_closed_z: Dictionary = {}  # label -> float


func _init(rig: Node3D) -> void:
	_doors = VanAnchors.side_doors(rig.get_tree())
	_windows = VanAnchors.side_windows(rig.get_tree())

	for side in [&"left", &"right"]:
		var leaf_name: String = "Left" if side == &"left" else "Right"
		var leaf: Node3D = _doors.get_node(leaf_name) as Node3D
		var grip: Node3D = leaf.get_node(^"Handle/Grip") as Node3D
		var mount: Node3D = leaf.get_node(^"Handle/Mount") as Node3D
		_door_leaf[side] = leaf
		_door_grip[side] = grip
		_door_mount[side] = mount
		_door_leaf_closed[side] = leaf.position
		_door_grip_closed[side] = grip.position
		_door_mount_closed[side] = mount.position

	for label in WINDOW_NAMES.keys():
		var node_name: String = "%s/Hinge" % String(WINDOW_NAMES[label])
		var hinge: Node3D = _windows.get_node(node_name) as Node3D
		_win_hinge[label] = hinge
		_win_hinge_closed_z[label] = hinge.rotation.z


## label (door_left, door_right, win_left_rear, ...) -> Node3D (door leaf / window hinge).
## Triangles whose node is that root or under it belong to it.
func moving_roots() -> Dictionary:
	var roots: Dictionary = {}
	roots[&"door_left"] = _door_leaf[&"left"]
	roots[&"door_right"] = _door_leaf[&"right"]
	for label in _win_hinge.keys():
		roots[label] = _win_hinge[label]
	return roots


## Sets the side doors and the two rear windows directly. 0.0 is the recorded closed pose.
## The front windows stay put: play forbids one open while its door is.
func pose(fraction: float) -> void:
	for side in [&"left", &"right"]:
		_pose_door(side, fraction)
	for label in _win_hinge.keys():
		if not FRONT_WINDOWS.has(label):
			_pose_window(label, fraction)


## Sets only the two front windows; doors and rear windows are left as they are.
func pose_front(fraction: float) -> void:
	for label in FRONT_WINDOWS:
		_pose_window(label, fraction)


func _pose_door(side: StringName, fraction: float) -> void:
	_windows.set_front_hinges_visible(side, fraction <= 0.0)  # Mirrors play: hinges hide while its door is open (bars stay).
	var leaf: Node3D = _door_leaf[side]
	var grip: Node3D = _door_grip[side]
	var mount: Node3D = _door_mount[side]
	var closed_pos: Vector3 = _door_leaf_closed[side]
	var grip_closed: Vector3 = _door_grip_closed[side]
	var mount_closed: Vector3 = _door_mount_closed[side]

	if fraction <= 0.0:
		leaf.position = closed_pos
		grip.position = grip_closed
		mount.position = mount_closed
		return

	# Same axes and signs as side_doors.gd's open tween (_inward_axis, _into_door_axis).
	var inward: Vector3 = Vector3.RIGHT if side == &"left" else Vector3.LEFT
	var into_door: Vector3 = Vector3.LEFT if side == &"left" else Vector3.RIGHT
	var recess_distance: float = _doors.recess_distance
	var slide_distance: float = _doors.slide_distance
	var grip_retract_distance: float = _doors.grip_retract_distance
	var mount_retract_distance: float = _doors.mount_retract_distance

	var recessed_pos: Vector3 = closed_pos + inward * recess_distance
	leaf.position = recessed_pos + Vector3(0.0, 0.0, slide_distance * fraction)
	grip.position = grip_closed + into_door * grip_retract_distance
	mount.position = mount_closed + into_door * mount_retract_distance


func _pose_window(label: StringName, fraction: float) -> void:
	var hinge: Node3D = _win_hinge[label]
	var closed_z: float = _win_hinge_closed_z[label]
	var is_left: bool = label == &"win_left_rear" or label == &"win_left_front"
	# Same axis and sign as side_windows.gd's _open_rotation_z.
	var angle: float = deg_to_rad(float(_windows.open_angle_deg))
	var signed_angle: float = -angle if is_left else angle
	hinge.rotation.z = closed_z + fraction * signed_angle
