class_name ArmDress
extends RefCounted
## Dresses the goblin's arms from the van seed: fingerless glove, rings and tape on the gun hand, boxer's wrap, forearm bandage and chain on the free hand, cut-off sleeves and rag tails on both; every piece is a shrinkwrap band or sits on one, so nothing floats.

## No extra bones: a band samples only its own bone.
static var _none := PackedStringArray()
const FINGERS: Array[String] = ["f_index", "f_middle", "f_ring", "f_pinky"]
## Wrist tape turns: t0, t1 and offset (fraction of the radius).
const TAPE_TURNS: Array[Vector3] = [
	Vector3(0.80, 0.87, 0.05), Vector3(0.86, 0.93, 0.07), Vector3(0.92, 1.00, 0.09),
]
## Rag tails: segments per tail, each this fraction of the forearm bone long.
const TAIL_SEGS := 5
const TAIL_STEP := 0.26
## Angle 0 is the face the lamp sits on; rag tails stay this many degrees away from it.
const LAMP_CLEAR := 40.0


static func right(model: Node3D, rng: RandomNumberGenerator) -> void:
	var sk := ArmRig.skeleton(model)
	var mi := arm_mesh(sk)
	if mi == null:
		return
	var glove := ArmMaterials.glove(rng)
	var tape := ArmMaterials.tape(rng)
	var sleeve := ArmMaterials.sleeve(rng)
	var rag := ArmMaterials.rag(rng)
	_glove(mi, sk, glove, rng)
	_rings(mi, sk, ArmMaterials.brass(), rng)
	_tape(mi, sk, tape, rng)
	_sleeve(mi, sk, ".R", sleeve, rng)
	_rag(mi, sk, ".R", rag, rng, rng.randf_range(-90.0, -50.0))


static func left(model: Node3D, rng: RandomNumberGenerator) -> void:
	var sk := ArmRig.skeleton(model)
	var mi := arm_mesh(sk)
	if mi == null:
		return
	var cloth := ArmMaterials.wrap_cloth(rng)
	var sleeve := ArmMaterials.sleeve(rng)
	var rag := ArmMaterials.rag(rng)
	_boxer_wrap(mi, sk, cloth, rng)
	_bandage(mi, sk, cloth, rng)
	_chain(mi, sk, ArmMaterials.brass(), rng)
	_sleeve(mi, sk, ".L", sleeve, rng)
	_rag(mi, sk, ".L", rag, rng, rng.randf_range(50.0, 90.0))


## The arm's skinned mesh: the skeleton's first MeshInstance3D child.
static func arm_mesh(sk: Skeleton3D) -> MeshInstance3D:
	if sk != null:
		for c in sk.get_children():
			if c is MeshInstance3D:
				return c as MeshInstance3D
	push_warning("ArmDress: no arm mesh under the skeleton")
	return null


## Mean radius at mid-bone: the scale every offset of a piece is a fraction of.
static func _rad(mi: MeshInstance3D, sk: Skeleton3D, bone: String,
		include: PackedStringArray) -> float:
	return ArmWrap.mean_radius(ArmWrap.section(mi, sk, bone, 0.5, 12, include))


## One shrinkwrap band on `att`; `off` is a fraction of the bone's mid radius. A null attachment
## (missing bone, already warned) or an empty section skips the band.
static func _band(att: Node3D, mi: MeshInstance3D, sk: Skeleton3D, bone: String, t0: float,
		t1: float, rings: int, sectors: int, off: float, include: PackedStringArray,
		mat: Material, rng: RandomNumberGenerator, fray := 0.0, tilt := 0.0) -> void:
	if att == null:
		return
	var r := _rad(mi, sk, bone, include)
	var node := "Band%d" % att.get_child_count()
	if r <= 0.0 or ArmWrap.band(att, node, mi, sk, bone, t0, t1, rings, sectors, off * r,
			include, mat, rng, fray, tilt) == null:
		push_warning("ArmDress: no band for %s on %s" % [att.name, bone])


## A box lying on the skin at (t, angle degrees); `rot` turns it about its own frame.
static func _flat(att: Node3D, node: String, mi: MeshInstance3D, sk: Skeleton3D, bone: String,
		t: float, angle: float, off: float, include: PackedStringArray, size: Vector3,
		mat: Material, rot: Basis) -> void:
	var f := ArmWrap.surface_frame(mi, sk, bone, t, angle, off, include)
	ArmParts.mesh(att, node, ArmParts.box(size), mat, f.origin, f.basis * rot)


