class_name VanCeiling
extends Node3D

## Barrel-vault interior ceiling with exposed wooden vigas, headliner, and cargo dressing.

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
	_build_cross_braces()
	_build_wiring()
	_build_vent_duct()
	_build_ceiling_lights()
	_build_tie_down_rings()
	_build_duct_tape_patches()
	_build_junction_box()
	_build_hanging_scraps()


func _build_vault_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_x := span_x * 0.5
	var half_z := span_z * 0.5
	var verts: Array = []
	var uvs: Array = []

	for iz in range(z_segments + 1):
		var row: Array = []
		var uv_row: Array = []
		var z := lerpf(-half_z, half_z, float(iz) / float(z_segments))
		var v := float(iz) / float(z_segments)
		for ix in range(x_segments + 1):
			var x := lerpf(-half_x, half_x, float(ix) / float(x_segments))
			var t := absf(x) / half_x
			var y := edge_height + peak_rise * (1.0 - t * t)
			var u := float(ix) / float(x_segments)
			row.append(Vector3(x, y, z))
			uv_row.append(Vector2(u, v))
		verts.append(row)
		uvs.append(uv_row)

	for iz in range(z_segments):
		for ix in range(x_segments):
			var v00: Vector3 = verts[iz][ix]
			var v10: Vector3 = verts[iz][ix + 1]
			var v01: Vector3 = verts[iz + 1][ix]
			var v11: Vector3 = verts[iz + 1][ix + 1]
			var uv00: Vector2 = uvs[iz][ix]
			var uv10: Vector2 = uvs[iz][ix + 1]
			var uv01: Vector2 = uvs[iz + 1][ix]
			var uv11: Vector2 = uvs[iz + 1][ix + 1]
			# Winding faces the room interior (normals point downward).
			st.set_uv(uv00)
			st.add_vertex(v00)
			st.set_uv(uv01)
			st.add_vertex(v01)
			st.set_uv(uv10)
			st.add_vertex(v10)
			st.set_uv(uv10)
			st.add_vertex(v10)
			st.set_uv(uv01)
			st.add_vertex(v01)
			st.set_uv(uv11)
			st.add_vertex(v11)

	st.generate_normals()
	st.generate_tangents()
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
	# Slight per-beam variation so the run doesn't look stamped.
	var radius_jitter := 1.0 + float((index % 3) - 1) * 0.04
	var tip_scale := 0.9 + float(index % 2) * 0.04
	var cyl := CylinderMesh.new()
	cyl.top_radius = viga_radius * tip_scale * radius_jitter
	cyl.bottom_radius = viga_radius * radius_jitter
	cyl.height = viga_length
	cyl.radial_segments = 12

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

	var band_mat := _metal_mat(Color(0.16, 0.15, 0.13, 1.0), 0.7, 0.48)
	var half_len := viga_length * 0.5
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var band_x: float = side * (half_len - 0.18)
		var band := CylinderMesh.new()
		band.top_radius = viga_radius * radius_jitter + 0.012
		band.bottom_radius = viga_radius * radius_jitter + 0.012
		band.height = 0.035
		band.radial_segments = 10
		var side_label := "L" if side < 0.0 else "R"
		var band_mi := MeshInstance3D.new()
		band_mi.name = "VigaBand_%d_%s" % [index, side_label]
		band_mi.mesh = band
		band_mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		band_mi.position = Vector3(band_x, center_y, z_pos)
		band_mi.material_override = band_mat
		band_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(band_mi)

		# Short wall corbel under each beam end.
		_add_box(
			"VigaCorbel_%d_%s" % [index, side_label],
			Vector3(0.12, 0.08, 0.14),
			Vector3(side * (half_len - 0.05), center_y - viga_radius * 0.55, z_pos),
			material
		)


func _build_cross_braces() -> void:
	var metal := _metal_mat(Color(0.14, 0.145, 0.14, 1.0), 0.65, 0.55)
	var half_z := span_z * 0.5
	var margin := viga_spacing * 0.45
	var z_positions: Array[float] = []
	var z := -half_z + margin
	while z <= half_z - margin * 0.5:
		z_positions.append(z)
		z += viga_spacing

	for i in range(z_positions.size() - 1):
		var z_mid := (z_positions[i] + z_positions[i + 1]) * 0.5
		var t := absf(z_mid) / (span_z * 0.5)
		var arch_y := edge_height + peak_rise * (1.0 - t * t * 0.35) - viga_radius * 0.55
		# Flat metal strap bridging adjacent vigas.
		_add_box(
			"CrossBrace_%d" % i,
			Vector3(viga_length * 0.88, 0.025, 0.06),
			Vector3(0.0, arch_y, z_mid),
			metal
		)


