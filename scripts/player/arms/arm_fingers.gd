class_name ArmFingers
extends RefCounted
## Procedural finger tubes: per hand one skinned mesh of five bony finger tubes (knuckle knobs, thin shafts, flat pads, tapering tips, a seeded sideways crook) in the glb skin's bind space.

## Vertices per ring.
const SECTORS := 8
## Dorsal half-width kept on the flat pad side of a ring.
const PAD_H := 0.86
## Dorsal half-width of the nail bed, on the distal rings from this fraction of the tip on.
const NAIL_H := 0.85
const NAIL_FROM := 0.55
## Thumb shaft radius as a multiple of the index finger's shaft radius.
const THUMB_R := 1.35


## Builds `Skin_fingers` under the arm skeleton and returns, per finger in `ArmRig.FINGERS`,
## {tip_len, bed_r, dorsal, lateral, crook, shaft, length, r2, r3} of its `.03` bone (bind
## units, bone-local axes). `girth` is the shaft radius as a share of the glb finger root radius.
static func build(model: Node3D, suffix: String, girth: float, rng: RandomNumberGenerator,
		mat: Material) -> Dictionary:
	var sk := ArmRig.skeleton(model)
	var mi := _glb_mesh(sk)
	if mi == null or mi.skin == null or not (mi.mesh is ArrayMesh):
		push_warning("ArmFingers: no skinned arm mesh, no finger tubes")
		return {}
	var own := _owned(mi)
	var verts := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var out := {}
	var ref_r := 0.0
	for f in ArmRig.FINGERS:
		# Drawn even when the finger is skipped, so one missing bone keeps the others' crooks.
		var cr := rng.randf_range(-0.40, 0.40) * (0.0 if f == &"thumb" else 1.0)
		var fg := _finger(mi, sk, own, f, suffix, girth, cr, ref_r)
		if fg.is_empty():
			continue
		if f == &"f_index":
			ref_r = fg[&"r1"]
		var fv: PackedVector3Array = fg[&"verts"]
		var centres: PackedVector3Array = fg[&"centres"]
		var rings: int = fg[&"rings"]
		var idx := ArmSkinMesh.tube_indices(fv, centres, rings, SECTORS)
		idx.append_array(_cap(fv, rings, centres[rings - 1]))
		var base := verts.size()
		for i in idx:
			indices.append(base + i)
		verts.append_array(fv)
		var wts: Array = fg[&"wts"]
		for w in wts:
			var t4 := ArmSkinMesh.top4(w)
			bones.append_array(t4[0])
			weights.append_array(t4[1])
		out[f] = fg[&"info"]
	if not verts.is_empty():
		ArmSkinMesh.build(mi, sk, &"Skin_fingers", verts, PackedVector3Array(),
				PackedFloat32Array(), bones, weights, indices, mat, true)
	return out


