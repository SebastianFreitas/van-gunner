extends RefCounted
## Strike geometry for ArmGesture's slam kinds: the lunged shoulder, the wrist target on the camera ray and the slam hand frame.

const ArmGestureKeys := preload("res://scripts/player/arms/arm_gesture_keys.gd")
## How far the slam hand_dir tips from `dir` toward the world up (0 = along dir).
const SLAM_UP := 0.4
## The pull's and slides' snatch frame: how far hand_dir tips from `dir` toward down and toward the rig's right.
const SNATCH_DOWN := 0.15
const SNATCH_RIGHT := 0.3
## How far (rig units) the snatch's wrist target sits below the far crossing, perpendicular to the ray.
const SNATCH_LOW := 0.35
## How far (rig units) the snatch's wrist target is sent deeper along the ray.
const SNATCH_DEEP := 0.2
## How far (rig units) the snatch's shoulder drops, on the lunge envelope.
const SNATCH_SINK := 0.075
## How far (rig units) the shoulder also lunges along the centre ray, on the sideways lunge's
## envelope: the strike's far crossing is only R beyond the shoulder, so this is the depth gain.
const FORWARD_LUNGE := 0.45
## Longest wrist back-off (rig units) the claw-tip aim may apply.
const TIP_AIM_MAX := 0.6

# Static on purpose: each call takes the ArmGesture `g` and reads its fields (age, channels, ray,
# reach); holding it as a field would make a reference cycle that leaks at exit.

## Sets the gesture's shoulder lunge (size and direction) from the new hit's eye and ray.
static func set_lunge(g: RefCounted) -> void:
	var eye: Vector3 = g._eye_left - g._pos
	var sh: Vector3 = g._shoulder
	var to_ray: Vector3 = eye + g._ray_left * maxf((sh - eye).dot(g._ray_left), 0.0) - sh
	var d := to_ray.length()
	g._lunge = minf(maxf(g.SHOULDER_LUNGE, d - g._big_r + g.LUNGE_MARGIN), d)
	g._lunge_dir = to_ray / maxf(d, 0.0001)
	g._has_hit = true

## The strike shoulder at the gesture's age: the rest shoulder pushed toward the centre ray.
static func shoulder(g: RefCounted) -> Vector3:
	var m := envelope(g)
	var lunged: Vector3 = g._shoulder + g._lunge_dir * float(g._lunge) * m + g._ray_left * FORWARD_LUNGE * m
	if g._posed == &"pull" or g._posed == &"slide_open" or g._posed == &"slide_close":
		# The snatch drops the shoulder with the claw so upper arm and forearm read as one line (D59).
		lunged += Vector3.DOWN * SNATCH_SINK * m
	return lunged


## The lunge weight: 0 at the coil's end, 1 at contact, held at 1 until the settle blend starts
## (the wrist can only reach R from the shoulder, so a retreating shoulder would pull it back
## toward the camera), then 0 at the gesture's end with the settle weight.
static func envelope(g: RefCounted) -> float:
	var hit: float = ArmGestureKeys.CONTACT[g._posed]
	var age: float = g._age
	var m := smoothstep(float(g._coil_t), hit, age)
	var keys: Array = ArmGestureKeys.KEYS[g._posed][&"reach"]
	var settle_from: float = keys[keys.size() - 2][&"t"]
	var sw := smoothstep(settle_from, g.duration(g._posed), age)
	return m * (1.0 - sw * sw)


## `target` with the claw tips, not the wrist, on the centre ray: the wrist shifts off the ray by
## the sideways part of the wrist-to-tip vector the last frame solved (the hand's frame does not
## depend on the target, so it is stable). The part along the ray stays, or the hand would lose
## the depth the forward lunge gained. Weighted by the lunge envelope so the rest and the ends
## stay put.
static func aimed(g: RefCounted, shoulder_pos: Vector3) -> Vector3:
	if g._posed == &"pull" or g._posed == &"slide_open" or g._posed == &"slide_close":
		# The snatch strikes with the wrist on the far crossing, like press: its hooked claws would
		# otherwise pull the wrist up off the ray (D57).
		# It aims below the crosshair and deeper, like press's low small hand (D58).
		var snatch_ray: Vector3 = g._ray_left
		var down_perp := (Vector3.DOWN - snatch_ray * Vector3.DOWN.dot(snatch_ray)).normalized()
		return target(g, shoulder_pos) + (down_perp * SNATCH_LOW + snatch_ray * SNATCH_DEEP) * envelope(g)
	var ray: Vector3 = g._ray_left
	var back: Vector3 = g._tip_off
	back -= ray * back.dot(ray)
	return target(g, shoulder_pos) - back.limit_length(TIP_AIM_MAX) * envelope(g)


