extends RefCounted
## Debug console `arms`: frames the first-person arms from fixed angles and freezes poses.

const _Fit := preload("res://scripts/debug/debug_arms_fit.gd")
const _Thumbs := preload("res://scripts/debug/debug_arms_thumbs.gd")
const _Ik := preload("res://scripts/debug/debug_arms_ik.gd")
const _Touch := preload("res://scripts/debug/debug_arms_touch.gd")
const _HandsCheck := preload("res://scripts/debug/debug_arms_hands.gd")
const _Dump := preload("res://scripts/debug/debug_arms_dump.gd")
const _Wrist := preload("res://scripts/debug/debug_arms_wrist.gd")
const _Hints := preload("res://scripts/debug/debug_arms_hints.gd")
const _Frame :=preload("res://scripts/debug/debug_arms_frame.gd")
const _Cam := preload("res://scripts/debug/debug_arms_cam.gd")
const _ReachEnd := preload("res://scripts/debug/debug_arms_reach_end.gd")
const _Gesture := preload("res://scripts/player/arms/arm_gesture.gd")
const _Weave := preload("res://scripts/player/arms/arm_weave.gd")

## Every subcommand `cmd_arms` handles; the one list behind `sub_commands()`, hints and usage.
const SUBS: PackedStringArray = [
	"cam", "curl", "dress", "dump", "fit", "fov", "frame", "gesture", "gun", "hands",
	"ik", "inspect", "lthumb", "lthumbaim", "lthumbroll", "reach", "reload", "rall", "reach-end", "ridx", "rmid", "rpinky",
	"rring", "shot", "thumbaim", "thumbcurl", "thumbroll", "thumbs", "thumbturn", "touch",
	"walk", "weave", "wrist", "wristang",
]

var host: Node  # the DebugCommands autoload (tree access and shared finders)
## Player body meshes hidden for the current debug camera, restored on the next switch.
var _hidden: Array[VisualInstance3D] = []


func _init(owner: Node) -> void:
	host = owner


## Every `arms` subcommand, sorted alphabetically.
func sub_commands() -> PackedStringArray:
	var out := SUBS.duplicate()
	out.sort()
	return out


## `arms <sub> <current values>  - note`, or "" for an unknown sub.
func hint(sub: String) -> String:
	return _hints().hint(sub)


## The current-value argument text of `sub`, or "" when it has none.
func current_args(sub: String) -> String:
	return _hints().current_args(sub)


## Like `current_args`; `curl <finger>` gives that finger's values.
func current_args_for(sub: String, first_arg: String) -> String:
	return _hints().current_args_for(sub, first_arg)


## The finger names `arms curl` accepts.
func curl_fingers() -> PackedStringArray:
	return _hints().curl_fingers()


## Header plus one hint line per subcommand.
func usage() -> String:
	return _hints().usage()


func _hints() -> RefCounted:
	return _Hints.new(host, sub_commands())


