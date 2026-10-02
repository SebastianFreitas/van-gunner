extends RefCounted
class_name ArmSleeve
## Builds the oversized torn T-shirt sleeve as a skinned tube on the upper arm, above the elbow.

const RINGS := 14
const SECTORS := 16


## The sleeve on `side` (".L" or ".R"): a loose skinned tube down the upper arm, its hem torn
## and open just above the elbow. CUSTOM0 carries the rest position and the edge value (0 at
## the hem) the cloth shader reads. Null with a warning when the arm mesh or a chain bone is
## missing.
static func build(model: Node3D, side: String, rng: RandomNumberGenerator,
		mat: Material) -> MeshInstance3D:
	var sk := ArmRig.skeleton(model)
	var mi := _arm_mesh(sk)
	if mi == null:
		push_warning("ArmSleeve: no arm mesh under the skeleton")
		return null
	var chain: Array[StringName] = [
		StringName("DEF-upper_arm" + side), StringName("DEF-upper_arm" + side + ".001")]
	var froms: Array[float] = [0.25, 0.0]
	var tos: Array[float] = [1.0, 0.72]
	var lens: Array[float] = []
	var total := 0.0
	for i in chain.size():
		if sk.find_bone(chain[i]) == -1:
			push_warning("ArmSleeve: bone %s missing" % chain[i])
			return null
		lens.append(ArmWrap.bone_len(mi, sk, chain[i]) * (tos[i] - froms[i]))
		total += lens[i]
	var s_hem := (lens[0] + lens[1]) / maxf(total, 0.0001)

	var frames: Array[Transform3D] = []
	var ring_bone: Array[StringName] = []
	var ring_radii: Array[PackedFloat32Array] = []
	var rs: Array[float] = []
	var downs: Array[Vector3] = []
	var centres := PackedVector3Array()
	for k in RINGS:
		var at := _walk(lens, froms, tos, float(k) / float(RINGS - 1))
		var bone: StringName = chain[int(at[0])]
		var t := float(at[1])
		var radii := ArmWrap.section(mi, sk, bone, t, SECTORS, PackedStringArray())
		if radii.is_empty():
			push_warning("ArmSleeve: no arm section for %s" % bone)
			return null
		var frame := ArmSkinMesh.ring_frame(mi, sk, bone, t)
		var down := ArmSkinMesh.posed_local(model, bone, Vector3.DOWN)
		down.y = 0.0
		frames.append(frame)
		ring_bone.append(bone)
		ring_radii.append(radii)
		rs.append(ArmWrap.mean_radius(radii))
		downs.append(down.normalized())
		centres.append(frame.origin)
	var spacing := frames[RINGS - 2].origin.distance_to(frames[RINGS - 1].origin)

	var phi1 := rng.randf() * TAU
	var phi2 := rng.randf() * TAU
	var hem := _hem(rng, spacing)
	var pulls: PackedFloat32Array = hem[0]
	var notches: Array = hem[1]
	var up := frames[RINGS - 1].basis.y.normalized()

	var verts := PackedVector3Array()
	verts.resize(RINGS * SECTORS)
	var custom0 := PackedFloat32Array()
	custom0.resize(RINGS * SECTORS * 4)
	for k in RINGS:
		var s := float(k) / float(RINGS - 1)
		var r := rs[k]
		var ed := (s - s_hem) / 0.12
		var offset := lerpf(0.10, 0.40, ease(s, 1.6)) * r + 0.05 * r * exp(-ed * ed)
		var shift := downs[k] * (0.12 * r * s * s + 0.04 * r)
		for j in SECTORS:
			# ArmWrap.section bins by atan2(z, x) + PI, so sector j is centred here.
			var a := -PI + (float(j) + 0.5) / float(SECTORS) * TAU
			var folds := (0.04 * r * sin(4.0 * a + 2.5 * s * TAU * 0.25 + phi1)
					+ 0.03 * r * sin(7.0 * a + phi2)) * (0.4 + 0.6 * s)
			var base: float = ring_radii[k][j]
			var dir := Vector3(cos(a), 0.0, sin(a))
			# The gap is kept after the sag shift, so the side opposite it stays clear.
			var radial := maxf(base + offset + folds, base + 0.06 * r - shift.dot(dir))
			var local := dir * radial + shift
			var v := frames[k] * local
			var e := 1.0
			if k == RINGS - 1:
				v -= up * pulls[j]
				e = 0.0
			elif k == RINGS - 2:
				e = 0.1 if j in notches else 0.33
			elif k == RINGS - 3:
				e = 0.67
			var idx := k * SECTORS + j
			verts[idx] = v
			custom0[idx * 4] = v.x
			custom0[idx * 4 + 1] = v.y
			custom0[idx * 4 + 2] = v.z
			custom0[idx * 4 + 3] = e

	var raw: Array[Dictionary] = []
	for k in RINGS:
		raw.append(ArmSkinMesh.ring_weights(mi, sk, frames[k], 0.5 * spacing, rs[k],
				ring_bone[k]))
	var smooth := ArmSkinMesh.smooth_weights(raw, 2)
	var fore_binds: Array[int] = [ArmWrap.bind_index(mi, sk, "DEF-forearm" + side),
			ArmWrap.bind_index(mi, sk, "DEF-forearm" + side + ".001")]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for k in RINGS:
		var share := smooth[k]
		# The hem is an open tube above the elbow: left blended with the forearm it swings away
		# from the arm skin there when the elbow bends, so the last rings follow the upper arm.
		if float(k) / float(RINGS - 1) >= 0.7:
			var kept := {}
			var sum := 0.0
			for key in share:
				if not key in fore_binds:
					kept[key] = share[key]
					sum += float(share[key])
			if sum > 0.0:
				for key in kept:
					kept[key] = float(kept[key]) / sum
				share = kept
		var four := ArmSkinMesh.top4(share)
		for _j in SECTORS:
			bones.append_array(four[0] as PackedInt32Array)
			weights.append_array(four[1] as PackedFloat32Array)

	var indices := ArmSkinMesh.tube_indices(verts, centres, RINGS, SECTORS)
	return ArmSkinMesh.build(mi, sk, &"Gear_sleeve", verts, PackedVector3Array(), custom0,
			bones, weights, indices, mat)


