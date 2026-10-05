extends RefCounted
## Builds the `arms` console hints: one line per subcommand with its CURRENT values, read-only.

const _Weave := preload("res://scripts/player/arms/arm_weave.gd")
const FINGERS: Array[StringName] = [&"f_index", &"f_middle", &"f_ring", &"f_pinky"]
## sub -> [argument shape shown when no value is stored, note].
const INFO := {
	"cam": ["<front|side|left|top|elbow|off>", "orbit camera on the arms"],
	"reload": ["<0..1|off>", "pin the reload at this progress"],
	"inspect": ["<sec|play|off>", "pin or play the gun inspect"],
	"dress": ["<gear|rags|none>", "gear|rags|none"],
	"gear": ["", "gear fit report"],
	"fov": ["<deg>", "viewmodel FOV, 0 = world camera"],
	"frame": ["", "framing report"],
	"weave": ["<sec|off>", "pin the finger weave time"],
	"shot": ["<sec|off>", "pin one shot's kick time"],
	"walk": ["<cycle 0..1> [amount]", "walk cycle; also start|stop <sec> and off"],
	"gesture": ["<kind> <sec|contact|off>", "pin a left-hand gesture; also play <kind>"],
	"thumbs": ["", "thumb report"],
	"wristang": ["[t|axes|flex|dev|scan [t0 t1]]", "left wrist angles"],
	"ik": ["", "IK report"],
	"touch": ["", "touch report"],
	"fit": ["", "fit report"],
	"thumbaim": ["<x> <y> <z>", "right thumb palm-joint euler"],
	"thumbturn": ["<roll> <toward> <down>", "right thumb turn"],
	"thumbroll": ["<deg>", "right thumb tip spin about its length"],
	"thumbcurl": ["<a> <b> <c>", "right thumb curl"],
	"wrist": ["<x> <y> <z>", "right wrist offset in the gun"],
	"curl": ["<f_index|f_middle|f_ring|f_pinky> <a> <b> <c>",
			"right finger curl; bare lists all"],
	"ridx": ["[1|2|3 x y z | shift x y z | reset]", "right index per joint, x curl, y twist, "
			+ "z swing (deg); shift moves the knuckle (cm)"],
	"gun": ["<grip|pistol>", "grip|pistol"],
	"lthumb": ["<bx> <by> <bz> <spread> <ax> <ay> <az>", "left thumb rest pose"],
	"lthumbaim": ["<x> <y> <z>", "left thumb palm-joint euler"],
	"lthumbroll": ["<deg>", "left thumb tip spin about its length"],
	"hands": ["", "hands check"],
	"dump": ["<path>", "dump the arms to a file"],
}

var host: Node  # the DebugCommands autoload (tree access)
var _subs: PackedStringArray


func _init(owner: Node, subs: PackedStringArray) -> void:
	host = owner
	_subs = subs


## The multi-line usage text: a header then one hint per subcommand.
func usage() -> String:
	var lines: Array[String] = ["arms <sub> [args]  (current values shown)"]
	for sub in _subs:
		lines.append(hint(sub))
	return "\n".join(lines)


## `arms <sub> <current args>  - note`, or "" for an unknown sub.
func hint(sub: String) -> String:
	if not INFO.has(sub):
		return ""
	var info: Array = INFO[sub]
	var args := current_args(sub)
	if args.is_empty():
		args = str(info[0])
	var head := "arms " + sub
	if not args.is_empty():
		head += " " + args
	return head + "  - " + str(info[1])


## The current-value argument text of `sub`, or "" when it has none.
func current_args(sub: String) -> String:
	var vm := _vm()
	match sub:
		"thumbaim":
			return _v3(ArmsBuilder.right_thumb_aim)
		"thumbturn":
			return _v3(ArmsBuilder.right_thumb_turn)
		"thumbcurl":
			return _v3(ArmsBuilder.right_thumb_curl)
		"wrist":
			return _v3(ArmsBuilder.right_wrist_in_gun)
		"thumbroll":
			return "%.1f" % ArmsBuilder.right_thumb_roll
		"dress":
			return str(ArmsBuilder.dress_style)
		"gun":
			return str(ArmsBuilder.gun_style)
		"lthumb":
			var axis: Vector3 = _Weave.left_thumb_axis
			var base: Vector3 = _Weave.left_thumb_base
			return "%.2f %.2f %.2f %.2f %.2f %.2f %.2f" % [
					base.x, base.y, base.z, _Weave.left_thumb_spread, axis.x, axis.y, axis.z]
		"lthumbaim":
			return _v3(_Weave.left_thumb_aim)
		"lthumbroll":
			return "%.1f" % _Weave.left_thumb_roll
	if vm == null:
		return ""
	match sub:
		"fov":
			return "%.1f" % float(vm.viewmodel_fov)
		"reload":
			return _timer(vm.debug_reload_t)
		"inspect":
			return _timer(vm.debug_inspect_t)
		"weave":
			return _timer(vm.debug_weave_t)
		"shot":
			return _timer(vm.debug_shot_t)
		"walk":
			if vm.debug_walk_t < 0.0:
				return "off"
			if vm.debug_walk_kind != &"":
				return "%s %.2f" % [vm.debug_walk_kind, vm.debug_walk_t]
			return "%.2f %.2f" % [vm.debug_walk_t, vm.debug_walk_amount]
		"gesture":
			if vm.debug_gesture_t < 0.0:
				return "off"
			return "%s %.2f" % [vm.debug_gesture_kind, vm.debug_gesture_t]
	return ""


