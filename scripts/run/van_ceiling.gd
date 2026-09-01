class_name VanCeiling
extends Node3D

## Barrel-vault interior ceiling with exposed wooden vigas (Southwestern-style beams).

@export var span_x := 4.72
@export var span_z := 9.4
@export var edge_height := 3.02
@export var peak_rise := 0.38
@export var x_segments := 20
@export var z_segments := 40
@export var viga_spacing := 1.35
@export var viga_radius := 0.105
@export var viga_length := 4.76
@export var ceiling_material: Material
@export var viga_material: Material
@export var rebuild_on_ready := true

var _built := false


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_build()


func _build() -> void:
	if _built:
		return
	_built = true

	var ceiling_mat := ceiling_material if ceiling_material else _default_ceiling_material()
	var viga_mat := viga_material if viga_material else _default_viga_material()

	var vault := MeshInstance3D.new()
	vault.name = "Vault"
	vault.mesh = _build_vault_mesh()
	vault.material_override = ceiling_mat
	vault.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(vault)

	_build_vigas(viga_mat)


func _build_vault_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_x := span_x * 0.5
	var half_z := span_z * 0.5
	var verts: Array = []

	for iz in range(z_segments + 1):
		var row: Array = []
		var z := lerpf(-half_z, half_z, float(iz) / float(z_segments))
		for ix in range(x_segments + 1):
			var x := lerpf(-half_x, half_x, float(ix) / float(x_segments))
			var t := absf(x) / half_x
			var y := edge_height + peak_rise * (1.0 - t * t)
			row.append(Vector3(x, y, z))
		verts.append(row)

	for iz in range(z_segments):
		for ix in range(x_segments):
			var v00: Vector3 = verts[iz][ix]
			var v10: Vector3 = verts[iz][ix + 1]
			var v01: Vector3 = verts[iz + 1][ix]
			var v11: Vector3 = verts[iz + 1][ix + 1]
			# Winding faces the room interior (normals point downward).
			st.add_vertex(v00)
			st.add_vertex(v01)
			st.add_vertex(v10)
			st.add_vertex(v10)
			st.add_vertex(v01)
			st.add_vertex(v11)

	st.generate_normals()
	return st.commit()


func _build_vigas(material: Material) -> void:
	var half_z := span_z * 0.5
	var margin := viga_spacing * 0.45
	var z := -half_z + margin
	var index := 0

	while z <= half_z - margin * 0.5:
		_add_viga(index, z, material)
		z += viga_spacing
		index += 1


func _add_viga(index: int, z_pos: float, material: Material) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = viga_radius * 0.92
	cyl.bottom_radius = viga_radius
	cyl.height = viga_length
	cyl.radial_segments = 10

	var t := absf(z_pos) / (span_z * 0.5)
	var arch_y := edge_height + peak_rise * (1.0 - t * t * 0.35)
	var center_y := arch_y - viga_radius * 0.35

	var mi := MeshInstance3D.new()
	mi.name = "Viga_%d" % index
	mi.mesh = cyl
	mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	mi.position = Vector3(0.0, center_y, z_pos)
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _default_ceiling_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.30, 0.27, 1.0)
	mat.roughness = 0.88
	return mat


func _default_viga_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.13, 0.085, 1.0)
	mat.roughness = 0.85
	return mat
