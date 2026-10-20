extends RefCounted
## Debug console `arms export <path.glb> [rest]`: writes both built hands as baked static meshes, one object per part, posed or in bind pose, for the Blender defect hunt.

const _CLAWS: Array[String] = ["index", "middle", "ring", "pinky", "thumb"]


func run(vm: Node, args: Array) -> String:
	if args.size() < 2 or args.size() > 3 or (args.size() == 3 and str(args[2]) != "rest"):
		return "ARMS EXPORT ERROR: usage arms export <path.glb> [rest]"
	var path := str(args[1])
	if path.get_extension().to_lower() != "glb":
		return "ARMS EXPORT ERROR: path must end in .glb"
	var rest := args.size() == 3
	var roots := vm.get("_roots") as Dictionary
	if roots == null:
		return "ARMS EXPORT ERROR: no arms"
	var holder := Node3D.new()
	var objects := 0
	var verts := 0
	var tris := 0
	var missing: Array[String] = []
	var bone_heads := {}
	for hand: Array in [["R", "right_root"], ["L", "left_root"]]:
		var root := roots.get(hand[1]) as Node3D
		if root == null:
			continue
		for c in root.get_children():
			var sk := ArmRig.skeleton(c as Node3D) if c is Node3D else null
			if sk == null:
				continue
			bone_heads[hand[0]] = _heads(sk, rest)
			for part: Array in _parts(sk, hand[0]):
				var mi := part[1] as MeshInstance3D
				var baked := _bake(mi, part[2] as Transform3D, rest)
				if baked == null:
					missing.append(part[0])
					continue
				var out := MeshInstance3D.new()
				out.name = part[0]
				out.mesh = baked
				holder.add_child(out)
				objects += 1
				for s in baked.get_surface_count():
					var a := baked.surface_get_arrays(s)
					verts += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
					tris += int((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3.0)
	var err := ""
	if objects == 0:
		err = "no arm parts found"
	else:
		err = _write(holder, path)
		if err == "":
			var f := FileAccess.open(path.get_basename() + ".bones.json", FileAccess.WRITE)
			if f == null:
				err = "cannot write bones.json"
			else:
				f.store_string(JSON.stringify(bone_heads))
				f.close()
	holder.free()
	if err != "":
		return "ARMS EXPORT ERROR: " + err
	return "ARMS EXPORT %s %s objects=%d verts=%d tris=%d%s" % [
			path, "rest" if rest else "posed", objects, verts, tris,
			"" if missing.is_empty() else " missing=" + ",".join(missing)]


## Every bone's global head, bone name to [x, y, z], in the glb's space and mode.
func _heads(sk: Skeleton3D, rest: bool) -> Dictionary:
	var out := {}
	for i in sk.get_bone_count():
		var t := sk.get_bone_global_rest(i) if rest else sk.get_bone_global_pose(i)
		var p := sk.global_transform * t.origin
		out[sk.get_bone_name(i)] = [p.x, p.y, p.z]
	return out


## [object name, MeshInstance3D, world placement for a rest export] per existing part of one hand.
func _parts(sk: Skeleton3D, side: String) -> Array:
	var out: Array = []
	var base := sk.global_transform
	for n in sk.get_children():
		var mi := n as MeshInstance3D
		if mi != null:
			var nm := String(mi.name)
			if nm == side + "_skin" or nm == side + "_fingers" or nm == side + "_webs":
				out.append([nm, mi, base])
			elif nm.begins_with("Limb_tail"):
				out.append([side + "_tail", mi, base])
		var att := n as BoneAttachment3D
		if att != null and String(att.name).begins_with("Claw_"):
			var claw := att.get_node_or_null("Claw") as MeshInstance3D
			var bone := sk.find_bone(att.bone_name)
			var fname := String(att.name).trim_prefix("Claw_").trim_prefix("f_")
			if claw != null and bone >= 0 and _CLAWS.has(fname):
				out.append([side + "_claw_" + fname, claw,
						base * sk.get_bone_global_rest(bone) * claw.transform])
	return out


## A static ArrayMesh in world space, one surface per source surface, vertices kept as built.
func _bake(mi: MeshInstance3D, rest_place: Transform3D, rest: bool) -> ArrayMesh:
	if mi.mesh == null:
		return null
	var src: Mesh = mi.mesh
	var place := rest_place
	var sk := mi.get_parent() as Skeleton3D
	var skinned := not rest and mi.skin != null and sk != null
	if not rest:
		place = sk.global_transform if skinned else mi.global_transform
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var a := src.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null \
				else PackedVector3Array()
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null \
				else PackedInt32Array()
		if idx.is_empty():
			for i in v.size():
				idx.append(i)
		var wv := PackedVector3Array()
		var wn := PackedVector3Array()
		if skinned:
			_skin(mi, sk, a, wv, wn)
			for i in wv.size():
				wv[i] = place * wv[i]
				wn[i] = (place.basis * wn[i]).normalized()
		else:
			for i in v.size():
				wv.append(place * v[i])
			var nb := place.basis.inverse().transposed()
			for i in nrm.size():
				wn.append((nb * nrm[i]).normalized())
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = wv
		if not wn.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = wn
		arrays[Mesh.ARRAY_INDEX] = idx
		# The baked vertex id (CUSTOM2.w) rides in UV2.x so the hunt can map clusters back.
		if a[Mesh.ARRAY_CUSTOM2] != null:
			var c2: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM2]
			var uv2 := PackedVector2Array()
			uv2.resize(v.size())
			for i in v.size():
				uv2[i] = Vector2(roundf(c2[i * 4 + 3]), 0.0)
			arrays[Mesh.ARRAY_TEX_UV2] = uv2
			# The glb writer drops UV2 when there is no UV, and the hunt reads the second layer.
			var uv0 := PackedVector2Array()
			uv0.resize(v.size())
			arrays[Mesh.ARRAY_TEX_UV] = uv0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## CPU skinning in skeleton space: the engine's bake needs a registered skin on a live skeleton
## and refuses these meshes, so blend bone pose * bind pose by the vertex weights.
func _skin(mi: MeshInstance3D, sk: Skeleton3D, a: Array, wv: PackedVector3Array,
		wn: PackedVector3Array) -> void:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var per := int(float(bones.size()) / maxf(v.size(), 1.0))
	var mats: Array[Transform3D] = []
	for b in mi.skin.get_bind_count():
		var bi := mi.skin.get_bind_bone(b)
		if bi < 0:
			bi = sk.find_bone(mi.skin.get_bind_name(b))
		mats.append(sk.get_bone_global_pose(bi) * mi.skin.get_bind_pose(b))
	for i in v.size():
		var p := Vector3.ZERO
		var n := Vector3.ZERO
		for k in per:
			var w := weights[i * per + k]
			if w > 0.0:
				var m := mats[bones[i * per + k]]
				p += w * (m * v[i])
				n += w * (m.basis * nrm[i])
		wv.append(p)
		wn.append(n.normalized())


func _write(holder: Node3D, path: String) -> String:
	var dir := path.get_base_dir()
	if not dir.is_empty() and DirAccess.make_dir_recursive_absolute(dir) != OK:
		return "cannot create folder " + dir
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_scene(holder, state) != OK:
		return "glTF append failed"
	if doc.write_to_filesystem(state, path) != OK:
		return "cannot write " + path
	return ""