static func _glove(mi: MeshInstance3D, sk: Skeleton3D, mat: Material,
		rng: RandomNumberGenerator) -> void:
	var palm := PackedStringArray(["DEF-hand.R", "DEF-palm.01.R", "DEF-palm.02.R",
			"DEF-palm.03.R", "DEF-palm.04.R", "DEF-thumb.01.R"])
	_band(ArmWrap.attach(sk, "DEF-hand.R", "Dress_glove"), mi, sk, "DEF-hand.R", -0.06, 1.0,
			5, 12, 0.10, palm, mat, rng, 0.04)
	# The negative t0 overlaps the palm band so finger curl never opens a gap.
	for f in FINGERS:
		var bone := "DEF-%s.01.R" % f
		_band(ArmWrap.attach(sk, bone, "Dress_glove_" + f.trim_prefix("f_")), mi, sk, bone,
				-0.15, 0.72, 3, 8, 0.10, _none, mat, rng, 0.07)
	_band(ArmWrap.attach(sk, "DEF-thumb.01.R", "Dress_glove_thumb"), mi, sk, "DEF-thumb.01.R",
			0.0, 0.85, 3, 8, 0.10, _none, mat, rng, 0.07)


## Brass rings on the bare finger past the glove's cut edge; the pinky's is seeded.
static func _rings(mi: MeshInstance3D, sk: Skeleton3D, mat: Material,
		rng: RandomNumberGenerator) -> void:
	var pinky := rng.randf() < 0.7
	_band(ArmWrap.attach(sk, "DEF-f_middle.01.R", "Dress_ring_middle"), mi, sk,
			"DEF-f_middle.01.R", 0.78, 0.92, 2, 8, 0.16, _none, mat, rng)
	if pinky:
		_band(ArmWrap.attach(sk, "DEF-f_pinky.01.R", "Dress_ring_pinky"), mi, sk,
				"DEF-f_pinky.01.R", 0.70, 0.86, 2, 8, 0.16, _none, mat, rng)


## Three turns of tape at the wrist, the last over the glove cuff, and a peeling tail.
static func _tape(mi: MeshInstance3D, sk: Skeleton3D, mat: Material,
		rng: RandomNumberGenerator) -> void:
	var bone := "DEF-forearm.R.001"
	var tail_a := rng.randf_range(100.0, 160.0)
	var att := ArmWrap.attach(sk, bone, "Dress_tape_r")
	if att == null:
		return
	for turn in TAPE_TURNS:
		_band(att, mi, sk, bone, turn.x, turn.y, 2, 12, turn.z, _none, mat, rng, 0.0, 0.015)
	var r := _rad(mi, sk, bone, _none)
	_flat(att, "Tail", mi, sk, bone, 0.97, tail_a, 0.10 * r, _none,
			Vector3(0.9 * r, 0.03 * r, 0.28 * r), mat, Basis(Vector3.UP, deg_to_rad(20.0)))


## Cut-off sleeve on the upper arm with a hacked hem on its lower half.
static func _sleeve(mi: MeshInstance3D, sk: Skeleton3D, sd: String, mat: Material,
		rng: RandomNumberGenerator) -> void:
	var bone := "DEF-upper_arm" + sd
	var hem := bone + ".001"
	var tag := sd.substr(1).to_lower()
	_band(ArmWrap.attach(sk, bone, "Dress_sleeve_" + tag), mi, sk, bone, 0.0, 1.0, 4, 10, 0.12,
			PackedStringArray([bone, hem]), mat, rng)
	# Its own attachment: the hem band is built in the lower bone's space.
	_band(ArmWrap.attach(sk, hem, "Dress_sleeve_hem_" + tag), mi, sk, hem, 0.0, 0.35, 3, 10,
			0.12, _none, mat, rng, 0.10)


