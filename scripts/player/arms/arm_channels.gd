class_name ArmChannels
extends RefCounted
## Checks the baked hand parts still carry the shader's CUSTOM0-2 channels after the glb import and warns for each surface that lost one; it changes nothing: positions, normals, indices, weights and UVs are never touched.


## Warns for every surface of `mi` missing one of CUSTOM0 (vein mask chart), CUSTOM1 (rest position
## + hand weight) or CUSTOM2 (rest normal). Returns whether all are present.
static func ensure(mi: MeshInstance3D) -> bool:
	var mesh := mi.mesh as ArrayMesh
	var ok := true
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		for c in 3:
			if arrays[Mesh.ARRAY_CUSTOM0 + c] == null:
				push_warning("ArmChannels: %s surface %d lost CUSTOM%d" % [mi.name, s, c])
				ok = false
	return ok
