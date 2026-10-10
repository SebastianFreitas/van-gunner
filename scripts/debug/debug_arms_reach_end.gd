extends RefCounted
## Debug `arms reach-end`: pins each interact gesture at mid-swing, contact and mid-settle and checks
## that the far end of the left arm's limb tail projects off screen through the viewmodel lens.

const _Gesture := preload("res://scripts/player/arms/arm_gesture.gd")
const _Keys := preload("res://scripts/player/arms/arm_gesture_keys.gd")
const _TAIL := &"Limb_tail_L"
## The tail's far ring is the last ring of the tube; ArmLimbTail's RINGS and SECTORS.
const _SECTORS := 14
## The delta of each posing step: GunViewmodel._process ignores a delta of zero.
const _STEP := 0.001
## The gun inspect pins sampled, in seconds.
const _INSPECT_PINS: Array[float] = [1.1, 2.8, 4.0, 5.5, 6.3]


## One line per kind and sample, the hand-to-target lines and a summary; BAD lines mark failures.
func run(vm: Node) -> String:
	var roots := vm.get("_roots") as Dictionary
	var root := roots.get("left_root") as Node3D
	var cam := vm.get("_camera") as Node3D
	var rig := vm.get("_rig") as Node3D
	var sk: Skeleton3D = null
	if root != null:
		for c in root.get_children():
			if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
				sk = ArmRig.skeleton(c as Node3D)
	var tail := sk.get_node_or_null(NodePath(String(_TAIL))) as MeshInstance3D if sk else null
	if tail == null or cam == null or rig == null:
		return "REACH_END BAD 1 (no left tail, camera or rig)"
	var out: Array[String] = []
	var bad := 0
	var total := 0
	var worst := ""
	var worst_score := INF
	for kind: StringName in _Gesture.KINDS:
		var keys: Array = _Keys.KEYS[kind][&"reach"]
		var coil_t: float = keys[1][&"t"]
		var hit_t: float = _Keys.CONTACT[kind]
		var settle_from: float = keys[keys.size() - 2][&"t"]
		var samples := {
			"swing": (coil_t + hit_t) * 0.5, "contact": hit_t,
			"settle": (settle_from + float(_Keys.DURATION[kind])) * 0.5,
		}
		for label: String in samples:
			var t: float = samples[label]
			vm.debug_gesture_kind = kind
			vm.debug_gesture_t = t
			vm.call(&"_process", _STEP)
			var m := _margin(sk, tail, vm, cam)
			total += 1
			var behind := m.w > 0.0
			var ok := behind or m.z > 0.0
			if not ok:
				bad += 1
			var reading := "behind %.2f" % m.w if behind else "ndc %.2f,%.2f margin %.2f" % [
				m.x, m.y, m.z]
			out.append("REACH_END %s %s %.2f: %s %s" % [
				kind, label, t, reading, "OK" if ok else "BAD"])
			# A sample in front is worse than any behind; then the smaller number is worse.
			var score := m.w if behind else m.z - 1000.0
			if score < worst_score:
				worst_score = score
				worst = "REACH_END MIN %s %.2f %s" % [kind, t,
						"%.2f m behind" % m.w if behind else "%.2f margin" % m.z]
			if label == "contact":
				var hand := sk.global_transform * _posed_global(sk, sk.find_bone("DEF-hand.L"))
				var target := rig.to_global(_Gesture.DEFAULT_HIT_RIG)
				out.append("REACH_END %s hand %.3f m" % [kind, hand.origin.distance_to(target)])
	vm.debug_gesture_t = -1.0
	vm.call(&"_process", _STEP)
	for t: float in _INSPECT_PINS:
		vm.debug_inspect_t = t
		vm.call(&"_process", _STEP)
		var m := _margin(sk, tail, vm, cam)
		total += 1
		var behind := m.w > 0.0
		var ok := behind or m.z > 0.0
		if not ok:
			bad += 1
		var reading := "behind %.2f" % m.w if behind else "ndc %.2f,%.2f margin %.2f" % [
			m.x, m.y, m.z]
		out.append("REACH_END inspect pin %.2f: %s %s" % [t, reading, "OK" if ok else "BAD"])
		var score := m.w if behind else m.z - 1000.0
		if score < worst_score:
			worst_score = score
			worst = "REACH_END MIN inspect %.2f %s" % [t,
					"%.2f m behind" % m.w if behind else "%.2f margin" % m.z]
	vm.debug_inspect_t = -1.0
	vm.call(&"_process", _STEP)
	out.append(worst)
	out.append("REACH_END %d/%d OK" % [total - bad, total] if bad == 0
			else "REACH_END BAD %d" % bad)
	return "\n".join(out)


## The on-screen-most far-ring point: x, y in NDC and z = how far outside the box it is; z > 0
## means every point is off screen. w > 0 means every point is behind the near plane and is the
## smallest depth behind it in metres (x, y, z are then unused). Points in front win over behind.
func _margin(sk: Skeleton3D, tail: MeshInstance3D, vm: Node, cam: Node3D) -> Vector4:
	var arrays := tail.mesh.surface_get_arrays(0)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var bi := (arrays[Mesh.ARRAY_BONES] as PackedInt32Array)[0]
	var bone := sk.find_bone(StringName(tail.skin.get_bind_name(bi)))
	var skin_xf := sk.global_transform * _posed_global(sk, bone) * tail.skin.get_bind_pose(bi)
	var vp := vm.get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var tan_half := tan(deg_to_rad(float(vm.viewmodel_fov)) * 0.5)
	var inv := cam.global_transform.affine_inverse()
	var near: float = (cam as Camera3D).near if cam is Camera3D else 0.05
	var best := Vector3(0.0, 0.0, INF)
	var behind := INF
	for j in _SECTORS:
		var p := inv * (skin_xf * verts[verts.size() - 1 - _SECTORS + j])
		var depth := -p.z
		if depth <= near:
			behind = minf(behind, near - depth)
			continue
		var x := p.x / (depth * tan_half * aspect)
		var y := p.y / (depth * tan_half)
		var out_by := maxf(absf(x), absf(y)) - 1.0
		if out_by < best.z:
			best = Vector3(x, y, out_by)
	if best.z == INF:
		return Vector4(0.0, 0.0, 0.0, maxf(behind, 0.0001))
	return Vector4(best.x, best.y, best.z, 0.0)


## Global pose from the local poses: Skeleton3D's cached global pose can be stale.
func _posed_global(sk: Skeleton3D, i: int) -> Transform3D:
	var t := sk.get_bone_pose(i)
	var p := sk.get_bone_parent(i)
	while p != -1:
		t = sk.get_bone_pose(p) * t
		p = sk.get_bone_parent(p)
	return t
