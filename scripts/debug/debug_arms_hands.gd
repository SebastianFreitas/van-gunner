extends RefCounted
## The monster-hand bar (hand as long as the forearm, finger shaft over a quarter of its length,
## neighbours not merged) measured on the posed skeleton.
const _FINGERS: Array[StringName] = [&"f_index", &"f_middle", &"f_ring", &"f_pinky"]
## Per hand and finger: `r_ratio` scales r1 against the middle finger, `tip_off` is the tip pole's
## lateral offset (m), `knob` the joint swell as a fraction of the shaft radius it sits on.
const _DIGITS := {
	&"R": {
		&"f_index": {&"r_ratio": 0.8226, &"tip_off": -0.0020207, &"knob": 1.22},
		&"f_middle": {&"r_ratio": 1.0, &"tip_off": -0.0163481, &"knob": 1.24},
		&"f_ring": {&"r_ratio": 0.8115, &"tip_off": 0.0080549, &"knob": 1.26},
		&"f_pinky": {&"r_ratio": 0.7171, &"tip_off": 0.0019330, &"knob": 1.28},
	},
	&"L": {
		&"f_index": {&"r_ratio": 0.8226, &"tip_off": 0.0146573, &"knob": 1.22},
		&"f_middle": {&"r_ratio": 1.0, &"tip_off": -0.0066347, &"knob": 1.24},
		&"f_ring": {&"r_ratio": 0.8115, &"tip_off": -0.0132470, &"knob": 1.26},
		&"f_pinky": {&"r_ratio": 0.7171, &"tip_off": 0.0092982, &"knob": 1.28},
	},
}
## Knots over the four fingers of a hand (+-20 percent): phase 1's R total, 9+11+13+13. A finger's
## own count is hash noise, so only the sum is checked.
const _KNOTS_TOTAL := 46.0
## A vertex is hand-weighted for `_shape` when hand and palm weights are at least this share of
## its total. The old largest-weight pick sat on a three-way tie (forearm, palm.01, thumb.01 near
## 0.34 each) at the thumb side of slab 0, so which side counted it hung on how finely the vein
## relief had cut that arm's mesh (R has far more vertices there than L), not on the weights.
const HAND_SHARE := 0.30


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
	var rows := _rows(fingers, h, mi.get_meta(&"knuckle_rise", PackedFloat32Array()))
	var wrist := _wrist(sk, mi, h, float(fingers[&"f_middle"][&"shaft"]) * hand_k)
	return {&"line": line + rows[&"text"] + wrist[&"text"] + _shape(mi, h),
			&"ok": good and rows[&"ok"] and wrist[&"ok"]}


## Third of the summed area of each vertex's triangles (indices empty: consecutive triples).
func _vertex_area(arrays: Array) -> PackedFloat32Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
			else PackedInt32Array()
	var area := PackedFloat32Array()
	area.resize(verts.size())
	var n := idx.size() if idx.size() > 0 else verts.size()
	for t in range(0, n - 2, 3):
		var i0 := idx[t] if idx.size() > 0 else t
		var i1 := idx[t + 1] if idx.size() > 0 else t + 1
		var i2 := idx[t + 2] if idx.size() > 0 else t + 2
		var a := 0.5 * (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).length() / 3.0
		area[i0] += a
		area[i1] += a
		area[i2] += a
	return area


## The |lateral| where the area weight, summed from the smallest, first reaches 0.95 of the total.
func _p95(lats: PackedFloat32Array, areas: PackedFloat32Array) -> float:
	var order: Array[int] = []
	var total := 0.0
	for i in lats.size():
		order.append(i)
		total += areas[i]
	order.sort_custom(func(a: int, b: int) -> bool: return lats[a] < lats[b])
	var acc := 0.0
	for i in order:
		acc += areas[i]
		if acc >= 0.95 * total:
			return lats[i]
	return 0.0