## One finger's rings, weights and info, or {} when one of its bones is missing.
static func _finger(mi: MeshInstance3D, sk: Skeleton3D, own: Dictionary, f: StringName,
		suffix: String, girth: float, cr: float, ref_r: float) -> Dictionary:
	var thumb := f == &"thumb"
	# The thumb's tube covers .02 and .03: its .01 is the palm's thumb meat.
	var first := 2 if thumb else 1
	var names: Array[String] = ["", "", "", ""]
	var binds: Array[int] = [-1, -1, -1, -1]
	for j in range(first, 4):
		names[j] = "DEF-%s.0%d%s" % [f, j, suffix]
		binds[j] = ArmWrap.bind_index(mi, sk, names[j])
		if sk.find_bone(names[j]) < 0 or binds[j] < 0:
			push_warning("ArmFingers: bone %s missing, %s gets no tube" % [names[j], f])
			return {}
	var lens: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for j in range(first, 3):
		lens[j] = ArmWrap.bone_len(mi, sk, names[j])
	var root_pts: PackedVector3Array = own.get(binds[first], PackedVector3Array())
	var tip_pts: PackedVector3Array = own.get(binds[3], PackedVector3Array())
	lens[3] = _tip_len(tip_pts, lens[2])
	# Pads face down; the thumb's faces the index finger, turning its flat pad and claw inward.
	var pad := Vector3.DOWN
	if thumb:
		var idx := "DEF-f_index.01" + suffix
		if sk.find_bone(idx) >= 0 and ArmWrap.bind_index(mi, sk, idx) >= 0:
			var toward := ArmSkinMesh.ring_frame(mi, sk, idx, 0.0).origin \
					- ArmSkinMesh.ring_frame(mi, sk, names[2], 0.0).origin
			if toward.length() >= 1e-4:
				pad = toward
	var r0 := _root_radius(root_pts, lens[first])
	# The thumb is sized from the index's shaft, not its own thin glb root.
	var use_ref := thumb and ref_r > 0.0
	var rk := _radii(ref_r if use_ref else r0, girth, thumb, use_ref)
	var shaft: PackedFloat32Array = rk[0]
	var knob: PackedFloat32Array = rk[1]
	var fg := {
		&"verts": PackedVector3Array(), &"centres": PackedVector3Array(), &"wts": [],
		&"rings": 0, &"names": names, &"binds": binds, &"lens": lens,
		&"cr": cr, &"r1": shaft[1], &"r2": shaft[2], &"r3": shaft[3], &"pad": pad,
		&"tip_rings": [],
	}
	var tip_prof := _tip_profile(knob[3], shaft[3])
	for j in range(first, 4):
		var prof := tip_prof if j == 3 else _shaft_profile(knob[j], shaft[j], knob[j + 1])
		_segment(mi, sk, fg, j, prof)
	# The pole closes the tip on the finger's own (crooked) axis, weighted to .03 only.
	var base := ArmSkinMesh.ring_frame(mi, sk, names[3], 0.0)
	var ax := _axes(base, pad)
	var fv: PackedVector3Array = fg[&"verts"]
	fv.append(base.origin + base.basis.y.normalized() * 1.06 * lens[3]
			+ ax[1] * _crook(3, 1.0, fg))
	var wts: Array = fg[&"wts"]
	wts.append({binds[3]: 1.0})
	var inv := base.basis.inverse()
	var tube_len := 0.0
	for j in range(first, 4):
		tube_len += lens[j]
	# Tip rings in the nail frame (x lateral, y along the bone, z dorsal) of the bone-local
	# attachment, so ArmClaw can follow the tube without further offsets.
	var lat_n := (inv * ax[1]).normalized()
	var dor_n := (inv * ax[0]).normalized()
	var tip_rings: Array = []
	for r: Dictionary in fg[&"tip_rings"]:
		var v: Vector3 = inv * (r[&"centre"] - base.origin)
		tip_rings.append({&"t": r[&"t"], &"centre": Vector3(lat_n.dot(v), v.y, dor_n.dot(v)),
				&"half_w": r[&"half_w"], &"half_h": r[&"half_h"]})
	tip_rings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a[&"t"]) < float(b[&"t"]))
	fg[&"info"] = {
		&"tip_rings": tip_rings,
		&"tip_len": lens[3],
		&"bed_r": _radius_at(tip_prof, 0.5),
		&"dorsal": (inv * ax[0]).normalized(),
		&"lateral": (inv * ax[1]).normalized(),
		&"crook": cr * shaft[2] + 0.3 * cr * shaft[3],
		&"shaft": shaft[first],
		&"length": tube_len,
		&"r2": shaft[2],
		&"r3": shaft[3],
	}
	return fg


