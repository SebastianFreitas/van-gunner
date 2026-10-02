extends RefCounted
## Debug console `arms fit`: the right thumb's clearance from the gun parts in palm lengths,
## plus `arms thumbaim|thumbcurl|wrist x y z`, which set the builder's live tunables, rebuild
## the arms and print the fit again.


## Gap the thumb's skin must keep from a gun box, in palm lengths: a gripping thumb touches the
## steel, so only a near-touch is asked for.
const CLEARANCE_P := 0.03

## Depth past which a buried dressing vertex counts; looser than CLEARANCE_P because the
## palm-side bands sit inside the grip where the palm does.
const DRESS_DEPTH_P := 0.10


## Read-only readout of the right thumb against the gun's steel and rubber parts, in palm lengths,
## to tune a pose without a screenshot per try, ending FIT OK or FIT CLIP <n> and a DRESS line.
func run(vm: Node) -> String:
	var roots := vm.get("_roots") as Dictionary
	var right := roots.get("right_root") as Node3D
	var gun := roots.get("gun_root") as Node3D
	if right == null or gun == null or not gun.visible:
		return "arms fit: no gun"
	var body := gun.get_node_or_null(^"Body") as Node3D
	var model: Node3D = null
	for c in right.get_children():
		if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
			model = c as Node3D
	if body == null or model == null:
		return "arms fit: no gun"
	var sk := ArmRig.skeleton(model)
	sk.force_update_all_bone_transforms()
	var p := HeldGun.palm_len_of(gun)
	# A thick thumb buried in the gun is a clip: the point clears by its shaft radius too.
	var fingers: Dictionary = model.get_meta(&"fingers", {})
	var thumb: Dictionary = fingers.get(&"thumb", {})
	var hand_i := sk.find_bone("DEF-hand.R")
	var hand_k := sk.get_bone_pose_scale(hand_i).y if hand_i != -1 else 1.0
	var r_thumb := float(thumb.get(&"shaft", 0.0)) * hand_k
	var r_tip := float(thumb.get(&"r3", 0.0)) * hand_k
	if r_tip <= 0.0:
		r_tip = r_thumb
	var heads := {}
	for n in ["thumb.01", "thumb.02", "thumb.03", "f_index.01"]:
		var i := sk.find_bone("DEF-%s.R" % n)
		if i == -1:
			return "arms fit: bone " + n + " missing"
		heads[n] = sk.global_transform * sk.get_bone_global_pose(i).origin
	# The tube's tip vertex sits at bone-local (0, tip_len, 0) on .03, whose pose scale carries
	# the hand scale and the tip stretch, so basis.y is deliberately not normalised.
	var i03 := sk.find_bone("DEF-thumb.03.R")
	var gp03 := sk.get_bone_global_pose(i03)
	var tip_len := float(thumb.get(&"tip_len", 0.0))
	var tip: Vector3
	if tip_len > 0.0:
		tip = sk.global_transform * (gp03.origin + gp03.basis.y * tip_len)
	else:
		tip = heads["thumb.03"] + (heads["thumb.03"] - heads["thumb.02"])
	var pts := {"thumb.01": heads["thumb.01"], "thumb.02": heads["thumb.02"],
			"thumb.03": heads["thumb.03"], "tip": tip}
	var to_body := body.global_transform.affine_inverse()
	var lines: Array[String] = []
	var clips := 0
	for key: String in pts:
		var g: Vector3 = pts[key]
		var best := INF
		var part := "-"
		for part_name in ["GripCore", "GripPanelL", "GripPanelR", "Frame", "Beavertail", "Barrel"]:
			var mi := body.get_node_or_null(NodePath(part_name)) as MeshInstance3D
			if mi == null:
				continue
			var q := mi.transform.affine_inverse() * (to_body * g)
			var sd := _box_sd(mi, q)
			if sd < best:
				best = sd
				part = part_name
		var r := r_tip if key == "tip" else r_thumb
		var clear := (best - CLEARANCE_P * p - r) / p
		if clear < 0.0:
			clips += 1
		var b: Vector3 = (to_body * g) / p
		lines.append("%s body/p (%.2f, %.2f, %.2f) nearest %s clearance/p %.2f"
				% [key, b.x, b.y, b.z, part, clear])
	lines.append("tip len / p %.2f" % (tip_len * hand_k / p))
	lines.append("tip to index.01 / p %.2f" % (tip.distance_to(heads["f_index.01"]) / p))
	# Dressing is judged by buried vertices, not boxes: a band hugging the gripping hand
	# overlaps every gun box, and the palm-side bands sit inside the grip where the palm does,
	# so only depths past the finger clearance count.
	var dress_depth := DRESS_DEPTH_P * p  # looser than the thumb's clearance, see DRESS_DEPTH_P
	var dress_clips := 0
	var dress_pieces := 0
	for att in sk.find_children("Dress_*", "BoneAttachment3D", true, false):
		for found in att.find_children("*", "MeshInstance3D", true, false):
			var dm := found as MeshInstance3D
			if dm == null or dm.mesh == null:
				continue
			dress_pieces += 1
			var total := 0
			var n := 0
			var min_sd := 0.0
			var worst := "-"
			for s in dm.mesh.get_surface_count():
				var arr := dm.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				for v in verts:
					total += 1
					var g := dm.global_transform * v
					var is_buried := false
					for part_name in ["GripCore", "GripPanelL", "GripPanelR", "Frame",
							"Beavertail", "Barrel"]:
						var gm := body.get_node_or_null(NodePath(part_name)) as MeshInstance3D
						if gm == null:
							continue
						var sd := _box_sd(gm, gm.transform.affine_inverse() * (to_body * g))
						if sd < min_sd:
							min_sd = sd
							worst = part_name
						if sd < -dress_depth:
							is_buried = true
					if is_buried:
						n += 1
			if min_sd < -0.02 * p:
				if n > 0:
					dress_clips += 1
				lines.append("dress %s/%s depth/p %.2f buried %d/%d in %s"
						% [att.name, dm.name, -min_sd / p, n, total, worst])
	lines.append("FIT OK" if clips == 0 else "FIT CLIP %d" % clips)
	if dress_pieces == 0:
		lines.append("DRESS OK (0 pieces)")
	else:
		lines.append("DRESS OK" if dress_clips == 0 else "DRESS CLIP %d" % dress_clips)
	var text := "\n".join(lines)
	print(text)
	return text