func cmd_arms(args: Array) -> String:
	var vm := _viewmodel()
	if vm == null:
		return "arms: no viewmodel"
	if args.is_empty():
		return usage()
	if args.size() == 1 and ["weave", "shot", "walk", "gesture", "inspect"].has(str(args[0])):
		return hint(str(args[0]))
	if args[0] == "cam" and args.size() >= 2:
		return _Cam.new(self).run(vm, args.slice(1))
	if args[0] == "reload" and args.size() >= 2:
		var arg := str(args[1])
		if arg == "off":
			vm.debug_reload_t = -1.0
			return "arms reload off"
		vm.debug_reload_t = clampf(float(arg), 0.0, 1.0)
		return "arms reload " + str(vm.debug_reload_t)
	if args[0] == "gesture" and args.size() >= 2:
		return _gesture(vm, args)
	if args[0] == "reach":
		return _reach(vm)
	if args[0] == "inspect" and args.size() >= 2:
		var arg := str(args[1])
		if arg == "play":
			return "arms inspect play" if vm.play_inspect() else "arms inspect: busy"
		if arg == "off":
			vm.debug_inspect_t = -1.0
			return "arms inspect off"
		if not arg.is_valid_float():
			return "bad args. " + hint("inspect")
		vm.debug_inspect_t = maxf(float(arg), 0.0)
		return "arms inspect " + str(vm.debug_inspect_t)
	if args[0] == "weave" and args.size() >= 2:
		var arg := str(args[1])
		if arg == "off":
			vm.debug_weave_t = -1.0
			return "arms weave off"
		if not arg.is_valid_float():
			return "bad args. " + hint("weave")
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
				return "bad args. " + hint("walk")
			vm.debug_walk_kind = StringName(arg)
			vm.debug_walk_t = maxf(float(str(args[2])), 0.0)
			return "arms walk %s %s" % [arg, str(vm.debug_walk_t)]
		if not arg.is_valid_float():
			return "bad args. " + hint("walk")
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
			return "bad args. " + hint("shot")
		vm.debug_shot_t = maxf(float(arg), 0.0)
		return "arms shot " + str(vm.debug_shot_t)
	if args[0] == "dress" and args.size() >= 2:
		var arg := str(args[1])
		if arg != "rags" and arg != "none" and arg != "bare":
			return "bad args. " + hint("dress")
		if not vm.has_method(&"rebuild_arms"):
			return "arms: no viewmodel"
		ArmsBuilder.dress_style = StringName(arg)
		vm.call(&"rebuild_arms", int(vm.get("_arms_seed")))
		return "arms dress: " + arg
	if args[0] == "curl":
		if args.size() < 3:
			return _hints().curl_show(args)
		var fingers: Array[StringName] = [&"f_index", &"f_middle", &"f_ring", &"f_pinky"]
		if args.size() != 5 or not fingers.has(StringName(str(args[1]))):
			return "bad args. " + hint("curl")
		for i in range(2, 5):
			if not str(args[i]).is_valid_float():
				return "bad args. " + hint("curl")
		if not vm.has_method(&"rebuild_arms"):
			return "arms: no viewmodel"
		var curl := ArmsBuilder.right_curl
		curl[StringName(str(args[1]))] = Vector3(
				float(str(args[2])), float(str(args[3])), float(str(args[4])))
		ArmsBuilder.right_curl = curl
		vm.call(&"rebuild_arms", int(vm.get("_arms_seed")))
		return "arms curl %s %s" % [str(args[1]), str(curl[StringName(str(args[1]))])]
	if str(args[0]) in ["ridx", "rmid", "rring", "rpinky", "rall"]:
		return _hints().rfinger_apply(args, vm)
	if args[0] == "gun":
		if args.size() < 2:
			return "arms gun: " + str(ArmsBuilder.gun_style)
		var arg := str(args[1])
		if arg != "grip" and arg != "pistol":
			return "bad args. " + hint("gun")
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
			return "bad args. " + hint("fov")
		vm.set_viewmodel_fov(float(arg))
		return "arms fov -> %.1f" % float(arg)
	if args[0] == "frame":
		if vm.get_parent().get_node_or_null(NodePath(_Cam.CAM_NAME)) != null:
			return "FRAME n/a (arms cam on; run arms cam off)"
		return _Frame.new().run(vm)
	if args[0] == "fit":
		return _Fit.new().run(vm)
	if args[0] == "thumbs":
		return _Thumbs.new().run(vm)
	if args[0] == "wristang":
		return _Wrist.new().run(vm, args)
	if args[0] == "ik":
		return _Ik.new().run(vm)
	if args[0] == "touch":
		return _Touch.new().run(vm)
	if args[0] == "reach-end":
		return _ReachEnd.new().run(vm)
	if args[0] == "lthumb":
		return _lthumb(args)
	if args[0] == "lthumbaim":
		return _lthumbaim(args)
	if args[0] == "lthumbroll":
		return _thumbroll(args, false)
	if args[0] == "thumbroll":
		return _thumbroll(args, true)
	if args[0] == "hands":
		return _HandsCheck.new().run(vm)
	if args[0] == "dump":
		var parts: Array[String] = []
		for a in args.slice(1):
			parts.append(str(a))
		var path := " ".join(parts)
		if path.is_empty():
			return "bad args. " + hint("dump")
		return _Dump.new().run(vm, path)
	if args[0] == "thumbaim" or args[0] == "thumbturn" or args[0] == "thumbcurl" \
			or args[0] == "wrist":
		return _Fit.new().tune(vm, str(args[0]), args.slice(1))
	if SUBS.has(str(args[0])):
		return "bad args. " + hint(str(args[0]))
	return usage()


