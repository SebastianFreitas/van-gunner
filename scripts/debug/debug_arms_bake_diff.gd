class_name ArmsBakeDiff
extends RefCounted
## Compare for `arms import-diff`: per part the vertex fields, triangles (up to cyclic rotation, flips apart), weights; the bones by name (parent, rest); per skin the binds. A "set" is {parts: {name: [surface arrays]}, bones: {name: {parent, rest}}, skins: {part: {names, bones, binds}}}.

const _FIELDS: Array[int] = [
	Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV,
	Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2,
]
const _NAMES := {
	Mesh.ARRAY_VERTEX: "pos", Mesh.ARRAY_NORMAL: "nrm", Mesh.ARRAY_COLOR: "color",
	Mesh.ARRAY_TEX_UV: "uv", Mesh.ARRAY_TEX_UV2: "uv2", Mesh.ARRAY_CUSTOM0: "c0",
	Mesh.ARRAY_CUSTOM1: "c1", Mesh.ARRAY_CUSTOM2: "c2",
}


static func new_set() -> Dictionary:
	return {"parts": {}, "bones": {}, "skins": {}}


## Adds a skeleton's bones to the set by name: the importer merges the two sides into one
## Skeleton3D, so bones are compared by name, parent name and rest, not by index.
static func add_bones(bag: Dictionary, info: Dictionary) -> void:
	for i in (info["names"] as Array).size():
		var p: int = info["parents"][i]
		bag["bones"][String(info["names"][i]).replace(".", "_")] = {
			"parent": String(info["names"][p]).replace(".", "_") if p >= 0 else "", "rest": info["rests"][i]}


## {names, parents, rests} of a skeleton.
static func skel_info(sk: Skeleton3D) -> Dictionary:
	var info := {"names": [], "parents": [], "rests": []}
	for i in sk.get_bone_count():
		info["names"].append(sk.get_bone_name(i))
		info["parents"].append(sk.get_bone_parent(i))
		info["rests"].append(sk.get_bone_rest(i))
	return info


## {names, bones, binds} of a skin; an empty bind name is read off the skeleton's bone.
static func skin_info(skin: Skin, skel: Dictionary) -> Dictionary:
	var info := {"names": [], "bones": [], "binds": []}
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		var nm := String(skin.get_bind_name(i))
		if nm.is_empty() and bone >= 0 and bone < (skel["names"] as Array).size():
			nm = skel["names"][bone]
		info["names"].append(nm.replace(".", "_"))
		info["bones"].append(bone)
		info["binds"].append(skin.get_bind_pose(i))
	return info


## Imports `path` into a set; {"error": text} on failure.
static func load_file(path: String) -> Dictionary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return {"error": "cannot import " + path}
	var root := doc.generate_scene(state)
	if root == null:
		return {"error": "no scene in " + path}
	var out := new_set()
	var skels := {}
	for n in root.find_children("*", "Skeleton3D", true, false):
		var info := skel_info(n as Skeleton3D)
		skels[n] = info
		add_bones(out, info)
	# The ImporterMesh keeps the arrays as read (the built ArrayMesh would compress them).
	var raw := {}
	for gn: GLTFNode in state.get_nodes():
		if gn.mesh >= 0:
			raw[String(gn.resource_name)] = state.get_meshes()[gn.mesh].mesh
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var part := String(n.name)
		var im := raw.get(part) as ImporterMesh
		if im == null:
			continue
		var surfaces: Array = []
		for s in im.get_surface_count():
			surfaces.append(im.get_surface_arrays(s))
		out["parts"][part] = surfaces
		var mi := n as MeshInstance3D
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if sk != null and mi.skin != null:
			out["skins"][part] = skin_info(mi.skin, skels[sk])
	root.free()
	return out


