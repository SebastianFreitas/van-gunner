extends RefCounted

## The dark cab behind the windshield (dash, dash glow, seats, driver silhouette) and the mirrors.

var cab: VanCab


func _init(owner_cab: VanCab) -> void:
	cab = owner_cab


func build_interior() -> void:
	var seat_mat := VanCab._dark_material(Color(0.05, 0.045, 0.04), 0.9)
	var dash_mat := VanCab._dark_material(Color(0.035, 0.035, 0.035), 0.9)
	var driver_mat := VanCab._dark_material(Color(0.02, 0.02, 0.022), 0.9)
	var face_z := VanCab.NOSE_Z

	var dash := cab._add_mesh("Dash", cab._box(Vector3(4.2, 0.5, 0.6)), dash_mat,
			Vector3(0.0, 1.55, face_z + 0.4))
	dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var gauge_mat := StandardMaterial3D.new()
	gauge_mat.albedo_color = Color(0.05, 0.06, 0.04)
	gauge_mat.roughness = 0.8
	gauge_mat.metallic = 0.0
	gauge_mat.emission_enabled = true
	gauge_mat.emission = Color(0.55, 0.75, 0.35)
	gauge_mat.emission_energy_multiplier = 0.6
	var gauges := cab._add_mesh("DashGauges", cab._box(Vector3(0.6, 0.12, 0.02)), gauge_mat,
			Vector3(-1.0, 1.72, face_z + 0.71))
	gauges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	## Faint dash glow behind the windshield, well under the bloom threshold.
	var glow := OmniLight3D.new()
	glow.name = "DashGlow"
	glow.position = Vector3(-0.6, 1.95, face_z + 0.95)
	glow.light_energy = 0.25
	glow.omni_range = 1.8
	glow.light_color = Color(0.6, 0.8, 0.45)
	glow.shadow_enabled = false
	glow.light_cull_mask = 1
	cab.add_child(glow)

	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.17
	wheel_mesh.outer_radius = 0.21
	var wheel := cab._add_mesh("SteeringWheel", wheel_mesh, dash_mat,
			Vector3(-1.0, 2.0, face_z + 0.9), Vector3(deg_to_rad(-55.0), 0.0, 0.0))
	wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 0.03
	column_mesh.bottom_radius = 0.03
	column_mesh.height = 0.5
	var column := cab._add_mesh("SteeringColumn", column_mesh, dash_mat,
			Vector3(-1.0, 1.85, face_z + 0.7), Vector3(deg_to_rad(-35.0), 0.0, 0.0))
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for s: float in [-1.0, 1.0]:
		var suffix := "Driver" if s < 0.0 else "Passenger"
		var base := cab._add_mesh("Seat%sBase" % suffix, cab._box(Vector3(0.8, 0.3, 0.7)), seat_mat,
				Vector3(s * 1.0, 1.35, face_z + 1.75))
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var back := cab._add_mesh("Seat%sBack" % suffix, cab._box(Vector3(0.8, 1.1, 0.15)), seat_mat,
				Vector3(s * 1.0, 2.05, face_z + 2.15))
		back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var headrest := cab._add_mesh("Seat%sHeadrest" % suffix, cab._box(Vector3(0.4, 0.25, 0.12)),
				seat_mat, Vector3(s * 1.0, 2.75, face_z + 2.15))
		headrest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var torso := cab._add_mesh("DriverTorso", cab._box(Vector3(0.55, 0.75, 0.3)), driver_mat,
			Vector3(-1.0, 1.9, face_z + 1.95))
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head := cab._add_mesh("DriverHead", cab._box(Vector3(0.26, 0.3, 0.28)), driver_mat,
			Vector3(-1.0, 2.5, face_z + 1.95))
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for arm_s: float in [-1.0, 1.0]:
		var arm_suffix := "L" if arm_s < 0.0 else "R"
		var shoulder := Vector3(-1.0 + arm_s * 0.25, 2.15, face_z + 1.85)
		var hand := Vector3(-1.0 + arm_s * 0.18, 2.0, face_z + 0.9)
		var arm_length := (hand - shoulder).length()
		var arm_mid := (shoulder + hand) * 0.5
		var arm := cab._add_mesh("DriverArm%s" % arm_suffix, cab._box(Vector3(0.1, 0.1, arm_length)),
				driver_mat, arm_mid)
		arm.basis = Basis.looking_at(hand - shoulder, Vector3.UP)
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func build_mirrors(mat: Material, rng: RandomNumberGenerator) -> void:
	var face_z := VanCab.NOSE_Z
	for s: float in [-1.0, 1.0]:
		var suffix := "L" if s < 0.0 else "R"
		var outer_x := cab.profile.outer_x_at(2.4)
		cab._add_mesh("MirrorArm%s" % suffix, cab._box(Vector3(0.45, 0.04, 0.04)), mat,
				Vector3(s * (outer_x + 0.2), 2.4, face_z + 0.3))
		var tilt := deg_to_rad(s * rng.randf_range(-8.0, 8.0))
		cab._add_mesh("Mirror%s" % suffix, cab._box(Vector3(0.08, 0.4, 0.24)), mat,
				Vector3(s * (outer_x + 0.45), 2.4, face_z + 0.3), Vector3(0.0, tilt, 0.0))
