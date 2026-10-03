extends RefCounted
## Debug console `arms`: frames the first-person arms from fixed angles and freezes poses.

const _Fit := preload("res://scripts/debug/debug_arms_fit.gd")
const _Thumbs := preload("res://scripts/debug/debug_arms_thumbs.gd")
const _Ik := preload("res://scripts/debug/debug_arms_ik.gd")
const _Touch := preload("res://scripts/debug/debug_arms_touch.gd")
const _GearFit := preload("res://scripts/debug/debug_arms_gear_fit.gd")
const _HandsCheck := preload("res://scripts/debug/debug_arms_hands.gd")
const _Dump := preload("res://scripts/debug/debug_arms_dump.gd")
const _Frame :=preload("res://scripts/debug/debug_arms_frame.gd")
const _Gesture := preload("res://scripts/player/arms/arm_gesture.gd")
const _Weave := preload("res://scripts/player/arms/arm_weave.gd")

const CAM_NAME := &"ArmsDebugCam"
## Camera offsets from the focus point in Weapon space (metres); `left` aims at the left hand,
## `elbow` at the left elbow, from below and to its left. The hands are half again as big, so
## the close-ups step back.
const VIEWS := {
	&"front": Vector3(0.0, 0.042, -0.448),
	&"side": Vector3(-0.42, 0.07, -0.07),
	&"left": Vector3(0.07, 0.112, -0.42),
	&"top": Vector3(0.0, 0.42, 0.028),
	&"elbow": Vector3(-0.14, -0.168, -0.392),
}
## Where `DEF-forearm.L` starts (the left elbow) relative to the left-hand focus, Weapon space,
## measured with the arms at rest (-0.099, -0.051, 0.002).
const ELBOW_FROM_WRIST := Vector3(-0.1, -0.05, 0.0)
const USAGE := "arms cam <front|side|left|top|elbow|off> | arms reload <0..1|off> | arms weave <seconds|off> | arms shot <seconds|off> | arms fit | arms thumbaim [x y z] | arms thumbcurl [a b c] | arms wrist [x y z] | arms gear | arms thumbs | arms ik | arms touch | arms lthumb <bx> <by> <bz> <spread> <ax> <ay> <az> | arms hands | arms dump <path> | arms dress <gear|rags|none> | arms gun [grip|pistol] | arms fov [deg] | arms frame | arms gesture <kind> <sec|contact|off> | arms gesture play <kind> | arms walk <cycle 0..1> [amount] | arms walk start|stop <sec> | arms walk off"

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
	if args[0] == "gesture" and args.size() >= 2:
		return _gesture(vm, args)
	if args[0] == "weave" and args.size() >= 2:
		var arg := str(args[1])
		if arg == "off":
			vm.debug_weave_t = -1.0
			return "arms weave off"
		if not arg.is_valid_float():
			return USAGE
		vm.debug_weave_t = maxf(float(arg), 0.0)
		return "arms weave " + str(vm.debug_weave_t)
	if args[0] == "walk" and args.size() >= 2:
		var arg := str(args[1])
		if arg == "off":
			vm.debug_walk_t = -1.0
			vm.debug_walk_kind = &""
			vm.debug_walk_amount = 1.0
			return "arms walk off"
		if arg == "start" or arg == "stop":
			if args.size() < 3 or not str(args[2]).is_valid_float():
				return USAGE
			vm.debug_walk_kind = StringName(arg)
			vm.debug_walk_t = maxf(float(str(args[2])), 0.0)
			return "arms walk %s %s" % [arg, str(vm.debug_walk_t)]
		if not arg.is_valid_float():
			return USAGE
		vm.debug_walk_kind = &""
		vm.debug_walk_t = fposmod(float(arg), 1.0)
		vm.debug_walk_amount = 1.0
		if args.size() >= 3:
			vm.debug_walk_amount = clampf(float(str(args[2])), 0.0, 1.0)
		return "arms walk " + str(vm.debug_walk_t)
	if args[0] == "shot" and args.size() >= 2:
		var arg := str(args[1])
		if arg == "off":
			vm.debug_shot_t = -1.0
			return "arms shot off"
		if not arg.is_valid_float():
			return USAGE
		vm.debug_shot_t = maxf(float(arg), 0.0)
		return "arms shot " + str(vm.debug_shot_t)
	if args[0] == "dress" and args.size() >= 2:
		var arg := str(args[1])
		if arg != "gear" and arg != "rags" and arg != "none":
			return USAGE
		if not vm.has_method(&"rebuild_arms"):
			return "arms: no viewmodel"
		ArmsBuilder.dress_style = StringName(arg)
		vm.call(&"rebuild_arms", int(vm.get("_arms_seed")))
		return "arms dress: " + arg
	if args[0] == "gun":
		if args.size() < 2:
			return "arms gun: " + str(ArmsBuilder.gun_style)
		var arg := str(args[1])
		if arg != "grip" and arg != "pistol":
			return USAGE
		if not vm.has_method(&"rebuild_arms"):
			return "arms: no viewmodel"
		ArmsBuilder.gun_style = StringName(arg)
		vm.call(&"rebuild_arms", int(vm.get("_arms_seed")))
		if arg == "pistol":
			return "arms gun: pistol"
		var roots: Dictionary = vm.get("_roots")
		var gun_root := roots.get("gun_root") as Node3D
		var palm := HeldGun.palm_len_of(gun_root) if gun_root != null else 0.22
		return "arms gun: grip | " + MonsterGrip.size_report(palm)
	if args[0] == "fov":
		if args.size() < 2:
			return "arms fov %.1f (default %.1f, 0 = world camera)" % [
				vm.viewmodel_fov, vm.VIEWMODEL_FOV]
		var arg := str(args[1])
		if not arg.is_valid_float() or float(arg) < 0.0 or float(arg) > 120.0:
			return USAGE
		vm.set_viewmodel_fov(float(arg))
		return "arms fov -> %.1f" % float(arg)
	if args[0] == "frame":
		if vm.get_parent().get_node_or_null(NodePath(CAM_NAME)) != null:
			return "FRAME n/a (arms cam on; run arms cam off)"
		return _Frame.new().run(vm)
	if args[0] == "fit":
		return _Fit.new().run(vm)
	if args[0] == "gear":
		return _GearFit.new(host).run(vm)
	if args[0] == "thumbs":
		return _Thumbs.new().run(vm)
	if args[0] == "ik":
		return _Ik.new().run(vm)
	if args[0] == "touch":
		return _Touch.new().run(vm)
	if args[0] == "lthumb":
		return _lthumb(args)
	if args[0] == "hands":
		return _HandsCheck.new().run(vm)
	if args[0] == "dump":
		var parts: Array[String] = []
		for a in args.slice(1):
			parts.append(str(a))
		var path := " ".join(parts)
		if path.is_empty():
			return USAGE
		return _Dump.new().run(vm, path)
	if args[0] == "thumbaim" or args[0] == "thumbcurl" or args[0] == "wrist":
		return _Fit.new().tune(vm, str(args[0]), args.slice(1))
	return USAGE