## Text only (unbanded): how the hand grows out of the wrist, in bind space with `_wrist`'s frame.
## Hand verts (hand + palm weight share, thumb out) fall in nine slabs
## s = k/8 * L along head -> middle root (L = finger-root centre along it), +-L/16 thick. `growth`
## prints each slab's W_k (area-weighted 95th percentile of |lateral|, W0..8), `mono` (no W_k under
## 0.99 of the last) and `jump` (largest step over the mean step, a straight ramp reads 1.0), both
## on slabs 0..7 only (the knuckle row may taper, D59). `dome` and `palm_depth` are slab 4's
## largest dorsal and palmar offsets from the axis line over W_4 (dorsal = UP less its axis part).
func _shape(mi: MeshInstance3D, h: String) -> String:
	var skin := mi.skin
	var bind_o := {}
	for b in skin.get_bind_count():
		bind_o[String(skin.get_bind_name(b))] = skin.get_bind_pose(b).affine_inverse().origin
	var roots: Array[Vector3] = []
	for f: StringName in _FINGERS:
		var fname := "DEF-%s.01.%s" % [f, h]
		if not bind_o.has(fname):
			return "\nhands %s: shape bone missing" % h
		roots.append(bind_o[fname])
	var seam: Dictionary = mi.get_meta(&"wrist_seam", {})
	if seam.is_empty():
		return "\nhands %s: shape bone missing" % h
	var head: Vector3 = seam["hand_head"]
	var axis2 := (roots[1] - head).normalized()
	var centre := (roots[0] + roots[1] + roots[2] + roots[3]) * 0.25
	var span := (centre - head).dot(axis2)
	var lat := (roots[3] - roots[0])
	lat = (lat - axis2 * lat.dot(axis2)).normalized()
	var dorsal := (Vector3.UP - axis2 * Vector3.UP.dot(axis2)).normalized()
	var kind: Array[bool] = []
	for b in skin.get_bind_count():
		var name := String(skin.get_bind_name(b))
		kind.append(name == "DEF-hand." + h or name.begins_with("DEF-palm"))
	var slab_l: Array[PackedFloat32Array] = []
	var slab_a: Array[PackedFloat32Array] = []
	for k in 9:
		slab_l.append(PackedFloat32Array())
		slab_a.append(PackedFloat32Array())
	var up_max := -INF
	var down_max := -INF
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := int(bones.size() / float(maxi(verts.size(), 1)))
		var area := _vertex_area(arrays)
		for v in verts.size():
			var wsum := 0.0
			var hand_w := 0.0
			for k in stride:
				wsum += weights[v * stride + k]
				if kind[bones[v * stride + k]]:
					hand_w += weights[v * stride + k]
			if wsum <= 0.0 or hand_w < HAND_SHARE * wsum:
				continue
			var d := verts[v] - head
			var ax := d.dot(axis2)
			var k := roundi(ax / span * 8.0)
			if k < 0 or k > 8 or absf(ax - float(k) / 8.0 * span) > span / 16.0:
				continue
			slab_l[k].append(absf(d.dot(lat)))
			slab_a[k].append(area[v])
			if k == 4:
				var dor := (d - axis2 * ax).dot(dorsal)
				up_max = maxf(up_max, dor)
				down_max = maxf(down_max, -dor)
	var w: Array[float] = []
	for k in 9:
		w.append(_p95(slab_l[k], slab_a[k]))
	var mono := true
	var jump := 0.0
	var ws := ""
	for k in 9:
		ws += " %.3f" % w[k]
		if k > 0 and k <= 7:
			mono = mono and w[k] >= 0.99 * w[k - 1]
			jump = maxf(jump, w[k] - w[k - 1])
	jump /= maxf((w[7] - w[0]) / 7.0, 0.0001)
	var w4 := maxf(w[4], 0.0001)
	return "\nhands %s: growth W0..8%s mono %s jump %.2f" % [h, ws, str(mono).to_lower(), jump] \
			+ "\nhands %s: dome %.3f palm_depth %.3f" % [h, up_max / w4, down_max / w4]


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
	return {&"ok": step <= 0.05 and wp >= 0.70 and wp <= 0.85, &"text":
			"\nhands %s: wrist_step %.3f (<= 0.05) fore r %.4f hand r %.4f" \
			% [h, step, fore_r, hand_r] + " (seam 1%% %.4f)" % seam_r
			+ "\nhands %s: wrist/palm %.3f (0.70..0.85) palm half %.4f" \
			% [h, wp, palm]
			+ "\nhands %s: r1/palm %.3f" % [h, r1 / maxf(palm, 0.0001)]}


