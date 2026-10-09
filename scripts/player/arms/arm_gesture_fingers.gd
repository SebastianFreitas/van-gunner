extends RefCounted
## Straightens the claws at slam contact: the curl channel's scale only delivers about a third of a negative key.

const ArmGestureKeys := preload("res://scripts/player/arms/arm_gesture_keys.gd")

## Seconds before contact the straightening starts.
const LEAD := 0.05
## The negative curl key (degrees) that counts as fully flat.
const FLAT_KEY := 20.0


## Weight 0..1 of the flat claws: ease in over the lead, then the curl channel's own negative
## part, so the hold and the settle follow the keys. Press and push only (knock is a fist).
static func weight(kind: StringName, age: float, curl_mid: float) -> float:
	if kind != &"press" and kind != &"push":
		return 0.0
	var contact: float = ArmGestureKeys.CONTACT[kind]
	if age < contact - LEAD:
		return 0.0
	if age < contact:
		var x := (age - (contact - LEAD)) / LEAD
		return x * x
	return clampf(-curl_mid / FLAT_KEY, 0.0, 1.0)


## Slerps every finger joint toward its rest rotation (the dump's zero curl) by `w`, keeping the
## fan `spread` (index/pinky, ring; as ArmGesture._dress) on each finger's first joint.
static func straighten(sk: Skeleton3D, joints: Array[int], w: float, spread: Vector2) -> void:
	if w <= 0.0:
		return
	for n in joints.size():
		var i := joints[n]
		if i == -1:
			continue
		var rest := sk.get_bone_rest(i).basis.get_rotation_quaternion()
		var f := floori(n / 3.0)
		var fan := spread.x if f == 0 else (-spread.y if f == 2 else (-spread.x if f == 3 else 0.0))
		if n % 3 == 0 and fan != 0.0:
			rest *= Quaternion(Vector3.BACK, deg_to_rad(fan))
		sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(rest, w))
