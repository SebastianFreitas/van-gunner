extends RefCounted
## Debug console `arms ik`: sweeps ArmRig.reach over targets and poles, then bars the thumb nail.

## Widest a nail may be next to its finger tip: nail mesh width over twice the widest tip ring.
const NAIL_W_MAX := 0.78
## Largest angle in degrees between the thumb nail's dorsal and straight away from the index.
const THUMB_NAIL_TOP_MAX := 38.0
## Smallest distance from the thumb nail's vertices to the thumb bone axis, in bed radii.
const THUMB_NAIL_SEAT_MIN := 0.34

## Wrist distances swept, as a share of upper arm plus forearm (reach clamps 0.3 to 0.98).
const _RATIOS: Array[float] = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1]
const _POLE_STEPS: Array[int] = [0, 90, 180, 270]
## Wrist error (share of arm length) an unclamped sample may show.
const _ERR_MAX := 0.001


## Read-only sweep of both arms' two-bone IK and the thumb nail bars, ending IK OK or IK CHECK.
## The skeleton pose is saved first and restored exactly, so the weave pose is untouched.
func run(vm: Node) -> String:
	var lines: Array[String] = []
	var roots := vm.get("_roots") as Dictionary
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
			lines.append("ik %s: no model" % h)
			ok = false
			continue
		var res := _hand(model, h)
		lines.append_array(res[&"lines"] as Array[String])
		ok = ok and res[&"ok"]
	lines.append("IK OK" if ok else "IK CHECK")
	return "\n".join(lines)


## {lines, ok} for one hand: sweep lines, the pinned pose line and the nail line.
func _hand(model: Node3D, h: String) -> Dictionary:
	var sfx := "." + h
	var fail := {&"lines": ["ik %s: bone missing" % h] as Array[String], &"ok": false}
	var sk := ArmRig.skeleton(model)
	sk.force_update_all_bone_transforms()
	var iu := sk.find_bone("DEF-upper_arm" + sfx)
	var ifa := sk.find_bone("DEF-forearm" + sfx)
	var ifa1 := sk.find_bone("DEF-forearm" + sfx + ".001")
	var ih := sk.find_bone("DEF-hand" + sfx)
	if iu == -1 or ifa == -1 or ifa1 == -1 or ih == -1:
		return fail
	var to_rig := Transform3D.IDENTITY
	var node: Node = sk
	while node != model.get_parent() and node is Node3D:
		to_rig = (node as Node3D).transform * to_rig
		node = node.get_parent()
	var r_u := ArmRig._global_rest(sk, iu)
	var r_f := ArmRig._global_rest(sk, ifa)
	var r_h := ArmRig._global_rest(sk, ih)
	var ab := (r_f.origin.distance_to(r_u.origin) + r_h.origin.distance_to(r_f.origin)
			) * to_rig.basis.y.length()
	# The pinned inputs are read back off the posed skeleton: the builder computes them locally.
	var s := to_rig * sk.get_bone_global_pose(iu).origin
	var e := to_rig * sk.get_bone_global_pose(ifa).origin
	var w := to_rig * sk.get_bone_global_pose(ih).origin
	var dh := (w - s).normalized()
	var pole0 := (e - s) - dh * (e - s).dot(dh)
	if pole0.length() < 0.001:
		pole0 = dh.cross(Vector3.UP)
	pole0 = pole0.normalized()
	var rest_b := r_h.basis.orthonormalized()
	var m := sk.get_bone_global_pose(ih).basis.orthonormalized() * rest_b.inverse()
	var d0 := rest_b.y.normalized()
	var n0 := (Vector3.DOWN - d0 * Vector3.DOWN.dot(d0)).normalized()
	var hand_dir := to_rig.basis * (m * d0)
	var palm_n := to_rig.basis * (m * n0)
	var rest_q := sk.get_bone_rest(ifa1).basis.get_rotation_quaternion()
	var pinned_r := (w - s).length() / ab
	var pinned_elbow := _elbow_deg(s, e, w)
	var pinned_twist := rad_to_deg(sk.get_bone_pose_rotation(ifa1).angle_to(rest_q))

	var saved := _save(sk)
	var ok := true
	var lines: Array[String] = []
	for step in _POLE_STEPS:
		var pole := pole0.rotated(dh, deg_to_rad(float(step)))
		var elbows := PackedStringArray()
		var clamps := PackedStringArray()
		var max_twist := 0.0
		var max_err := 0.0
		for r in _RATIOS:
			var target := s + dh * (r * ab)
			var res := ArmRig.reach(model, sfx, s, target, pole, hand_dir, palm_n)
			var e2: Vector3 = res["elbow"]
			var w2: Vector3 = res["wrist"]
			elbows.append("%.0f" % _elbow_deg(s, e2, w2))
			var clamp_kind := "lo" if r < 0.3 else ("hi" if r > 0.98 else "-")
			clamps.append(clamp_kind)
			max_twist = maxf(max_twist, rad_to_deg(
					sk.get_bone_pose_rotation(ifa1).angle_to(rest_q)))
			if clamp_kind != "-":
				continue
			var err := target.distance_to(w2) / ab
			max_err = maxf(max_err, err)
			if err > _ERR_MAX:
				ok = false
			var off := (e2 - s) - dh * (e2 - s).dot(dh)
			if r < 0.98 and off.dot(pole) <= 0.0:
				ok = false
		lines.append("ik %s pole %d: elbow %s | clamp %s | twist %.0f | err %.3f" % [
				h, step, " ".join(elbows), ",".join(clamps), max_twist, max_err])
	_restore(sk, saved)
	var pinned_clamp := "lo" if pinned_r <= 0.3 + 0.0001 else (
			"hi" if pinned_r >= 0.98 - 0.0001 else "-")
	if pinned_clamp != "-":
		ok = false
	lines.append("ik %s pinned: r %.2f elbow %.0f twist %.0f clamp %s" % [
			h, pinned_r, pinned_elbow, pinned_twist, pinned_clamp])
	var nails := _nails(model, sk, h)
	lines.append(nails[&"line"])
	return {&"lines": lines, &"ok": ok and nails[&"ok"]}