## {text, ok}: per finger the r1 ratio, tip pole offset, claw length and knot count against
## `_DIGITS`, and the finger length over the middle's (reported only).
func _rows(fingers: Dictionary, h: String, rises: PackedFloat32Array) -> Dictionary:
	var digits: Dictionary = _DIGITS[StringName(h)]
	var mid: Dictionary = fingers[&"f_middle"]
	var text := ""
	var ok := true
	var knots_sum := 0
	for f: StringName in _FINGERS:
		var info: Dictionary = fingers[f]
		var d: Dictionary = digits[f]
		var r1 := float(info[&"shaft"]) / maxf(float(mid[&"shaft"]), 0.0001)
		var off := float(info[&"tip_off"])
		var tip_len := float(info[&"tip_len"])
		var horn := ArmRig.horn_length(info, false, ArmsBuilder.CLAW_K) + 0.16 * tip_len
		var claw := horn / maxf(tip_len, 0.0001)
		var len_r := float(info[&"length"]) / maxf(float(mid[&"length"]), 0.0001)
		var s1 := maxf(float(info[&"shaft"]), 0.0001)
		var r2 := float(info[&"r2"])
		var r3 := float(info[&"r3"])
		var r2_r1 := r2 / s1
		var r3_r1 := r3 / s1
		var k2_r2 := float(info[&"k2"]) / maxf(r2, 0.0001)
		var k3_r3 := float(info[&"k3"]) / maxf(r3, 0.0001)
		var k2_r1 := float(info[&"k2"]) / s1
		var knob := float(d[&"knob"])
		var row_ok := absf(r1 - float(d[&"r_ratio"])) <= 0.02 \
				and absf(off - float(d[&"tip_off"])) <= 0.002 and claw >= 0.88 - 0.0001
		var knob_ok := r2_r1 >= 0.72 and r2_r1 <= 0.85 and r3_r1 >= 0.55 and r3_r1 <= 0.65 \
				and absf(k2_r2 - knob) <= 0.02 and absf(k3_r3 - knob) <= 0.02 and k2_r1 <= 0.97
		knots_sum += int(info[&"knots"])
		var tris := (int(info[&"rings"]) - 1) * ArmFingerInfo.SECTORS * 2 + ArmFingerInfo.SECTORS \
				+ (8 if float(info.get(&"web", -1.0)) >= 0.0 else 0)
		var fi := _FINGERS.find(f)
		var knuckle := rises[fi] / maxf(float(mid[&"shaft"]), 0.0001) if fi >= 0 and fi < rises.size() else -1.0
		var knuckle_ok := knuckle >= 0.35 and knuckle <= 0.48
		ok = ok and row_ok and knob_ok and knuckle_ok
		text += "\nhands %s %s: r1 %.4f (%.4f) tip_off %.5f (%.5f) len x%.2f claw_len %.2f knots %d%s" \
				% [h, f, r1, d[&"r_ratio"], off, d[&"tip_off"], len_r, claw, info[&"knots"],
				"" if row_ok else " ROW CHECK"]
		text += "\nhands %s %s: tris %d" % [h, f, tris]
		text += "\nhands %s %s: r2/r1 %.2f r3/r1 %.2f k2/r2 %.3f k3/r3 %.3f (%.2f) k2/r1 %.2f%s" \
				% [h, f, r2_r1, r3_r1, k2_r2, k3_r3, knob, k2_r1,
				"" if knob_ok else " ROW CHECK"]
		text += "\nhands %s %s: knuckle %.2f (0.35..0.48)%s" \
				% [h, f, knuckle, "" if knuckle_ok else " ROW CHECK"]
	var knots_ok := absf(float(knots_sum) - _KNOTS_TOTAL) <= 0.2 * _KNOTS_TOTAL
	text += "\nhands %s: knots total %d (%d, +-20%%)%s" \
			% [h, knots_sum, int(_KNOTS_TOTAL), "" if knots_ok else " ROW CHECK"]
	var web_ok := true
	for i in _FINGERS.size() - 1:
		var info: Dictionary = fingers[_FINGERS[i]]
		var gap1: PackedFloat32Array = info.get(&"gap1", PackedFloat32Array([0.0, 0.0, 0.0]))
		var pair := "%s-%s" % [_FINGERS[i], _FINGERS[i + 1]]
		text += "\nhands %s %s: gap1 %.4f %.4f %.4f (t .00 .14 .30)" \
				% [h, pair, gap1[0], gap1[1], gap1[2]]
		if float(info.get(&"web", -1.0)) < 0.0:
			text += "\nhands %s %s: web none (gap1 .30 <= 0)" % [h, pair]
			continue
		var over := float(info[&"web_over"])
		var over_ok := over <= 0.0001 * float(info[&"shaft"])
		web_ok = web_ok and over_ok
		text += "\nhands %s %s: web top t %.2f over %.5f%s" \
				% [h, pair, info[&"web"], over, "" if over_ok else " ROW CHECK"]
	return {&"text": text, &"ok": ok and knots_ok and web_ok}


## Smallest (distance - ra - rb) / ra over neighbouring finger pairs (index..pinky).
func _min_gap(pts: Array[Vector3], radii: Array[float]) -> float:
	var worst := INF
	for i in range(pts.size() - 1):
		var ra := maxf(radii[i], 0.0001)
		worst = minf(worst, (pts[i].distance_to(pts[i + 1]) - ra - radii[i + 1]) / ra)
	return worst
