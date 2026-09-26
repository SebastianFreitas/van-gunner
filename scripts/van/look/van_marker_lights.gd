extends Node3D
## Truck clearance and tail lamps on the cargo box: small emissive fixtures, each with a faint light that washes the body.

const INTERIOR_PATH := ^"../../Interior"

const LAMP_Y := 2.93
const SIDE_LAMP_Z: Array[float] = [-4.2, -2.1, 0.0, 2.1, 4.2]
const SKIN_OUT := 0.06 ## hull skin offset outward from the inner liner

const AMBER := Color(1.0, 0.55, 0.15)
const RED := Color(0.9, 0.08, 0.05)

const SIDE_LIGHT_ENERGY := 0.35
const SIDE_LIGHT_RANGE := 3.0
const TAIL_LIGHT_ENERGY := 0.45
const TAIL_LIGHT_RANGE := 2.6

const ID_LAMP_X: Array[float] = [-0.35, 0.0, 0.35]


func rebuild_look(_look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var profile := VanBodyProfile.from_interior(get_node_or_null(INTERIOR_PATH))
	if profile == null:
		return

	var amber_lens := StandardMaterial3D.new()
	amber_lens.albedo_color = AMBER * 0.6
	amber_lens.emission_enabled = true
	amber_lens.emission = AMBER
	amber_lens.emission_energy_multiplier = 1.6

	var red_lens := StandardMaterial3D.new()
	red_lens.albedo_color = RED * 0.6
	red_lens.emission_enabled = true
	red_lens.emission = RED
	red_lens.emission_energy_multiplier = 1.3

	var housing_mat := StandardMaterial3D.new()
	housing_mat.albedo_color = Color(0.06, 0.06, 0.06)
	housing_mat.roughness = 0.8

	_build_side_lamps(profile, amber_lens, housing_mat)
	_build_rear_lamps(profile, red_lens, amber_lens, housing_mat)


func _build_side_lamps(profile: VanBodyProfile, lens_mat: Material, housing_mat: Material) -> void:
	var sx := profile.inner_x_at(LAMP_Y) + SKIN_OUT
	for sign_idx in 2:
		var side := -1.0 if sign_idx == 0 else 1.0
		var side_letter := "L" if sign_idx == 0 else "R"
		for i in SIDE_LAMP_Z.size():
			var z := SIDE_LAMP_Z[i]
			var housing_mesh := BoxMesh.new()
			housing_mesh.size = Vector3(0.05, 0.08, 0.16)
			_add_mesh("Clearance%s%d" % [side_letter, i], housing_mesh, housing_mat,
					Vector3(side * (sx + 0.025), LAMP_Y, z))

			var lens_mesh := BoxMesh.new()
			lens_mesh.size = Vector3(0.02, 0.05, 0.12)
			_add_mesh("Lens%s%d" % [side_letter, i], lens_mesh, lens_mat,
					Vector3(side * (sx + 0.06), LAMP_Y, z))

		var glow := OmniLight3D.new()
		glow.name = "ClearanceGlow%s" % side_letter
		glow.position = Vector3(side * (sx + 0.12), LAMP_Y, 0.0)
		glow.light_color = AMBER
		glow.light_energy = SIDE_LIGHT_ENERGY
		glow.omni_range = SIDE_LIGHT_RANGE
		glow.shadow_enabled = false
		glow.light_cull_mask = 1
		add_child(glow)


func _build_rear_lamps(profile: VanBodyProfile, red_lens_mat: Material, amber_lens_mat: Material,
		housing_mat: Material) -> void:
	var rear := profile.half_length() + 0.08
	var id_y := profile.wall_height() + 0.14

	for side_idx in 2:
		var side := -1.0 if side_idx == 0 else 1.0
		var side_letter := "L" if side_idx == 0 else "R"
		var x := side * 2.15

		var housing_mesh := BoxMesh.new()
		housing_mesh.size = Vector3(0.22, 0.30, 0.05)
		_add_mesh("Tail%s" % side_letter, housing_mesh, housing_mat, Vector3(x, 0.75, rear + 0.025))

		var lens_mesh := BoxMesh.new()
		lens_mesh.size = Vector3(0.18, 0.26, 0.02)
		_add_mesh("TailLens%s" % side_letter, lens_mesh, red_lens_mat, Vector3(x, 0.75, rear + 0.06))

		var glow := OmniLight3D.new()
		glow.name = "TailGlow%s" % side_letter
		glow.position = Vector3(x, 0.75, rear + 0.15)
		glow.light_color = RED
		glow.light_energy = TAIL_LIGHT_ENERGY
		glow.omni_range = TAIL_LIGHT_RANGE
		glow.shadow_enabled = false
		glow.light_cull_mask = 1
		add_child(glow)

	for i in ID_LAMP_X.size():
		var x := ID_LAMP_X[i]
		var housing_mesh := BoxMesh.new()
		housing_mesh.size = Vector3(0.10, 0.07, 0.05)
		_add_mesh("IdLamp%d" % i, housing_mesh, housing_mat, Vector3(x, id_y, rear + 0.025))

		var lens_mesh := BoxMesh.new()
		lens_mesh.size = Vector3(0.07, 0.045, 0.02)
		_add_mesh("IdLens%d" % i, lens_mesh, amber_lens_mat, Vector3(x, id_y, rear + 0.06))


func _add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
