extends Node
## Headless dump of an instantiated scene's nodes, properties, resources and connections for diffing.

const _SKIP_PROPS: Array[StringName] = [
	&"script", &"scene_file_path", &"owner", &"resource_path", &"resource_scene_unique_id",
]
const _MAX_LEAF := 160

## Instance id -> sharing index, assigned in first-encounter order so a shared
## resource prints once with its contents and every later reference as `#k`.
var _res_ids: Dictionary = {}
## The instantiated scene root, used to render every NODEREF and CONN target
## as a path relative to it.
var _inst: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not SaveSandbox.enabled:
		push_error("scene dump: save sandbox is off")
		get_tree().quit(1)
		return
	var idx := args.find("--smoke-sandbox")
	var scene_path := args[idx + 1]
	var out_path := args[idx + 2]

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("scene dump: failed to load %s" % scene_path)
		get_tree().quit(1)
		return

	_inst = packed.instantiate()
	var lines: PackedStringArray = []
	var stack: Array[Node] = [_inst]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		_dump_node(_inst, node, lines)
		var children := node.get_children()
		for i in range(children.size() - 1, -1, -1):
			stack.push_back(children[i])

	var out := ProjectSettings.globalize_path(out_path)
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	_inst.free()
	get_tree().quit(0)


func _dump_node(root: Node, node: Node, lines: PackedStringArray) -> void:
	var header := "NODE %s %s" % [str(root.get_path_to(node)), node.get_class()]
	var script: Script = node.get_script()
	if script != null:
		header += " script=%s" % script.resource_path
	lines.append(header)

	var groups: Array[String] = []
	for g in node.get_groups():
		var gname := String(g)
		if gname.begins_with("_"):
			continue
		groups.append(gname)
	if not groups.is_empty():
		groups.sort()
		lines.append("  groups=%s" % ", ".join(groups))

	for prop in node.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var prop_name: String = prop["name"]
		if _SKIP_PROPS.has(prop_name):
			continue
		lines.append("  %s=%s" % [prop_name, _fmt_value(node.get(prop_name))])

	var conn_lines: PackedStringArray = []
	for sig_info in node.get_signal_list():
		var sig_name: String = sig_info["name"]
		for conn in node.get_signal_connection_list(sig_name):
			var flags: int = conn["flags"]
			if flags & CONNECT_PERSIST == 0:
				continue
			var callable: Callable = conn["callable"]
			var target_obj: Object = callable.get_object()
			var target_str: String
			if target_obj is Node and (target_obj == root or root.is_ancestor_of(target_obj)):
				target_str = str(root.get_path_to(target_obj))
			else:
				target_str = "<external>"
			var method := String(callable.get_method())
			conn_lines.append(
				"  CONN %s -> %s::%s flags=%d" % [sig_name, target_str, method, flags]
			)
	conn_lines.sort()
	for conn_line in conn_lines:
		lines.append(conn_line)


func _fmt_value(value: Variant) -> String:
	if value is Resource:
		return _fmt_resource(value)
	if value is Node:
		return "NODEREF %s" % str(_inst.get_path_to(value))
	if value is Object:
		return "<%s>" % value.get_class()
	if value is Array:
		var parts: PackedStringArray = []
		for element in value:
			parts.append(_fmt_value(element))
		return "[" + ", ".join(parts) + "]"
	if value is Dictionary:
		var parts: PackedStringArray = []
		for key in value.keys():
			parts.append("%s: %s" % [_fmt_value(key), _fmt_value(value[key])])
		return "{" + ", ".join(parts) + "}"
	var text := var_to_str(value)
	if text.length() > _MAX_LEAF:
		return "<%s len=%d md5=%s>" % [type_string(typeof(value)), text.length(), text.md5_text()]
	return text


func _fmt_resource(res: Resource) -> String:
	if res == null:
		return "null"
	var cls := res.get_class()
	if res.resource_path != "" and not res.resource_path.contains("::"):
		var ext := res.resource_path.get_extension()
		if ext != "tres" and ext != "res":
			return "%s(%s)" % [cls, res.resource_path]

	var id := res.get_instance_id()
	if _res_ids.has(id):
		return "%s#%d" % [cls, _res_ids[id]]
	var k: int = _res_ids.size()
	_res_ids[id] = k

	var parts: PackedStringArray = []
	for prop in res.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var prop_name: String = prop["name"]
		if _SKIP_PROPS.has(prop_name):
			continue
		parts.append("%s=%s" % [prop_name, _fmt_value(res.get(prop_name))])
	return "%s#%d{%s}" % [cls, k, ", ".join(parts)]
