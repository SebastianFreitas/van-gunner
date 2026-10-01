extends Node3D
## Truck clearance and tail lamps on the cargo box: small emissive fixtures, each with a faint light that washes the body.

const INTERIOR_PATH := ^"../../Interior"

const LAMP_Y := 2.93
const SIDE_LAMP_Z: Array[float] = [-4.2, -2.1, 0.0, 2.1, 4.2]
const SIDE_WALLS_PATH := ^"../../Interior/Shell/SideWalls"

## How far the side door leaf slides open along z. Keep in step with `slide_distance` in
## side_doors.gd (neither script has a class_name to read it from).
const DOOR_SLIDE_M := 2.45
## Half length of the side door leaf. Keep in step with `DOOR_HALF_Z` in side_door_leaf.gd.
const DOOR_LEAF_HALF_Z := 1.105

const AMBER := Color(1.0, 0.55, 0.15)
const RED := Color(0.9, 0.08, 0.05)

const SIDE_LIGHT_ENERGY := 0.35
const SIDE_LIGHT_RANGE := 3.0
const TAIL_LIGHT_ENERGY := 0.55
const TAIL_LIGHT_RANGE := 3.2

## The amber ID row stands on the roof's rear rim: only about 4.5 cm of rear face is free above
## the rear doors' OuterLip/AstragalOuter (top about y 3.475), less than the housing is tall.
const ID_LAMP_X: Array[float] = [-0.35, 0.0, 0.35]

## ID lamp housing box size.
const ID_HOUSING_SIZE := Vector3(0.10, 0.07, 0.05)

## ID lamp lens box size.
const ID_LENS_SIZE := Vector3(0.07, 0.045, 0.02)

## How far the ID housing base is sunk into the roof.
const ID_LAMP_SINK_M := 0.02

## How far the ID housing's rear face stands proud of the roof's rear rim.
const ID_LAMP_OVERHANG_M := 0.02


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
	var sx := profile.inner_x_at(LAMP_Y) + VanHull.SIDE_SKIN_OUTER_M
	var walls := get_node_or_null(SIDE_WALLS_PATH) as VanSideWall
	for sign_idx in 2:
		var side := -1.0 if sign_idx == 0 else 1.0
		var side_letter := "L" if sign_idx == 0 else "R"
		for i in SIDE_LAMP_Z.size():
			var z := SIDE_LAMP_Z[i]
			if walls != null:
				var door_z0 := walls.door_center_z - walls.door_half_length
				var door_z1 := walls.door_center_z + DOOR_SLIDE_M + DOOR_LEAF_HALF_Z
				if z + 0.08 + 0.02 > door_z0 and z - 0.08 - 0.02 < door_z1:
					continue
			var housing_mesh := BoxMesh.new()
			housing_mesh.size = Vector3(0.05, 0.08, 0.16)
			_add_mesh("Clearance%s%d" % [side_letter, i], housing_mesh, housing_mat,
					Vector3(side * (sx + 0.025), LAMP_Y, z))

			var lens_mesh := BoxMesh.new()
			lens_mesh.size = Vector3(0.03, 0.05, 0.12)
			_add_mesh("Lens%s%d" % [side_letter, i], lens_mesh, lens_mat,
					Vector3(side * (sx + 0.05), LAMP_Y, z))

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
	var rim_z := VanHull.ROOF_Z_MAX
	var roof_w := profile.inner_x_at(profile.wall_height()) + VanHull.SIDE_SKIN_OUTER_M
	var max_x := 0.0
	for lamp_x in ID_LAMP_X:
		max_x = maxf(max_x, absf(lamp_x))
	var edge_x := max_x + ID_HOUSING_SIZE.x * 0.5
	var base_y := VanHull.roof_y_at(edge_x, roof_w, profile.wall_height()) - ID_LAMP_SINK_M
	var id_y := base_y + ID_HOUSING_SIZE.y * 0.5
	var id_z := rim_z + ID_LAMP_OVERHANG_M - ID_HOUSING_SIZE.z * 0.5

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
		housing_mesh.size = ID_HOUSING_SIZE
		_add_mesh("IdLamp%d" % i, housing_mesh, housing_mat, Vector3(x, id_y, id_z))

		var lens_mesh := BoxMesh.new()
		lens_mesh.size = ID_LENS_SIZE
		_add_mesh("IdLens%d" % i, lens_mesh, amber_lens_mat, Vector3(x, id_y, id_z + 0.035))


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