func _build_wiring() -> void:
	var wire_mat := _metal_mat(Color(0.06, 0.055, 0.05, 1.0), 0.15, 0.72)
	var cable_mat := _rubber_mat(Color(0.04, 0.038, 0.035, 1.0), 0.0, 0.96, 0.0)

	# Main power run along the left side, clipped to ceiling.
	_add_cylinder_run(
		"PowerRun",
		Vector3(-1.65, edge_height - 0.18, 0.0),
		span_z * 0.82,
		0.012,
		cable_mat,
		Vector3(90.0, 0.0, 0.0)
	)
	# Secondary cable draped slightly between two bay sections.
	_add_cylinder_run(
		"CableDrape",
		Vector3(1.35, edge_height - 0.28, 1.8),
		2.4,
		0.009,
		cable_mat,
		Vector3(82.0, 12.0, 0.0)
	)
	# Thin grounding strap.
	_add_cylinder_run(
		"GroundStrap",
		Vector3(-1.85, edge_height - 0.12, -2.5),
		1.6,
		0.006,
		wire_mat,
		Vector3(88.0, -25.0, 0.0)
	)
	# Cable clips (small boxes along the power run).
	var clip_mat := _metal_mat(Color(0.18, 0.17, 0.16, 1.0), 0.55, 0.48)
	for i in range(5):
		var cz := lerpf(-3.6, 3.2, float(i) / 4.0)
		var ct := absf(cz) / (span_z * 0.5)
		var cy := edge_height - 0.18 + peak_rise * (1.0 - ct * ct * 0.2) * 0.08
		_add_box(
			"CableClip_%d" % i,
			Vector3(0.035, 0.02, 0.04),
			Vector3(-1.65, cy, cz),
			clip_mat
		)


func _build_vent_duct() -> void:
	var duct_mat := _metal_mat(Color(0.28, 0.29, 0.285, 1.0), 0.3, 0.68)
	# Slim HVAC duct tucked along the left ceiling edge ΓÇö avoids blocking center sightlines.
	var duct_z := 2.4
	var duct_x := -1.35
	var duct_y := _vault_surface_y(duct_z, duct_x) - 0.05
	_add_box(
		"VentDuct",
		Vector3(0.14, 0.07, span_z * 0.32),
		Vector3(duct_x, duct_y, duct_z),
		duct_mat
	)
	# Vent grille at the rear end.
	var grille_mat := _metal_mat(Color(0.22, 0.225, 0.22, 1.0), 0.45, 0.58)
	var grille_z := duct_z + span_z * 0.16
	var grille_y := _vault_surface_y(grille_z, duct_x) - 0.05
	_add_box(
		"VentGrille",
		Vector3(0.16, 0.06, 0.018),
		Vector3(duct_x, grille_y, grille_z),
		grille_mat
	)
	# Duct hangers.
	var hanger_mat := _metal_mat(Color(0.16, 0.165, 0.16, 1.0), 0.55, 0.52)
	for i in range(3):
		var hz := lerpf(duct_z - 1.2, grille_z, float(i) / 2.0)
		var hy := _vault_surface_y(hz, duct_x) + 0.02
		_add_box(
			"DuctHanger_%d" % i,
			Vector3(0.025, 0.045, 0.025),
			Vector3(duct_x + 0.08, hy, hz),
			hanger_mat
		)