## A rag knotted on the elbow half of the forearm with two tails laid toward the wrist. Each
## tail is a chain of skin points joined end to end, so the strip cannot float or dip.
static func _rag(mi: MeshInstance3D, sk: Skeleton3D, sd: String, mat: Material,
		rng: RandomNumberGenerator, knot_deg: float) -> void:
	var bone := "DEF-forearm" + sd
	# The tails run past this bone's end, so the wrist half's vertices count for the surface.
	var inc := PackedStringArray([bone + ".001"])
	var att := ArmWrap.attach(sk, bone, "Dress_rag_" + sd.substr(1).to_lower())
	if att == null:
		return
	var r := _rad(mi, sk, bone, inc)
	_flat(att, "Knot", mi, sk, bone, 0.22, knot_deg, 0.06 * r, inc,
			Vector3(0.5 * r, 0.35 * r, 0.5 * r), mat, Basis.IDENTITY)
	for side in 2:
		var a := _clear_lamp(knot_deg + (-25.0 if side == 0 else 25.0))
		var pts: Array[Vector3] = []
		var nrm: Array[Vector3] = []
		for k in TAIL_SEGS + 1:
			if k > 0:
				a = _clear_lamp(a + rng.randf_range(-10.0, 10.0))
			# The tail end lifts a little off the skin.
			var lift := 0.05 if k <= 3 else 0.10 if k == 4 else 0.14
			var f := ArmWrap.surface_frame(mi, sk, bone, 0.22 + k * TAIL_STEP, a, lift * r, inc)
			pts.append(f.origin)
			nrm.append(f.basis.y)
		for k in TAIL_SEGS:
			var p0: Vector3 = pts[k]
			var p1: Vector3 = pts[k + 1]
			var dir: Vector3 = p1 - p0
			var length: float = dir.length()
			if length < 0.001:
				continue
			dir /= length
			var n: Vector3 = (nrm[k] + nrm[k + 1]).normalized()
			var across: Vector3 = dir.cross(n).normalized()
			n = across.cross(dir)
			ArmParts.mesh(att, "Tail%d_%d" % [side, k],
					ArmParts.box(Vector3(length, 0.04 * r, 0.26 * r)), mat, (p0 + p1) * 0.5,
					Basis(dir, n, across))


## Keeps an angle (degrees) at least LAMP_CLEAR away from the lamp face at 0.
static func _clear_lamp(a: float) -> float:
	var w := wrapf(a, -180.0, 180.0)
	if absf(w) < LAMP_CLEAR:
		return LAMP_CLEAR if w >= 0.0 else -LAMP_CLEAR
	return w


## Boxer's wrap round the left hand: two layered straps and a thumb loop in one cloth.
static func _boxer_wrap(mi: MeshInstance3D, sk: Skeleton3D, mat: Material,
		rng: RandomNumberGenerator) -> void:
	var palm := PackedStringArray(["DEF-hand.L", "DEF-palm.01.L", "DEF-palm.02.L",
			"DEF-palm.03.L", "DEF-palm.04.L"])
	var att := ArmWrap.attach(sk, "DEF-hand.L", "Dress_wrap")
	_band(att, mi, sk, "DEF-hand.L", 0.12, 0.96, 4, 12, 0.08, palm, mat, rng, 0.0, 0.02)
	_band(att, mi, sk, "DEF-hand.L", 0.30, 0.62, 2, 12, 0.14, palm, mat, rng, 0.0, 0.04)
	_band(ArmWrap.attach(sk, "DEF-thumb.01.L", "Dress_wrap_thumb"), mi, sk, "DEF-thumb.01.L",
			0.05, 0.40, 2, 8, 0.08, _none, mat, rng)


## Bandage over the wrist half of the forearm with a loose end flapping.
static func _bandage(mi: MeshInstance3D, sk: Skeleton3D, mat: Material,
		rng: RandomNumberGenerator) -> void:
	var bone := "DEF-forearm.L.001"
	var end_a := rng.randf_range(60.0, 120.0)
	var att := ArmWrap.attach(sk, bone, "Dress_bandage")
	if att == null:
		return
	_band(att, mi, sk, bone, 0.40, 1.0, 7, 12, 0.10, _none, mat, rng, 0.05, 0.02)
	var r := _rad(mi, sk, bone, _none)
	_flat(att, "End", mi, sk, bone, 0.45, end_a, 0.12 * r, _none,
			Vector3(0.9 * r, 0.03 * r, 0.3 * r), mat, Basis(Vector3.BACK, deg_to_rad(25.0)))


## Brass chain bracelet; present 80% of the time, the stream advances the same either way.
static func _chain(mi: MeshInstance3D, sk: Skeleton3D, mat: Material,
		rng: RandomNumberGenerator) -> void:
	var bone := "DEF-forearm.L.001"
	var present := rng.randf() < 0.8
	var att := ArmWrap.attach(sk, bone, "Dress_chain") if present else null
	var r := _rad(mi, sk, bone, _none) if present else 0.0
	for i in 12:
		var a := i * 30.0 + rng.randf_range(-6.0, 6.0)
		var t := 0.93 + rng.randf_range(-0.01, 0.01)
		if att == null:
			continue
		# Odd links turn a quarter so the chain reads as interlocked.
		var roll := Basis(Vector3.BACK, PI * 0.5) if i % 2 == 1 else Basis.IDENTITY
		_flat(att, "Link%d" % i, mi, sk, bone, t, a, 0.22 * r, _none,
				Vector3(0.12 * r, 0.10 * r, 0.34 * r), mat, roll)
