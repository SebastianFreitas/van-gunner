class_name ArmSkinMesh
extends RefCounted
## Builds skinned cloth meshes on an arm skeleton: ring frames, averaged ring weights, tube indices.


## Bone frame in mesh (= bind) space, origin moved t of the bone's length along its Y.
static func ring_frame(mi: MeshInstance3D, sk: Skeleton3D, bone: StringName,
		t: float) -> Transform3D:
	var b := ArmWrap.bind_index(mi, sk, bone)
	if b == -1:
		push_warning("ArmSkinMesh: bone %s missing from the arm skin" % bone)
		return Transform3D.IDENTITY
	var frame := mi.skin.get_bind_pose(b).affine_inverse()
	frame.origin += frame.basis.y.normalized() * t * ArmWrap.bone_len(mi, sk, bone)
	return frame


## Arm-mesh weights (bind index to share, summing to 1) of the vertices inside a ring slab, so
## cloth sitting on that ring blends the same bones the skin underneath does.
static func ring_weights(mi: MeshInstance3D, sk: Skeleton3D, frame: Transform3D,
		half_width: float, radius: float, bone: StringName) -> Dictionary:
	var fallback_bind := ArmWrap.bind_index(mi, sk, bone)
	if fallback_bind == -1 or not (mi.mesh is ArrayMesh):
		push_warning("ArmSkinMesh: arm mesh or bone %s missing" % bone)
		return {}
	var mesh := mi.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := 4
	if (mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0:
		per = 8
	if bones.size() < verts.size() * per or weights.size() < verts.size() * per:
		return {fallback_bind: 1.0}
	var inv := frame.affine_inverse()
	var hw := half_width
	for _try in 3:
		var sum := {}
		for k in verts.size():
			var p := inv * verts[k]
			if absf(p.y) > hw or Vector2(p.x, p.z).length() > 2.5 * radius:
				continue
			for m in per:
				var w := weights[k * per + m]
				if w > 0.0:
					var bi := bones[k * per + m]
					sum[bi] = float(sum.get(bi, 0.0)) + w
		if not sum.is_empty():
			return _normalized(sum)
		hw *= 2.0
	return {fallback_bind: 1.0}


## Each ring blended with its neighbours (0.25 / 0.5 / 0.25), `passes` times, so the
## weights fade along the arm instead of stepping at a ring.
static func smooth_weights(rings: Array[Dictionary], passes: int) -> Array[Dictionary]:
	var cur: Array[Dictionary] = []
	for r in rings:
		cur.append(r)
	for _p in passes:
		var nxt: Array[Dictionary] = []
		for i in cur.size():
			var mixed := {}
			var parts: Array[Dictionary] = [
				cur[maxi(i - 1, 0)], cur[i], cur[mini(i + 1, cur.size() - 1)]]
			var shares := [0.25, 0.5, 0.25]
			for j in 3:
				for key in parts[j]:
					mixed[key] = float(mixed.get(key, 0.0)) + float(parts[j][key]) * shares[j]
			nxt.append(_normalized(mixed))
		cur = nxt
	return cur


## The 4 largest weights as [PackedInt32Array bones, PackedFloat32Array weights], renormalized
## and padded with (bind 0, 0.0), the layout a 4-weight skinned surface takes.
static func top4(w: Dictionary) -> Array:
	var keys: Array = w.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		if float(w[a]) == float(w[b]):
			return int(a) < int(b)
		return float(w[a]) > float(w[b]))
	var ids := PackedInt32Array()
	ids.resize(4)
	var ws := PackedFloat32Array()
	ws.resize(4)
	var total := 0.0
	for i in mini(4, keys.size()):
		ids[i] = int(keys[i])
		ws[i] = float(w[keys[i]])
		total += ws[i]
	if total > 0.0:
		for i in 4:
			ws[i] /= total
	return [ids, ws]


