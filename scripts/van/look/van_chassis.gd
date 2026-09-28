extends RefCounted
## Builds the van's chassis kit around the wheels: arch flares and wells, side steps, saddle tank,
## toolbox, short exhaust, chained spares, rear rails and bumper.

## Outer face of the sill/skin.
const SKIN_X := 2.56
const FLARE_GAP := 0.08
const FLARE_OUT := 0.06
const LIP_H := 0.07
const ARC_SEGMENTS := 10

var _wheels: VanWheels


func _init(wheels: VanWheels) -> void:
	_wheels = wheels


func build(hull_mat: Material, rubber: Material, rear_axles: Array[float], exhaust_side: float,
		spare_mask: int) -> void:
	var dark := VanCab._dark_material(Color(0.03, 0.03, 0.03), 0.9)

	for side: float in [-1.0, 1.0]:
		var label := "L" if side < 0.0 else "R"
		var idx := 0
		var front_centre := Vector3(side * VanWheels.WHEEL_X,
				VanWheels.ROAD_Y + VanWheels.FRONT_RADIUS, VanWheels.FRONT_AXLE_Z)
		_build_flare("Flare%s%d" % [label, idx], front_centre, VanWheels.FRONT_RADIUS, hull_mat)
		_build_well("Well%s%d" % [label, idx], front_centre, VanWheels.FRONT_RADIUS, dark)
		idx += 1
		for z: float in rear_axles:
			var rear_centre := Vector3(side * VanWheels.WHEEL_X, VanWheels.ROAD_Y + VanWheels.REAR_RADIUS, z)
			_build_flare("Flare%s%d" % [label, idx], rear_centre, VanWheels.REAR_RADIUS, hull_mat)
			_build_well("Well%s%d" % [label, idx], rear_centre, VanWheels.REAR_RADIUS, dark)
			idx += 1
		_build_steps(side, label, hull_mat)

	_build_tank(-exhaust_side, hull_mat)
	_build_toolbox(exhaust_side, hull_mat)
	_build_exhaust(exhaust_side, hull_mat)

	if spare_mask & 1:
		_build_spare(-1.0, "L", rubber, hull_mat)
	if spare_mask & 2:
		_build_spare(1.0, "R", rubber, hull_mat)

	_build_rear_bumper(hull_mat)


func _build_flare(flare_name: String, centre: Vector3, radius: float, mat: Material) -> void:
	var side := signf(centre.x)
	var r := radius + FLARE_GAP
	var x_in := side * (SKIN_X + 0.01)
	var x_out := side * (VanWheels.WHEEL_X + VanWheels.TYRE_WIDTH * 0.5 + FLARE_OUT)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(ARC_SEGMENTS):
		var a0: float = PI * i / ARC_SEGMENTS
		var a1: float = PI * (i + 1) / ARC_SEGMENTS
		var p_in0 := Vector3(x_in, centre.y + r * sin(a0), centre.z + r * cos(a0))
		var p_out0 := Vector3(x_out, centre.y + r * sin(a0), centre.z + r * cos(a0))
		var p_out1 := Vector3(x_out, centre.y + r * sin(a1), centre.z + r * cos(a1))
		var p_in1 := Vector3(x_in, centre.y + r * sin(a1), centre.z + r * cos(a1))
		VanCab._add_quad(st, p_in0, p_out0, p_out1, p_in1, centre)
		VanCab._add_quad(st, p_in0, p_out0, p_out1, p_in1, centre, true)

		var lip_a := Vector3(x_out, centre.y + r * sin(a0), centre.z + r * cos(a0))
		var lip_b := Vector3(x_out, centre.y + r * sin(a1), centre.z + r * cos(a1))
		var lip_c := Vector3(x_out, centre.y + (r - LIP_H) * sin(a1), centre.z + (r - LIP_H) * cos(a1))
		var lip_d := Vector3(x_out, centre.y + (r - LIP_H) * sin(a0), centre.z + (r - LIP_H) * cos(a0))
		var lip_centre := Vector3(side * 1.0, centre.y, centre.z)
		VanCab._add_quad(st, lip_a, lip_b, lip_c, lip_d, lip_centre)
		VanCab._add_quad(st, lip_a, lip_b, lip_c, lip_d, lip_centre, true)
	st.generate_normals()
	_wheels._add_mesh(flare_name, st.commit(), mat, Vector3.ZERO)


