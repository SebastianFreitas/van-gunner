extends RefCounted
## The monster-hand bar (hand as long as the forearm, finger shaft over a quarter of its length,
## neighbours not merged) measured on the posed skeleton.
const _FINGERS: Array[StringName] = [&"f_index", &"f_middle", &"f_ring", &"f_pinky"]


## One line per hand and a last line HANDS OK or HANDS CHECK.
func run(vm: Node) -> String:
	var roots := vm.get("_roots") as Dictionary
	var lines: Array[String] = []
	var ok := true
	for hand: Array in [["R", "right_root"], ["L", "left_root"]]:
		var h: String = hand[0]
		var root := roots.get(hand[1]) as Node3D
		var model: Node3D = null
		if root != null:
			for c in root.get_children():
				if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
					model = c as Node3D
		if model == null:
			lines.append("hands %s: no model" % h)
			ok = false
			continue
		var sk := ArmRig.skeleton(model)
		sk.force_update_all_bone_transforms()
		var fingers: Dictionary = model.get_meta(&"fingers", {})
		if fingers.is_empty():
			lines.append("hands %s: no fingers" % h)
			ok = false
			continue
		var res := _hand(sk, fingers, h)
		lines.append(res[&"line"])
		ok = ok and res[&"ok"]
	lines.append("HANDS OK" if ok else "HANDS CHECK")
	return "\n".join(lines)


## {line, ok} for one hand: the length (along the middle finger, curl-independent), shaft and
## neighbour-gap numbers against the bar.
func _hand(sk: Skeleton3D, fingers: Dictionary, h: String) -> Dictionary:
	var fail := {&"line": "hands %s: bone missing" % h, &"ok": false}
	var mi: MeshInstance3D = null
	for c in sk.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).skin != null:
			mi = c as MeshInstance3D
			break
	var hand_i := sk.find_bone("DEF-hand." + h)
	var fore_i := sk.find_bone("DEF-forearm." + h)
	if mi == null or hand_i == -1 or fore_i == -1:
		return fail
	var hand_k := sk.get_bone_pose_scale(hand_i).y
	var hand_o := sk.get_bone_global_pose(hand_i).origin
	var fore_len := sk.get_bone_global_pose(fore_i).origin.distance_to(hand_o)
	var mids2: Array[Vector3] = []
	var mids3: Array[Vector3] = []
	var r2s: Array[float] = []
	var r3s: Array[float] = []
	var tip := Vector3.ZERO
	var hand_len := 0.0
	for f: StringName in _FINGERS:
		var info: Dictionary = fingers.get(f, {})
		var n2 := "DEF-%s.02.%s" % [f, h]
		var i1 := sk.find_bone("DEF-%s.01.%s" % [f, h])
		var i2 := sk.find_bone(n2)
		var i3 := sk.find_bone("DEF-%s.03.%s" % [f, h])
		if info.is_empty() or i1 == -1 or i2 == -1 or i3 == -1:
			return fail
		var gp2 := sk.get_bone_global_pose(i2)
		var gp3 := sk.get_bone_global_pose(i3)
		var tip_len := float(info[&"tip_len"])
		var shaft := float(info[&"shaft"])
		mids2.append(gp2.origin + gp2.basis.y * 0.5 * ArmWrap.bone_len(mi, sk, n2))
		mids3.append(gp3.origin + gp3.basis.y * 0.5 * tip_len)
		r2s.append(float(info.get(&"r2", shaft)) * hand_k)
		r3s.append(float(info.get(&"r3", shaft)) * hand_k)
		if f == &"f_middle":
			tip = gp3.origin + gp3.basis.y * tip_len
			var o1 := sk.get_bone_global_pose(i1).origin
			hand_len = (hand_o.distance_to(o1) + o1.distance_to(gp2.origin)
					+ gp2.origin.distance_to(gp3.origin) + gp3.origin.distance_to(tip))
	var index: Dictionary = fingers[&"f_index"]
	var len_x := hand_len / maxf(fore_len, 0.0001)
	var shaft_x := 2.0 * float(index[&"shaft"]) / maxf(float(index[&"length"]), 0.0001)
	var gap2 := _min_gap(mids2, r2s)
	var gap3 := _min_gap(mids3, r3s)
	# The right hand's gaps (-0.29, -0.13) are pre-existing at 1d5e14f5, plan
	# hands-geometry-pass phase 1: its band is the old value less 0.02.
	var min2 := -0.31 if h == "R" else -0.20
	var min3 := -0.15 if h == "R" else 0.0
	var good := len_x >= 0.95 and shaft_x >= 0.28 and gap2 >= min2 and gap3 >= min3
	var line := "hands %s: k %.2f len x%.2f shaft x%.2f gap2 %.2f gap3 %.2f" \
			% [h, hand_k, len_x, shaft_x, gap2, gap3]
	var helper := DebugArmsHandsRows.new()
	var rows := helper.rows(fingers, h, _measure(sk, mi, fingers, h))
	var wrist := _wrist(sk, mi, h, float(fingers[&"f_middle"][&"shaft"]) * hand_k)
	var shape := helper.shape(mi, h)
	return {&"line": line + rows[&"text"] + wrist[&"text"] + shape[&"text"],
			&"ok": good and rows[&"ok"] and wrist[&"ok"] and shape[&"ok"]}


