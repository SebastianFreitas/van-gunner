extends RefCounted
## Debug console `arms`: frames the first-person arms from fixed angles and freezes poses.

const CAM_NAME := &"ArmsDebugCam"
## Camera offsets from the focus point in Weapon space (metres); `left` aims at the left hand.
const VIEWS := {
	&"front": Vector3(0.0, 0.03, -0.32),
	&"side": Vector3(-0.3, 0.05, -0.05),
	&"left": Vector3(0.05, 0.08, -0.3),
	&"top": Vector3(0.0, 0.3, 0.02),
}
const USAGE := "arms cam <front|side|left|top|off> | arms reload <0..1|off> | arms weave <seconds|off> | arms fit"

var host: Node  # the DebugCommands autoload (tree access and shared finders)
## Player body meshes hidden for the current debug camera, restored on the next switch.
var _hidden: Array[VisualInstance3D] = []


func _init(owner: Node) -> void:
	host = owner


func cmd_arms(args: Array) -> String:
	var vm := _viewmodel()
	if vm == null:
		return "arms: no viewmodel"
	if args.is_empty():
		return USAGE
	if args[0] == "cam" and args.size() >= 2:
		return _cam(vm, StringName(str(args[1])))
	if args[0] == "reload" and args.size() >= 2:
		var arg := str(args[1])
		if arg == "off":
			vm.debug_reload_t = -1.0
			return "arms reload off"
		vm.debug_reload_t = clampf(float(arg), 0.0, 1.0)
		return "arms reload " + str(vm.debug_reload_t)
	if args[0] == "weave" and args.size() >= 2:
		var arg := str(args[1])
		if arg == "off":
			vm.debug_weave_t = -1.0
			return "arms weave off"
		if not arg.is_valid_float():
			return USAGE
		vm.debug_weave_t = maxf(float(arg), 0.0)
		return "arms weave " + str(vm.debug_weave_t)
	if args[0] == "fit":
		return _fit(vm)
	return USAGE


## Read-only readout of where the right thumb sits against the gun's steel and rubber parts,
## in palm lengths, so a thumb pose can be tuned without a screenshot per try.
func _fit(vm: Node) -> String:
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
	var p := ArmRig.palm_len(model)
	var heads := {}
	for n in ["thumb.01", "thumb.02", "thumb.03", "f_index.01"]:
		var i := sk.find_bone("DEF-%s.R" % n)
		if i == -1:
			return "arms fit: bone " + n + " missing"
		heads[n] = sk.global_transform * sk.get_bone_global_pose(i).origin
	var tip: Vector3 = heads["thumb.03"] + (heads["thumb.03"] - heads["thumb.02"])
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
			var box := mi.get_aabb()
			var d := (q - box.get_center()).abs() - box.size * 0.5
			var sd := d.max(Vector3.ZERO).length() + minf(maxf(d.x, maxf(d.y, d.z)), 0.0)
			if sd < best:
				best = sd
				part = part_name
		var clear := (best - 0.10 * p) / p
		if clear < 0.0:
			clips += 1
		var b: Vector3 = (to_body * g) / p
		lines.append("%s body/p (%.2f, %.2f, %.2f) nearest %s clearance/p %.2f"
				% [key, b.x, b.y, b.z, part, clear])
	lines.append("tip to index.01 / p %.2f" % (tip.distance_to(heads["f_index.01"]) / p))
	lines.append("FIT OK" if clips == 0 else "FIT CLIP %d" % clips)
	var text := "\n".join(lines)
	print(text)
	return text


func _cam(vm: Node, view: StringName) -> String:
	var parent := vm.get_parent()
	var old := parent.get_node_or_null(NodePath(CAM_NAME))
	if old != null:
		parent.remove_child(old)
		old.free()
	_show_body()
	var player_cam := parent.get_parent() as Camera3D
	if view == &"off":
		if player_cam != null:
			player_cam.make_current()
		return "arms cam off"
	if not VIEWS.has(view):
		return USAGE
	var cam := Camera3D.new()
	cam.name = CAM_NAME
	cam.fov = 50.0
	cam.near = 0.01
	if player_cam != null:
		cam.cull_mask = player_cam.cull_mask
	parent.add_child(cam)
	_hide_body(vm)
	var focus: Vector3 = vm.arms_focus(&"left" if view == &"left" else &"right")
	var from: Vector3 = focus + (VIEWS[view] as Vector3)
	var up := Vector3.FORWARD if view == &"top" else Vector3.UP
	cam.transform = Transform3D(Basis.looking_at(focus - from, up), from)
	cam.make_current()
	return "arms cam " + str(view)


## The player's own meshes would block the front and top views.
func _hide_body(vm: Node) -> void:
	var player := host.get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	_collect(player, vm, _hidden)
	for node in _hidden:
		node.visible = false


func _show_body() -> void:
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()


func _collect(node: Node, vm: Node, out: Array[VisualInstance3D]) -> void:
	for child in node.get_children():
		if child == vm:
			continue
		var vi := child as VisualInstance3D
		if vi != null and vi.visible and not (vi is Light3D):
			out.append(vi)
		_collect(child, vm, out)


func _viewmodel() -> Node:
	return host.get_tree().get_first_node_in_group(&"gun_viewmodel")
