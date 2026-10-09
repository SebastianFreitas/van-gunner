class_name ArmSkinLayers
extends RefCounted
## Seeds one arm's skin-layer shader uniforms: scars, wounds, knuckle grazes, dirt, the van-name tattoo.

## Flip a component to -1 if the tattoo reads mirrored (x) or upside down (y) in the arms-left shot.
const TAT_READ := Vector2(1, 1)
const SECTORS := 12
## Array sizes of the shader's uniforms.
const SCAR_MAX := 8
const WOUND_MAX := 4
const KNUCKLE_MAX := 4
const FINGERS: Array[String] = ["index", "middle", "ring", "pinky"]
## Scar centres sit this far off the facing angle, on the flanks of the arm.
const SCAR_OFFSET := PI / 3.0
## Re-rolls of a scar whose centre lands on the tattoo box.
const SCAR_TRIES := 8


## All positions are rest (mesh) space, never posed, so the layers follow the skinned mesh.
## `side` is ".L" or ".R"; `mat` is already this arm's own duplicate.
static func apply(mat: ShaderMaterial, model: Node3D, side: String, rng: RandomNumberGenerator,
		van_name: String, tattoo: bool) -> void:
	var sk := ArmRig.skeleton(model)
	var mi := _arm_mesh(sk)
	if mi == null:
		push_warning("ArmSkinLayers: no arm mesh under the skeleton")
		return
	var box := {}
	if tattoo and not van_name.strip_edges().is_empty():
		box = _tattoo(mat, model, mi, sk, side, rng, van_name)
	if box.is_empty():
		mat.set_shader_parameter(&"tat_count", 0)
	_scars(mat, model, mi, sk, side, rng, box)
	_wounds(mat, model, mi, sk, side, rng)
	_knuckles(mat, model, mi, sk, side, rng)
	ArmSkinFolds.apply(mat, mi, sk, side)
	mat.set_shader_parameter(&"dirt_amount", rng.randf_range(0.6, 0.9))


## The tattoo on the lower forearm, toward the wrist, where the player camera sees it. Returns
## its box (origin, axis, width, angle) for the scars to avoid, empty when nothing was set.
static func _tattoo(mat: ShaderMaterial, model: Node3D, mi: MeshInstance3D, sk: Skeleton3D,
		side: String, rng: RandomNumberGenerator, van_name: String) -> Dictionary:
	var fore := "DEF-forearm" + side
	var low := fore + ".001"
	if not _has(mi, sk, fore) or not _has(mi, sk, low):
		return {}
	var frame := ArmSkinMesh.ring_frame(mi, sk, fore, 0.80)
	var p0 := frame.origin
	var span := ArmSkinMesh.ring_frame(mi, sk, low, 0.65).origin - p0
	var width := span.length()
	if width < 0.0001:
		return {}
	var axis := span / width
	var height := 1.5 * _radius(mi, sk, fore, 0.5)
	var lay := ArmTattooFont.layout(van_name, width * 0.92, height)
	var unit: float = lay["unit"]
	if unit <= 0.0:
		return {}
	var segs := ArmTattooFont.jitter(lay["segs"], rng, 0.15 * unit)
	for i in segs.size():
		var s := segs[i]
		var x0 := s.x + 0.04 * width
		var x1 := s.z + 0.04 * width
		var y0 := s.y
		var y1 := s.w
		if TAT_READ.x < 0.0:
			x0 = width - x0
			x1 = width - x1
		if TAT_READ.y < 0.0:
			y0 = height - y0
			y1 = height - y1
		segs[i] = Vector4(x0, y0, x1, y1)
	var count := segs.size()
	segs.resize(ArmTattooFont.MAX_SEGS)
	var bx := frame.basis.x
	var angle := ArmSkinMesh.facing_angle(model, fore, 1.0)
	mat.set_shader_parameter(&"tat_count", count)
	mat.set_shader_parameter(&"tat_segs", segs)
	mat.set_shader_parameter(&"tat_origin", p0)
	mat.set_shader_parameter(&"tat_axis", axis)
	mat.set_shader_parameter(&"tat_ref", (bx - axis * bx.dot(axis)).normalized())
	mat.set_shader_parameter(&"tat_radius", _radius(mi, sk, fore, 1.0))
	mat.set_shader_parameter(&"tat_angle", angle)
	mat.set_shader_parameter(&"tat_along0", 0.0)
	mat.set_shader_parameter(&"tat_width", width)
	mat.set_shader_parameter(&"tat_height", height)
	mat.set_shader_parameter(&"tat_stroke", 0.32 * unit)
	return {"origin": p0, "axis": axis, "width": width, "angle": angle}


