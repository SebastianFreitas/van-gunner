extends RefCounted
## Writes the posed arm skeletons (both hands) to a JSON file so two poses can be diffed.


## Dumps both hands to `path`; returns one summary line (or the error).
func run(vm: Node, path: String) -> String:
	var roots := vm.get("_roots") as Dictionary
	var gun := roots.get("gun_root") as Node3D
	var out := {"hands": {}}
	var errors: Array[String] = []
	var models: Dictionary = {}
	var counts: Dictionary = {"R": 0, "L": 0}
	for hand: Array in [["R", "right_root"], ["L", "left_root"]]:
		var h: String = hand[0]
		var root := roots.get(hand[1]) as Node3D
		var model: Node3D = null
		if root != null:
			for c in root.get_children():
				if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
					model = c as Node3D
		if model == null:
			out["hands"][h] = null
			errors.append("arms dump: no model for %s" % h)
			continue
		models[h] = model
		var sk := ArmRig.skeleton(model)
		sk.force_update_all_bone_transforms()
		var res := _hand(sk, h, gun)
		out["hands"][h] = res
		counts[h] = (res["bones"] as Dictionary).size()
	var palm_model := models.get("R", models.get("L", null)) as Node3D
	var palm := -1.0
	if palm_model != null:
		palm = ArmRig.palm_len(palm_model)
		out["palm_len"] = palm
	else:
		out["palm_len"] = null
	# Which pose the dump came from, so two dumps can be told apart.
	out["weave_t"] = vm.get("debug_weave_t")
	out["shot_t"] = vm.get("debug_shot_t")
	out["reload_t"] = vm.get("debug_reload_t")
	out["seed"] = vm.get("_arms_seed")
	var dir := path.get_base_dir()
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "arms dump: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	file.store_string(JSON.stringify(out, "\t", true))
	file.close()
	var line := "arms dump: %d bones R, %d bones L, palm_len %.4f -> %s" % [
		int(counts["R"]), int(counts["L"]), palm, path]
	if not errors.is_empty():
		line = "\n".join(errors) + "\n" + line
	return line


## Bones, finger curls and wrist-in-gun position of one hand (rig units except the wrist).
func _hand(sk: Skeleton3D, h: String, gun: Node3D) -> Dictionary:
	var bones := {}
	for i in sk.get_bone_count():
		var bname := String(sk.get_bone_name(i))
		if not (bname.begins_with("DEF-") and bname.ends_with("." + h)):
			continue
		var ps := sk.get_bone_pose_scale(i)
		bones[bname] = {
			"pose_pos": _vec(sk.get_bone_pose_position(i)),
			"pose_rot": _quat(sk.get_bone_pose_rotation(i)),
			"pose_scale": _vec(ps),
			"global": _xform(sk.get_bone_global_pose(i)),
		}
	var curl := {}
	for f: StringName in ArmRig.FINGERS:
		var degs: Array = []
		var offs: Array = []
		for j in range(1, 4):
			var i := sk.find_bone("DEF-%s.0%d.%s" % [f, j, h])
			if i == -1:
				degs.append(null)
				offs.append(null)
				continue
			# Undo the rest rotation to get the curl ArmRig.curl applied about RIGHT.
			var d := sk.get_bone_rest(i).basis.get_rotation_quaternion().inverse() \
				* sk.get_bone_pose_rotation(i)
			var deg := rad_to_deg(2.0 * atan2(d.x, d.w)) * ArmRig.CURL_SIGN
			var off := rad_to_deg(2.0 * asin(clampf(Vector2(d.y, d.z).length(), 0.0, 1.0)))
			degs.append(snappedf(deg, 0.01))
			offs.append(snappedf(off, 0.01))
		curl[String(f)] = {"deg": degs, "off_axis": offs}
	var wrist: Variant = null
	var hand_i := sk.find_bone("DEF-hand." + h)
	if hand_i != -1 and gun != null:
		var w := gun.global_transform.affine_inverse() \
			* (sk.global_transform * sk.get_bone_global_pose(hand_i).origin)
		wrist = _vec(w)
	return {"bones": bones, "curl": curl, "wrist_in_gun": wrist}


func _vec(v: Vector3) -> Array:
	return [snappedf(v.x, 0.00001), snappedf(v.y, 0.00001), snappedf(v.z, 0.00001)]


func _xform(t: Transform3D) -> Dictionary:
	return {
		"origin": _vec(t.origin),
		"basis_x": _vec(t.basis.x),
		"basis_y": _vec(t.basis.y),
		"basis_z": _vec(t.basis.z),
	}


func _quat(q: Quaternion) -> Array:
	return [snappedf(q.x, 0.00001), snappedf(q.y, 0.00001),
		snappedf(q.z, 0.00001), snappedf(q.w, 0.00001)]
