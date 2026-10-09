extends RefCounted
## Debug console `gun`: shows the railgun's attachment sockets as boxes and reports the gun.

const GIZMOS := "SocketGizmos"
const SUBS: PackedStringArray = ["sockets", "report", "attach"]
## sub -> [argument shape, note], read by `usage()` and `hint()`.
const INFO := {
	"sockets": ["<on|off>", "orange boxes and names at every attachment socket"],
	"report": ["", "mesh count, bounding box and the socket list"],
	"attach": ["<id|all|clear>", "boon visuals on the sockets (clear removes the previews)"],
}

var host: Node  # the DebugCommands autoload (tree access)


func _init(owner: Node) -> void:
	host = owner


## Header plus one hint line per subcommand.
func usage() -> String:
	var lines: Array[String] = ["gun <sub> [args]"]
	for sub in SUBS:
		lines.append(hint(sub))
	return "\n".join(lines)


## `gun <sub> <args>  - note`, or "" for an unknown sub.
func hint(sub: String) -> String:
	if not INFO.has(sub):
		return ""
	var info: Array = INFO[sub]
	return "gun %s %s  - %s" % [sub, info[0], info[1]]


func sub_commands() -> PackedStringArray:
	return SUBS


func cmd_gun(args: Array) -> String:
	if args.is_empty() or not SUBS.has(str(args[0])):
		return usage()
	var body := _body()
	if body == null:
		return "gun: no gun"
	match str(args[0]):
		"sockets":
			var on := args.size() < 2 or str(args[1]) != "off"
			return _sockets(body, on)
		"report":
			return _report(body)
	return _attach(body, str(args[1]) if args.size() > 1 else "")


func _body() -> Node3D:
	var vm := host.get_tree().get_first_node_in_group(&"gun_viewmodel")
	if vm == null:
		return null
	var roots: Dictionary = vm.get("_roots")
	var gun := roots.get("gun_root") as Node3D
	return gun.get_node_or_null(^"Body") as Node3D if gun != null else null


func _sockets(body: Node3D, on: bool) -> String:
	var old := body.get_node_or_null(GIZMOS)
	if old != null:
		body.remove_child(old)
		old.queue_free()
	if not on:
		return "gun sockets off"
	var root := Node3D.new()
	root.name = GIZMOS
	body.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 50
	mat.albedo_color = Color(1.0, 0.45, 0.05, 0.35)
	var sockets := GunSockets.all(body)
	var p := 0.22
	if body.get_parent() != null:
		p = HeldGun.palm_len_of(body.get_parent() as Node3D)
	for s in sockets:
		var size: Vector3 = s.get_meta(&"size")
		var box := ArmParts.mesh(root, "Box_" + String(s.name), ArmParts.box(size), mat,
				s.position)
		box.layers = VanLighting.LAYER_VAN_INTERIOR
		var label := Label3D.new()
		label.text = String(s.name).trim_prefix("Socket_")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.002
		label.font_size = 48
		label.outline_size = 12
		label.outline_modulate = Color(0.0, 0.0, 0.0)
		label.no_depth_test = true
		label.render_priority = 60
		label.outline_render_priority = 59
		label.modulate = Color(1.0, 0.8, 0.4)
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.layers = VanLighting.LAYER_VAN_INTERIOR
		var n: Vector3 = s.get_meta(&"normal")
		label.position = s.position + n * (absf(n.dot(size)) * 0.5 + 0.03 * p)
		root.add_child(label)
	return "gun sockets on: %d" % sockets.size()


func _report(body: Node3D) -> String:
	var p := 0.22
	var gun := body.get_parent()
	if gun != null:
		p = HeldGun.palm_len_of(gun as Node3D) * MonsterGrip.GUN_K
	var count := 0
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var boxes: Array[AABB] = []
	for c in body.get_children():
		if c is MeshInstance3D:
			count += 1
			var box := (c as MeshInstance3D).transform * (c as MeshInstance3D).get_aabb()
			boxes.append(box)
			lo = lo.min(box.position)
			hi = hi.max(box.end)
	var size := hi - lo
	var lines: Array[String] = ["gun: %d meshes" % count,
			"bbox size %s m, %s p" % [size.snappedf(0.001), (size / p).snappedf(0.01)]]
	for s in GunSockets.all(body):
		var sz: Vector3 = s.get_meta(&"size")
		var cell := AABB(s.position - sz * 0.5, sz)
		var hits := 0
		for b in boxes:
			if b.intersects(cell):
				hits += 1
		var n: Vector3 = s.get_meta(&"normal")
		var ax := n.abs().max_axis_index()
		var under := GunSockets.footprint_boxes(boxes, s.position, n)
		var buried := false
		for b in under:
			if s.position[ax] > b.position[ax] and s.position[ax] < b.end[ax]:
				buried = true
		var snap := (s.position - (s.get_meta(&"spec_pos") as Vector3)).length() / p
		lines.append("  %s zone %s used %s box-overlaps %d snap %.2f%s%s" % [s.name,
				GunSockets.zone(s), s.get_meta(&"used"), hits, snap,
				"" if not under.is_empty() else " no-mesh", " buried" if buried else ""])
	var att := body.get_node_or_null(^"Attachments")
	if att != null:
		for c in att.get_children():
			var lo2 := Vector3(INF, INF, INF)
			var hi2 := Vector3(-INF, -INF, -INF)
			for m in c.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				var bb := (c as Node3D).transform * (mi.transform * mi.get_aabb())
				lo2 = lo2.min(bb.position)
				hi2 = hi2.max(bb.end)
			lines.append("attach %s on %s aabb %s at %s" % [c.get_meta(&"boon_id", &""),
					c.get_meta(&"socket", &""), ((hi2 - lo2) / p).snappedf(0.01),
					(((lo2 + hi2) * 0.5) / p).snappedf(0.01)])
	return "\n".join(lines)


func _attach(body: Node3D, what: String) -> String:
	var att := body.get_node_or_null(^"Attachments") as GunAttachments
	if att == null:
		return "gun: no attachments"
	if what == "clear":
		att.clear_debug()
		return "gun attach: cleared"
	if what == "all":
		att.attach_all_debug()
		return "gun attach: all"
	if att.attach_debug(StringName(what)):
		return "gun attach: " + what
	return "gun attach <id|all|clear>, ids: " + ", ".join(GunBoonVisuals.ids())
