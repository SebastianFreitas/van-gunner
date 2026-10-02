class_name ViewmodelFov
extends RefCounted
## Sets the viewmodel FOV override on every arm shader and base material under a rig.


## Applies `fov_deg` (0 = the camera's own) to every material under `root`.
static func apply(root: Node, fov_deg: float) -> void:
	if root == null:
		return
	var seen := {}
	_walk(root, fov_deg, seen)


static func _walk(node: Node, fov_deg: float, seen: Dictionary) -> void:
	var geo := node as GeometryInstance3D
	if geo != null:
		_material(geo.material_override, fov_deg, seen)
		_material(geo.material_overlay, fov_deg, seen)
		var mi := geo as MeshInstance3D
		if mi != null and mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				_material(mi.get_surface_override_material(i), fov_deg, seen)
				_material(mi.mesh.surface_get_material(i), fov_deg, seen)
	for child in node.get_children():
		_walk(child, fov_deg, seen)


static func _material(mat: Material, fov_deg: float, seen: Dictionary) -> void:
	while mat != null and not seen.has(mat):
		seen[mat] = true
		var sm := mat as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter(&"viewmodel_fov", fov_deg)
		var bm := mat as BaseMaterial3D
		if bm != null:
			bm.use_fov_override = fov_deg > 0.0
			if fov_deg > 0.0:
				bm.fov_override = fov_deg
		mat = mat.next_pass