func _build_ceiling_lights() -> void:
	var fixture_mat := _metal_mat(Color(0.2, 0.19, 0.18, 1.0), 0.4, 0.55)
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.95, 0.88, 0.72, 1.0)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(1.0, 0.86, 0.62, 1.0)
	lens_mat.emission_energy_multiplier = 0.7
	lens_mat.roughness = 0.3

	var light_positions: Array[Vector3] = [
		Vector3(-0.55, 0.0, -2.8),
		Vector3(0.55, 0.0, 0.5),
		Vector3(-0.55, 0.0, 3.2),
	]

	for i in range(light_positions.size()):
		var lp: Vector3 = light_positions[i]
		var lt := absf(lp.z) / (span_z * 0.5)
		var ly := edge_height + peak_rise * (1.0 - lt * lt * 0.35) - viga_radius * 0.85

		# Dome fixture housing.
		var housing := MeshInstance3D.new()
		housing.name = "LightHousing_%d" % i
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.11
		cyl.bottom_radius = 0.13
		cyl.height = 0.06
		cyl.radial_segments = 12
		housing.mesh = cyl
		housing.material_override = fixture_mat
		housing.position = Vector3(lp.x, ly, lp.z)
		housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(housing)

		# Lens plate.
		var lens := MeshInstance3D.new()
		lens.name = "LightLens_%d" % i
		var disc := CylinderMesh.new()
		disc.top_radius = 0.095
		disc.bottom_radius = 0.095
		disc.height = 0.012
		disc.radial_segments = 12
		lens.mesh = disc
		lens.material_override = lens_mat
		lens.position = Vector3(lp.x, ly - 0.035, lp.z)
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lens)

		# Pendant cord from nearest viga.
		var cord_mat := _rubber_mat(Color(0.03, 0.028, 0.025, 1.0), 0.0, 0.98, 0.0)
		_add_cylinder_run(
			"LightCord_%d" % i,
			Vector3(lp.x, ly + 0.08, lp.z),
			0.16,
			0.004,
			cord_mat,
			Vector3(0.0, 0.0, 0.0)
		)


func _build_tie_down_rings() -> void:
	var ring_mat := _metal_mat(Color(0.15, 0.14, 0.13, 1.0), 0.7, 0.45)
	var ring_positions: Array[Vector3] = [
		Vector3(-1.55, 0.0, -3.2),
		Vector3(1.55, 0.0, -3.2),
		Vector3(-1.55, 0.0, 3.5),
		Vector3(1.55, 0.0, 3.5),
		Vector3(-1.55, 0.0, 0.0),
		Vector3(1.55, 0.0, 0.0),
	]

	for i in range(ring_positions.size()):
		var rp: Vector3 = ring_positions[i]
		var rt := absf(rp.z) / (span_z * 0.5)
		var ry := edge_height + peak_rise * (1.0 - rt * rt * 0.25) - 0.22

		var ring := MeshInstance3D.new()
		ring.name = "TieDownRing_%d" % i
		var torus := TorusMesh.new()
		torus.inner_radius = 0.028
		torus.outer_radius = 0.048
		torus.rings = 6
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = ring_mat
		ring.position = Vector3(rp.x, ry, rp.z)
		ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(ring)

		# Backing plate.
		_add_box(
			"RingPlate_%d" % i,
			Vector3(0.06, 0.06, 0.012),
			Vector3(rp.x, ry + 0.008, rp.z),
			ring_mat
		)


## Barrel height at lateral position x (ignores Z sag — for end doors / bulkheads).
func vault_y_at(x: float) -> float:
	var half_x := maxf(span_x * 0.5, 0.05)
	var t := clampf(absf(x) / half_x, 0.0, 1.0)
	return edge_height + peak_rise * (1.0 - t * t)


func _vault_surface_y(z_pos: float, x_pos: float = 0.0) -> float:
	var half_x := span_x * 0.5
	var t_x := absf(x_pos) / half_x
	var t_z := absf(z_pos) / (span_z * 0.5)
	return edge_height + peak_rise * (1.0 - t_x * t_x) * (1.0 - t_z * t_z * 0.15)


func _build_duct_tape_patches() -> void:
	var tape_mat := StandardMaterial3D.new()
	tape_mat.albedo_color = Color(0.52, 0.46, 0.3, 1.0)
	tape_mat.roughness = 0.55
	tape_mat.metallic = 0.05
	tape_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var patches := [
		{"size": Vector2(0.32, 0.18), "x": -0.8, "z": 2.1, "rot": 14.0},
		{"size": Vector2(0.22, 0.14), "x": 1.1, "z": -1.4, "rot": -22.0},
		{"size": Vector2(0.45, 0.12), "x": 0.3, "z": -3.0, "rot": 5.0},
	]

	for i in range(patches.size()):
		var p: Dictionary = patches[i]
		var px: float = p["x"]
		var pz: float = p["z"]
		var py := _vault_surface_y(pz, px) - 0.02
		_add_ceiling_patch(
			"TapePatch_%d" % i,
			p["size"],
			Vector3(px, py, pz),
			p["rot"],
			tape_mat
		)


func _build_junction_box() -> void:
	var box_mat := _metal_mat(Color(0.14, 0.13, 0.12, 1.0), 0.25, 0.68)
	var jy := edge_height - 0.15
	_add_box("JunctionBox", Vector3(0.14, 0.1, 0.08), Vector3(-1.75, jy, -3.6), box_mat)
	# Conduit stub leaving the box.
	var conduit_mat := _metal_mat(Color(0.18, 0.17, 0.16, 1.0), 0.55, 0.52)
	_add_cylinder_run(
		"JunctionConduit",
		Vector3(-1.75, jy, -3.45),
		0.35,
		0.018,
		conduit_mat,
		Vector3(90.0, 0.0, 0.0)
	)


