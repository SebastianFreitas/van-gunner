extends RefCounted
## Gun inspect on the goblin arms: a keyed one-shot that raises the left hand to show its tattoo, then turns the held gun to show both sides while the right arm re-solves to keep the shoulder put.
##
## The right root is offset rigidly about the gun grip (so gun and right arm turn together) and the
## right arm is re-solved against that offset each frame; the left arm is re-solved to the keys.
## The finger weave keeps running on top. Keys are in `arm_inspect_keys.gd`, tuned with
## `arms inspect <sec>`.

const Solve := preload("res://scripts/player/arms/arm_inspect_solve.gd")
const Keys := preload("res://scripts/player/arms/arm_inspect_keys.gd")

## Blend-out lengths: `release` (D10) and `clear` (D5).
const RELEASE_TIME := 0.30
const CLEAR_TIME := 0.15
## Shape of the blend weight: `w = 1 - ease(p)`; "out" is 1-(1-p)^2, anything else smoothstep.
const W_EASE := &"smooth"

## Debug: with an inspect pin and this >= 0, the pinned pose is shown under a `clear()` blend this
## many seconds in.
var debug_cancel_t := -1.0

var _right_pivot := Vector3.ZERO
var _playing := false
var _start := 0.0
var _r := Transform3D.IDENTITY
var _l := Transform3D.IDENTITY
var _solve: RefCounted = null
var _solve_r: RefCounted = null
var _keys: RefCounted = null
## The right arm's build-time shoulder, wrist, pole, hand_dir and palm; empty without a gun.
var _right_reach := {}
## True while the solver has written bones that `restore` has not undone.
var _written := false
## Blend-out state: progress 0..1 over `_dur` s, the age it froze at, and whether the gun side
## skips the blend (a shot snaps the gun while the left hand still eases).
var _blending := false
var _p := 0.0
var _dur := CLEAR_TIME
var _frozen_a := 0.0
var _snap_gun := false
var _last_now := 0.0
## Started right after the restore when the blend ends (a gesture waiting for the left hand).
var _queued := Callable()


## With no left model the instance is inert: never plays, offsets stay identity.
func _init(right_pivot: Vector3, model_r: Node3D, model_l: Node3D, roots: Dictionary) -> void:
	if model_l == null:
		return
	_right_pivot = right_pivot
	_solve = Solve.new(model_l, ".L", roots.get("left_reach", {}) as Dictionary)
	_right_reach = roots.get("right_reach", {}) as Dictionary
	if not _right_reach.is_empty():
		_solve_r = Solve.new(model_r, ".R", _right_reach)
		_solve_r.reset_fore = true
	_keys = Keys.new(_solve.rest_shoulder, _solve.rest_wrist, _solve.rest_hand_dir,
			_solve.rest_palm, ArmRig.palm_len(model_l) * ArmsBuilder.HAND_K)


## Runs the timeline and holds at its last key until `release` or `clear`.
func play(now: float) -> void:
	if _solve == null:
		return
	_playing = true
	_start = now
	_last_now = now
	_blending = false
	_snap_gun = false


## Starts the slow blend-out (the E key going up); nothing unless playing and not blending.
func release(now: float) -> void:
	if is_playing(now) and not _blending:
		_begin_blend(now, RELEASE_TIME)


## Cancels with a quick blend-out from where it is; `snap_gun` puts the gun and right arm back
## at once while the left hand still eases. An ongoing blend keeps its progress at the new rate.
func clear(snap_gun := false) -> void:
	if not snap_gun:
		_queued = Callable()
	if _playing:
		_begin_blend(_last_now, CLEAR_TIME)
		_snap_gun = _snap_gun or snap_gun
	else:
		_r = Transform3D.IDENTITY
		_l = Transform3D.IDENTITY


## Ends at once, restoring both arms.
func snap() -> void:
	_queued = Callable()
	if _playing:
		_stop()


## Holds `fn` until the blend-out ends, then calls it right after the restore.
func queue(fn: Callable) -> void:
	_queued = fn


