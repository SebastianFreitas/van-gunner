extends RefCounted
## Debug console `arms roots`: per hand, how each finger tube meets the palm skin (crossing size, normal angle, vein-frame and mask steps) and the arm mesh's mask steps, in bind space. Read-only; per finger the streak meter (S0, S_f, sweep) and the hand's build ms.

const SECTORS := 8
const SIDES := [["R", "right_root"], ["L", "left_root"]]

var _mesh := preload("res://scripts/debug/debug_arms_roots_mesh.gd").new()
var _streak := preload("res://scripts/debug/debug_arms_roots_streak.gd")


## One block per hand.
func run(vm: Node) -> String:
	var roots := vm.get("_roots") as Dictionary
	var lines: Array[String] = []
	for hand: Array in SIDES:
		var root := roots.get(hand[1]) as Node3D
		if root == null:
			lines.append("roots %s: no root" % hand[0])
			continue
		for c in root.get_children():
			if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
				lines.append(_hand(c as Node3D, hand[0]))
	return "\n".join(lines)


func _hand(model: Node3D, side: String) -> String:
	var sk := ArmRig.skeleton(model)
	var mi := model.find_child("Arm" + side, true, false) as MeshInstance3D
	var tubes := sk.get_node_or_null("Skin_fingers") as MeshInstance3D
	if mi == null or mi.skin == null or tubes == null:
		return "roots %s: no arm mesh or finger tubes" % side
	var heads := {}
	_mesh.names = PackedStringArray()
	for b in mi.skin.get_bind_count():
		var full := String(mi.skin.get_bind_name(b))
		if full.is_empty():
			full = sk.get_bone_name(mi.skin.get_bind_bone(b))
		_mesh.names.append(full)
		if full.ends_with("." + side):
			heads[StringName(full.left(full.length() - 2))] = mi.skin.get_bind_pose(b).affine_inverse().origin
	if not heads.has(&"DEF-thumb.01"):
		return "roots %s: bone heads missing" % side
	_mesh.load_arm(mi.mesh)
	var vf := ArmMuscle.frame(heads)
	var out := "roots %s:" % side
	var tb := tubes.mesh.surface_get_arrays(0)
	var tv: PackedVector3Array = tb[Mesh.ARRAY_VERTEX]
	var tn: PackedVector3Array = tb[Mesh.ARRAY_NORMAL]
	var tc: PackedFloat32Array = tb[Mesh.ARRAY_CUSTOM0]
	var fingers: Dictionary = model.get_meta(&"fingers", {})
	var comp := _components(tv.size(), tb[Mesh.ARRAY_INDEX])
	var thumb := Vector3.ZERO
	var r_t := 0.0
	for fi in mini(comp.size(), ArmRig.FINGERS.size()):
		var name: StringName = ArmRig.FINGERS[fi]
		var is_thumb := name == &"thumb"
		var root := StringName("DEF-%s.0%d" % [name, 2 if is_thumb else 1])
		var nxt := StringName("DEF-%s.0%d" % [name, 3 if is_thumb else 2])
		var hd: Vector3 = heads.get(root, Vector3.ZERO)
		var d: Vector3 = Vector3(heads.get(nxt, Vector3.ZERO)) - hd
		var ids: PackedInt32Array = comp[fi]
		var first := ids[0]
		var rr := float((fingers.get(name, {}) as Dictionary).get(&"shaft", 0.0))
		var tris := ArmSkinNearest.prefilter(_mesh.v, _mesh.idx, hd - 0.25 * d, 2.0 * rr)
		var info := {}
		var tmax := -INF
		for i in ids:
			var t := (tv[i] - hd).dot(d) / d.length_squared()
			if t >= 1.0:
				continue
			var q := ArmSkinNearest.nearest(_mesh.v, _mesh.idx, tris, tv[i])
			q[&"t"] = t
			info[i] = q
			if float(q[&"s"]) <= 0.05 * rr:
				tmax = maxf(tmax, t)
		var cross: Array[int] = []
		for i: int in info:
			if absf(float(info[i][&"s"])) <= 0.05 * rr:
				cross.append(i)
		var fallback := cross.is_empty()
		if fallback:
			for k in SECTORS:
				var lane: Array[int] = []
				for i: int in info:
					if (i - first) % SECTORS == k:
						lane.append(i)
				lane.sort_custom(func(a: int, b: int) -> bool:
						return absf(float(info[a][&"s"])) < absf(float(info[b][&"s"])))
				cross.append_array(lane.slice(0, 2))
		var ang := 0.0
		var dc := 0.0
		var wt := 0.0
		var wp := 0.0
		var sign_min := 1.0
		var rt := 0.0
		var worst := 0
		var worst_a := -1.0
		var ctp := hd + maxf(tmax, 0.0) * d
		for i in cross:
			var q: Dictionary = info[i]
			var a := rad_to_deg(tn[i].angle_to(q[&"n"]))
			if a > worst_a:
				worst_a = a
				worst = i
			ang = maxf(ang, a)
			var cx := Vector3(tc[i * 4], tc[i * 4 + 1], tc[i * 4 + 2])
			dc = maxf(dc, cx.distance_to(ArmMuscle.frame_xyz(vf, tv[i])))
			wt = maxf(wt, tc[i * 4 + 3])
			var pw := _mesh.interp(q[&"p"], q[&"n"])
			wp = maxf(wp, pw.x)
			sign_min = minf(sign_min, pw.y)
			rt = maxf(rt, ctp.distance_to(q[&"p"]))
		out += "\n %s r %.4f t_c %.3f crossing %d%s: angle %.1f deg, dxyz %.4f, w tube %.2f palm %.2f, n.stored min %.2f, worst lane %d t %.2f" % [
				name, rr, tmax, cross.size(), " (fallback)" if fallback else "", ang, dc, wt, wp, sign_min, (worst - first) % SECTORS, float(info[worst][&"t"]) if info.has(worst) else 0.0]
		var fr: Dictionary = (model.get_meta(&"finger_roots", {}) as Dictionary).get(name, {})
		if not fr.is_empty():
			out += _streak.line(fr[&"c_f"], fr[&"t_c"], ids, tv, tc, hd, d)
		if is_thumb:
			thumb = ctp
			r_t = rt
	var ms: float = (model.get_meta(&"finger_roots", {}) as Dictionary).get(&"ms", -1.0)
	out += "\n build %.1f ms" % ms
	return out + _mesh.arm(vf, heads, thumb, r_t)


## Vertex ids of each connected piece of an indexed mesh, in order of first vertex.
func _components(count: int, idx: PackedInt32Array) -> Array:
	var parent := PackedInt32Array()
	for i in count:
		parent.append(i)
	for i in idx.size():
		var a := idx[i]
		var b := idx[i - i % 3]
		while parent[a] != a:
			a = parent[a]
		while parent[b] != b:
			b = parent[b]
		parent[maxi(a, b)] = mini(a, b)
	var groups := {}
	for i in count:
		var r := i
		while parent[r] != r:
			r = parent[r]
		var list: PackedInt32Array = groups.get(r, PackedInt32Array())
		list.append(i)
		groups[r] = list
	var keys := groups.keys()
	keys.sort()
	var out: Array = []
	for k: int in keys:
		out.append(groups[k])
	return out