## Degrees between shoulder to elbow and elbow to wrist (0 is a straight arm).
func _elbow_deg(s: Vector3, e: Vector3, w: Vector3) -> float:
	return rad_to_deg((e - s).angle_to(w - e))


## Every bone's pose position, rotation and scale, so the sweep can put them back exactly.
func _save(sk: Skeleton3D) -> Array:
	var out: Array = []
	for i in sk.get_bone_count():
		out.append([sk.get_bone_pose_position(i), sk.get_bone_pose_rotation(i),
				sk.get_bone_pose_scale(i)])
	return out


func _restore(sk: Skeleton3D, saved: Array) -> void:
	for i in saved.size():
		var p: Array = saved[i]
		sk.set_bone_pose_position(i, p[0])
		sk.set_bone_pose_rotation(i, p[1])
		sk.set_bone_pose_scale(i, p[2])
	sk.force_update_all_bone_transforms()


## {line, ok} for the nail bars of one hand on the current pose: width next to the tip rings on
## every finger, and the thumb nail's dorsal angle and root seat.
func _nails(model: Node3D, sk: Skeleton3D, h: String) -> Dictionary:
	var fingers: Dictionary = model.get_meta(&"fingers", {})
	var mi: MeshInstance3D = null
	for c in sk.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).skin != null:
			mi = c as MeshInstance3D
			break
	var t3 := sk.find_bone("DEF-thumb.03." + h)
	var i1 := sk.find_bone("DEF-f_index.01." + h)
	var thumb: Dictionary = fingers.get(&"thumb", {})
	var claw_t := _claw(sk, &"thumb")
	if mi == null or t3 == -1 or i1 == -1 or claw_t == null or thumb.is_empty():
		return {&"line": "ik %s nails: missing" % h, &"ok": false}
	var worst := 0.0
	var worst_f := &""
	var thumb_w := 0.0
	for f in ArmRig.FINGERS:
		var claw := _claw(sk, f)
		var d: Dictionary = fingers.get(f, {})
		if claw == null or d.is_empty():
			continue
		var half_w := 0.0
		for ring: Dictionary in d[&"tip_rings"]:
			half_w = maxf(half_w, float(ring[&"half_w"]))
		if half_w <= 0.0:
			continue
		var nail_w := claw.mesh.get_aabb().size.x / (2.0 * half_w)
		if f == &"thumb":
			thumb_w = nail_w
		if nail_w > worst:
			worst = nail_w
			worst_f = f
	var w3 := sk.global_transform * sk.get_bone_global_pose(t3)
	var len_w := ArmWrap.bone_len(mi, sk, "DEF-thumb.03." + h) * w3.basis.y.length()
	var tip := w3.origin + w3.basis.y.normalized() * len_w
	var axis := w3.basis.y.normalized()
	var index_o := (sk.global_transform * sk.get_bone_global_pose(i1)).origin
	var away := tip - index_o
	away -= axis * away.dot(axis)
	var dorsal := (w3.basis * claw_t.transform.basis).z.normalized()
	var top := rad_to_deg(dorsal.angle_to(away))
	# Seat in the bone's own space, where bed_r and the rest length live.
	var bone_len := ArmWrap.bone_len(mi, sk, "DEF-thumb.03." + h)
	var verts: PackedVector3Array = claw_t.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var nearest := INF
	for v in verts:
		var lv := claw_t.transform * v
		var t := clampf(lv.y / bone_len, 0.0, 1.0)
		nearest = minf(nearest, lv.distance_to(Vector3(0.0, bone_len * t, 0.0)))
	var seat := nearest / float(thumb[&"bed_r"])
	var bars: Array[String] = []
	if worst > NAIL_W_MAX:
		bars.append("nail_w")
	if top > THUMB_NAIL_TOP_MAX:
		bars.append("nail_top")
	if seat < THUMB_NAIL_SEAT_MIN:
		bars.append("nail_seat")
	var line := "ik %s nails: nail_w thumb %.2f worst %.2f (%s) nail_top %.0f nail_seat %.2f" % [
			h, thumb_w, worst, String(worst_f), top, seat]
	if not bars.is_empty():
		line += " BAR " + ",".join(bars)
	return {&"line": line, &"ok": bars.is_empty()}


## The "Claw" mesh under a finger's `Claw_<finger>` attachment, or null.
func _claw(sk: Skeleton3D, finger: StringName) -> MeshInstance3D:
	var att := sk.get_node_or_null("Claw_" + String(finger))
	if att == null:
		return null
	return att.get_node_or_null("Claw") as MeshInstance3D