## 3 or 4 scars, the longest first and stitched. On the tattoo arm only one thin scar may cross
## the ink, the owner wants one over it; any other whose centre lands in the box is re-rolled.
static func _scars(mat: ShaderMaterial, model: Node3D, mi: MeshInstance3D, sk: Skeleton3D,
		side: String, rng: RandomNumberGenerator, box: Dictionary) -> void:
	var bones: Array[String] = ["DEF-forearm" + side, "DEF-forearm" + side + ".001",
			"DEF-hand" + side]
	var scars: Array[Dictionary] = []
	var crossed := false
	for _i in rng.randi_range(3, 4):
		for _try in SCAR_TRIES:
			var s := _roll_scar(model, mi, sk, bones[rng.randi_range(0, 2)], rng)
			if s.is_empty():
				break
			var centre: Vector3 = s["centre"]
			var angle: float = s["angle"]
			if not box.is_empty() and _in_box(box, centre, angle):
				if crossed:
					continue
				crossed = true
				s["cross"] = true
			scars.append(s)
			break
	# Slot 0 is the stitched scar, so the thin tattoo-crossing one never takes it: the
	# longest of the others goes first, and the crossing scar is thinned after the swap.
	var best := -1
	for i in scars.size():
		if scars[i].has("cross"):
			continue
		if best < 0 or _scar_len(scars[i]) > _scar_len(scars[best]):
			best = i
	if best > 0:
		var first := scars[0]
		scars[0] = scars[best]
		scars[best] = first
	for i in range(1, scars.size()):
		if scars[i].has("cross"):
			scars[i]["hw"] = 0.05 * float(scars[i]["r"])
	var va := PackedVector4Array()
	var vb := PackedVector4Array()
	for i in scars.size():
		var p0: Vector3 = scars[i]["p0"]
		var p1: Vector3 = scars[i]["p1"]
		var hw: float = scars[i]["hw"]
		va.append(Vector4(p0.x, p0.y, p0.z, hw))
		vb.append(Vector4(p1.x, p1.y, p1.z, 1.0 if i == 0 else 0.0))
	va.resize(SCAR_MAX)
	vb.resize(SCAR_MAX)
	mat.set_shader_parameter(&"scar_count", scars.size())
	mat.set_shader_parameter(&"scar_a", va)
	mat.set_shader_parameter(&"scar_b", vb)


## One scar's endpoints (surface points either side of a centre on the arm's flank), its
## half-width and the centre's chart position; empty when the bone is missing.
static func _roll_scar(model: Node3D, mi: MeshInstance3D, sk: Skeleton3D, bone: String,
		rng: RandomNumberGenerator) -> Dictionary:
	if not _has(mi, sk, bone):
		return {}
	var t := rng.randf_range(0.2, 0.8)
	var side_sign := SCAR_OFFSET if rng.randf() < 0.5 else -SCAR_OFFSET
	var angle := ArmSkinMesh.facing_angle(model, bone, t) + side_sign
	var r := maxf(_radius(mi, sk, bone, 0.5), 0.001)
	var half := 0.5 * rng.randf_range(0.6, 1.6) * r
	var dir := rng.randf_range(0.0, TAU)
	var hw := rng.randf_range(0.07, 0.12) * r
	# The scar's direction on the skin, as a step along the bone and a step around it.
	var dt := cos(dir) * half / maxf(ArmWrap.bone_len(mi, sk, bone), 0.001)
	var da := sin(dir) * half / r
	return {
		"p0": _surf(mi, sk, bone, clampf(t - dt, 0.0, 1.0), angle - da),
		"p1": _surf(mi, sk, bone, clampf(t + dt, 0.0, 1.0), angle + da),
		"centre": _surf(mi, sk, bone, t, angle),
		"angle": angle,
		"hw": hw,
		"r": r,
	}


## Wounds: the right arm gets a gash on the forearm and maybe a small one
## on the back of the hand, the left arm one small one on the back of the hand.
static func _wounds(mat: ShaderMaterial, model: Node3D, mi: MeshInstance3D, sk: Skeleton3D,
		side: String, rng: RandomNumberGenerator) -> void:
	var fore := "DEF-forearm" + side
	var hand := "DEF-hand" + side
	var rolled: Array[PackedVector4Array] = []
	if side == ".R":
		rolled.append(_wound(model, mi, sk, fore, 0.66, 0.22, 0.30, rng))
		if rng.randf() < 0.5:
			rolled.append(_wound(model, mi, sk, hand, 0.5, 0.12, 0.16, rng))
	else:
		rolled.append(_wound(model, mi, sk, hand, 0.5, 0.12, 0.16, rng))
	var wp := PackedVector4Array()
	var wd := PackedVector4Array()
	for w in rolled:
		if w.size() == 2:
			wp.append(w[0])
			wd.append(w[1])
	var count := wp.size()
	wp.resize(WOUND_MAX)
	wd.resize(WOUND_MAX)
	mat.set_shader_parameter(&"wound_count", count)
	mat.set_shader_parameter(&"wound_p", wp)
	mat.set_shader_parameter(&"wound_d", wd)


