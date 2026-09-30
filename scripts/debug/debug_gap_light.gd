extends RefCounted
## Debug gap light: paints everything that is not van magenta, so a see-through seam shows pink.

var _magenta: StandardMaterial3D = null
var _black: StandardMaterial3D = null
## Window glass node -> its own material_override (null allowed), restored on off.
var _glass: Dictionary = {}


func run(rig: Node3D, args: Array) -> String:
	var root := rig.get_node_or_null(^"DebugGapLight") as Node3D
	if root == null:
		root = _build(rig)
		rig.add_child(root)
	var outside := root.get_node(^"Outside") as Node3D
	var inside := root.get_node(^"Inside") as Node3D
	var mask := root.get_node(^"FrontMask") as Node3D
	var action := ""
	if not args.is_empty():
		action = str(args[0]).to_lower()
	if action != "on" and action != "out" and action != "off":
		action = "off" if root.visible else "on"
	match action:
		"on":
			root.visible = true
			outside.visible = true
			mask.visible = true
			inside.visible = false
			_paint_glass(rig)
			return "gaplight on: everything that is not van is magenta, seen from the cabin"
		"out":
			root.visible = true
			inside.visible = true
			mask.visible = true
			outside.visible = false
			_paint_glass(rig)
			return "gaplight out: the cabin is magenta, seen from the street"
		_:
			root.visible = false
			for key in _glass:
				if is_instance_valid(key):
					(key as MeshInstance3D).material_override = _glass[key] as Material
			_glass.clear()
			return "gaplight off"


func _paint_glass(rig: Node3D) -> void:
	var parents: Array[Node] = [
		rig.get_node_or_null(^"Interior/Shell/SideWindows"),
		rig.get_node_or_null(^"Interior/Shell/RearWall"),
	]
	for parent in parents:
		if parent == null:
			continue
		for node in parent.find_children("WindowGlass", "MeshInstance3D", true, false):
			var glass := node as MeshInstance3D
			if not _glass.has(glass):
				_glass[glass] = glass.material_override
			glass.material_override = _black


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## A mesh on the street and interior layers; layers are set here, before any add_child.
func _new_mesh_instance(node_name: StringName, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	return mi


func _build(rig: Node3D) -> Node3D:
	_magenta = _make_material(Color(1, 0, 1))
	_black = _make_material(Color(0, 0, 0))
	var root := Node3D.new()
	root.name = &"DebugGapLight"
	root.visible = false
	root.add_child(_build_outside(rig))
	root.add_child(_build_inside(rig))
	root.add_child(_build_front_mask(rig))
	return root


func _build_outside(rig: Node3D) -> MeshInstance3D:
	var outside := _new_mesh_instance(&"Outside", null, _magenta)
	var box: AABB = _merged_mesh_aabb(
		[rig.get_node_or_null(^"Interior"), rig.get_node_or_null(^"VanLook")], rig)
	if box.size != Vector3.ZERO:
		var low := Vector3(box.position.x - 0.5, box.position.y + 0.05, box.position.z - 0.5)
		var high := Vector3(box.end.x + 0.5, box.end.y + 0.5, box.end.z + 0.5)
		var mesh := BoxMesh.new()
		mesh.size = high - low
		outside.mesh = mesh
		outside.position = (low + high) * 0.5
	return outside


func _build_inside(rig: Node3D) -> Node3D:
	var inside := Node3D.new()
	inside.name = &"Inside"
	var walls := rig.get_node_or_null(^"Interior/Shell/SideWalls") as VanSideWall
	var ceiling := rig.get_node_or_null(^"Interior/Shell/Ceiling") as VanCeiling
	if walls == null or ceiling == null:
		return inside
	var hinge := rig.get_node_or_null(^"Interior/Shell/RearWall/LeftHinge") as Node3D
	var zr := hinge.position.z - 0.08 if hinge != null else 4.63
	# Rear slab just in front of the rear wall, and the body from the front wall back to it.
	_add_slab_pair(inside, &"RearSlab", walls, ceiling, 0.0, 0.0, 0.0, zr - 0.12, zr - 0.10)
	_add_slab_pair(inside, &"Body", walls, ceiling, 0.01, 0.10, 0.06,
		VanFrontWall.FACE_Z + 0.01, zr - 0.12)
	return inside


func _add_slab_pair(parent: Node3D, base: StringName, walls: VanSideWall, ceiling: VanCeiling,
		y_min: float, x_inset: float, y_inset: float, z_from: float, z_to: float) -> void:
	var mesh: ArrayMesh = VanHullMesh.build_vaulted_xy_slab(
		walls, ceiling, 0.0, -1.0, y_min, z_to - z_from, Vector3.ZERO, x_inset, y_inset)
	var centre := (z_from + z_to) * 0.5
	var left := _new_mesh_instance(StringName(str(base) + "L"), mesh, _magenta)
	left.position.z = centre
	parent.add_child(left)
	var right := _new_mesh_instance(StringName(str(base) + "R"), mesh, _magenta)
	right.scale = Vector3(-1, 1, 1)
	right.position.z = centre
	parent.add_child(right)


func _build_front_mask(rig: Node3D) -> MeshInstance3D:
	var mask := _new_mesh_instance(&"FrontMask", null, _black)
	var box: AABB = _merged_mesh_aabb(
		[rig.get_node_or_null(^"Interior/FrontWall"), rig.get_node_or_null(^"Interior/CabDoor")],
		rig)
	if box.size != Vector3.ZERO:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(box.size.x, box.size.y, 0.02)
		mask.mesh = mesh
		mask.position = Vector3(
			box.position.x + box.size.x * 0.5, box.position.y + box.size.y * 0.5,
			box.position.z - 0.04)
	return mask


## Rig-local bounds of every mesh under the given nodes (null entries are skipped).
## A copy of the tools/ helper: game code never loads a tools/ script.
func _merged_mesh_aabb(nodes: Array[Node], rig: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in nodes:
		if node == null:
			continue
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			var to_rig := rig.global_transform.affine_inverse() * mesh.global_transform
			for i in 8:
				var point := to_rig * mesh.get_aabb().get_endpoint(i)
				if first:
					result = AABB(point, Vector3.ZERO)
					first = false
				else:
					result = result.expand(point)
	return result