## The middle claw tip minus the wrist in rig space, from the skeleton as posed now.
static func tip_vector(g: RefCounted) -> Vector3:
	var tip_bone: int = g._tip
	if tip_bone == -1:
		return Vector3.ZERO
	var sk: Skeleton3D = g._sk
	var xf: Transform3D = g._to_rig
	var base := sk.get_bone_global_pose(tip_bone)
	var tip := base.origin + base.basis.y * float(g._tip_len)
	return xf.basis * (tip - sk.get_bone_global_pose(g._wrist).origin)


## The wrist target at the gesture's age for the moved `shoulder`: coil back along -dir (the reach
## channel, ease out), strike to the point on the camera centre ray at the full reach from
## `shoulder` (the reach rising to 1, ease in). After contact the reach is 1 plus an offset along
## `dir` in rig units (the recoil), and the settle blends that pose back to the rest wrist.
static func target(g: RefCounted, shoulder_pos: Vector3) -> Vector3:
	var age: float = g._age
	var reach: float = g._reach
	var rest: Vector3 = g._rest_wrist
	var dir: Vector3 = g._dir
	if age < float(g._coil_t):
		return rest + dir * reach
	var struck := ray_point(g, shoulder_pos)
	if age < float(ArmGestureKeys.CONTACT[g._posed]):
		var coil: float = g._coil
		return (rest - dir * coil).lerp(struck, (reach + coil) / (1.0 + coil))
	var keys: Array = ArmGestureKeys.KEYS[g._posed][&"reach"]
	var settle_from: float = keys[keys.size() - 2][&"t"]
	var w := smoothstep(settle_from, float(g.duration(g._posed)), age)
	# Never nearer the camera than the rest wrist: the strike point from a retreating shoulder is.
	var held := struck + dir * (reach - 1.0) + side(g._posed, g.lat) * float(g._slide)
	var ray: Vector3 = g._ray_left
	held += ray * maxf(rest.dot(ray) - held.dot(ray), 0.0)
	return held.lerp(rest, w)


## The slide's yank direction in rig space: +x times `lat` to open, against it to close; zero for
## every other kind.
static func side(kind: StringName, lat: float) -> Vector3:
	if kind == &"slide_open":
		return Vector3.RIGHT * lat
	if kind == &"slide_close":
		return Vector3.LEFT * lat
	return Vector3.ZERO


## The forward point of the centre ray at distance R from `shoulder_pos`; if the ray misses that
## sphere, the ray point closest to the shoulder, limited to R.
static func ray_point(g: RefCounted, shoulder_pos: Vector3) -> Vector3:
	var eye: Vector3 = g._eye_left - g._pos  # the root is leaned by `_pos` at render
	var ray: Vector3 = g._ray_left
	var big_r: float = g._big_r
	var rel := shoulder_pos - eye
	var along := rel.dot(ray)
	var disc := big_r * big_r - (rel - ray * along).length_squared()
	if disc < 0.0:
		return shoulder_pos + (eye + ray * maxf(along, 0.0) - shoulder_pos).limit_length(big_r)
	return eye + ray * (along + sqrt(disc))


## The hand_dir and palm normal to solve with: the baked frame slerped toward the slam frame
## (palm along `dir`, fingers tipped up) by `weight`; weight 0 is the baked frame exactly.
static func frame(g: RefCounted, weight: float) -> Array[Vector3]:
	var base_h: Vector3 = g._hand_dir
	var base_p: Vector3 = g._palm
	if weight <= 0.0:
		return [base_h, base_p]
	var dir: Vector3 = g._dir
	var up := (Vector3.UP - dir * Vector3.UP.dot(dir)).normalized()
	var slam_h := dir.lerp(up, SLAM_UP).normalized()
	var slam_p := dir
	if g._posed == &"pull" or g._posed == &"slide_open" or g._posed == &"slide_close":
		# The snatch: fingers tipped down and sideways onto the handle, palm facing the rig's right.
		slam_h = (dir + Vector3.DOWN * SNATCH_DOWN + Vector3.RIGHT * SNATCH_RIGHT).normalized()
		slam_p = Vector3.RIGHT
	var hand := base_h.slerp(slam_h, weight)
	var palm := base_p.slerp(slam_p, weight)
	palm = (palm - hand * palm.dot(hand)).normalized()
	return [hand, palm]
