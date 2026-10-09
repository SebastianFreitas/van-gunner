class_name ArmLimbTail
extends RefCounted
## Builds a long bare monster limb that continues each upper arm back past the cut shoulder ring.

const RINGS := 12
const SECTORS := 14
## Length of the tail in rig units (1 = 18 cm).
const LENGTH := 4.0
## Radius gain at the sinew bulge and the fraction left at the far end.
const BULGE := 0.14
const END_TAPER := 0.8


## The tail on `side` (".L" or ".R"): a tube skinned wholly to the first upper-arm bone,
## starting on the glb's top ring with that ring's radii. Null with a warning when the arm
## mesh or the bone is missing.
static func build(model: Node3D, side: String, rng: RandomNumberGenerator,
		mat: Material) -> MeshInstance3D:
	var sk := ArmRig.skeleton(model)
	var mi := _arm_mesh(sk)
	var bone := StringName("DEF-upper_arm" + side)
	if mi == null or sk.find_bone(bone) == -1:
		push_warning("ArmLimbTail: no arm mesh or bone %s" % bone)
		return null
	var b := ArmWrap.bind_index(mi, sk, bone)
	if b == -1:
		push_warning("ArmLimbTail: bone %s not in the arm skin" % bone)
		return null
	var frame := ArmSkinMesh.ring_frame(mi, sk, bone, 0.0)
	var ring := _top_ring(mi, frame, b, 0.06 * ArmWrap.bone_len(mi, sk, bone))
	if ring.is_empty():
		push_warning("ArmLimbTail: no top ring for %s" % bone)
		return null
	var top_y: float = ring.y
	var centre: Vector2 = ring.centre
	var radii: PackedFloat32Array = ring.radii
	var mean_r := ArmWrap.mean_radius(radii)
	var length := LENGTH / maxf(model.transform.basis.get_scale().y, 0.001)
	var phi := rng.randf() * TAU

	var verts := PackedVector3Array()
	var custom0 := PackedFloat32Array()
	var centres := PackedVector3Array()
	for k in RINGS:
		var s := float(k) / float(RINGS - 1)
		# 1 at the glb ring, easing to a sinew bulge a third of the way, then a gentle taper.
		var girth := 1.0 + BULGE * sin(PI * clampf(s * 1.5, 0.0, 1.0)) \
				- (1.0 - END_TAPER) * smoothstep(0.35, 1.0, s)
		var y := top_y - s * length
		# Ring k=0 is the glb's own ring; the far ring closes toward the cap.
		for j in SECTORS:
			var a := TAU * float(j) / float(SECTORS)
			var sinew := 1.0 + 0.05 * sin(3.0 * a + phi + 5.0 * s) * s
			var r := lerpf(radii[j], mean_r, smoothstep(0.0, 0.5, s)) * girth * sinew
			var v := Vector3(centre.x + cos(a) * r, y, centre.y + sin(a) * r)
			verts.append(frame * v)
			custom0.append_array(PackedFloat32Array([-s * length, cos(a) * r, sin(a) * r, 1.0]))
		centres.append(frame * Vector3(centre.x, y, centre.y))

	var indices := ArmSkinMesh.tube_indices(verts, centres, RINGS, SECTORS)
	# Cap: one apex vertex past the last ring, wound the same way as the tube.
	var far_y := top_y - length
	var apex := verts.size()
	var apex_v := frame * Vector3(centre.x, far_y - 0.1 * mean_r, centre.y)
	verts.append(apex_v)
	custom0.append_array(PackedFloat32Array([-length, 0.0, 0.0, 1.0]))
	var out_dir := (frame.basis * Vector3.DOWN).normalized()
	var base := (RINGS - 1) * SECTORS
	for j in SECTORS:
		var ia := base + j
		var ib := base + (j + 1) % SECTORS
		var fn := (verts[apex] - verts[ia]).cross(verts[ib] - verts[ia])
		if fn.dot(out_dir) >= 0.0:
			indices.append_array(PackedInt32Array([ia, ib, apex]))
		else:
			indices.append_array(PackedInt32Array([ia, apex, ib]))

	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for _i in verts.size():
		bones.append_array(PackedInt32Array([b, 0, 0, 0]))
		weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	return ArmSkinMesh.build(mi, sk, StringName("Limb_tail" + side), verts,
			PackedVector3Array(), custom0, bones, weights, indices, mat, true, 0.0)


## The glb's top ring of the upper arm, in the bone's frame: {y, centre (x, z), radii per
## sector}, from the vertices mostly weighted to `bind` that lie within `slab` of the bone's
## most head-ward one. Empty when there are none.
static func _top_ring(mi: MeshInstance3D, frame: Transform3D, bind: int,
		slab: float) -> Dictionary:
	if not (mi.mesh is ArrayMesh):
		return {}
	var mesh := mi.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := 4
	if (mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0:
		per = 8
	if bones.size() < verts.size() * per:
		return {}
	var inv := frame.affine_inverse()
	var pts: Array[Vector3] = []
	var min_y := INF
	for i in verts.size():
		var best := -1
		var best_w := 0.0
		for m in per:
			if weights[i * per + m] > best_w:
				best_w = weights[i * per + m]
				best = bones[i * per + m]
		if best != bind:
			continue
		var p := inv * verts[i]
		# Head-ward is -Y; stray verts far off the axis are not part of the arm tube.
		if Vector2(p.x, p.z).length() > 1.0:
			continue
		pts.append(p)
		min_y = minf(min_y, p.y)
	var ring: Array[Vector3] = []
	for p in pts:
		if p.y <= min_y + slab:
			ring.append(p)
	if ring.size() < 3:
		return {}
	var c := Vector2.ZERO
	var y := 0.0
	for p in ring:
		c += Vector2(p.x, p.z)
		y += p.y
	c /= float(ring.size())
	y /= float(ring.size())
	var sums := PackedFloat32Array()
	sums.resize(SECTORS)
	var counts := PackedInt32Array()
	counts.resize(SECTORS)
	var total := 0.0
	for p in ring:
		var d := Vector2(p.x, p.z) - c
		var j := int(fposmod(d.angle(), TAU) / TAU * float(SECTORS)) % SECTORS
		sums[j] += d.length()
		counts[j] += 1
		total += d.length()
	var mean := total / float(ring.size())
	var radii := PackedFloat32Array()
	radii.resize(SECTORS)
	for j in SECTORS:
		radii[j] = sums[j] / float(counts[j]) if counts[j] > 0 else mean
	return {"y": y, "centre": c, "radii": radii}


static func _arm_mesh(sk: Skeleton3D) -> MeshInstance3D:
	if sk == null:
		return null
	for c in sk.get_children():
		var nm := String(c.name)
		if c is MeshInstance3D and not nm.begins_with("Limb_") and not nm.begins_with("Dress_"):
			return c as MeshInstance3D
	return null
