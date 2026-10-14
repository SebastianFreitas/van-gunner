extends RefCounted
## Debug flat grey: one grey material on every van-interior mesh, to judge shape without textures.

var _grey: StandardMaterial3D = null
var _black: StandardMaterial3D = null
var _tree: SceneTree = null
var _rig: Node3D = null
## Mesh -> its own material_override (null allowed), restored exactly on off.
var _saved: Dictionary = {}
var _rescan_frames := 0
## Key and fill lights (interior layer only) so wall, floor and ceiling faces read apart.
var _lights: Array[DirectionalLight3D] = []


func run(tree: SceneTree, args: Array) -> String:
	var action := ""
	if not args.is_empty():
		action = str(args[0]).to_lower()
	if action != "on" and action != "off":
		action = "off" if _tree != null else "on"
	if action == "off":
		return _off()
	if _tree == null:
		_tree = tree
		_tree.node_added.connect(_on_node_added)
	if _grey == null:
		_grey = StandardMaterial3D.new()
		_grey.albedo_color = Color(0.5, 0.5, 0.5)
		_grey.roughness = 0.9
		_grey.metallic = 0.0
		_black = StandardMaterial3D.new()
		_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_black.albedo_color = Color.BLACK
		# The side panes are one-sided facing the street: a culled back face shows the world.
		_black.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rig := tree.get_first_node_in_group(&"van_rig") as Node3D
	if rig == null:
		return "flatgrey armed: no van rig yet, it applies when the rig enters the tree"
	_apply_rig(rig)
	return "flatgrey on: van interior is flat grey, glass black"


func _off() -> String:
	if _tree == null:
		return "flatgrey off"
	if _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)
	if _tree.process_frame.is_connected(_on_frame):
		_tree.process_frame.disconnect(_on_frame)
	for key in _saved:
		if is_instance_valid(key):
			(key as MeshInstance3D).material_override = _saved[key] as Material
	_saved.clear()
	_free_lights()
	_tree = null
	_rig = null
	return "flatgrey off"


func _add_light(rig: Node3D, euler_deg: Vector3, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.name = &"FlatGreyLight"
	light.rotation_degrees = euler_deg
	light.light_energy = energy
	light.shadow_enabled = false
	light.light_cull_mask = 1 << (VanLighting.LAYER_VAN_INTERIOR - 1)
	rig.add_child(light)
	_lights.append(light)


func _free_lights() -> void:
	for light in _lights:
		if is_instance_valid(light):
			light.free()
	_lights.clear()


func _apply_rig(rig: Node3D) -> void:
	if rig != _rig:
		_free_lights()
		_add_light(rig, Vector3(-50.0, 150.0, 0.0), 0.9)
		_add_light(rig, Vector3(55.0, -40.0, 0.0), 0.35)
	_rig = rig
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		_paint(node as MeshInstance3D)
	# VanLighting moves meshes onto the interior layer a frame later: re-scan after it.
	_rescan_frames = 3
	if not _tree.process_frame.is_connected(_on_frame):
		_tree.process_frame.connect(_on_frame)


func _on_frame() -> void:
	_rescan_frames -= 1
	if _tree == null:
		return
	if _rescan_frames <= 0 and _tree.process_frame.is_connected(_on_frame):
		_tree.process_frame.disconnect(_on_frame)
	if is_instance_valid(_rig):
		for node in _rig.find_children("*", "MeshInstance3D", true, false):
			_paint(node as MeshInstance3D)


## Grey a mesh on the interior layer; glass panes go black (they ignore the layer test).
func _paint(mi: MeshInstance3D) -> void:
	var mat: Material = null
	if mi.name == &"WindowGlass" or mi.name == &"ExteriorPane":
		mat = _black
	elif mi.layers & (1 << (VanLighting.LAYER_VAN_INTERIOR - 1)) != 0:
		mat = _grey
	if mat == null:
		return
	if not _saved.has(mi):
		_saved[mi] = mi.material_override
	mi.material_override = mat


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		# Deferred: layers and the rig group may still be set after the node enters the tree.
		_catch_up.call_deferred(node)


func _catch_up(obj: Variant) -> void:
	# Variant: a mesh freed before the deferred call can't convert to a typed parameter.
	if _tree == null or not is_instance_valid(obj):
		return
	var mi := obj as MeshInstance3D
	if not mi.is_inside_tree():
		return
	var rig := _tree.get_first_node_in_group(&"van_rig") as Node3D
	if rig == null:
		return
	if rig != _rig:
		_apply_rig(rig)
	elif rig.is_ancestor_of(mi):
		_paint(mi)