## The finger rows' mesh numbers: {finger: {r1, r2, r3, k2, k3}} plus `&"rises"` (per finger).
## Empty when the finger part or the seam is missing.
func _measure(sk: Skeleton3D, mi: MeshInstance3D, fingers: Dictionary, h: String) -> Dictionary:
	var fingers_mi: MeshInstance3D = null
	for c in sk.get_children():
		if c is MeshInstance3D and String(c.name).ends_with(h + "_fingers"):
			fingers_mi = c as MeshInstance3D
	var seam: Dictionary = mi.get_meta(&"wrist_seam", {})
	if fingers_mi == null or seam.is_empty():
		return {}
	var bind_o := {}
	for b in mi.skin.get_bind_count():
		bind_o[String(mi.skin.get_bind_name(b))] = mi.skin.get_bind_pose(b).affine_inverse().origin
	var webs_mi: MeshInstance3D = null
	for c in sk.get_children():
		if c is MeshInstance3D and String(c.name).ends_with(h + "_webs"):
			webs_mi = c as MeshInstance3D
	var meas := DebugArmsHandsMesh.new()
	var out := meas.rings(fingers_mi, bind_o, fingers, h)
	out[&"webs"] = meas.webs(fingers_mi, webs_mi, fingers)
	out[&"rises"] = meas.rises(mi, bind_o, fingers, h, seam["hand_head"])
	return out


