extends RefCounted
## Debug console `arms touch`: per hand, whether a fingertip sits inside another finger or a gun
## part, and how far the right index tip is from the trigger, in palm lengths. Read-only.


## Largest gap, in palm lengths, the right index tip's skin may keep from the trigger. A tentative
## bar: the check is print-only.
const TRIGGER_MAX_P := 0.25

const _PARTS: Array[String] = ["GripCore", "GripPanelL", "GripPanelR", "Frame", "Beavertail",
		"Barrel", "Trigger", "GuardRear", "GuardBottom", "GuardFront", "GuardJoin"]


## Read-only readout ending TOUCH OK or TOUCH CHECK <n> (clips plus a far trigger finger).
func run(vm: Node) -> String:
	var roots := vm.get("_roots") as Dictionary
	var gun := roots.get("gun_root") as Node3D
	if gun == null or not gun.visible:
		return "arms touch: no gun"
	var p := HeldGun.palm_len_of(gun)
	var body := gun.get_node_or_null(^"Body") as Node3D
	var lines: Array[String] = []
	var counted := 0
	for side: Array in [["right_root", "R"], ["left_root", "L"]]:
		var root := roots.get(side[0]) as Node3D
		if root == null:
			continue
		var model: Node3D = null
		for c in root.get_children():
			if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
				model = c as Node3D
		if model == null:
			continue
		var h: String = side[1]
		var data := _hand_data(model, h)
		counted += _tip_in_fingers(data, h, p, lines)
		if body != null:
			counted += _tip_in_gun(data, h, p, body, lines)
	var text := "\n".join(lines)
	text += ("\n" if text != "" else "") + ("TOUCH OK" if counted == 0 else "TOUCH CHECK %d" % counted)
	print(text)
	return text


## Per finger name: {&"pts": 4 world points (three bone origins and the tip), &"r": 4 radii}.
func _hand_data(model: Node3D, h: String) -> Dictionary:
	var sk := ArmRig.skeleton(model)
	sk.force_update_all_bone_transforms()
	var hand_i := sk.find_bone("DEF-hand." + h)
	var hand_k := sk.get_bone_pose_scale(hand_i).y if hand_i != -1 else 1.0
	var fingers: Dictionary = model.get_meta(&"fingers", {})
	var out := {}
	for f: StringName in ArmRig.FINGERS:
		var info: Dictionary = fingers.get(f, {})
		var idx: Array[int] = []
		for n in ["01", "02", "03"]:
			idx.append(sk.find_bone("DEF-%s.%s.%s" % [f, n, h]))
		if idx.has(-1):
			continue
		var pts: Array[Vector3] = []
		for i in idx:
			pts.append(sk.global_transform * sk.get_bone_global_pose(i).origin)
		var gp3 := sk.get_bone_global_pose(idx[2])
		var tip_len := float(info.get(&"tip_len", 0.0))
		# The tip vertex sits at bone-local (0, tip_len, 0) on .03; its pose scale carries the
		# hand scale and the tip stretch, so basis.y is deliberately not normalised.
		if tip_len > 0.0:
			pts.append(sk.global_transform * (gp3.origin + gp3.basis.y * tip_len))
		else:
			pts.append(pts[2] + (pts[2] - pts[1]))
		var shaft := float(info.get(&"shaft", 0.0))
		var r2 := float(info.get(&"r2", shaft))
		var r3 := float(info.get(&"r3", shaft))
		out[f] = {&"pts": pts, &"r": [shaft * hand_k, r2 * hand_k, r3 * hand_k, r3 * hand_k]}
	return out


## Fingertip centres inside another finger's tube; returns the clip count.
func _tip_in_fingers(data: Dictionary, h: String, p: float, lines: Array[String]) -> int:
	var worst := -INF
	var worst_a := "-"
	var worst_b := "-"
	var clip_lines: Array[String] = []
	var clips := 0
	for a: StringName in data:
		var tip: Vector3 = data[a][&"pts"][3]
		for b: StringName in data:
			if a == b:
				continue
			var pts: Array = data[b][&"pts"]
			var radii: Array = data[b][&"r"]
			var depth := -INF
			for s in 3:
				var v0: Vector3 = pts[s]
				var seg: Vector3 = Vector3(pts[s + 1]) - v0
				var t := clampf((tip - v0).dot(seg) / maxf(seg.length_squared(), 0.000001), 0.0, 1.0)
				var dist := tip.distance_to(v0 + seg * t)
				depth = maxf(depth, lerpf(float(radii[s]), float(radii[s + 1]), t) - dist)
			if depth > worst:
				worst = depth
				worst_a = a
				worst_b = b
			if depth > 0.0:
				clips += 1
				clip_lines.append("%s clip %s tip vs %s depth/p %.3f" % [h, a, b, depth / p])
	if worst_a == "-":
		return 0
	lines.append("%s tip-in-finger worst %s tip vs %s depth/p %.3f %s"
			% [h, worst_a, worst_b, worst / p, "CLIP" if worst > 0.0 else "OK"])
	lines.append_array(clip_lines)
	return clips


## Fingertip centres inside a gun part's box, plus the right index tip's gap to the trigger;
## returns the clip count plus one when the trigger finger is too far.
func _tip_in_gun(data: Dictionary, h: String, p: float, body: Node3D,
		lines: Array[String]) -> int:
	var to_body := body.global_transform.affine_inverse()
	var counted := 0
	for f: StringName in data:
		var tip: Vector3 = to_body * Vector3(data[f][&"pts"][3])
		var best := INF
		var part := "-"
		for part_name in _PARTS:
			var mi := body.get_node_or_null(NodePath(part_name)) as MeshInstance3D
			if mi == null:
				continue
			var sd := _box_sd(mi, mi.transform.affine_inverse() * tip)
			if sd < best:
				best = sd
				part = part_name
		if part == "-":
			continue
		if best < 0.0:
			counted += 1
		lines.append("%s %s tip nearest %s sd/p %.3f %s"
				% [h, f, part, best / p, "CLIP" if best < 0.0 else "OK"])
	if h != "R" or not data.has(&"f_index"):
		return counted
	var trigger := body.get_node_or_null(^"Trigger") as MeshInstance3D
	if trigger == null:
		lines.append("R trigger: no Trigger node")
		return counted
	var q: Vector3 = trigger.transform.affine_inverse() * (to_body * Vector3(data[&"f_index"][&"pts"][3]))
	var gap := (_box_sd(trigger, q) - float(data[&"f_index"][&"r"][3])) / p
	if gap > TRIGGER_MAX_P:
		counted += 1
	lines.append("R index tip to trigger gap/p %.3f (bar <= %.2f) %s"
			% [gap, TRIGGER_MAX_P, "OK" if gap <= TRIGGER_MAX_P else "FAR"])
	return counted


## Signed distance from `q` (in the gun part's parent space) to the part's box; negative inside.
func _box_sd(mi: MeshInstance3D, q: Vector3) -> float:
	var box := mi.get_aabb()
	var d := (q - box.get_center()).abs() - box.size * 0.5
	return d.max(Vector3.ZERO).length() + minf(maxf(d.x, maxf(d.y, d.z)), 0.0)