## [centre + radius, direction + elongation] of a wound at (t, facing angle) of `bone`, with the
## direction along the bone turned up to 20 degrees on the surface; empty when the bone is missing.
static func _wound(model: Node3D, mi: MeshInstance3D, sk: Skeleton3D, bone: String, t: float,
		lo: float, hi: float, rng: RandomNumberGenerator) -> PackedVector4Array:
	if not _has(mi, sk, bone):
		return PackedVector4Array()
	var angle := ArmSkinMesh.facing_angle(model, bone, t)
	var frame := ArmSkinMesh.ring_frame(mi, sk, bone, t)
	var p := _surf(mi, sk, bone, t, angle)
	var normal := (frame.basis * Vector3(cos(angle), 0.0, sin(angle))).normalized()
	var dir := frame.basis.y.normalized().rotated(normal, deg_to_rad(rng.randf_range(-20.0, 20.0)))
	var radius := rng.randf_range(lo, hi) * _radius(mi, sk, bone, 0.5)
	var elong := rng.randf_range(1.6, 2.2)
	return PackedVector4Array([Vector4(p.x, p.y, p.z, radius),
			Vector4(dir.x, dir.y, dir.z, elong)])


## Grazes on the finger heads, pushed toward the back of the hand: all four on the right hand,
## two random ones on the left.
static func _knuckles(mat: ShaderMaterial, model: Node3D, mi: MeshInstance3D, sk: Skeleton3D,
		side: String, rng: RandomNumberGenerator) -> void:
	var hand := "DEF-hand" + side
	var picks: Array[int] = [0, 1, 2, 3]
	if side == ".L":
		var i0 := rng.randi_range(0, 3)
		var i1 := rng.randi_range(0, 2)
		picks = [i0, (i1 + 1) if i1 >= i0 else i1]
	var out := PackedVector4Array()
	if _has(mi, sk, hand):
		var fa := ArmSkinMesh.facing_angle(model, hand, 0.5)
		var face := (ArmSkinMesh.ring_frame(mi, sk, hand, 0.5).basis
				* Vector3(cos(fa), 0.0, sin(fa))).normalized()
		for i in picks:
			var bone := "DEF-f_%s.01%s" % [FINGERS[i], side]
			if not _has(mi, sk, bone):
				continue
			var fr := _radius(mi, sk, bone, 0.5)
			var c := ArmSkinMesh.ring_frame(mi, sk, bone, 0.0).origin + face * (0.7 * fr)
			out.append(Vector4(c.x, c.y, c.z, 0.9 * fr))
	var count := out.size()
	out.resize(KNUCKLE_MAX)
	mat.set_shader_parameter(&"knuckle_count", count)
	mat.set_shader_parameter(&"knuckles", out)


## True when the point sits inside the tattoo box: along the axis from -0.1 to 1.1 of its width
## and within 1.4 radians of the tattoo's angle around the arm.
static func _in_box(box: Dictionary, p: Vector3, angle: float) -> bool:
	var origin: Vector3 = box["origin"]
	var axis: Vector3 = box["axis"]
	var width: float = box["width"]
	var tat_angle: float = box["angle"]
	var along := (p - origin).dot(axis) / maxf(width, 0.0001)
	return along > -0.1 and along < 1.1 and absf(angle_difference(angle, tat_angle)) < 1.4


static func _scar_len(s: Dictionary) -> float:
	var p0: Vector3 = s["p0"]
	var p1: Vector3 = s["p1"]
	return p0.distance_to(p1)


## Point on the skin of `bone` at fraction t along it and angle a around it, in mesh space.
static func _surf(mi: MeshInstance3D, sk: Skeleton3D, bone: String, t: float,
		a: float) -> Vector3:
	var sec := ArmWrap.section(mi, sk, bone, t, SECTORS, PackedStringArray())
	var r := 0.0
	if not sec.is_empty():
		r = sec[wrapi(int(floor((a + PI) / TAU * SECTORS)), 0, SECTORS)]
	return ArmSkinMesh.ring_frame(mi, sk, bone, t) * Vector3(cos(a) * r, 0.0, sin(a) * r)


## Mean section radius of `bone` at fraction t: the scale every size here is a fraction of.
static func _radius(mi: MeshInstance3D, sk: Skeleton3D, bone: String, t: float) -> float:
	return ArmWrap.mean_radius(ArmWrap.section(mi, sk, bone, t, SECTORS, PackedStringArray()))


static func _has(mi: MeshInstance3D, sk: Skeleton3D, bone: String) -> bool:
	if ArmWrap.bind_index(mi, sk, bone) != -1:
		return true
	push_warning("ArmSkinLayers: bone %s missing, skipping its item" % bone)
	return false


## The bare arm mesh: the skeleton's first MeshInstance3D that is not a dress piece.
static func _arm_mesh(sk: Skeleton3D) -> MeshInstance3D:
	if sk == null:
		return null
	for c in sk.get_children():
		var nm := String(c.name)
		if c is MeshInstance3D and not nm.begins_with("Dress_"):
			return c as MeshInstance3D
	return null
