class_name ViewmodelFov
extends RefCounted
## Sets the viewmodel FOV override on every arm shader and base material under a rig and turns
## shadow casting off. The rig gets its own material copies, so world props sharing the original
## resources are untouched.


## Applies `fov_deg` (0 = the camera's own) to rig-owned copies of every material under `root`.
static func apply(root: Node, fov_deg: float) -> void:
	if root == null:
		return
	var seen := {}
	_walk(root, fov_deg, seen)


static func _walk(node: Node, fov_deg: float, seen: Dictionary) -> void:
	var geo := node as GeometryInstance3D
	if geo != null:
		# The shadow pass skips the lens, so a lens-drawn mesh would cast from where it is not seen.
		geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Assign copies back into the slots; writing into the mesh would leak to shared users.
		if geo.material_override != null:
			geo.material_override = _own(geo.material_override, fov_deg, seen)
		if geo.material_overlay != null:
			geo.material_overlay = _own(geo.material_overlay, fov_deg, seen)
		var mi := geo as MeshInstance3D
		if mi != null and mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_surface_override_material(i)
				if mat == null:
					mat = mi.mesh.surface_get_material(i)
				if mat != null:
					mi.set_surface_override_material(i, _own(mat, fov_deg, seen))
	for child in node.get_children():
		_walk(child, fov_deg, seen)


## Returns the rig-owned copy of `mat` (made once, reused for shared slots and re-applies) with
## the FOV override set. Materials may be shared with van props, so the originals stay untouched.
static func _own(mat: Material, fov_deg: float, seen: Dictionary) -> Material:
	if mat == null:
		return null
	var copy: Material
	if mat.has_meta(&"viewmodel_fov_own"):
		copy = mat
	elif seen.has(mat):
		copy = seen[mat]
	else:
		copy = mat.duplicate() as Material
		copy.set_meta(&"viewmodel_fov_own", true)
		seen[mat] = copy
	# A copy already visited this pass is done; this also breaks next_pass cycles.
	if seen.has(copy):
		return copy
	seen[copy] = copy
	if copy.next_pass != null:
		copy.next_pass = _own(copy.next_pass, fov_deg, seen)
	var sm := copy as ShaderMaterial
	if sm != null:
		sm.set_shader_parameter(&"viewmodel_fov", fov_deg)
	var bm := copy as BaseMaterial3D
	if bm != null:
		bm.use_fov_override = fov_deg > 0.0
		if fov_deg > 0.0:
			bm.fov_override = fov_deg
	return copy
