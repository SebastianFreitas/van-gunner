extends RefCounted
## Walk layer for the first-person arms: a footstep-locked figure-8 with roll, a footfall dip, strafe lean, a start/stop lag spring and a free left-arm swing, blended in by walking speed.

const STRIDE := 0.75  ## metres per step; one cycle (TAU) is two steps
const WALK_SPEED := 4.5  ## m/s that counts as full walk (fps_player move_speed)
const AMOUNT_RATE := 6.0  ## exp-smoothing per second for amount and lean
const SIDE := 0.035  ## rig units, lateral sway at the half rate
const DIP := 0.05  ## rig units, drop on each footfall
const ROLL := 3.5  ## degrees toward the planted foot
const YAW := 1.2  ## degrees
const PITCH := 1.5  ## degrees muzzle down on footfall
const LEAN := 4.0  ## degrees roll at full strafe speed
const LAG_GAIN := 0.015  ## rig units per m/s of spring-vs-real velocity
const LAG_MAX := 0.08  ## rig units clamp per axis
const LAG_PITCH := 0.6  ## degrees per m/s of forward lag, clamped to 3
const LAG_F := 2.5  ## Hz, velocity spring
const LAG_ZETA := 0.4  ## under-damped: one visible overshoot
const SWING_FWD := 0.12  ## rig units, left arm fore/aft
const SWING_UP := 0.10  ## rig units, rise on the forward swing
const SWING_IN := 0.04  ## rig units toward the centre on the forward swing
const SWING_PITCH := 10.0  ## degrees, hand tips up on the forward swing
const SWING_F := 3.0  ## Hz, left swing spring
const SWING_ZETA := 0.5
const SIM_DT := 1.0 / 120.0  ## fixed step for pinned start/stop

var _phase := 0.0
var _amount := 0.0
var _lean := 0.0  ## -1..1 smoothed lateral speed / WALK_SPEED
var _vs := Vector2.ZERO  ## spring velocity (x lateral, y forward), m/s
var _vs_vel := Vector2.ZERO
var _vel := Vector2.ZERO  ## real velocity (x lateral, y forward), m/s
var _swing := 0.0  ## filtered swing -1..1
var _swing_vel := 0.0


## Advances the walk by `delta`; `lateral` is m/s to the camera's right, `forward` m/s along
## the camera's flat forward. Long frames are split so the springs stay stable.
func step(delta: float, lateral: float, forward: float) -> void:
	if delta <= 0.0:
		return
	_vel = Vector2(lateral, forward)
	var n := 1
	if delta > 0.05:
		n = ceili(delta * 60.0)
	var dt := delta / float(n)
	for i in n:
		_sub_step(dt)


func _sub_step(delta: float) -> void:
	var k := 1.0 - exp(-AMOUNT_RATE * delta)
	_amount = lerpf(_amount, clampf(_vel.length() / WALK_SPEED, 0.0, 1.0), k)
	_lean = lerpf(_lean, clampf(_vel.x / WALK_SPEED, -1.0, 1.0), k)
	_phase = fmod(_phase + _vel.length() * delta / STRIDE * PI, TAU)
	var w := TAU * LAG_F
	_vs_vel += (w * w * (_vel - _vs) - 2.0 * LAG_ZETA * w * _vs_vel) * delta
	_vs += _vs_vel * delta
	var t := sin(_phase + PI) * _amount
	var ws := TAU * SWING_F
	_swing_vel += (ws * ws * (t - _swing) - 2.0 * SWING_ZETA * ws * _swing_vel) * delta
	_swing += _swing_vel * delta


## Freezes the layer at a cycle fraction (0..1) and walk amount, with no spring state.
func pin_cycle(cycle: float, walk_amount: float) -> void:
	reset()
	_phase = fposmod(cycle, 1.0) * TAU
	_amount = clampf(walk_amount, 0.0, 1.0)
	_swing = sin(_phase + PI) * _amount


## Simulates a start (from rest) or stop (from full walk) for `seconds` at a fixed step.
func pin_transition(kind: StringName, seconds: float) -> void:
	reset()
	if kind == &"stop":
		_vel = Vector2(0.0, WALK_SPEED)
		_vs = _vel
		_amount = 1.0
		_swing = 0.0
	var n := int(seconds / SIM_DT)
	for i in n:
		step(SIM_DT, 0.0, WALK_SPEED if kind == &"start" else 0.0)


func reset() -> void:
	_phase = 0.0
	_amount = 0.0
	_lean = 0.0
	_vs = Vector2.ZERO
	_vs_vel = Vector2.ZERO
	_vel = Vector2.ZERO
	_swing = 0.0
	_swing_vel = 0.0


func amount() -> float:
	return _amount


## Whole-rig sway, dip, lean and lag, rotated about `pivot` (the grip).
func rig_offset(pivot: Vector3) -> Transform3D:
	var a := _amount
	var p := _phase
	var c := 0.5 * (1.0 + cos(2.0 * p))  # 1 at footfall (p = 0 and PI)
	var pos := Vector3(
		a * SIDE * (sin(p) + 0.15 * sin(3.0 * p + 1.1)), -a * DIP * c * c, 0.0
	)
	var dv := _vs - _vel
	# Forward is -z in rig space: a forward start has dv.y < 0, so the arms lag toward the camera.
	pos.x += clampf(dv.x * LAG_GAIN, -LAG_MAX, LAG_MAX)
	pos.z -= clampf(dv.y * LAG_GAIN, -LAG_MAX, LAG_MAX)
	var roll := -a * ROLL * sin(p) - LEAN * _lean
	var yaw := a * YAW * sin(p + 0.3)
	var cp := 0.5 * (1.0 + cos(2.0 * (p - 0.25)))  # muzzle dips just after footfall
	var pitch := -a * PITCH * cp * cp + clampf(-dv.y * LAG_PITCH, -3.0, 3.0)
	var b := (
		Basis(Vector3.UP, deg_to_rad(yaw))
		* Basis(Vector3.RIGHT, deg_to_rad(pitch))
		* Basis(Vector3.BACK, deg_to_rad(roll))
	)
	return (
		Transform3D(Basis.IDENTITY, pos)
		* Transform3D(Basis.IDENTITY, pivot)
		* Transform3D(b, Vector3.ZERO)
		* Transform3D(Basis.IDENTITY, -pivot)
	)


## Free left-arm swing: back and low on the back swing, forward, up and inward on the forward one.
func left_offset() -> Transform3D:
	var s := _swing
	var f := maxf(s, 0.0)
	return Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(SWING_PITCH * s)),
		Vector3(SWING_IN * f, SWING_UP * pow(f, 1.5), -SWING_FWD * s)
	)
