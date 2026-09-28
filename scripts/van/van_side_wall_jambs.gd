extends RefCounted
## Door jambs for VanSideWall: the frame ring's lip inside each side door bay, without the outer return the wall's reveal owns.

var _wall: VanSideWall


func _init(wall: VanSideWall) -> void:
	_wall = wall


func add_door_jambs(wall_sign: float, mat: Material) -> void:
	var inner := _inner_poly()
	if inner.size() < 3:
		return
	var mid_y := (_wall.door_y_min + _wall.door_y_max) * 0.5
	var x_ref := _wall.wall_x_at(mid_y)
	var mi := MeshInstance3D.new()
	mi.name = "DoorJamb_%s" % ("L" if wall_sign < 0.0 else "R")
	var mesh := _wall.build_curved_frame_ring_mesh(
		wall_sign, _outer_poly(), inner,
		x_ref, mid_y, _wall.door_center_z, mid_y, _wall.thickness, 0.0, 8
	)
	var hy := (_wall.door_y_max - _wall.door_y_min) * 0.5
	mi.mesh = _strip_outer_return(mesh, _wall.door_half_length, hy)
	# Mesh is built around local origin — parent must sit on the wall (same as SideDoors leaves).
	mi.position = Vector3(wall_sign * x_ref, mid_y, _wall.door_center_z)
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_wall.add_child(mi)


func _outer_poly() -> PackedVector2Array:
	var hz := _wall.door_half_length
	var hy := (_wall.door_y_max - _wall.door_y_min) * 0.5
	return PackedVector2Array([
		Vector2(-hz, -hy), Vector2(hz, -hy), Vector2(hz, hy), Vector2(-hz, hy),
	])


func _inner_poly() -> PackedVector2Array:
	var hz := _wall.door_half_length - _wall.door_jamb_inset
	var hy := (_wall.door_y_max - _wall.door_y_min) * 0.5 - _wall.door_jamb_inset
	if hz <= 0.05 or hy <= 0.05:
		return PackedVector2Array()
	return PackedVector2Array([
		Vector2(-hz, -hy), Vector2(hz, -hy), Vector2(hz, hy), Vector2(-hz, hy),
	])


## Drops the triangles lying on the outer rect (the outer return): the wall's reveal and the
## hull skin's return cover that cut, so a second surface there z-fights them.
static func _strip_outer_return(mesh: ArrayMesh, hz: float, hy: float) -> ArrayMesh:
	if mesh.get_surface_count() == 0:
		return mesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		src = arrays[Mesh.ARRAY_INDEX]
	if src.is_empty():
		src.resize(verts.size())
		for i in range(verts.size()):
			src[i] = i
	var kept := PackedInt32Array()
	for t in range(0, src.size() - 2, 3):
		var on_rim := true
		for j in range(3):
			var v: Vector3 = verts[src[t + j]]
			if absf(absf(v.z) - hz) >= 1e-3 and absf(absf(v.y) - hy) >= 1e-3:
				on_rim = false
				break
		if not on_rim:
			kept.append(src[t])
			kept.append(src[t + 1])
			kept.append(src[t + 2])
	arrays[Mesh.ARRAY_INDEX] = kept
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mesh.surface_get_material(0) != null:
		out.surface_set_material(0, mesh.surface_get_material(0))
	return out