func _build_hanging_scraps() -> void:
	# Soft scraps / tags you'd actually see clipped to a cargo ceiling.
	var rag_mat := StandardMaterial3D.new()
	rag_mat.albedo_color = Color(0.26, 0.2, 0.15, 1.0)
	rag_mat.roughness = 0.98
	rag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var tag_mat := StandardMaterial3D.new()
	tag_mat.albedo_color = Color(0.72, 0.62, 0.28, 1.0)
	tag_mat.roughness = 0.85

	var chain_mat := _metal_mat(Color(0.18, 0.17, 0.15, 1.0), 0.75, 0.42)

	var hang_z := 1.15
	var hang_x := 1.05
	var hang_y := _vault_surface_y(hang_z, hang_x) - 0.35

	_add_cylinder_run(
		"HangChain",
		Vector3(hang_x, hang_y + 0.12, hang_z),
		0.28,
		0.005,
		chain_mat,
		Vector3(0.0, 0.0, 8.0)
	)

	# Vertical hanging rag (plane facing camera / along van).
	var rag := MeshInstance3D.new()
	rag.name = "HangRag"
	var rag_mesh := PlaneMesh.new()
	rag_mesh.size = Vector2(0.22, 0.3)
	rag_mesh.orientation = PlaneMesh.FACE_Z
	rag.mesh = rag_mesh
	rag.material_override = rag_mat
	rag.position = Vector3(hang_x + 0.02, hang_y - 0.05, hang_z)
	rag.rotation_degrees = Vector3(8.0, 18.0, 6.0)
	rag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rag)

	_add_ceiling_patch(
		"InspectTag",
		Vector2(0.08, 0.12),
		Vector3(-1.2, _vault_surface_y(-2.1, -1.2) - 0.18, -2.1),
		-12.0,
		tag_mat
	)


func _add_ceiling_patch(
	node_name: String,
	size: Vector2,
	pos: Vector3,
	yaw_deg: float,
	material: Material
) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.orientation = PlaneMesh.FACE_Y

	if material is BaseMaterial3D:
		(material as BaseMaterial3D).render_priority = 1

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = -0.01
	add_child(mi)


func _add_box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = box
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _add_cylinder_run(
	node_name: String,
	pos: Vector3,
	length: float,
	radius: float,
	material: Material,
	rot_deg: Vector3
) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = cyl
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _default_ceiling_material() -> ShaderMaterial:
	var shader := load("res://scenes/van/van_ceiling.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", Color(0.32, 0.30, 0.27, 1.0))
	mat.set_shader_parameter("seam_color", Color(0.14, 0.13, 0.115, 1.0))
	mat.set_shader_parameter("foam_color", Color(0.38, 0.36, 0.32, 1.0))
	mat.set_shader_parameter("stain_color", Color(0.22, 0.18, 0.12, 1.0))
	mat.set_shader_parameter("water_color", Color(0.28, 0.26, 0.22, 1.0))
	mat.set_shader_parameter("tape_color", Color(0.48, 0.42, 0.28, 1.0))
	mat.set_shader_parameter("ceiling_size_m", Vector2(span_x, span_z))
	mat.set_shader_parameter("bay_spacing_m", viga_spacing)
	mat.set_shader_parameter("quilt_scale_m", 0.14)
	mat.set_shader_parameter("roughness_value", 0.92)
	mat.set_shader_parameter("metallic_value", 0.0)
	return mat


func _default_viga_material() -> ShaderMaterial:
	var shader := load("res://scenes/van/van_viga.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", Color(0.18, 0.13, 0.085, 1.0))
	mat.set_shader_parameter("grain_dark", Color(0.11, 0.08, 0.055, 1.0))
	mat.set_shader_parameter("grain_light", Color(0.28, 0.2, 0.13, 1.0))
	mat.set_shader_parameter("wear_color", Color(0.32, 0.24, 0.16, 1.0))
	mat.set_shader_parameter("beam_length_m", viga_length)
	mat.set_shader_parameter("roughness_value", 0.82)
	mat.set_shader_parameter("metallic_value", 0.0)
	return mat


func _metal_mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _rubber_mat(color: Color, metallic: float, roughness: float, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color.lightened(0.15)
		mat.emission_energy_multiplier = emission
	return mat