## One block of lines: skeletons, then each part of `a` against `b` (a part missing from b says so).
func report(a: Dictionary, b: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(_bone_line(a["bones"], b["bones"]))
	for part: String in a["parts"]:
		if not b["parts"].has(part):
			lines.append("%s MISSING in second (parts: %s)" % [part, ",".join(b["parts"].keys())])
			continue
		var src: Array = a["parts"][part]
		var dst: Array = b["parts"][part]
		var worst := {}
		if src.size() != dst.size():
			worst["surfaces"] = "%d/%d" % [src.size(), dst.size()]
		for s in mini(src.size(), dst.size()):
			_compare(src[s], dst[s], worst)
		var skin_line := ""
		if a["skins"].has(part):
			skin_line = _skin_line(a["skins"][part], b["skins"].get(part))
		lines.append("%s %s %s" % [part, _cells(worst), skin_line])
	for part: String in b["parts"]:
		if not a["parts"].has(part):
			lines.append("%s MISSING in first" % part)
	return "\n".join(lines)


func _cells(worst: Dictionary) -> String:
	var keys := worst.keys()
	keys.sort()
	var cells: Array[String] = []
	for k in keys:
		cells.append("%s=%s" % [k, String.num_scientific(worst[k]) if worst[k] is float
				else str(worst[k])])
	return " ".join(cells)


## Bones of `a` looked up by name in `b`: counts, missing, parent-name mismatches, max rest delta.
func _bone_line(a: Dictionary, b: Dictionary) -> String:
	var missing := 0
	var first := ""
	var parent_bad := 0
	var rest := 0.0
	for nm: String in a:
		if not b.has(nm):
			missing += 1
			first = first if first != "" else nm
			continue
		parent_bad += 1 if a[nm]["parent"] != b[nm]["parent"] else 0
		rest = maxf(rest, _tdelta(a[nm]["rest"], b[nm]["rest"]))
	return "bones=%d/%d missing=%d (first %s) parent_diff=%d rest=%s" % [
		a.size(), b.size(), missing, first, parent_bad, String.num_scientific(rest)]


func _skin_line(a: Dictionary, b: Variant) -> String:
	if b == null:
		return "skin MISSING in second"
	var an: Array = a["names"]
	var bn: Array = b["names"]
	var name_bad := 0
	var bind := 0.0
	for i in mini(an.size(), bn.size()):
		name_bad += 1 if an[i] != bn[i] else 0
		bind = maxf(bind, _tdelta(a["binds"][i], b["binds"][i]))
	return "binds=%d/%d bind_name_diff=%d bind=%s" % [
		an.size(), bn.size(), name_bad, String.num_scientific(bind)]


func _tdelta(x: Transform3D, y: Transform3D) -> float:
	var d := _vdelta(x.origin, y.origin)
	for k in 3:
		d = maxf(d, _vdelta(x.basis[k], y.basis[k]))
	return d


## [i, j, k] turned so its smallest index is first (same cyclic order).
func _norm(t: Array) -> Array:
	var m := t.find(t.min())
	return [t[m], t[(m + 1) % 3], t[(m + 2) % 3]]


## Folds the max abs delta of every field `a` has into `worst`; counts and missing fields as text.
func _compare(a: Array, b: Array, worst: Dictionary) -> void:
	var n := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var m := (b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	worst["verts"] = "%d/%d" % [n, m]
	var ia: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var ib: PackedInt32Array = b[Mesh.ARRAY_INDEX] if b[Mesh.ARRAY_INDEX] != null \
			else PackedInt32Array()
	worst["idx"] = "%d/%d" % [ia.size(), ib.size()]
	if n != m:
		return
	var rot := 0
	var flips := 0
	var bad := 0
	for t in int(mini(ia.size(), ib.size()) / 3.0):
		var ta := [ia[t * 3], ia[t * 3 + 1], ia[t * 3 + 2]]
		var tb := [ib[t * 3], ib[t * 3 + 1], ib[t * 3 + 2]]
		if ta == tb:
			continue
		if _norm(ta) == _norm(tb):
			rot += 1
		elif _norm(ta) == _norm([tb[0], tb[2], tb[1]]):
			flips += 1
		else:
			bad += 1
	worst["flips"] = int(worst.get("flips", 0)) + flips
	worst["rot_tris"] = int(worst.get("rot_tris", 0)) + rot
	worst["tri_diff"] = int(worst.get("tri_diff", 0)) + bad
	for f: int in _FIELDS:
		if a[f] == null:
			continue
		if b[f] == null:
			worst[_NAMES[f]] = "MISSING"
			continue
		if (a[f] as Variant).size() != (b[f] as Variant).size():
			worst[_NAMES[f]] = "SIZE %d/%d" % [a[f].size(), b[f].size()]
			continue
		var d := 0.0
		for i in (a[f] as Variant).size():
			d = maxf(d, _vdelta(a[f][i], b[f][i]))
		worst[_NAMES[f]] = maxf(float(worst.get(_NAMES[f], 0.0)), d)
	_weights(a, b, n, worst)


func _weights(a: Array, b: Array, n: int, worst: Dictionary) -> void:
	var per_a := int(float((a[Mesh.ARRAY_BONES] as PackedInt32Array).size()) / maxf(n, 1.0))
	var per_b := int(float((b[Mesh.ARRAY_BONES] as PackedInt32Array).size()) / maxf(n, 1.0))
	var wd := 0.0
	var bd := 0
	for i in n:
		var wa := {}
		var wb := {}
		for k in per_a:
			if a[Mesh.ARRAY_WEIGHTS][i * per_a + k] > 0.0:
				wa[a[Mesh.ARRAY_BONES][i * per_a + k]] = a[Mesh.ARRAY_WEIGHTS][i * per_a + k]
		for k in per_b:
			if b[Mesh.ARRAY_WEIGHTS][i * per_b + k] > 0.0:
				wb[b[Mesh.ARRAY_BONES][i * per_b + k]] = b[Mesh.ARRAY_WEIGHTS][i * per_b + k]
		if wa.size() != wb.size():
			bd += 1
			continue
		for bone in wa:
			if not wb.has(bone):
				bd += 1
			else:
				wd = maxf(wd, absf(float(wa[bone]) - float(wb[bone])))
	worst["bone_diff"] = int(worst.get("bone_diff", 0)) + bd
	worst["weight"] = maxf(float(worst.get("weight", 0.0)), wd)


func _vdelta(x: Variant, y: Variant) -> float:
	if x is Vector3:
		return maxf(absf(x.x - y.x), maxf(absf(x.y - y.y), absf(x.z - y.z)))
	if x is Vector2:
		return maxf(absf(x.x - y.x), absf(x.y - y.y))
	if x is Color:
		return maxf(maxf(absf(x.r - y.r), absf(x.g - y.g)), maxf(absf(x.b - y.b), absf(x.a - y.a)))
	return absf(float(x) - float(y))
