extends RefCounted
## Debug console `arms join`: per hand and digit, at the ring where the finger tube emerges from the palm, how far its normals and hand weight are from the nearest palm skin's.


## One line per digit: max and mean tube normal angle to the palm normal (degrees), the largest
## CUSTOM2 angle gap, the largest w gap, and the tube ring's mean height over the palm surface.
func run(vm: Node) -> String:
	var roots := vm.get("_roots") as Dictionary
	var lines: Array[String] = []
	for hand: Array in [["R", "right_root"], ["L", "left_root"]]:
		var root := roots.get(hand[1]) as Node3D
		if root == null:
			lines.append("join %s: no root" % hand[0])
			continue
		for c in root.get_children():
			if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
				lines.append_array(_measure(c as Node3D, hand[0]))
	return "\n".join(lines)


func _measure(model: Node3D, side: String) -> Array[String]:
	var sk := ArmRig.skeleton(model)
	var mi := ArmFingerGlb.glb_mesh(sk)
	var tubes := sk.get_node_or_null("Skin_fingers") as MeshInstance3D
	if mi == null or tubes == null or not model.has_meta(&"fingers"):
		return ["join %s: no finger tubes" % side]
	var pal := ArmFingerJoin.palm(mi)
	var a := tubes.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var c1: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM1]
	var c2: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM2]
	var fingers: Dictionary = model.get_meta(&"fingers")
	var out: Array[String] = []
	for f: StringName in fingers:
		var info: Dictionary = fingers[f]
		var emerge: int = info[&"emerge"]
		var base: int = int(info[&"vert_base"]) + emerge * ArmFingers.SECTORS
		var worst := 0.0
		var total := 0.0
		var rest_gap := 0.0
		var w_gap := 0.0
		var height := 0.0
		var gap := 0.0
		var c0 := Vector3.ZERO
		var c1v := Vector3.ZERO
		for s in ArmFingers.SECTORS:
			var i := base + s
			var pm := ArmFingerJoin.sample(pal, verts[i])
			var pn: Vector3 = pm[&"n"]
			var ang := rad_to_deg(nrm[i].angle_to(pn))
			worst = maxf(worst, ang)
			total += ang
			var rn := Vector3(c2[i * 4], c2[i * 4 + 1], c2[i * 4 + 2])
			rest_gap = maxf(rest_gap, rad_to_deg(rn.angle_to(pm[&"rest_n"])))
			w_gap = maxf(w_gap, absf(c1[i * 4 + 3] - float(pm[&"w"])))
			var h := pn.dot(verts[i] - _nearest(pal, verts[i]))
			height += h / float(ArmFingers.SECTORS)
			gap = maxf(gap, absf(h))
			c0 += verts[i] / float(ArmFingers.SECTORS)
			c1v += verts[i + ArmFingers.SECTORS] / float(ArmFingers.SECTORS)
		# Angle between the tube's first step and the palm plane at the root (90 = straight out).
		var pn0: Vector3 = ArmFingerJoin.sample(pal, c0)[&"n"]
		var exit := rad_to_deg(asin(clampf(pn0.dot((c1v - c0).normalized()), -1.0, 1.0)))
		out.append("join %s %s ring %d: normal max %.1f mean %.1f deg, CUSTOM2 gap %.1f deg, "
				% [side, f, emerge, worst, total / float(ArmFingers.SECTORS), rest_gap]
				+ "w gap %.3f, height %.4f, max gap %.4f, exit %.1f deg, step %.4f, rise %.4f"
				% [w_gap, height, gap, exit, (c1v - c0).length(), pn0.dot(c1v - c0)])
	return out


## The palm vertex nearest `p`.
func _nearest(pal: Dictionary, p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var d := INF
	for v in pal[&"pos"] as PackedVector3Array:
		if v.distance_squared_to(p) < d:
			d = v.distance_squared_to(p)
			best = v
	return best