func _build_well(well_name: String, centre: Vector3, radius: float, mat: Material) -> void:
	var side := signf(centre.x)
	var r := radius + FLARE_GAP
	var x := side * (SKIN_X + 0.005)
	var hub := Vector3(x, centre.y, centre.z)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(ARC_SEGMENTS):
		var a0: float = PI * i / ARC_SEGMENTS
		var a1: float = PI * (i + 1) / ARC_SEGMENTS
		var p0 := Vector3(x, centre.y + r * sin(a0), centre.z + r * cos(a0))
		var p1 := Vector3(x, centre.y + r * sin(a1), centre.z + r * cos(a1))
		VanCab._add_tri(st, hub, p0, p1, Vector3(0.0, centre.y, centre.z))

	var left := Vector3(x, VanWheels.ROAD_Y, centre.z - r)
	var right := Vector3(x, VanWheels.ROAD_Y, centre.z + r)
	var top_left := Vector3(x, centre.y, centre.z - r)
	var top_right := Vector3(x, centre.y, centre.z + r)
	VanCab._add_tri(st, top_left, left, right, Vector3(0.0, centre.y, centre.z))
	VanCab._add_tri(st, top_left, right, top_right, Vector3(0.0, centre.y, centre.z))
	st.generate_normals()
	var mi := _wheels._add_mesh(well_name, st.commit(), mat, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_steps(side: float, label: String, mat: Material) -> void:
	_wheels._add_mesh("SideStep%s" % label, _wheels._box(Vector3(0.30, 0.05, 2.2)), mat,
			Vector3(side * (SKIN_X + 0.15), -0.06, -3.485))
	for i: int in range(2):
		var offset: float = 0.95 if i == 0 else -0.95
		_wheels._add_mesh("SideStepHanger%s%d" % [label, i], _wheels._box(Vector3(0.18, 0.12, 0.06)), mat,
				Vector3(side * (SKIN_X + 0.09), -0.04, -3.485 + offset))

	# Centred 3 cm further out than the hangers so its inner face clears the cab skin's bowed side.
	_wheels._add_mesh("CabStep%s" % label, _wheels._box(Vector3(0.28, 0.05, 1.2)), mat,
			Vector3(side * (SKIN_X + 0.17), 0.02, -5.7))
	for i: int in range(2):
		var offset: float = 0.5 if i == 0 else -0.5
		_wheels._add_mesh("CabStepHanger%s%d" % [label, i], _wheels._box(Vector3(0.18, 0.12, 0.06)), mat,
				Vector3(side * (SKIN_X + 0.14), 0.04, -5.7 + offset))


func _build_tank(side: float, mat: Material) -> void:
	var tank_mesh := CylinderMesh.new()
	tank_mesh.top_radius = 0.25
	tank_mesh.bottom_radius = 0.25
	tank_mesh.height = 1.5
	tank_mesh.radial_segments = 16
	var tank := _wheels._add_mesh("FuelTank", tank_mesh, mat, Vector3(side * (SKIN_X + 0.27), 0.12, 0.1))
	tank.rotation_degrees.x = 90.0

	for i: int in range(2):
		var offset: float = 0.5 if i == 0 else -0.5
		var strap_mesh := CylinderMesh.new()
		strap_mesh.top_radius = 0.265
		strap_mesh.bottom_radius = 0.265
		strap_mesh.height = 0.05
		var strap := _wheels._add_mesh("TankStrap%d" % i, strap_mesh, mat,
				Vector3(side * (SKIN_X + 0.27), 0.12, 0.1 + offset))
		strap.rotation_degrees.x = 90.0

	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.06
	cap_mesh.bottom_radius = 0.06
	cap_mesh.height = 0.06
	_wheels._add_mesh("TankCap", cap_mesh, mat, Vector3(side * (SKIN_X + 0.27), 0.40, 0.55))

	for i: int in range(2):
		var offset: float = 0.5 if i == 0 else -0.5
		_wheels._add_mesh("TankBracket%d" % i, _wheels._box(Vector3(0.3, 0.06, 0.08)), mat,
				Vector3(side * (SKIN_X + 0.15), -0.1, 0.1 + offset))


func _build_toolbox(side: float, mat: Material) -> void:
	_wheels._add_mesh("ToolBox", _wheels._box(Vector3(0.32, 0.46, 0.9)), mat,
			Vector3(side * (SKIN_X + 0.17), 0.30, 0.1))
	_wheels._add_mesh("ToolBoxLid", _wheels._box(Vector3(0.34, 0.04, 0.92)), mat,
			Vector3(side * (SKIN_X + 0.17), 0.55, 0.1))
	_wheels._add_mesh("ToolBoxLatch", _wheels._box(Vector3(0.03, 0.08, 0.12)), mat,
			Vector3(side * (SKIN_X + 0.345), 0.44, 0.1))


func _build_exhaust(side: float, mat: Material) -> void:
	var pipe_mesh := CylinderMesh.new()
	pipe_mesh.top_radius = 0.06
	pipe_mesh.bottom_radius = 0.06
	pipe_mesh.height = 2.3
	var pipe := _wheels._add_mesh("ExhaustPipe", pipe_mesh, mat, Vector3(side * (SKIN_X + 0.08), -0.09, 0.05))
	pipe.rotation_degrees.x = 90.0

	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.07
	tip_mesh.bottom_radius = 0.07
	tip_mesh.height = 0.3
	var tip := _wheels._add_mesh("ExhaustTip", tip_mesh, mat, Vector3(side * (SKIN_X + 0.12), -0.12, 1.3))
	tip.rotation_degrees = Vector3(60.0, 0.0, side * 25.0)

	for i: int in range(2):
		var z: float = -0.6 if i == 0 else 0.7
		_wheels._add_mesh("ExhaustHanger%d" % i, _wheels._box(Vector3(0.10, 0.08, 0.04)), mat,
				Vector3(side * (SKIN_X + 0.04), -0.05, z))


func _build_spare(side: float, label: String, rubber: Material, mat: Material) -> void:
	var tyre_mesh := CylinderMesh.new()
	tyre_mesh.top_radius = 0.42
	tyre_mesh.bottom_radius = 0.42
	tyre_mesh.height = 0.26
	tyre_mesh.radial_segments = 20
	var tyre := _wheels._add_mesh("Spare%s" % label, tyre_mesh, rubber,
			Vector3(side * (SKIN_X + 0.15), 0.55, -1.55))
	tyre.rotation_degrees.z = 90.0

	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.2
	hub_mesh.bottom_radius = 0.2
	hub_mesh.height = 0.04
	var hub := _wheels._add_mesh("SpareHub%s" % label, hub_mesh, mat,
			Vector3(side * (SKIN_X + 0.29), 0.55, -1.55))
	hub.rotation_degrees.z = 90.0

	_wheels._add_mesh("SpareMount%s" % label, _wheels._box(Vector3(0.04, 0.5, 0.5)), mat,
			Vector3(side * (SKIN_X + 0.02), 0.55, -1.55))

	for i: int in range(2):
		var chain := _wheels._add_mesh("SpareChain%s%d" % [label, i], _wheels._box(Vector3(0.04, 0.04, 0.8)),
				mat, Vector3(side * (SKIN_X + 0.30), 0.55, -1.55))
		chain.rotation_degrees.x = 45.0 if i == 0 else -45.0


func _build_rear_bumper(mat: Material) -> void:
	for side: float in [-1.0, 1.0]:
		var letter := "L" if side < 0.0 else "R"
		_wheels._add_mesh("FrameRail%s" % letter, _wheels._box(Vector3(0.16, 0.14, 1.0)), mat,
				Vector3(side * 1.05, -0.12, 4.4))
		_wheels._add_mesh("BumperHanger%s" % letter, _wheels._box(Vector3(0.12, 0.16, 0.2)), mat,
				Vector3(side * 1.05, -0.06, 4.8))
		_wheels._add_mesh("BumperCap%s" % letter, _wheels._box(Vector3(0.06, 0.2, 0.2)), mat,
				Vector3(side * 2.33, -0.10, 4.92))

	_wheels._add_mesh("RearBumper", _wheels._box(Vector3(4.6, 0.18, 0.16)), mat, Vector3(0.0, -0.10, 4.92))
