class_name VanFloorMid
extends RefCounted
## Ribs, wall lips and the step-well nosing on the raised mid slab, on the rear sheet's recipe.

const HOST_TOP := 0.30
const Z0 := -4.60
const Z1 := 0.94
## Ribs whose far end reaches into the doorway's TreadHigh.
const DOORWAY_Z1 := 1.00
const WELL_Z0 := -4.42
const WELL_Z1 := -1.91
const NOSING_Y0 := 0.28
const NOSING_Y1 := 0.335


## Adds MidRibs, MidLipLeft, MidLipRight and Nosing as unscaled children of `floor_node`.
static func add(floor_node: Node3D) -> void:
	var rib_mat := VanFloorSkin.material(VanFloorSkin.TINT_A, 1.0, 0.5)
	var lip_mat := VanFloorSkin.material(VanFloorSkin.TINT_A, 2.0, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for k in 13:
			var x: float = side * (0.125 + 0.25 * k)
			var z1 := Z1
			if side < 0.0 and k >= 8:
				z1 = DOORWAY_Z1
			elif side < 0.0 and k == 7:
				z1 = 0.90
			# D43: the right side door's gap breaks the outer rib like the left well strip.
			if (side < 0.0 and k >= 10) or (side > 0.0 and k == 12):
				_add_rib_clear(st, x, Z0, WELL_Z0)
				_add_rib_clear(st, x, WELL_Z1, z1)
			else:
				_add_rib_clear(st, x, Z0, z1)
	st.generate_tangents()
	_add(floor_node, &"MidRibs", st.commit(), rib_mat)

	var right := _join([VanFloorSheet.build_lip(1.0, Z0, -4.46, HOST_TOP),
			VanFloorSheet.build_lip(1.0, -1.87, Z1, HOST_TOP)])
	_add(floor_node, &"MidLipRight", right, lip_mat)
	var left := _join([VanFloorSheet.build_lip(-1.0, Z0, -4.46, HOST_TOP),
			VanFloorSheet.build_lip(-1.0, -1.87, Z1, HOST_TOP)])
	_add(floor_node, &"MidLipLeft", left, lip_mat)

	var nosing := _join([
		VanFloorSlab.build_box(Vector3(-2.48, NOSING_Y0, -4.37), Vector3(-2.42, NOSING_Y1, -1.96), &"edge"),
		VanFloorSlab.build_box(Vector3(-3.36, NOSING_Y0, -4.44), Vector3(-2.42, NOSING_Y1, -4.38), &"edge"),
		VanFloorSlab.build_box(Vector3(-3.36, NOSING_Y0, -1.95), Vector3(-2.42, NOSING_Y1, -1.89), &"edge")])
	_add(floor_node, &"Nosing", nosing, lip_mat)


## A rib along z from `za` to `zb`, split so it ends inside the M1/M2 patches it meets.
static func _add_rib_clear(st: SurfaceTool, x: float, za: float, zb: float) -> void:
	var z := za
	for iv in VanFloorPlates.mid_rib_blocked(x):
		if iv.y <= za or iv.x >= zb:
			continue
		if iv.x - z >= 0.05:
			VanFloorSheet.add_rib(st, Vector2(x, z), Vector2(x, iv.x), HOST_TOP)
		z = maxf(z, iv.y)
	if zb - z >= 0.05:
		VanFloorSheet.add_rib(st, Vector2(x, z), Vector2(x, zb), HOST_TOP)


## One mesh holding every surface of `meshes`.
static func _join(meshes: Array[ArrayMesh]) -> ArrayMesh:
	var out := ArrayMesh.new()
	for m in meshes:
		for s in m.get_surface_count():
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(s))
	return out


static func _add(parent: Node3D, node_name: StringName, mesh: ArrayMesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
