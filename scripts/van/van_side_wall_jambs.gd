extends RefCounted
## Door jambs for VanSideWall: the frame ring's lip inside each side door bay, without the outer return the wall's reveal owns.

## The jamb's front inner return reaches this far past the normal inset so it sits buried in the
## front wall slab (face at z -4.55) instead of 0.5 cm in front of it. Never narrow the inner
## poly elsewhere: that made the jamb hit the door leaves' edges.
const JAMB_FRONT_OUT := 0.017

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
	# Outer lip face sits 2.4 cm inside the wall's outer plane so it never z-fights the wall.
	var mesh := _wall.build_curved_frame_ring_mesh(
		wall_sign, _outer_poly(), inner,
		x_ref, mid_y, _wall.door_center_z, mid_y, _wall.thickness - 0.024, 0.0, 8
	)
	var hy := (_wall.door_y_max - _wall.door_y_min) * 0.5
	var stripped := _strip_outer_return(mesh, _wall.door_half_length, hy)
	var overlap := _front_overlap()
	if overlap > 0.001:
		stripped = _clip_front_strip(
			stripped, wall_sign, -_wall.door_half_length + overlap
		)
	# The rear's cabin face stops on the hole's grid line, edge to edge with the panel face.
	stripped = _clip_front_strip(
		stripped, wall_sign, -(_wall.door_half_length + _rear_overlap()), -1.0
	)
	mi.mesh = stripped
	# Mesh is built around local origin — parent must sit on the wall (same as SideDoors leaves).
	mi.position = Vector3(wall_sign * x_ref, mid_y, _wall.door_center_z)
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_wall.add_child(mi)


## The rear edge reaches 5 cm past the wall hole's grid line: the hole snaps past the bay's rear
## edge, and that slot was open to the street behind the reveal.
func _outer_poly() -> PackedVector2Array:
	var hz := _wall.door_half_length
	var hz_rear := hz + _rear_overlap() + 0.05
	var hy := (_wall.door_y_max - _wall.door_y_min) * 0.5
	return PackedVector2Array([
		Vector2(-hz, -hy), Vector2(hz_rear, -hy), Vector2(hz_rear, hy), Vector2(-hz, hy),
	])


func _inner_poly() -> PackedVector2Array:
	var hz := _wall.door_half_length - _wall.door_jamb_inset
	var hy := (_wall.door_y_max - _wall.door_y_min) * 0.5 - _wall.door_jamb_inset
	if hz <= 0.05 or hy <= 0.05:
		return PackedVector2Array()
	var hz_front := hz + JAMB_FRONT_OUT
	return PackedVector2Array([
		Vector2(-hz_front, -hy), Vector2(hz, -hy), Vector2(hz, hy), Vector2(-hz_front, hy),
	])


## Length of the jamb's cabin face that overlaps the wall panel's face at the bay's front edge:
## the wall's grid cell boundary past the edge, same lerp as VanSideWallPanel.build_side_mesh.
func _front_overlap() -> float:
	var half_z := _wall.span_z * 0.5
	var edge := _wall.door_center_z - _wall.door_half_length
	var segs := float(_wall.z_segments)
	var iz := ceilf((edge + half_z - _wall.center_z) / _wall.span_z * segs - 1e-4)
	return lerpf(_wall.center_z - half_z, _wall.center_z + half_z, iz / segs) - edge


## How far the wall hole's grid line lies past the bay's rear edge (cells whose centre is in the
## bay are punched, same rule as VanSideWallPanel.is_door_bay_open).
func _rear_overlap() -> float:
	var half_z := _wall.span_z * 0.5
	var edge := _wall.door_center_z + _wall.door_half_length
	var segs := float(_wall.z_segments)
	var iz := floorf((edge + half_z - _wall.center_z) / _wall.span_z * segs + 0.5)
	return lerpf(_wall.center_z - half_z, _wall.center_z + half_z, iz / segs) - edge


## Clips the cabin-face triangles (normal toward the cabin) to local z >= min_z (dir 1) or
## z <= -min_z (dir -1), so the jamb's cabin face meets the wall panel's cabin face edge to edge
## instead of lying over it.
static func _clip_front_strip(mesh: ArrayMesh, wall_sign: float, min_z: float,
		dir: float = 1.0) -> ArrayMesh:
	if mesh.get_surface_count() == 0:
		return mesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tans: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var src := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		src = arrays[Mesh.ARRAY_INDEX]
	if src.is_empty():
		src.resize(verts.size())
		for i in range(verts.size()):
			src[i] = i
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_t := PackedFloat32Array()
	for t in range(0, src.size() - 2, 3):
		# Each corner is [position, normal, uv, tangent(4)] so a clip can interpolate them all.
		var poly: Array = []
		for j in range(3):
			var k := src[t + j]
			poly.append([verts[k], norms[k], uvs[k],
				Vector4(tans[k * 4], tans[k * 4 + 1], tans[k * 4 + 2], tans[k * 4 + 3])])
		var cabin_face: bool = (poly[0][1] as Vector3).x * -wall_sign > 0.9
		if cabin_face:
			poly = _clip_poly(poly, min_z, dir)
		for i in range(1, poly.size() - 1):
			for c in [poly[0], poly[i], poly[i + 1]]:
				out_v.append(c[0])
				out_n.append(c[1])
				out_uv.append(c[2])
				var tg: Vector4 = c[3]
				out_t.append_array([tg.x, tg.y, tg.z, tg.w])
	arrays[Mesh.ARRAY_VERTEX] = out_v
	arrays[Mesh.ARRAY_NORMAL] = out_n
	arrays[Mesh.ARRAY_TEX_UV] = out_uv
	arrays[Mesh.ARRAY_TANGENT] = out_t
	arrays[Mesh.ARRAY_INDEX] = null
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mesh.surface_get_material(0) != null:
		out.surface_set_material(0, mesh.surface_get_material(0))
	return out


## Sutherland-Hodgman against the plane dir * z = min_z, keeping dir * z >= min_z (winding
## preserved).
static func _clip_poly(poly: Array, min_z: float, dir: float = 1.0) -> Array:
	var res: Array = []
	for i in range(poly.size()):
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var za: float = dir * (a[0] as Vector3).z - min_z
		var zb: float = dir * (b[0] as Vector3).z - min_z
		if za >= 0.0:
			res.append(a)
		if (za >= 0.0) != (zb >= 0.0):
			var f := za / (za - zb)
			res.append([
				(a[0] as Vector3).lerp(b[0], f), (a[1] as Vector3).lerp(b[1], f).normalized(),
				(a[2] as Vector2).lerp(b[2], f), (a[3] as Vector4).lerp(b[3], f),
			])
	return res


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