## Like `current_args`, but `curl <finger>` gives that finger's values.
func current_args_for(sub: String, first_arg: String) -> String:
	if sub == "curl":
		var finger := StringName(first_arg)
		if not FINGERS.has(finger):
			return ""
		var curl: Dictionary = ArmsBuilder.right_curl
		if not curl.has(finger):
			return ""
		return _v3(curl[finger])
	if sub == "ridx":
		if first_arg == "shift":
			return _v3(ArmsBuilder.right_index_shift)
		if ["1", "2", "3"].has(first_arg):
			return _v3(ArmsBuilder.right_index_aim[int(first_arg) - 1])
		return ""
	return current_args(sub)


## The finger names `arms curl` accepts.
func curl_fingers() -> PackedStringArray:
	var out := PackedStringArray()
	for f in FINGERS:
		out.append(str(f))
	return out


## One `arms curl <finger> a b c` line per finger, or just `finger` when one is named.
func curl_lines(finger: String) -> String:
	var lines: Array[String] = []
	for f in FINGERS:
		if finger.is_empty() or finger == str(f):
			lines.append("arms curl %s %s" % [f, current_args_for("curl", str(f))])
	return "\n".join(lines)


## `arms curl` and `arms curl <finger>`: the current values, or the hint for an unknown finger.
func curl_show(args: Array) -> String:
	if args.size() == 1:
		return curl_lines("")
	if curl_fingers().has(str(args[1])):
		return curl_lines(str(args[1]))
	return "bad args. " + hint("curl")


## `arms ridx` lines: the aim per joint, the knuckle shift and a copy-paste line of the values.
func ridx_show() -> String:
	var aims: Array = ArmsBuilder.right_index_aim
	var lines: Array[String] = []
	var paste: Array[String] = []
	for j in 3:
		lines.append("arms ridx %d %s" % [j + 1, _v3(aims[j])])
		paste.append("arms ridx %d %s" % [j + 1, _v3(aims[j])])
	lines.append("arms ridx shift %s" % _v3(ArmsBuilder.right_index_shift))
	paste.append("arms ridx shift %s" % _v3(ArmsBuilder.right_index_shift))
	lines.append("copy: " + "; ".join(paste))
	return "\n".join(lines)


## `arms ridx ...`: show, set a joint, set the shift or reset, then rebuild; else the usage line.
func ridx_apply(args: Array, vm: Node) -> String:
	if args.size() == 1:
		return ridx_show()
	if not vm.has_method(&"rebuild_arms"):
		return "arms: no viewmodel"
	var n := args.size()
	if n == 2 and str(args[1]) == "reset":
		ArmsBuilder.right_index_aim = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
		ArmsBuilder.right_index_shift = Vector3.ZERO
		vm.call(&"rebuild_arms", int(vm.get("_arms_seed")))
		return "arms ridx reset"
	var shift := n == 5 and str(args[1]) == "shift"
	if n != 5 and not shift:
		return "bad args. " + hint("ridx")
	if not shift and not ["1", "2", "3"].has(str(args[1])):
		return "bad args. " + hint("ridx")
	if n != 5:
		return "bad args. " + hint("ridx")
	for i in range(2, 5):
		if not str(args[i]).is_valid_float():
			return "bad args. " + hint("ridx")
	var v := Vector3(float(str(args[2])), float(str(args[3])), float(str(args[4])))
	var out := ""
	if shift:
		ArmsBuilder.right_index_shift = v
		out = "arms ridx shift (%s)" % _v3(v)
	else:
		var aims: Array = ArmsBuilder.right_index_aim
		aims[int(str(args[1])) - 1] = v
		ArmsBuilder.right_index_aim = aims
		out = "arms ridx %s (%s)" % [str(args[1]), _v3(v)]
	vm.call(&"rebuild_arms", int(vm.get("_arms_seed")))
	return out


func _timer(t: float) -> String:
	return "off" if t < 0.0 else "%.2f" % t


func _v3(v: Vector3) -> String:
	return "%.2f %.2f %.2f" % [v.x, v.y, v.z]


func _vm() -> Node:
	return host.get_tree().get_first_node_in_group(&"gun_viewmodel")
