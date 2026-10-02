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
const USAGE := "arms cam <front|side|left|top|down|off> | arms reload <0..1|off> | arms weave <seconds|off>"

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
	return USAGE


func _cam(vm: Node, view: StringName) -> String:
	var parent := vm.get_parent()
	var old := parent.get_node_or_null(NodePath(CAM_NAME))
	if old != null:
		parent.remove_child(old)
		old.free()
	_show_body()
	vm.debug_look_down = -1.0
	var player_cam := parent.get_parent() as Camera3D
	if view == &"off":
		if player_cam != null:
			player_cam.make_current()
		return "arms cam off"
	if view == &"down":
		vm.debug_look_down = 1.0
		if player_cam != null:
			player_cam.make_current()
		return "arms cam down (left arm raised as if looking down)"
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
