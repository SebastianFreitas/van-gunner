extends RefCounted
## Collects every visible triangle under a rig into parallel arrays, all in rig-local
## space, for the van audit's checks (specs 1-2 and 1-3 add more consumers).

var a: PackedVector3Array
var b: PackedVector3Array
var c: PackedVector3Array
var n: PackedVector3Array
var tri_lo: PackedVector3Array  # per-triangle AABB corners
var tri_hi: PackedVector3Array
var owner_idx: PackedInt32Array

var nodes: Array[Node3D] = []
var paths: PackedStringArray
var double_sided: PackedByteArray
var layers: PackedInt32Array


func collect(rig: Node3D) -> void:
	_visit(rig, rig)


func path_of(tri: int) -> String:
	return paths[owner_idx[tri]]


func count() -> int:
	return a.size()


func tri_aabb(tri: int) -> AABB:
	var lo: Vector3 = a[tri].min(b[tri]).min(c[tri])
	var hi: Vector3 = a[tri].max(b[tri]).max(c[tri])
	return AABB(lo, hi - lo)


## Vector3i cell -> PackedInt32Array of triangle indices for every cell each triangle's
## AABB touches.
func build_grid(cell: float) -> Dictionary:
	var grid: Dictionary = {}
	for t in range(count()):
		var box := tri_aabb(t)
		var lo := Vector3i((box.position / cell).floor())
		var hi := Vector3i(((box.position + box.size) / cell).floor())
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var key := Vector3i(x, y, z)
					var list: PackedInt32Array = grid.get(key, PackedInt32Array())
					list.append(t)
					grid[key] = list
	return grid


func _visit(node: Node, rig: Node3D) -> void:
	if node.name == "GunPort" or node.is_in_group(&"player"):
		return
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		_add_mesh_instance(node, rig)
	elif node is CSGShape3D and node.is_root_shape() and node.is_visible_in_tree():
		_add_csg_shape(node, rig)
	for child in node.get_children():
		_visit(child, rig)


func _add_mesh_instance(node: MeshInstance3D, rig: Node3D) -> void:
	var idx: int = _register(node, rig)
	var xform: Transform3D = rig.global_transform.affine_inverse() * node.global_transform
	var sided: int = 0
	for i in range(node.mesh.get_surface_count()):
		var mat: Material = node.get_active_material(i)
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED:
			sided = 1
	double_sided[idx] = sided
	_add_surfaces(node.mesh, xform, idx)


func _add_csg_shape(node: CSGShape3D, rig: Node3D) -> void:
	var idx: int = _register(node, rig)
	var pair: Array = node.get_meshes()
	if pair.is_empty():
		return
	var local_xform: Transform3D = pair[0]
	var mesh: Mesh = pair[1]
	var xform: Transform3D = rig.global_transform.affine_inverse() * node.global_transform * local_xform
	var sided: int = 0
	for i in range(mesh.get_surface_count()):
		var mat: Material = mesh.surface_get_material(i)
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED:
			sided = 1
	double_sided[idx] = sided
	_add_surfaces(mesh, xform, idx)


func _register(node: Node3D, rig: Node3D) -> int:
	var idx: int = nodes.size()
	nodes.append(node)
	paths.append(String(rig.get_path_to(node)))
	double_sided.append(0)
	layers.append(node.layers)
	return idx


func _add_surfaces(mesh: Mesh, xform: Transform3D, idx: int) -> void:
	for i in range(mesh.get_surface_count()):
		# PrimitiveMesh resources (BoxMesh, CylinderMesh, ...) don't expose this method
		# and are always triangles, so treat a missing method as PRIMITIVE_TRIANGLES.
		if mesh.has_method(&"surface_get_primitive_type") \
				and mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = mesh.surface_get_arrays(i)
		if arrays.is_empty():
			push_error("AUDIT: mesh arrays unavailable headless: %s" % paths[idx])
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index_arr: Variant = arrays[Mesh.ARRAY_INDEX]
		if index_arr != null and (index_arr as PackedInt32Array).size() > 0:
			var ia: PackedInt32Array = index_arr
			for t in range(0, ia.size() - 2, 3):
				_add_tri(xform * verts[ia[t]], xform * verts[ia[t + 1]], xform * verts[ia[t + 2]], idx)
		else:
			for t in range(0, verts.size() - 2, 3):
				_add_tri(xform * verts[t], xform * verts[t + 1], xform * verts[t + 2], idx)


func _add_tri(pa: Vector3, pb: Vector3, pc: Vector3, idx: int) -> void:
	var normal: Vector3 = (pc - pa).cross(pb - pa)
	if normal.length() * 0.5 < 1e-8:
		return
	a.append(pa)
	b.append(pb)
	c.append(pc)
	n.append(normal.normalized())
	tri_lo.append(pa.min(pb).min(pc))
	tri_hi.append(pa.max(pb).max(pc))
	owner_idx.append(idx)