## Appends the rings of tube bone `j` (profile `prof` of (t, radius, dorsal offset)) and the
## weight of each vertex to the finger being built in `fg`.
static func _segment(mi: MeshInstance3D, sk: Skeleton3D, fg: Dictionary, j: int,
		prof: Array[Vector3]) -> void:
	var names: Array[String] = fg[&"names"]
	var binds: Array[int] = fg[&"binds"]
	var lens: Array[float] = fg[&"lens"]
	var fv: PackedVector3Array = fg[&"verts"]
	var centres: PackedVector3Array = fg[&"centres"]
	var wts: Array = fg[&"wts"]
	var base := ArmSkinMesh.ring_frame(mi, sk, names[j], 0.0)
	var y := base.basis.y.normalized()
	var pad: Vector3 = fg[&"pad"]
	var ax := _axes(base, pad)
	var parent := _parent_bind(mi, sk, names[j])
	var nxt := binds[j + 1] if j < 3 else -1
	for p in prof:
		var c := base.origin + y * p.x * lens[j] + ax[0] * p.z * p.y \
				+ ax[1] * _crook(j, p.x, fg)
		var h := NAIL_H if j == 3 and p.x >= NAIL_FROM else 1.0
		_ring(fv, c, ax[0], ax[1], p.y, h)
		if j == 3:
			var tips: Array = fg[&"tip_rings"]
			tips.append({&"t": p.x, &"centre": c, &"half_w": 0.92 * p.y, &"half_h": p.y * h})
		centres.append(c)
		var w := _ring_weights(binds[j], parent, nxt, p.x)
		for _s in SECTORS:
			wts.append(w)
		fg[&"rings"] = int(fg[&"rings"]) + 1


## Eight points around centre `c`: sector 0 on the dorsal side, the pad half flattened.
static func _ring(fv: PackedVector3Array, c: Vector3, dorsal: Vector3, lateral: Vector3,
		radius: float, dorsal_h: float) -> void:
	for s in SECTORS:
		var a := TAU * float(s) / float(SECTORS)
		var h := dorsal_h if cos(a) >= 0.0 else PAD_H
		fv.append(c + dorsal * cos(a) * radius * h + lateral * sin(a) * radius * 0.92)


## Shaft bone rings: head knob `k`, thin shaft `r`, swelling into the next knob `kn`.
static func _shaft_profile(k: float, r: float, kn: float) -> Array[Vector3]:
	var p: Array[Vector3] = [
		Vector3(0.00, k, 0.18), Vector3(0.14, 0.96 * k, 0.12), Vector3(0.30, r, 0.0),
		Vector3(0.55, 0.95 * r, 0.0), Vector3(0.80, 1.05 * r, 0.0),
		Vector3(0.92, 0.88 * kn, 0.10),
	]
	return p


## Distal bone rings: knob `k3`, shaft `r3`, a tapering tip whose pad side sits low.
static func _tip_profile(k3: float, r3: float) -> Array[Vector3]:
	var p: Array[Vector3] = [
		Vector3(0.00, k3, 0.18), Vector3(0.14, 0.95 * k3, 0.10), Vector3(0.32, r3, 0.0),
		Vector3(0.55, 0.90 * r3, 0.0), Vector3(0.78, 0.72 * r3, 0.0),
		Vector3(0.95, 0.50 * r3, -0.10), Vector3(1.00, 0.30 * r3, -0.10),
	]
	return p


## Profile radius at fraction `t`, interpolated between its rings.
static func _radius_at(prof: Array[Vector3], t: float) -> float:
	for i in prof.size() - 1:
		if t <= prof[i + 1].x:
			return lerpf(prof[i].y, prof[i + 1].y, inverse_lerp(prof[i].x, prof[i + 1].x, t))
	return prof[prof.size() - 1].y


## [shaft radii, knob radii] indexed by bone number 1..3 (0 unused, thumb has no 1).
static func _radii(r0: float, girth: float, thumb: bool, ref: bool = false) -> Array:
	var r := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var k := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	if thumb:
		# With `ref`, r0 is already the index's shaft radius.
		r[2] = THUMB_R * r0 if ref else 1.1 * girth * r0
		r[3] = 0.90 * r[2]
		k[2] = 1.28 * r[2]
	else:
		r[1] = girth * r0
		r[2] = 0.90 * r[1]
		r[3] = 0.78 * r[1]
		k[1] = 1.40 * r[1]
		k[2] = 1.35 * r[2]
	k[3] = (1.22 if thumb else 1.25) * r[3]
	return [r, k]


## Sideways centre shift of bone `j` at fraction `t`: the .02 eases into the crook, the .03
## keeps leaning, the .01 stays straight.
static func _crook(j: int, t: float, fg: Dictionary) -> float:
	var cr: float = fg[&"cr"]
	var r2: float = fg[&"r2"]
	var r3: float = fg[&"r3"]
	if j == 2:
		return cr * r2 * smoothstep(0.0, 1.0, t)
	if j == 3:
		return cr * r2 + 0.6 * cr * r3 * t
	return 0.0


