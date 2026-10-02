class_name ArmRig
extends RefCounted
## Skinned first-person arm model: spawn, two-bone reach to a wrist target, finger curl and claws.

const SCENE := preload("res://assets/models/arms/arms.glb")
## Sign of the finger curl about the bone's local X, chosen so positive angles close the fist.
const CURL_SIGN := 1.0
## Share of the hand's roll the forearm twist bone takes, so the wrist never wrings thin.
const TWIST_SHARE := 0.5
const FINGERS:Array[StringName] = [&"f_index", &"f_middle", &"f_ring", &"f_pinky", &"thumb"]


static func spawn(side: StringName, scale_v: float, bulk: float = 1.0,
		muscle_seed: int = 0) -> Node3D:
	var model := SCENE.instantiate() as Node3D
	var keep := "Arm" + String(side)
	for n in ["ArmL", "ArmR"]:
		var m := model.find_child(n, true, false)
		if m == null:
			continue
		if n == keep:
			var mi := m as MeshInstance3D
			mi.layers = VanLighting.LAYER_VAN_INTERIOR
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ArmBulk.inflate(mi, skeleton(model), bulk, muscle_seed)
		else:
			m.get_parent().remove_child(m)
			m.free()
	var s := scale_v if scale_v > 0.0 else 1.0
	model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * s), Vector3.ZERO)
	return model


static func skeleton(model: Node3D) -> Skeleton3D:
	return model.find_child("Skeleton3D", true, false) as Skeleton3D


## The right hand's palm length (wrist to middle knuckle) in rig units, so the gun's holder is
## sized from the hand and fits every seed.
static func palm_len(model: Node3D) -> float:
	var sk := skeleton(model)
	if sk == null:
		return 0.22
	var ih := sk.find_bone("DEF-hand.R")
	var im := sk.find_bone("DEF-f_middle.01.R")
	if ih == -1 or im == -1:
		ih = sk.find_bone("DEF-hand.L")
		im = sk.find_bone("DEF-f_middle.01.L")
	if ih == -1 or im == -1:
		return 0.22
	var len_sk := _global_rest(sk, ih).origin.distance_to(_global_rest(sk, im).origin)
	var k := 1.0
	var node: Node = sk
	while node != model.get_parent() and node is Node3D:
		k *= (node as Node3D).transform.basis.get_scale().y
		node = node.get_parent()
	return len_sk * k


static func _aim(rest_basis: Basis, dir: Vector3) -> Basis:
	return Basis(Quaternion(rest_basis.y.normalized(), dir)) * rest_basis


static func _frame(dir: Vector3, normal: Vector3) -> Basis:
	var d := dir.normalized()
	var n := (normal - d * normal.dot(d)).normalized()
	return Basis(d, n, d.cross(n))


## Global rest from the local rests: Skeleton3D.get_bone_global_rest is stale before the first update.
static func _global_rest(sk: Skeleton3D, i: int) -> Transform3D:
	var t := sk.get_bone_rest(i)
	var p := sk.get_bone_parent(i)
	while p != -1:
		t = sk.get_bone_rest(p) * t
		p = sk.get_bone_parent(p)
	return t


static func _set_local(sk: Skeleton3D, i: int, parent_global: Transform3D,
		global: Transform3D) -> void:
	var local := parent_global.affine_inverse() * global
	sk.set_bone_pose_position(i, local.origin)
	sk.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())