## Which chain piece and fraction of its bone lie at fraction `s` of the chain's total length.
static func _walk(lens: Array[float], froms: Array[float], tos: Array[float],
		s: float) -> Array:
	var total := 0.0
	for l in lens:
		total += l
	var d := s * total
	for i in lens.size():
		if d <= lens[i] or i == lens.size() - 1:
			var u := clampf(d / maxf(lens[i], 0.0001), 0.0, 1.0)
			return [i, lerpf(froms[i], tos[i], u)]
		d -= lens[i]
	return [0, froms[0]]


## The torn hem as [PackedFloat32Array pull-back per sector, Array of the two notch sectors]:
## ragged pulls smoothed once with their neighbours, then two non-adjacent V-notches cut in.
static func _hem(rng: RandomNumberGenerator, spacing: float) -> Array:
	var raw := PackedFloat32Array()
	raw.resize(SECTORS)
	for j in SECTORS:
		raw[j] = rng.randf() * 0.7 * spacing
	var pulls := PackedFloat32Array()
	pulls.resize(SECTORS)
	for j in SECTORS:
		pulls[j] = 0.25 * raw[(j + SECTORS - 1) % SECTORS] + 0.5 * raw[j] \
				+ 0.25 * raw[(j + 1) % SECTORS]
	var n0 := rng.randi_range(0, SECTORS - 1)
	var n1 := (n0 + rng.randi_range(2, SECTORS - 2)) % SECTORS
	for n: int in [n0, n1]:
		pulls[n] = 0.95 * spacing
		pulls[(n + SECTORS - 1) % SECTORS] = 0.5 * spacing
		pulls[(n + 1) % SECTORS] = 0.5 * spacing
	return [pulls, [n0, n1]]


## The arm's skinned mesh: the skeleton's first MeshInstance3D child that is not worn gear.
static func _arm_mesh(sk: Skeleton3D) -> MeshInstance3D:
	if sk == null:
		return null
	for c in sk.get_children():
		var nm := String(c.name)
		if c is MeshInstance3D and not nm.begins_with("Gear_") and not nm.begins_with("Dress_"):
			return c as MeshInstance3D
	return null
