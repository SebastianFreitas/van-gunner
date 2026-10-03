extends RefCounted
## Keyed wrist routine for the free left hand: a slow twist now, flex and deviation beats in later steps, on one 3-roll clock.

const ROLLS := 3  ## finger rolls per routine
const TWIST_MAX := 30.0  ## degrees, the peak of the total twist
const FOREARM_SHARE := 1.0 / 3.0  ## share of the twist given to the forearm.001 bone
const EDGE_AMP := 0.55  ## twist amplitude outside roll 2, as a share of the middle's
## The SaveSandbox weave hold (GunViewmodel.WEAVE_SANDBOX_T): the twist is exactly 0 there,
## so smoke stills stay `same`.
const REST_T := 1.1
const PHASE_JITTER := 0.5  ## radians, the seeded shift of the carrier
const FOREARM_BONE := "DEF-forearm.L.001"

var period := 3.6
var routine := 10.8
## Routine time of the last `sample`, fposmod(t, routine); later steps read it.
var rt := 0.0
## Euler degrees to ADD to the wrist (x flex, y twist, z sideways); only y is used so far.
var wrist := Vector3.ZERO
## Degrees about the forearm.001 bone's local Y of the last sample.
var forearm := 0.0
var _phase := 0.0
var _norm := 1.0
var _sk: Skeleton3D = null
var _fa := -1
var _fa_pose := Quaternion.IDENTITY


func _init(rng: RandomNumberGenerator, period_s: float) -> void:
	period = period_s
	routine = ROLLS * period_s
	_phase = rng.randf_range(-PHASE_JITTER, PHASE_JITTER)
	# Scale so the biggest swing away from the rest pose is exactly TWIST_MAX.
	var rest := _raw(REST_T)
	var m := 0.0
	for i in 721:
		m = maxf(m, absf(_raw(routine * i / 720.0) - rest))
	_norm = TWIST_MAX / m


## Finds the forearm.001 bone and reads the pose ArmRig.reach left on it (nothing re-poses
## that bone each frame), so the twist can be layered on top.
func bind(sk: Skeleton3D) -> void:
	_sk = sk
	_fa = sk.find_bone(FOREARM_BONE)
	if _fa == -1:
		push_warning("ArmWristRoutine: bone not found: " + FOREARM_BONE)
		return
	_fa_pose = sk.get_bone_pose_rotation(_fa)


## Samples the routine at time `t` and twists the forearm bone. Allocation-free per frame.
func sample(t: float) -> void:
	rt = fposmod(t, routine)
	var tw := (_raw(rt) - _raw(REST_T)) * _norm
	wrist = Vector3(0.0, tw * (1.0 - FOREARM_SHARE), 0.0)
	forearm = tw * FOREARM_SHARE
	if _fa != -1 and is_instance_valid(_sk):
		# The hand is a child of forearm.001, so the hand's total turn is wrist.y + forearm.
		_sk.set_bone_pose_rotation(_fa, _fa_pose * Quaternion(Vector3.UP, deg_to_rad(forearm)))


## The un-normalised, unanchored twist on a -1..1 scale: one slow swing per routine, peaking
## mid roll 2, with a raised-cosine envelope so roll 2 swings widest without a kink.
func _raw(rt_s: float) -> float:
	var u := rt_s / routine
	var c := -cos(TAU * u + _phase)
	var e := EDGE_AMP
	if rt_s >= period and rt_s <= 2.0 * period:
		e += (1.0 - EDGE_AMP) * (0.5 - 0.5 * cos(TAU * (rt_s - period) / period))
	return c * e