## Poses shoulder-to-wrist so the wrist lands on `wrist` (clamped to reach). Inputs and result are
## in the space of model.get_parent().
static func reach(model: Node3D, suffix: String, shoulder: Vector3, wrist: Vector3,
		pole: Vector3, hand_dir: Vector3, palm_n: Vector3) -> Dictionary:
	var sk := skeleton(model)
	var to_rig := Transform3D.IDENTITY
	var node: Node = sk
	while node != model.get_parent() and node is Node3D:
		to_rig = (node as Node3D).transform * to_rig
		node = node.get_parent()
	var to_sk := to_rig.affine_inverse()
	var iu := sk.find_bone("DEF-upper_arm" + suffix)
	var iu1 := sk.find_bone("DEF-upper_arm" + suffix + ".001")
	var ifa := sk.find_bone("DEF-forearm" + suffix)
	var ifa1 := sk.find_bone("DEF-forearm" + suffix + ".001")
	var ih := sk.find_bone("DEF-hand" + suffix)
	var names := ["DEF-upper_arm", "DEF-upper_arm.001", "DEF-forearm", "DEF-forearm.001",
			"DEF-hand"]
	var ids := [iu, iu1, ifa, ifa1, ih]
	for k in ids.size():
		if ids[k] == -1:
			push_warning("ArmRig: missing bone " + String(names[k]) + suffix)
			return {"elbow": shoulder, "wrist": wrist}
	var r_u := _global_rest(sk, iu)
	var r_f := _global_rest(sk, ifa)
	var r_h := _global_rest(sk, ih)
	var a := r_f.origin.distance_to(r_u.origin)
	var b := r_h.origin.distance_to(r_f.origin)
	var s := to_sk * shoulder
	var dv := to_sk * wrist - s
	var d := clampf(dv.length(), 0.3 * (a + b), 0.98 * (a + b))
	var dh := dv.normalized()
	var w := s + dh * d
	var x := (a * a - b * b + d * d) / (2.0 * d)
	var h := sqrt(maxf(a * a - x * x, 0.0))
	var p := (to_sk.basis * pole).normalized()
	p -= dh * p.dot(dh)
	if p.length() < 0.001:
		p = dh.cross(Vector3.UP)
	var e := s + dh * x + p.normalized() * h
	# set_bone_global_pose leaves stale parents in 4.7, so the local poses are composed here.
	var g_u := Transform3D(_aim(r_u.basis, (e - s).normalized()), s)
	_set_local(sk, iu, Transform3D.IDENTITY, g_u)
	sk.reset_bone_pose(iu1)
	var g_u1 := g_u * sk.get_bone_rest(iu1)
	var g_f := Transform3D(_aim(r_f.basis, (w - e).normalized()), e)
	_set_local(sk, ifa, g_u1, g_f)
	var g_f1_rest := g_f * sk.get_bone_rest(ifa1)
	var d0 := r_h.basis.y.normalized()
	var n0 := Vector3.DOWN - d0 * Vector3.DOWN.dot(d0)
	var f0 := _frame(d0, n0.normalized())
	var f1 := _frame((to_sk.basis * hand_dir).normalized(), (to_sk.basis * palm_n).normalized())
	var hand_b := (f1 * f0.inverse()) * r_h.basis
	var h_rest_b := g_f1_rest.basis * sk.get_bone_rest(ih).basis
	var q := Quaternion((hand_b.orthonormalized() * h_rest_b.orthonormalized().inverse()
			).orthonormalized())
	if q.w < 0.0:
		q = Quaternion(-q.x, -q.y, -q.z, -q.w)
	# Only the roll about the forearm axis is shared: the twist bone takes part of it so the wrist
	# skin is not wrung into a thin stalk by the hand bone alone.
	var ax := g_f1_rest.basis.y.normalized()
	var pr := ax * Vector3(q.x, q.y, q.z).dot(ax)
	var twist := Quaternion(pr.x, pr.y, pr.z, q.w)
	if twist.length() < 0.00001:
		twist = Quaternion.IDENTITY
	else:
		twist = twist.normalized()
	var half := Quaternion.IDENTITY.slerp(twist, TWIST_SHARE)
	var g_f1 := Transform3D(Basis(half) * g_f1_rest.basis, g_f1_rest.origin)
	_set_local(sk, ifa1, g_f, g_f1)
	_set_local(sk, ih, g_f1, Transform3D(hand_b, w))
	return {"elbow": to_rig * e, "wrist": to_rig * w}


## Curls fingers: each value is the degrees for joints .01/.02/.03 of that finger.
static func curl(model: Node3D, suffix: String, angles: Dictionary) -> void:
	var sk := skeleton(model)
	for f in FINGERS:
		if not angles.has(f):
			continue
		var v: Vector3 = angles[f]
		for j in 3:
			var i := sk.find_bone("DEF-%s.0%d%s" % [f, j + 1, suffix])
			if i == -1:
				continue
			var q := sk.get_bone_rest(i).basis.get_rotation_quaternion()
			sk.set_bone_pose_rotation(i, q * Quaternion(Vector3.RIGHT,
					deg_to_rad(v[j]) * CURL_SIGN))


static func stretch_tips(model: Node3D, suffix: String, k: float) -> void:
	var sk := skeleton(model)
	for f in FINGERS:
		var i := sk.find_bone("DEF-%s.03%s" % [f, suffix])
		if i != -1:
			sk.set_bone_pose_scale(i, Vector3(1.0, k, 1.0))


## Lengthens the thumb: pose-scales its .02 bone along Y, which its .03 inherits.
static func stretch_thumb(model: Node3D, suffix: String, k: float) -> void:
	var sk := skeleton(model)
	var i := sk.find_bone("DEF-thumb.02" + suffix)
	if i != -1:
		sk.set_bone_pose_scale(i, Vector3(1.0, k, 1.0))


## Uniform pose scale on `DEF-hand<suffix>` about the wrist: the palm, finger bones, skinned
## finger tubes and claw attachments inherit it, the forearm does not.
static func scale_hand(model: Node3D, suffix: String, k: float) -> void:
	var sk := skeleton(model)
	var i := sk.find_bone("DEF-hand" + suffix)
	if i == -1:
		return
	sk.set_bone_pose_scale(i, Vector3.ONE * k)


## One swept claw per finger on its `.03` bone, sized from `ArmFingers.build`'s dictionary: the
## nail bed starts half-way along the tip's back and the horn reaches `claw_k` tips past it.
static func add_claws(model: Node3D, suffix: String, fingers: Dictionary, claw_k: float,
		curve_deg: float, mat: Material) -> void:
	var sk := skeleton(model)
	for f in FINGERS:
		var i3 := sk.find_bone("DEF-%s.03%s" % [f, suffix])
		if i3 == -1 or not fingers.has(f):
			continue
		var d: Dictionary = fingers[f]
		var tip_len: float = d[&"tip_len"]
		var bed_r: float = d[&"bed_r"]
		var horn_len := claw_k * tip_len
		if horn_len <= 0.0 or bed_r <= 0.0:
			continue
		var att := BoneAttachment3D.new()
		att.name = "Claw_" + String(f)
		att.bone_name = sk.get_bone_name(i3)
		sk.add_child(att)
		var dorsal: Vector3 = d[&"dorsal"]
		var lateral: Vector3 = d[&"lateral"]
		var crook: float = d[&"crook"]
		var at := Vector3(0.0, 0.5 * tip_len, 0.0) + dorsal * 0.92 * bed_r + lateral * crook
		ArmParts.mesh(att, "Claw", ArmClaw.mesh(0.5 * tip_len, horn_len, 1.5 * bed_r,
				0.35 * bed_r, curve_deg), mat, at, Basis(lateral, Vector3.UP, dorsal))
