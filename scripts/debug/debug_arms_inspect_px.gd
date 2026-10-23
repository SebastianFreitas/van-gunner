extends RefCounted
## Debug `arms inspect <t>` probe: one line with the left arm's pixel positions (1920x1080), tattoo size and facing at the pinned inspect age.

const _STEP := 0.001
const _SCREEN := Vector2(1920.0, 1080.0)
## The tattoo band centre, back from the wrist along elbow to wrist (rig units).
const _BAND_BACK := 0.235
const _TAN_HALF_LENS := 0.466


## The pinned frame is posed with one `_process` step, then measured from the bone poses.
func run(vm: Node, t: float) -> String:
	var roots := vm.get("_roots") as Dictionary
	var root := roots.get("left_root") as Node3D
	var cam := vm.get("_camera") as Camera3D
	var rig := vm.get("_rig") as Node3D
	var insp: RefCounted = vm.get("_inspect")
	var sk: Skeleton3D = null
	if root != null:
		for c in root.get_children():
			if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
				sk = ArmRig.skeleton(c as Node3D)
	if sk == null or cam == null or rig == null or insp == null:
		return "INSPECT_PX no left arm, camera, rig or inspect"
	vm.call(&"_process", _STEP)
	var s := rig.global_transform.basis.x.length()
	var xf := sk.global_transform
	var wrist := xf * _pose(sk, "DEF-hand.L").origin
	var elbow := xf * _pose(sk, "DEF-forearm.L").origin
	var shoulder := xf * _pose(sk, "DEF-upper_arm.L").origin
	var knuckle := xf * _pose(sk, "DEF-f_middle.01.L").origin
	var g3 := _pose(sk, "DEF-f_middle.03.L")
	var info: Dictionary = (root.get_child(0).get_meta(&"fingers", {}) as Dictionary).get(
			&"f_middle", {})
	var tip := xf * (g3.origin + g3.basis.y * float(info.get(&"tip_len", 0.0)))
	var band := wrist - (wrist - elbow).normalized() * _BAND_BACK * s
	var eye := cam.global_position
	var radius := 1.0
	var angle := 0.0
	var width := 0.0
	for c in sk.get_children():
		var mat: ShaderMaterial = (c as MeshInstance3D).material_override as ShaderMaterial \
				if c is MeshInstance3D else null
		if mat != null and mat.get_shader_parameter(&"tat_radius") != null:
			radius = float(mat.get_shader_parameter(&"tat_radius"))
			angle = float(mat.get_shader_parameter(&"tat_angle"))
			width = float(mat.get_shader_parameter(&"tat_width"))
			break
	var r_rig := radius * xf.basis.x.length() / s
	var band_px := _px(vm, cam, band)
	var z := band_px.z / s
	var letter := 1.5 * r_rig / (_TAN_HALF_LENS * z) * 0.5 * _SCREEN.y
	var palm_n := root.global_transform.basis * ((insp.get("_keys") as RefCounted).call(
			&"sample", t)[&"palm_n"] as Vector3)
	var fore := xf.basis * _pose(sk, "DEF-forearm.L.001").basis
	var face := (fore * Vector3(cos(angle), 0.0, sin(angle))).normalized()
	var to_cam := (eye - band).normalized()
	var u := (shoulder - elbow).normalized()
	var v := (wrist - elbow).normalized()
	var w := _px(vm, cam, wrist)
	var h := _px(vm, cam, (wrist + knuckle) * 0.5)
	var tp := _px(vm, cam, tip)
	var half := 0.5 * width * xf.basis.x.length() * v.normalized()
	var e0 := _px(vm, cam, band + half)
	var e1 := _px(vm, cam, band - half)
	return _right_line(vm, t) + "\n" + ("INSPECT_PX L %.2f wrist %.0f,%.0f tip %.0f,%.0f hand %.0f,%.0f band %.0f,%.0f "
			+ "z %.3f r %.3f letter %.1f px elbow %.0f deg palm_dot %.2f face_dot %.2f "
			+ "strip top %.0f bottom %.0f") % [
		t, w.x, w.y, tp.x, tp.y, h.x, h.y, band_px.x, band_px.y, z, r_rig, letter,
		rad_to_deg(u.angle_to(v)), palm_n.normalized().dot(to_cam), face.dot(to_cam),
		minf(e0.y, e1.y), maxf(e0.y, e1.y)]