## True until the blend-out has reached zero.
func is_playing(now: float) -> bool:
	return _playing and now >= _start


## Seconds until the blend-out ends; 0 when not blending.
func blend_left(_now: float) -> float:
	return (1.0 - _p) * _dur if _blending else 0.0


func step(now: float, pinned_t: float) -> void:
	if _solve == null:
		return
	var a := pinned_t
	var w := 1.0
	var wr := 1.0
	if pinned_t >= 0.0:
		if debug_cancel_t >= 0.0:
			w = _weight(debug_cancel_t / CLEAR_TIME)
			wr = w
	else:
		var dt := maxf(now - _last_now, 0.0)
		_last_now = now
		# Also covers a wrapped clock putting now before the start; sandbox keeps smoke stills.
		if SaveSandbox.enabled or not is_playing(now):
			_stop()
			return
		a = now - _start
		if _blending:
			_p = minf(_p + dt / _dur, 1.0)
			if _p >= 1.0:
				_stop()
				return
			a = _frozen_a
			w = _weight(_p)
			wr = 0.0 if _snap_gun else w
	var k: Dictionary = _keys.sample(a)
	var rest: RefCounted = _solve
	var dir: Vector3 = (rest.rest_hand_dir as Vector3).slerp(k[&"hand_dir"] as Vector3, w)
	var palm: Vector3 = (rest.rest_palm as Vector3).slerp(k[&"palm_n"] as Vector3, w)
	_solve.solve((rest.rest_shoulder as Vector3).lerp(k[&"shoulder"] as Vector3, w),
			(rest.rest_wrist as Vector3).lerp(k[&"wrist"] as Vector3, w),
			(rest.rest_pole as Vector3).lerp(Keys.POLE, w), dir, palm)
	_solve.dress((k[&"wrist_fd"] as Vector2) * w, (k[&"fingers"] as Vector3) * w,
			(k[&"spread"] as Vector2) * w)
	_written = true
	_r = Transform3D.IDENTITY.interpolate_with(
			_about(_right_pivot, k[&"r_pos"] as Vector3, k[&"r_rot"] as Vector3), wr)
	if _solve_r:
		# The root rides the offset, so the shoulder is put back in root space.
		_solve_r.solve(_r.affine_inverse() * (_right_reach["shoulder"] as Vector3),
				_right_reach["wrist"] as Vector3, _right_reach["pole"] as Vector3,
				_right_reach["hand_dir"] as Vector3, _right_reach["palm"] as Vector3)


func _begin_blend(now: float, dur: float) -> void:
	if not _blending:
		_blending = true
		_p = 0.0
		_frozen_a = maxf(now - _start, 0.0)
	_dur = dur


## The one restore of both sides, offsets back to identity, then the waiting callable.
func _stop() -> void:
	_playing = false
	_blending = false
	_snap_gun = false
	_r = Transform3D.IDENTITY
	_l = Transform3D.IDENTITY
	if _written:
		_solve.restore()
		if _solve_r:
			_solve_r.restore()
		_written = false
	var fn := _queued
	_queued = Callable()
	if fn.is_valid():
		fn.call()


static func _weight(p: float) -> float:
	var q := clampf(p, 0.0, 1.0)
	return 1.0 - (q * q * (3.0 - 2.0 * q) if W_EASE != &"out" else 1.0 - (1.0 - q) * (1.0 - q))


func right_offset() -> Transform3D:
	return _r


func left_offset() -> Transform3D:
	return _l


static func _about(pivot: Vector3, pos: Vector3, rot_deg: Vector3) -> Transform3D:
	var r := rot_deg * (PI / 180.0)
	var b := Basis(Vector3.UP, r.y) * Basis(Vector3.RIGHT, r.x) * Basis(Vector3.BACK, r.z)
	var p := Transform3D(Basis.IDENTITY, pivot)
	return Transform3D(Basis.IDENTITY, pos) * p * Transform3D(b, Vector3.ZERO) \
			* p.affine_inverse()