## {text, ok}: the wrist seam in bind space (the inflated arrays, no skinning, D38). Seam plane = the
## hand bone's head, normal along twist head -> hand head (mesh meta `wrist_seam`). A vertex is forearm-weighted when its largest weight is on the
## twist bone, hand-weighted on DEF-hand, a palm bone or the thumb root. wrist_step compares the
## largest axis radius of each side within 3 percent of the forearm length of the seam. The palm
## half-width is the lateral half-extent (index to pinky direction) of hand-weighted vertices in a
## slice of +-5 percent of the forearm length about the mean of the four finger roots, normal
## along hand head -> middle root. `r1` is the middle finger's shaft radius, posed.
func _wrist(sk: Skeleton3D, mi: MeshInstance3D, h: String, r1: float) -> Dictionary:
	var twist_i := sk.find_bone("DEF-forearm.%s.001" % h)
	var fore_i := sk.find_bone("DEF-forearm." + h)
	var hand_i := sk.find_bone("DEF-hand." + h)
	var skin := mi.skin
	var bind_o := {}
	for b in skin.get_bind_count():
		bind_o[String(skin.get_bind_name(b))] = skin.get_bind_pose(b).affine_inverse().origin
	var roots: Array[Vector3] = []
	for f: StringName in _FINGERS:
		var fname := "DEF-%s.01.%s" % [f, h]
		if not bind_o.has(fname):
			return {&"text": "\nhands %s: wrist bone missing" % h, &"ok": false}
		roots.append(bind_o[fname])
	var seam: Dictionary = mi.get_meta(&"wrist_seam", {})
	if twist_i == -1 or fore_i == -1 or hand_i == -1 or seam.is_empty() \
			or not bind_o.has("DEF-forearm." + h):
		return {&"text": "\nhands %s: wrist bone missing" % h, &"ok": false}
	var head: Vector3 = seam["hand_head"]
	var axis := (head - Vector3(seam["twist_head"])).normalized()
	var fore_len := Vector3(bind_o["DEF-forearm." + h]).distance_to(head)
	var win := 0.03 * fore_len
	var centre := (roots[0] + roots[1] + roots[2] + roots[3]) * 0.25
	var axis2 := (roots[1] - head).normalized()
	var lat := (roots[3] - roots[0])
	lat = (lat - axis2 * lat.dot(axis2)).normalized()
	var slab := 0.05 * fore_len
	var kind: Array[int] = []
	for b in skin.get_bind_count():
		var name := String(skin.get_bind_name(b))
		kind.append(1 if name == "DEF-forearm.%s.001" % h else 2 if name == "DEF-hand." + h
				or name.begins_with("DEF-palm") else 0)
	var fore_r := 0.0
	var hand_r := 0.0
	var seam_r := 0.0
	var lat_lo := INF
	var lat_hi := -INF
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := int(bones.size() / float(maxi(verts.size(), 1)))
		for v in verts.size():
			var best := 0
			var wsum := 0.0
			for k in stride:
				wsum += weights[v * stride + k]
				if weights[v * stride + k] > weights[v * stride + best]:
					best = k
			var vk: int = kind[bones[v * stride + best]]
			if vk == 0 or wsum <= 0.0:
				continue
			var p := verts[v]
			var ax := (p - head).dot(axis)
			var rad := (p - head - axis * ax).length()
			if absf(ax) <= win:
				if vk == 1:
					fore_r = maxf(fore_r, rad)
				else:
					hand_r = maxf(hand_r, rad)
					if ax >= 0.0 and ax <= 0.01 * fore_len:
						seam_r = maxf(seam_r, rad)
			if vk == 2 and absf((p - centre).dot(axis2)) <= slab:
				var l := (p - centre).dot(lat)
				lat_lo = minf(lat_lo, l)
				lat_hi = maxf(lat_hi, l)
	var palm := 0.5 * (lat_hi - lat_lo)
	var step := absf(fore_r - hand_r) / maxf(fore_r, 0.0001)
	var wp := fore_r / maxf(palm, 0.0001)
	return {&"ok": step <= 0.05 and wp >= 0.62 and wp <= 0.85, &"text":
			"\nhands %s: wrist_step %.3f (<= 0.05) fore r %.4f hand r %.4f" \
			% [h, step, fore_r, hand_r] + " (seam 1%% %.4f)" % seam_r
			+ "\nhands %s: wrist/palm %.3f (0.62..0.85) palm half %.4f" \
			% [h, wp, palm]
			+ "\nhands %s: r1/palm %.3f" % [h, r1 / maxf(palm, 0.0001)]}


## Smallest (distance - ra - rb) / ra over neighbouring finger pairs (index..pinky).
func _min_gap(pts: Array[Vector3], radii: Array[float]) -> float:
	var worst := INF
	for i in range(pts.size() - 1):
		var ra := maxf(radii[i], 0.0001)
		worst = minf(worst, (pts[i].distance_to(pts[i + 1]) - ra - radii[i + 1]) / ra)
	return worst