## `which` is "thumbaim", "thumbcurl" or "wrist"; with fewer than three numeric args it prints
## the current value, otherwise it sets the tunable, rebuilds the arms and returns the new fit.
func tune(vm: Node, which: String, args: Array) -> String:
	var current: Vector3
	if which == "thumbaim":
		current = ArmsBuilder.right_thumb_aim
	elif which == "thumbcurl":
		current = ArmsBuilder.right_thumb_curl
	elif which == "wrist":
		current = ArmsBuilder.right_wrist_in_gun
	else:
		return "arms: unknown tunable " + which
	if args.size() < 3:
		return "arms %s (%.2f, %.2f, %.2f)" % [which, current.x, current.y, current.z]
	for i in 3:
		if not str(args[i]).is_valid_float():
			return "arms %s <x> <y> <z>" % which
	var v := Vector3(float(str(args[0])), float(str(args[1])), float(str(args[2])))
	if which == "thumbaim":
		ArmsBuilder.right_thumb_aim = v
	elif which == "thumbcurl":
		ArmsBuilder.right_thumb_curl = v
	else:
		ArmsBuilder.right_wrist_in_gun = v
	if not vm.has_method(&"rebuild_arms"):
		return "arms: no viewmodel"
	vm.call(&"rebuild_arms", int(vm.get("_arms_seed")))
	return "arms %s (%.2f, %.2f, %.2f)\n" % [which, v.x, v.y, v.z] + run(vm)


## Signed distance from `q` (in the gun part's parent space) to the part's box; negative inside.
func _box_sd(mi: MeshInstance3D, q: Vector3) -> float:
	var box := mi.get_aabb()
	var d := (q - box.get_center()).abs() - box.size * 0.5
	return d.max(Vector3.ZERO).length() + minf(maxf(d.x, maxf(d.y, d.z)), 0.0)