## The right arm's wrist reach (distance from the put-back shoulder over arm length) and the
## hand's twist about the forearm axis against the rest pose.
func _right_line(vm: Node, t: float) -> String:
	var root := (vm.get("_roots") as Dictionary).get("right_root") as Node3D
	var insp: RefCounted = vm.get("_inspect")
	var sk: Skeleton3D = null
	if root != null:
		for c in root.get_children():
			if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
				sk = ArmRig.skeleton(c as Node3D)
	if sk == null or insp == null or (insp.get("_right_reach") as Dictionary).is_empty():
		return "INSPECT_PX R no right arm"
	var reach: Dictionary = insp.get("_right_reach")
	var shoulder: Vector3 = (insp.call(&"right_offset") as Transform3D).affine_inverse() \
			* (reach["shoulder"] as Vector3)
	var to_root := root.global_transform.affine_inverse() * sk.global_transform
	var ua := to_root * _pose(sk, "DEF-upper_arm.R").origin
	var fa := to_root * _pose(sk, "DEF-forearm.R").origin
	var hand := _pose(sk, "DEF-hand.R")
	var wrist := to_root * hand.origin
	var arm_len := ua.distance_to(fa) + fa.distance_to(wrist)
	var now_twist := _twist(_pose(sk, "DEF-forearm.R"), hand)
	# The rest pose is the restore solve (inspect off); the next frame re-poses the arm.
	(insp.get("_solve_r") as RefCounted).call(&"restore")
	var twist := now_twist - _twist(_pose(sk, "DEF-forearm.R"), _pose(sk, "DEF-hand.R"))
	twist = fposmod(twist + 180.0, 360.0) - 180.0
	return "INSPECT_PX R %.2f rwrist d/R %.2f twist %.0f" % [
		t, wrist.distance_to(shoulder) / arm_len, twist]


## Degrees about the forearm axis (elbow to wrist) from the forearm's x to the hand's x.
func _twist(fore: Transform3D, hand: Transform3D) -> float:
	var axis := (hand.origin - fore.origin).normalized()
	var a := (fore.basis.x - axis * fore.basis.x.dot(axis)).normalized()
	var b := (hand.basis.x - axis * hand.basis.x.dot(axis)).normalized()
	return rad_to_deg(a.signed_angle_to(b, axis))


## Screen px (x, y) and the depth in metres (z) of a global point through the viewmodel lens.
func _px(vm: Node, cam: Camera3D, p: Vector3) -> Vector3:
	var local := cam.global_transform.affine_inverse() * p
	var depth := maxf(-local.z, 0.0001)
	var tan_half := tan(deg_to_rad(float(vm.viewmodel_fov)) * 0.5)
	var nx := local.x / (depth * tan_half * _SCREEN.x / _SCREEN.y)
	var ny := local.y / (depth * tan_half)
	return Vector3((nx + 1.0) * 0.5 * _SCREEN.x, (1.0 - ny) * 0.5 * _SCREEN.y, depth)


## Global pose from the local poses: Skeleton3D's cached global pose can be stale.
func _pose(sk: Skeleton3D, bone: String) -> Transform3D:
	var i := sk.find_bone(bone)
	var t := sk.get_bone_pose(i)
	var p := sk.get_bone_parent(i)
	while p != -1:
		t = sk.get_bone_pose(p) * t
		p = sk.get_bone_parent(p)
	return t
