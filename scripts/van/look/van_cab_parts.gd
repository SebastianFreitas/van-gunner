extends RefCounted

## Cab interior and mirrors, split out of van_cab.gd to keep it under the line cap.

var cab: VanCab


func _init(owner_cab: VanCab) -> void:
	cab = owner_cab


func build_interior() -> void:
	var seat_mat := VanCab._dark_material(Color(0.05, 0.045, 0.04), 0.9)
	var dash_mat := VanCab._dark_material(Color(0.035, 0.035, 0.035), 0.9)

	for s: float in [-1.0, 1.0]:
		var suffix := "Driver" if s < 0.0 else "Passenger"
		var base := cab._add_mesh("Seat%sBase" % suffix, cab._box(Vector3(0.8, 0.3, 0.7)), seat_mat,
				Vector3(s * 1.0, 0.55, -5.1))
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var back := cab._add_mesh("Seat%sBack" % suffix, cab._box(Vector3(0.8, 1.0, 0.15)), seat_mat,
				Vector3(s * 1.0, 1.15, -4.85))
		back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var dash := cab._add_mesh("Dash", cab._box(Vector3(4.4, 0.35, 0.6)), dash_mat,
			Vector3(0.0, VanCab.HOOD_Y - 0.05, VanCab.CAB_FRONT_Z + 0.45))
	dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.17
	wheel_mesh.outer_radius = 0.21
	var wheel := cab._add_mesh("SteeringWheel", wheel_mesh, dash_mat,
			Vector3(-1.0, VanCab.HOOD_Y + 0.2, VanCab.CAB_FRONT_Z + 0.75),
			Vector3(deg_to_rad(-55.0), 0.0, 0.0))
	wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 0.03
	column_mesh.bottom_radius = 0.03
	column_mesh.height = 0.5
	var column := cab._add_mesh("SteeringColumn", column_mesh, dash_mat,
			Vector3(-1.0, VanCab.HOOD_Y + 0.05, VanCab.CAB_FRONT_Z + 0.55),
			Vector3(deg_to_rad(-35.0), 0.0, 0.0))
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func build_mirrors(mat: Material, rng: RandomNumberGenerator) -> void:
	for s: float in [-1.0, 1.0]:
		var suffix := "L" if s < 0.0 else "R"
		cab._add_mesh("MirrorArm%s" % suffix, cab._box(Vector3(0.35, 0.04, 0.04)), mat,
				Vector3(s * (VanCab.CAB_HALF_W + 0.17), 1.95, -5.9))
		var tilt := deg_to_rad(s * rng.randf_range(-8.0, 8.0))
		cab._add_mesh("Mirror%s" % suffix, cab._box(Vector3(0.08, 0.35, 0.22)), mat,
				Vector3(s * (VanCab.CAB_HALF_W + 0.36), 1.95, -5.9), Vector3(0.0, tilt, 0.0))
