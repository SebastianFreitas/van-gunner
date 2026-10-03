extends RefCounted
## Gun inspect on the goblin arms: a keyed one-shot that turns the held gun and right forearm to show both sides, then raises the left hand to show its back, palm and both sides of the forearm.
##
## Rigid offsets of each arm root about a pivot (the right one about the gun grip, so gun and
## right arm turn together; the left one about the resting left wrist), written on top of the
## other layers. The finger weave keeps running on top. Keys are first guesses, tuned with
## `arms inspect <sec>`.

## Keys of t (s from start), pos (rig-space root offset, virtual metres: camera at origin,
## -Z forward, +X right, +Y up) and rot (degrees: x pitch, y yaw, z roll about the forward axis;
## roll applies first, then pitch, then yaw).
const RIGHT_KEYS: Array[Dictionary] = [
	{&"t": 0.0, &"pos": Vector3(0, 0, 0), &"rot": Vector3(0, 0, 0)},
	{&"t": 0.30, &"pos": Vector3(-0.25, 0.22, 0.30), &"rot": Vector3(0, 70, 0)},  # gun's left side to the eye
	{&"t": 0.50, &"pos": Vector3(-0.25, 0.24, 0.30), &"rot": Vector3(5, 65, 10)},
	{&"t": 0.75, &"pos": Vector3(-0.25, 0.22, 0.30), &"rot": Vector3(0, 70, 150)},  # rolled over: the right side
	{&"t": 0.92, &"pos": Vector3(-0.25, 0.24, 0.30), &"rot": Vector3(5, 65, 140)},
	{&"t": 1.12, &"pos": Vector3(-0.30, 0.10, 0.20), &"rot": Vector3(-30, 45, -50)},  # forearm swept across, inner side up
	{&"t": 1.28, &"pos": Vector3(-0.10, 0.05, 0.12), &"rot": Vector3(-20, 25, 30)},  # rolled back, sweeping out
	{&"t": 1.45, &"pos": Vector3(0, 0, 0), &"rot": Vector3(0, 0, 0)},
]

## Same format as RIGHT_KEYS, for the left arm root.
const LEFT_KEYS: Array[Dictionary] = [
	{&"t": 1.35, &"pos": Vector3(0, 0, 0), &"rot": Vector3(0, 0, 0)},
	{&"t": 1.60, &"pos": Vector3(0.55, 0.45, 0.30), &"rot": Vector3(70, 0, -80)},  # hand up, back of the hand to the eye
	{&"t": 1.80, &"pos": Vector3(0.55, 0.47, 0.30), &"rot": Vector3(70, 5, -70)},
	{&"t": 2.05, &"pos": Vector3(0.55, 0.45, 0.30), &"rot": Vector3(70, 0, 80)},  # turned: the palm
	{&"t": 2.25, &"pos": Vector3(0.55, 0.47, 0.30), &"rot": Vector3(70, -5, 70)},
	{&"t": 2.50, &"pos": Vector3(0.75, 0.25, 0.10), &"rot": Vector3(-10, -45, 80)},  # forearm laid across, inner side up
	{&"t": 2.72, &"pos": Vector3(0.45, 0.25, 0.10), &"rot": Vector3(-10, -45, -80)},  # rolled: the outer forearm and its tattoo
	{&"t": 3.00, &"pos": Vector3(0, 0, 0), &"rot": Vector3(0, 0, 0)},
]

var _right_pivot := Vector3.ZERO
var _left_pivot := Vector3.ZERO
var _playing := false
var _start := 0.0
var _r := Transform3D.IDENTITY
var _l := Transform3D.IDENTITY


func _init(right_pivot: Vector3, left_pivot: Vector3) -> void:
	_right_pivot = right_pivot
	_left_pivot = left_pivot


func play(now: float) -> void:
	_playing = true
	_start = now


func clear() -> void:
	_playing = false
	_r = Transform3D.IDENTITY
	_l = Transform3D.IDENTITY


func is_playing(now: float) -> bool:
	return _playing and now >= _start and now - _start < duration()


func duration() -> float:
	var right_end := RIGHT_KEYS[RIGHT_KEYS.size() - 1][&"t"] as float
	var left_end := LEFT_KEYS[LEFT_KEYS.size() - 1][&"t"] as float
	return maxf(right_end, left_end)


func step(now: float, pinned_t: float) -> void:
	if pinned_t >= 0.0:
		_pose(pinned_t)
		return
	if SaveSandbox.enabled:
		# Keeps smoke stills comparable.
		clear()
		return
	# Also covers a wrapped clock putting now before the start.
	if not is_playing(now):
		clear()
		return
	_pose(now - _start)


func right_offset() -> Transform3D:
	return _r


func left_offset() -> Transform3D:
	return _l


func _pose(a: float) -> void:
	_r = _sample(RIGHT_KEYS, a, _right_pivot)
	_l = _sample(LEFT_KEYS, a, _left_pivot)


## Interpolates the keys at age a (smoothstep between neighbours); rest pose outside them.
static func _sample(keys: Array[Dictionary], a: float, pivot: Vector3) -> Transform3D:
	if a < (keys[0][&"t"] as float) or a >= (keys[keys.size() - 1][&"t"] as float):
		return Transform3D.IDENTITY
	for n in keys.size() - 1:
		var k0: Dictionary = keys[n]
		var k1: Dictionary = keys[n + 1]
		var t0 := k0[&"t"] as float
		var t1 := k1[&"t"] as float
		if a >= t0 and a < t1:
			var f := smoothstep(0.0, 1.0, (a - t0) / (t1 - t0))
			# Component-wise lerp, never slerp: a roll from -80 to 80 must pass through 0.
			var pos := (k0[&"pos"] as Vector3).lerp(k1[&"pos"] as Vector3, f)
			var rot := (k0[&"rot"] as Vector3).lerp(k1[&"rot"] as Vector3, f)
			return _about(pivot, pos, rot)
	return Transform3D.IDENTITY


static func _about(pivot: Vector3, pos: Vector3, rot_deg: Vector3) -> Transform3D:
	var r := rot_deg * (PI / 180.0)
	var b := Basis(Vector3.UP, r.y) * Basis(Vector3.RIGHT, r.x) * Basis(Vector3.BACK, r.z)
	var p := Transform3D(Basis.IDENTITY, pivot)
	return Transform3D(Basis.IDENTITY, pos) * p * Transform3D(b, Vector3.ZERO) \
			* p.affine_inverse()
