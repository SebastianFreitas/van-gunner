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
	var good := len_x >= 0.95 and shaft_x >= 0.28 and gap2 >= -0.20 and gap3 >= 0.0
	return {&"line": "hands %s: k %.2f len x%.2f shaft x%.2f gap2 %.2f gap3 %.2f"
			% [h, hand_k, len_x, shaft_x, gap2, gap3], &"ok": good}


## Smallest (distance - ra - rb) / ra over neighbouring finger pairs (index..pinky).
func _min_gap(pts: Array[Vector3], radii: Array[float]) -> float:
	var worst := INF
	for i in range(pts.size() - 1):
		var ra := maxf(radii[i], 0.0001)
		worst = minf(worst, (pts[i].distance_to(pts[i + 1]) - ra - radii[i + 1]) / ra)
	return worst