## `arms lthumb <bx> <by> <bz> <spread> <ax> <ay> <az>`: live-tunes the free left thumb's rest pose.
func _lthumb(args: Array) -> String:
	if args.size() == 1:
		return "lthumb base %s spread %.1f axis %s" % [
				_Weave.left_thumb_base, _Weave.left_thumb_spread, _Weave.left_thumb_axis]
	if args.size() != 8:
		return "bad args. " + hint("lthumb")
	var n: Array[float] = []
	for i in range(1, 8):
		if not str(args[i]).is_valid_float():
			return "bad args. " + hint("lthumb")
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


## `arms lthumbaim [x y z]`: shows or sets the extra euler on the left thumb's palm joint.
func _lthumbaim(args: Array) -> String:
	if args.size() == 1:
		return "lthumbaim %s (euler degrees on DEF-thumb.01.L, after flex and spread)" % (
				_Weave.left_thumb_aim)
	if args.size() != 4:
		return "bad args. " + hint("lthumbaim")
	for i in range(1, 4):
		if not str(args[i]).is_valid_float():
			return "bad args. " + hint("lthumbaim")
	_Weave.left_thumb_aim = Vector3(
			float(str(args[1])), float(str(args[2])), float(str(args[3])))
	return "lthumbaim set to %s" % _Weave.left_thumb_aim


## `arms lthumbroll|thumbroll [deg]`: shows or sets the thumb tip's spin about its own length. The
## left one is live; the right one lives in the builder, so it rebuilds the arms.
func _thumbroll(args: Array, right: bool) -> String:
	var name: String = args[0]
	if args.size() == 1:
		return "%s %.1f (degrees, spins the thumb's tip bone about its own length (twists the nail sideways); the rest of the thumb stays put)" % [
				name, ArmsBuilder.right_thumb_roll if right else _Weave.left_thumb_roll]
	if args.size() != 2 or not str(args[1]).is_valid_float():
		return "bad args. " + hint(name)
	var deg := float(str(args[1]))
	if not right:
		_Weave.left_thumb_roll = deg
		return "lthumbroll set to %.1f" % deg
	ArmsBuilder.right_thumb_roll = deg
	var vm := _viewmodel()
	if vm == null or not vm.has_method(&"rebuild_arms"):
		return "arms: no viewmodel"
	vm.call(&"rebuild_arms", int(vm.get("_arms_seed")))
	return "thumbroll set to %.1f" % deg


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
		vm.play_gesture(play_kind, vm.to_global(Vector3(0.0, 0.0, -0.9)))
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
		return "bad args. " + hint("gesture")
	vm.debug_gesture_kind = kind
	vm.debug_gesture_t = t
	return "arms gesture %s %s" % [kind, t]


## `arms reach`: the left arm's reach numbers in rig units (1 = 18 cm), in the left root's space.
func _reach(vm: Node) -> String:
	var roots := vm.get("_roots") as Dictionary
	var root := roots.get("left_root") as Node3D
	var wrist := (roots.get("left_reach", {}) as Dictionary).get("wrist", Vector3.ZERO) as Vector3
	var sk: Skeleton3D = null
	var to_rig := Transform3D.IDENTITY
	for c in root.get_children():
		if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
			sk = ArmRig.skeleton(c as Node3D)
			var n: Node = sk
			while n != root and n is Node3D:
				to_rig = (n as Node3D).transform * to_rig
				n = n.get_parent()
	var o: Array[Vector3] = []
	for bone in ["upper_arm", "forearm", "hand"]:
		o.append(ArmRig._global_rest(sk, sk.find_bone("DEF-%s.L" % bone)).origin)
	var k := to_rig.basis.x.length()
	var a := k * o[0].distance_to(o[1])
	var b := k * o[1].distance_to(o[2])
	var big_r := 0.98 * (a + b)
	var shoulder := to_rig * sk.get_bone_global_pose(sk.find_bone("DEF-upper_arm.L")).origin
	var d := wrist.distance_to(shoulder)
	var cam := host.get_viewport().get_camera_3d()
	var hit := root.to_local(cam.to_global(Vector3(0, 0, -0.9)))
	var rd := (wrist - shoulder).dot((hit - shoulder).normalized())
	var s := sqrt(big_r * big_r - d * d + rd * rd) - rd
	return "reach (left root space, rig units): k %.4f a %.4f b %.4f R %.4f d %.4f " % [
			k, a, b, big_r, d] + "wrist_off %.5f S %.4f" % [
			wrist.distance_to(ArmsBuilder.LEFT_SHOWN_WRIST), s]


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
