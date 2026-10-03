extends RefCounted
## Keyed wrist routine for the free left hand: a slow twist and a flex beat now, deviation in a later step, on one 3-roll clock.

const ROLLS := 3  ## finger rolls per routine
const TWIST_MAX := 30.0  ## degrees, the peak of the total twist
const FOREARM_SHARE := 1.0 / 3.0  ## share of the twist given to the forearm.001 bone
const EDGE_AMP := 0.55  ## twist amplitude outside roll 2, as a share of the middle's
## The SaveSandbox weave hold (GunViewmodel.WEAVE_SANDBOX_T), as absolute seconds: the twist is
## exactly 0 there, so smoke stills stay `same`.
const REST_T := 1.1
const PHASE_JITTER := 0.5  ## radians, the seeded shift of the carrier
const FOREARM_BONE := "DEF-forearm.L.001"
const FLEX_DOWN := 30.0  ## degrees, the big downward flex peak of roll 1
const FLEX_UP := 20.0  ## degrees, the smaller upward extension peak after it
const PEAK_DOWN_U := 0.30  ## share of the roll where the down peak sits (0 at u 0 and 1)
const PEAK_UP_U := 0.80  ## share of the roll where the up peak sits
## Wrist euler degrees (x, y, z) per degree of DOWNWARD flexion. On the left rig flexion is -z
## and x is sideways, and this unit vector cancels the sideways swing (measured in
## `.claude/plans/idle-wrist-research.md` round 1; tuned by `arms wristang flex`).
const FLEX_AXIS := Vector3(0.463, 0.0, -0.886)

var period := 3.6
var routine := 10.8
## Routine time of the last `sample`, fposmod(t - origin, routine); later steps read it.
var rt := 0.0
## Euler degrees to ADD to the wrist (x and z flex, y twist).
var wrist := Vector3.ZERO
## Degrees about the forearm.001 bone's local Y of the last sample.
var forearm := 0.0
var flex := 0.0  ## degrees of downward flex of the last sample (negative = up)
var _phase := 0.0
var _norm := 1.0
## Absolute seconds where the routine's rt = 0: the flex's big down peak lands on the finger
## curl crest, PEAK_DOWN_U into the roll.
var _origin := 0.0
var _rest_rt := 0.0  ## routine time of the sandbox hold
var _rest_raw := 0.0
var _sk: Skeleton3D = null
var _fa := -1
var _fa_pose := Quaternion.IDENTITY


func _init(rng: RandomNumberGenerator, period_s: float, crest_phase: float) -> void:
	period = period_s
	routine = ROLLS * period_s
	_phase = rng.randf_range(-PHASE_JITTER, PHASE_JITTER)
	var crest_t := fposmod((PI / 2.0 - crest_phase) / TAU, 1.0) * period_s
	_origin = fposmod(crest_t - PEAK_DOWN_U * period_s, period_s)
	_rest_rt = fposmod(REST_T - _origin, routine)
	# Scale so the biggest swing away from the rest pose is exactly TWIST_MAX.
	_rest_raw = _raw(_rest_rt)
	var m := 0.0
	for i in 721:
		m = maxf(m, absf(_raw(routine * i / 720.0) - _rest_raw))
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
func sample(t: float, beat_scale := 1.0) -> void:
	rt = fposmod(t - _origin, routine)
	var tw := (_raw(rt) - _rest_raw) * _norm
	flex = _flex(rt) * beat_scale
	wrist = Vector3(0.0, tw * (1.0 - FOREARM_SHARE), 0.0) + FLEX_AXIS * flex
	forearm = tw * FOREARM_SHARE
	if _fa != -1 and is_instance_valid(_sk):
		# The hand is a child of forearm.001, so the hand's total turn is wrist.y + forearm.
		_sk.set_bone_pose_rotation(_fa, _fa_pose * Quaternion(Vector3.UP, deg_to_rad(forearm)))


## The flex beat in degrees of downward flex (negative = up): roll 1 only, 0 at its start and
## end, a big down peak then a smaller up peak. Each leg eases in and out.
func _flex(rt_s: float) -> float:
	var u := rt_s / period
	if u >= 1.0:
		return 0.0
	if u < PEAK_DOWN_U:
		return FLEX_DOWN * smoothstep(0.0, 1.0, u / PEAK_DOWN_U)
	if u < PEAK_UP_U:
		return lerpf(FLEX_DOWN, -FLEX_UP,
				smoothstep(0.0, 1.0, (u - PEAK_DOWN_U) / (PEAK_UP_U - PEAK_DOWN_U)))
	return -FLEX_UP * (1.0 - smoothstep(0.0, 1.0, (u - PEAK_UP_U) / (1.0 - PEAK_UP_U)))


## The un-normalised, unanchored twist on a -1..1 scale: one slow swing per routine, peaking
## mid roll 2, with a raised-cosine envelope so roll 2 swings widest without a kink.
func _raw(rt_s: float) -> float:
	var u := rt_s / routine
	var c := -cos(TAU * u + _phase)
	var e := EDGE_AMP
	if rt_s >= period and rt_s <= 2.0 * period:
		e += (1.0 - EDGE_AMP) * (0.5 - 0.5 * cos(TAU * (rt_s - period) / period))
	return c * e