## `arms lthumb <bx> <by> <bz> <spread> <ax> <ay> <az>`: live-tunes the free left thumb's rest pose.
func _lthumb(args: Array) -> String:
	if args.size() != 8:
		return USAGE
	var n: Array[float] = []
	for i in range(1, 8):
		if not str(args[i]).is_valid_float():
			return USAGE
		n.append(float(str(args[i])))
	var axis := Vector3(n[4], n[5], n[6])
	if axis.is_zero_approx():
		return "lthumb: axis must be non-zero"
	_Weave.left_thumb_base = Vector3(n[0], n[1], n[2])
	_Weave.left_thumb_spread = n[3]
	_Weave.left_thumb_axis = axis.normalized()
	var ax: Vector3 = _Weave.left_thumb_axis
	return "lthumb base (%.0f, %.0f, %.0f) spread %.0f axis (%.2f, %.2f, %.2f)" % [
			n[0], n[1], n[2], n[3], ax.x, ax.y, ax.z]


## `arms gesture <kind> <seconds|contact>`, `off` and `play <kind>`: pins or plays a left-hand gesture.
func _gesture(vm: Node, args: Array) -> String:
	var kinds: Array = _Gesture.KINDS
	if str(args[1]) == "off":
		vm.debug_gesture_t = -1.0
		return "arms gesture off"
	if str(args[1]) == "play" and args.size() >= 3:
		var play_kind := StringName(str(args[2]))
		if not kinds.has(play_kind):
			return "arms gesture: kinds " + ", ".join(kinds)
		vm.play_gesture(play_kind)
		return "arms gesture play " + str(play_kind)
	var kind := StringName(str(args[1]))
	if not kinds.has(kind) or args.size() < 3:
		return "arms gesture: kinds " + ", ".join(kinds)
	var arg := str(args[2])
	var t := 0.0
	if arg == "contact":
		t = float(_Gesture.CONTACT[kind])
	elif arg.is_valid_float():
		t = maxf(float(arg), 0.0)
	else:
		return USAGE
	vm.debug_gesture_kind = kind
	vm.debug_gesture_t = t
	return "arms gesture %s %s" % [kind, t]


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
		vm.set_viewmodel_fov(vm.viewmodel_fov)
		return "arms cam off"
	if not VIEWS.has(view):
		return USAGE
	# The debug cameras look at the arms from outside; the player-camera FOV override would zoom them.
	ViewmodelFov.apply(vm.get_node("Rig"), 0.0)
	var cam := Camera3D.new()
	cam.name = CAM_NAME
	cam.fov = 50.0
	cam.near = 0.01
	if player_cam != null:
		cam.cull_mask = player_cam.cull_mask
	parent.add_child(cam)
	_hide_body(vm)
	var left_view := view == &"left" or view == &"elbow"
	var focus: Vector3 = vm.arms_focus(&"left" if left_view else &"right")
	if view == &"elbow":
		focus += ELBOW_FROM_WRIST
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