## [dorsal, lateral] in mesh space for a bone frame: the pad faces `pad_hint` (DOWN for the
## fingers, as the rest hand hangs palm down; the index finger for the thumb).
static func _axes(frame: Transform3D, pad_hint: Vector3 = Vector3.DOWN) -> PackedVector3Array:
	var y := frame.basis.y.normalized()
	var pad := (pad_hint - y * pad_hint.dot(y)).normalized()
	return PackedVector3Array([-pad, y.cross(pad).normalized()])


## Own bone, blended with the parent near the head and the next tube bone near the tail.
static func _ring_weights(own: int, parent: int, nxt: int, t: float) -> Dictionary:
	if t < 0.2 and parent >= 0:
		var pw := 0.5 * (1.0 - t / 0.2)
		return {own: 1.0 - pw, parent: pw}
	if t > 0.8 and nxt >= 0:
		var cw := 0.5 * (t - 0.8) / 0.2
		return {own: 1.0 - cw, nxt: cw}
	return {own: 1.0}


static func _parent_bind(mi: MeshInstance3D, sk: Skeleton3D, bone: String) -> int:
	var p := sk.get_bone_parent(sk.find_bone(bone))
	if p < 0:
		return -1
	return ArmWrap.bind_index(mi, sk, sk.get_bone_name(p))


## Triangles closing the last ring on the pole vertex (the one after the rings), wound so the
## first one's outward normal (c - a) x (b - a), as ArmSkinMesh.build reads it, faces away.
static func _cap(fv: PackedVector3Array, rings: int, last_c: Vector3) -> PackedInt32Array:
	var first := (rings - 1) * SECTORS
	var pole := rings * SECTORS
	var out := PackedInt32Array()
	for s in SECTORS:
		out.append_array(PackedInt32Array([first + s, first + (s + 1) % SECTORS, pole]))
	var n := (fv[out[2]] - fv[out[0]]).cross(fv[out[1]] - fv[out[0]])
	if n.dot(fv[pole] - last_c) < 0.0:
		for i in range(0, out.size(), 3):
			var tmp := out[i + 1]
			out[i + 1] = out[i + 2]
			out[i + 2] = tmp
	return out


## The arm skeleton's glb mesh: first skinned MeshInstance3D child (as ArmSkinMesh._arm_mesh).
static func _glb_mesh(sk: Skeleton3D) -> MeshInstance3D:
	if sk == null:
		return null
	for c in sk.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).skin != null:
			return c as MeshInstance3D
	return null


## Glb vertices in bone space per bind index, those the bind holds at weight 0.5 or more.
static func _owned(mi: MeshInstance3D) -> Dictionary:
	var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := int(float(bones.size()) / maxf(float(verts.size()), 1.0))
	var out := {}
	if per == 0 or weights.size() < verts.size() * per:
		return out
	for k in verts.size():
		for m in per:
			if weights[k * per + m] >= 0.5:
				var b := bones[k * per + m]
				var pts: PackedVector3Array = out.get(b, PackedVector3Array())
				pts.append(mi.skin.get_bind_pose(b) * verts[k])
				out[b] = pts
	return out


## The leaf bone's length: its highest owned vertex, or 0.8 x the parent's with too few.
static func _tip_len(pts: PackedVector3Array, len02: float) -> float:
	if pts.size() < 3:
		return 0.8 * len02
	var top := pts[0].y
	for p in pts:
		top = maxf(top, p.y)
	return top


## The un-shrunk root's radius: 90th percentile of the owned vertices just past the head.
static func _root_radius(pts: PackedVector3Array, length: float) -> float:
	var rs: Array[float] = []
	for p in pts:
		var u := p.y / length
		if u >= 0.02 and u <= 0.10:
			rs.append(Vector2(p.x, p.z).length())
	if rs.size() < 6:
		return 0.26 * length
	rs.sort()
	return rs[int(0.9 * float(rs.size() - 1))]