## Quad strip indices for `rings` rings of `sectors` vertices (index = ring * sectors + s, the
## sectors wrap), wound clockwise seen from outside, Godot's front face.
static func tube_indices(verts: PackedVector3Array, centres: PackedVector3Array, rings: int,
		sectors: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if rings < 2 or sectors < 3 or verts.size() < rings * sectors:
		return out
	for k in rings - 1:
		for s in sectors:
			var s1 := (s + 1) % sectors
			var a := k * sectors + s
			var b := k * sectors + s1
			var c := (k + 1) * sectors + s
			var d := (k + 1) * sectors + s1
			out.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var centre := centres[0] if not centres.is_empty() else Vector3.ZERO
	var outward := verts[out[0]] - centre
	var face := (verts[out[1]] - verts[out[0]]).cross(verts[out[2]] - verts[out[0]])
	if face.dot(outward) >= 0.0:
		for i in range(0, out.size(), 3):
			var tmp := out[i + 1]
			out[i + 1] = out[i + 2]
			out[i + 2] = tmp
	return out


## Skinned cloth mesh on `sk`, sharing the arm mesh's Skin so ARRAY_BONES index its binds.
static func build(mi: MeshInstance3D, sk: Skeleton3D, node_name: StringName,
		verts: PackedVector3Array, normals: PackedVector3Array, custom0: PackedFloat32Array,
		bones: PackedInt32Array, weights: PackedFloat32Array, indices: PackedInt32Array,
		mat: Material, rest_chart: bool = false, hand_weight: float = 1.0) -> MeshInstance3D:
	if mi == null or mi.skin == null or sk == null:
		push_warning("ArmSkinMesh: arm mesh without a skin, cannot build %s" % node_name)
		return null
	var old := sk.get_node_or_null(NodePath(String(node_name)))
	if old != null:
		sk.remove_child(old)
		old.queue_free()
	var nrm := normals
	if nrm.is_empty():
		nrm.resize(verts.size())
		for i in range(0, indices.size() - 2, 3):
			var a := indices[i]
			var b := indices[i + 1]
			var c := indices[i + 2]
			var fn := (verts[c] - verts[a]).cross(verts[b] - verts[a])
			nrm[a] += fn
			nrm[b] += fn
			nrm[c] += fn
		for i in nrm.size():
			nrm[i] = nrm[i].normalized()
	var c0 := custom0
	if c0.is_empty():
		c0.resize(verts.size() * 4)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_CUSTOM0] = c0
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	if rest_chart and not verts.is_empty():
		# The skin shader reads the unposed position and normal from CUSTOM1/CUSTOM2 (the same
		# chart ArmBulk._rest_channels bakes); w 1.0 is the hand weight it uses for grime.
		var c1 := PackedFloat32Array()
		c1.resize(verts.size() * 4)
		var c2 := PackedFloat32Array()
		c2.resize(verts.size() * 4)
		for i in verts.size():
			c1[i * 4] = verts[i].x
			c1[i * 4 + 1] = verts[i].y
			c1[i * 4 + 2] = verts[i].z
			c1[i * 4 + 3] = hand_weight
			c2[i * 4] = nrm[i].x
			c2[i * 4 + 1] = nrm[i].y
			c2[i * 4 + 2] = nrm[i].z
		arrays[Mesh.ARRAY_CUSTOM1] = c1
		arrays[Mesh.ARRAY_CUSTOM2] = c2
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.skin = mi.skin
	node.skeleton = NodePath("..")
	node.transform = mi.transform
	# The shadow pass skips the viewmodel lens, so a rig shadow would land off its mesh.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = mi.layers
	node.material_override = mat
	sk.add_child(node)
	return node


## The camera's frame in skeleton space (skeleton up to, not including, its Camera3D parent), so
## a camera-space direction can be taken into the rig. Identity with no Camera3D ancestor.
static func camera_in_skeleton(model: Node3D) -> Transform3D:
	var sk := ArmRig.skeleton(model)
	if sk == null:
		push_warning("ArmSkinMesh: no Skeleton3D under the arm model")
		return Transform3D.IDENTITY
	var acc := Transform3D.IDENTITY
	var n: Node = sk
	while n is Node3D:
		acc = (n as Node3D).transform * acc
		var par := n.get_parent()
		if par is Camera3D:
			return acc.affine_inverse()
		n = par
	return Transform3D.IDENTITY


## A camera-space direction in the bone's own space under the current pose.
static func posed_local(model: Node3D, bone: StringName, dir_cam: Vector3) -> Vector3:
	var sk := ArmRig.skeleton(model)
	var i := sk.find_bone(bone) if sk != null else -1
	if i == -1:
		push_warning("ArmSkinMesh: bone %s missing" % bone)
		return Vector3.ZERO
	var pose := _posed_global(sk, i)
	return (pose.basis.inverse() * (camera_in_skeleton(model).basis * dir_cam)).normalized()


## Angle (ArmWrap.section's atan2(z, x) convention) around the bone, at fraction t of its
## length, of the direction toward the camera under the current pose.
static func facing_angle(model: Node3D, bone: StringName, t: float) -> float:
	var sk := ArmRig.skeleton(model)
	var i := sk.find_bone(bone) if sk != null else -1
	if i == -1:
		push_warning("ArmSkinMesh: bone %s missing" % bone)
		return 0.0
	var pose := _posed_global(sk, i)
	var p := pose.origin + pose.basis.y.normalized() * t \
			* ArmWrap.bone_len(_arm_mesh(sk), sk, bone)
	var d := pose.basis.inverse() * (camera_in_skeleton(model).origin - p)
	return atan2(d.z, d.x)


## Global pose from the local poses: Skeleton3D's cached global pose can be stale.
static func _posed_global(sk: Skeleton3D, i: int) -> Transform3D:
	var t := sk.get_bone_pose(i)
	var p := sk.get_bone_parent(i)
	while p != -1:
		t = sk.get_bone_pose(p) * t
		p = sk.get_bone_parent(p)
	return t


## The arm's skinned mesh: the skeleton's first MeshInstance3D child that has a skin.
static func _arm_mesh(sk: Skeleton3D) -> MeshInstance3D:
	for c in sk.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).skin != null:
			return c as MeshInstance3D
	return null


static func _normalized(w: Dictionary) -> Dictionary:
	var total := 0.0
	for key in w:
		total += float(w[key])
	if total <= 0.0:
		return w
	var out := {}
	for key in w:
		out[key] = float(w[key]) / total
	return out
