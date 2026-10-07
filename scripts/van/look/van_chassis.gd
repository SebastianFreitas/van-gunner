extends RefCounted
## Builds the van's chassis kit around the wheels: arch flares and wells cut around the lifted wheels' hubs, side steps with chained drop steps, saddle tank,
## toolbox, short exhaust, chained spares, rear rails and bumper.

## Outer face of the sill/skin.
const SKIN_X := 2.56
## Reference x of the tank, toolbox and spare add-ons (still the pre-widening skin; see report).
const ADDON_X := 2.56
const FLARE_GAP := 0.08
const FLARE_OUT := 0.09
const LIP_H := 0.07
## Flare band and lip thickness (D12).
const FLARE_T := 0.02
const ARC_SEGMENTS := 14
## Outer face of VanHullPatches' sill (wall_x_at(0) 2.42 + SIDE_SKIN_OUTER_M 0.22 + 0.06); the
## exhaust keeps 2 cm off it.
const SILL_OUT_X := 2.70
## Start of the add-on slot: just behind the open side door's rear edge (z 0.135), so the door's
## slide path stays clear.
const SLOT_Z0 := 0.16
## Gap between packed add-ons (D12).
const ADDON_GAP := 0.02
## The tank and toolbox hang under the floor deck (underside y -0.27, road y -0.9), not in the widened cabin.
const TANK_DY := -0.70
const BOX_DY := -0.88
const TANK_LEN := 1.2
## The lid's length, the box's longest part.
const TOOLBOX_LEN := 0.92
## The spare's tyre diameter.
const SPARE_LEN := 0.84
## Half gap between the tandem arches' flares where they meet (D12: faces 2 cm apart).
const TANDEM_GAP := 0.01
## The drop step's rung height: halfway between the road (VanWheels.ROAD_Y -0.9) and the side step.
const DROP_STEP_Y := -0.48
## Links per drop-step chain.
const CHAIN_LINKS := 5

var _wheels: VanWheels


func _init(wheels: VanWheels) -> void:
	_wheels = wheels


func build(hull_mat: Material, rubber: Material, rear_axles: Array[float], exhaust_side: float,
		spare_mask: int) -> void:
	var dark := VanCab._dark_material(Color(0.03, 0.03, 0.03), 0.9)

	for side: float in [-1.0, 1.0]:
		var label := "L" if side < 0.0 else "R"
		var idx := 0
		# The front wheels sit under the truck front's own fenders (van_cab_body.gd): no arch at idx 0.
		idx += 1
		# Tandem arches meet at their midpoint, the flares 2 * TANDEM_GAP apart.
		var tandem_min := 2.0 * (VanWheels.REAR_RADIUS + FLARE_GAP + FLARE_T) + 2.0 * TANDEM_GAP
		for j: int in range(rear_axles.size()):
			var z := rear_axles[j]
			var flare_lo := -INF
			var flare_hi := INF
			var well_lo := -INF
			var well_hi := INF
			if j + 1 < rear_axles.size() and rear_axles[j + 1] - z < tandem_min:
				var z_mid := (z + rear_axles[j + 1]) * 0.5
				flare_hi = z_mid - TANDEM_GAP
				well_hi = z_mid
			if j > 0 and z - rear_axles[j - 1] < tandem_min:
				var z_mid := (z + rear_axles[j - 1]) * 0.5
				flare_lo = z_mid + TANDEM_GAP
				well_lo = z_mid
			var rear_centre := Vector3(side * VanWheels.WHEEL_X, VanWheels.ROAD_Y + VanWheels.REAR_RADIUS, z)
			_build_flare("Flare%s%d" % [label, idx], rear_centre, VanWheels.REAR_RADIUS, hull_mat,
					flare_lo, flare_hi)
			_build_well("Well%s%d" % [label, idx], rear_centre, VanWheels.REAR_RADIUS, dark,
					well_lo, well_hi)
			idx += 1
		_build_steps(side, label, hull_mat)

	# Add-ons pack front to rear in the slot behind the open side door; one that would pass the
	# rear arch's flare is not built (D6).
	var slot_z1 := rear_axles[0] - (VanWheels.REAR_RADIUS + FLARE_GAP + FLARE_T) - 0.02
	for side: float in [-1.0, 1.0]:
		var label := "L" if side < 0.0 else "R"
		var z := SLOT_Z0
		if side == exhaust_side:
			if z + TOOLBOX_LEN <= slot_z1:
				_build_toolbox(side, hull_mat, z + TOOLBOX_LEN * 0.5)
				z += TOOLBOX_LEN + ADDON_GAP
		elif z + TANK_LEN <= slot_z1:
			_build_tank(side, hull_mat, z + TANK_LEN * 0.5)
			z += TANK_LEN + ADDON_GAP
		var spare_bit := 1 if side < 0.0 else 2
		if spare_mask & spare_bit and z + SPARE_LEN <= slot_z1:
			_build_spare(side, label, rubber, hull_mat, z + SPARE_LEN * 0.5)
	_build_exhaust(exhaust_side, hull_mat)

	_build_rear_bumper(hull_mat)


func _build_flare(flare_name: String, centre: Vector3, radius: float, mat: Material,
		z_lo: float = -INF, z_hi: float = INF) -> void:
	var side := signf(centre.x)
	var r := radius + FLARE_GAP
	var x_in := side * (SKIN_X + 0.06)
	var x_out := side * (VanWheels.WHEEL_X + VanWheels.TYRE_WIDTH * 0.5 + FLARE_OUT)
	# L profile as (x, rho) pairs, plus each edge's outward direction: 0 = +rho, 1 = +x, 2 = -rho,
	# 3 = -x, wrapping P0..P5.
	var profile: Array[Vector2] = [
		Vector2(x_in, r + FLARE_T), Vector2(x_out, r + FLARE_T), Vector2(x_out, r - LIP_H),
		Vector2(x_out - side * FLARE_T, r - LIP_H), Vector2(x_out - side * FLARE_T, r),
		Vector2(x_in, r)]
	var edge_dirs: Array[int] = [0, 1, 2, 3, 2, 3]

	# Angle a puts a profile point at z = centre.z + rho * cos(a), so a = 0 is the +z end.
	var rho_out := r + FLARE_T
	# The arch is a circle around the hub, cut where it meets the hull's underside; the hub sits
	# above that line, so a_base is negative and the arch wraps past horizontal.
	var a_base := asin(clampf((VanWheels.HULL_BOTTOM_Y - centre.y) / rho_out, -1.0, 1.0))
	var a_min := a_base
	if z_hi - centre.z < rho_out:
		a_min = maxf(a_base, acos(clampf((z_hi - centre.z) / rho_out, -1.0, 1.0)))
	var a_max := PI - a_base
	if centre.z - z_lo < rho_out:
		a_max = minf(PI - a_base, PI - acos(clampf((centre.z - z_lo) / rho_out, -1.0, 1.0)))
	if a_min >= a_max:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i: int in range(ARC_SEGMENTS):
		var a0 := lerpf(a_min, a_max, float(i) / ARC_SEGMENTS)
		var a1 := lerpf(a_min, a_max, float(i + 1) / ARC_SEGMENTS)
		var am :=(a0 + a1) * 0.5
		var radial := Vector3(0.0, sin(am), cos(am))
		for k: int in range(6):
			var pa: Vector2 = profile[k]
			var pb: Vector2 = profile[(k + 1) % 6]
			var q0 := _flare_point(centre, pa, a0)
			var q1 := _flare_point(centre, pb, a0)
			var q2 := _flare_point(centre, pb, a1)
			var q3 := _flare_point(centre, pa, a1)
			var out_dir := Vector3.ZERO
			match edge_dirs[k]:
				0: out_dir = radial
				1: out_dir = Vector3(side, 0.0, 0.0)
				2: out_dir = -radial
				_: out_dir = Vector3(-side, 0.0, 0.0)
			var ref := (q0 + q1 + q2 + q3) * 0.25 - out_dir * 0.005
			VanCab._add_quad(st, q0, q1, q2, q3, ref)

	# End caps: the L as a quad (P0 P1 P4 P5) plus two triangles. Only the profile's own vertices,
	# so every cap edge matches a side quad's edge (a split point mid-edge on P1P2 was a T-junction
	# the audit reports as open edges).
	for a_cap: float in [a_min, a_max]:
		var a_ref := a_min + 0.05 if a_cap == a_min else a_max - 0.05
		var sum := Vector3.ZERO
		for p: Vector2 in profile:
			sum += _flare_point(centre, p, a_ref)
		var ref := sum / 6.0
		var pt: Array[Vector3] = []
		for p: Vector2 in profile:
			pt.append(_flare_point(centre, p, a_cap))
		VanCab._add_quad(st, pt[0], pt[1], pt[4], pt[5], ref)
		VanCab._add_tri(st, pt[4], pt[1], pt[2], ref)
		VanCab._add_tri(st, pt[4], pt[2], pt[3], ref)
	st.generate_normals()
	_wheels._add_mesh(flare_name, st.commit(), mat, Vector3.ZERO)


func _flare_point(centre: Vector3, p: Vector2, angle: float) -> Vector3:
	return Vector3(p.x, centre.y + p.y * sin(angle), centre.z + p.y * cos(angle))


## Clamping to a tandem limit collapses some triangles to slivers; skip those.
func _add_tri_solid(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ref: Vector3) -> void:
	if (b - a).cross(c - a).length() * 0.5 < 1e-6:
		return
	VanCab._add_tri(st, a, b, c, ref)


func _clamp_z(p: Vector3, z_lo: float, z_hi: float) -> Vector3:
	return Vector3(p.x, p.y, clampf(p.z, z_lo, z_hi))


func _build_well(well_name: String, centre: Vector3, radius: float, mat: Material,
		z_lo: float = -INF, z_hi: float = INF) -> void:
	var side := signf(centre.x)
	var r := radius + FLARE_GAP
	var x := side * (SKIN_X + 0.005)
	# The plate is the arch's circle clipped under the hull's underside; a hub below that line is
	# moved up onto it so the fan still covers the segment.
	var hub := _clamp_z(Vector3(x, maxf(centre.y, VanWheels.HULL_BOTTOM_Y), centre.z), z_lo, z_hi)
	var ref := Vector3(0.0, centre.y, centre.z)
	var a_base := asin(clampf((VanWheels.HULL_BOTTOM_Y - centre.y) / r, -1.0, 1.0))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(ARC_SEGMENTS):
		var a0 := lerpf(a_base, PI - a_base, float(i) / ARC_SEGMENTS)
		var a1 := lerpf(a_base, PI - a_base, float(i + 1) / ARC_SEGMENTS)
		var p0 := _clamp_z(Vector3(x, centre.y + r * sin(a0), centre.z + r * cos(a0)), z_lo, z_hi)
		var p1 := _clamp_z(Vector3(x, centre.y + r * sin(a1), centre.z + r * cos(a1)), z_lo, z_hi)
		_add_tri_solid(st, hub, p0, p1, ref)

	# The sliver between the hub and the clip line.
	if a_base < 0.0:
		var c0 := _clamp_z(Vector3(x, centre.y + r * sin(PI - a_base),
				centre.z + r * cos(PI - a_base)), z_lo, z_hi)
		var c1 := _clamp_z(Vector3(x, centre.y + r * sin(a_base),
				centre.z + r * cos(a_base)), z_lo, z_hi)
		_add_tri_solid(st, hub, c0, c1, ref)
	st.generate_normals()
	var mi := _wheels._add_mesh(well_name, st.commit(), mat, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_steps(side: float, label: String, mat: Material) -> void:
	_wheels._add_mesh("SideStep%s" % label, _wheels._box(Vector3(0.22, 0.05, 2.2)), mat,
			Vector3(side * (SKIN_X + 0.19), -0.06, -3.485))
	# Hangers end 2 cm under the skin edge and 4 cm short of the step's inner end: no shared planes.
	for i: int in range(2):
		var offset: float = 0.95 if i == 0 else -0.95
		_wheels._add_mesh("SideStepHanger%s%d" % [label, i], _wheels._box(Vector3(0.16, 0.11, 0.06)), mat,
				Vector3(side * (SKIN_X + 0.10), -0.055, -3.485 + offset))

	# The drop step hangs on two chains from the side step; each chain's ends sink 1 cm into the
	# step above and the rung below, and alternate links turn 90 degrees so it reads as chain.
	_wheels._add_mesh("SideStepDrop%s" % label, _wheels._box(Vector3(0.22, 0.05, 1.0)), mat,
			Vector3(side * (SKIN_X + 0.19), DROP_STEP_Y, -3.485))
	var chain_mat := VanCab._dark_material(Color(0.09, 0.085, 0.08), 0.75)
	var y_top := -0.075
	var y_bot := DROP_STEP_Y + 0.025 - 0.01
	var pitch := (y_top - y_bot - 0.085) / (CHAIN_LINKS - 1)
	for i: int in range(2):
		var chain_z: float = -3.485 + (0.4 if i == 0 else -0.4)
		for k: int in range(CHAIN_LINKS):
			var size := Vector3(0.015, 0.085, 0.045) if k % 2 == 0 else Vector3(0.045, 0.085, 0.015)
			var pos := Vector3(side * (SKIN_X + 0.19), y_top - 0.0425 - k * pitch, chain_z)
			_wheels._add_mesh("SideStepChain%s%d_%d" % [label, i, k], _wheels._box(size), chain_mat, pos)

	# Under the cab door, inner face 3 cm off the truck cab's side.
	_wheels._add_mesh("CabStep%s" % label, _wheels._box(Vector3(0.28, 0.05, 1.2)), mat,
			Vector3(side * (VanCab.CAB_HALF_W + 0.17), 0.02, -5.7))
	for i: int in range(2):
		var offset: float = 0.5 if i == 0 else -0.5
		_wheels._add_mesh("CabStepHanger%s%d" % [label, i], _wheels._box(Vector3(0.18, 0.12, 0.06)), mat,
				Vector3(side * (VanCab.CAB_HALF_W + 0.11), 0.04, -5.7 + offset))


func _build_tank(side: float, mat: Material, zc: float) -> void:
	var tank_mesh := CylinderMesh.new()
	tank_mesh.top_radius = 0.25
	tank_mesh.bottom_radius = 0.25
	tank_mesh.height = TANK_LEN
	tank_mesh.radial_segments = 16
	var tank := _wheels._add_mesh("FuelTank", tank_mesh, mat, Vector3(side * (ADDON_X + 0.27), 0.12 + TANK_DY, zc))
	tank.rotation_degrees.x = 90.0

	for i: int in range(2):
		var offset: float = 0.4 if i == 0 else -0.4
		var strap_mesh := CylinderMesh.new()
		strap_mesh.top_radius = 0.265
		strap_mesh.bottom_radius = 0.265
		strap_mesh.height = 0.05
		var strap := _wheels._add_mesh("TankStrap%d" % i, strap_mesh, mat,
				Vector3(side * (ADDON_X + 0.27), 0.12 + TANK_DY, zc + offset))
		strap.rotation_degrees.x = 90.0

	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.06
	cap_mesh.bottom_radius = 0.06
	cap_mesh.height = 0.06
	_wheels._add_mesh("TankCap", cap_mesh, mat, Vector3(side * (ADDON_X + 0.27), 0.40 + TANK_DY, zc + 0.45))

	for i: int in range(2):
		var offset: float = 0.4 if i == 0 else -0.4
		_wheels._add_mesh("TankBracket%d" % i, _wheels._box(Vector3(0.3, 0.06, 0.08)), mat,
				Vector3(side * (ADDON_X + 0.15), -0.1 + TANK_DY, zc + offset))


func _build_toolbox(side: float, mat: Material, zc: float) -> void:
	_wheels._add_mesh("ToolBox", _wheels._box(Vector3(0.32, 0.46, 0.9)), mat,
			Vector3(side * (ADDON_X + 0.17), 0.30 + BOX_DY, zc))
	_wheels._add_mesh("ToolBoxLid", _wheels._box(Vector3(0.34, 0.04, 0.92)), mat,
			Vector3(side * (ADDON_X + 0.17), 0.55 + BOX_DY, zc))
	_wheels._add_mesh("ToolBoxLatch", _wheels._box(Vector3(0.03, 0.08, 0.12)), mat,
			Vector3(side * (ADDON_X + 0.345), 0.44 + BOX_DY, zc))


func _build_exhaust(side: float, mat: Material) -> void:
	var pipe_mesh := CylinderMesh.new()
	pipe_mesh.top_radius = 0.06
	pipe_mesh.bottom_radius = 0.06
	pipe_mesh.height = 2.3
	var pipe := _wheels._add_mesh("ExhaustPipe", pipe_mesh, mat, Vector3(side * (SILL_OUT_X + 0.02 + 0.06), -0.09, 0.05))
	pipe.rotation_degrees.x = 90.0

	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.07
	tip_mesh.bottom_radius = 0.07
	tip_mesh.height = 0.3
	var tip := _wheels._add_mesh("ExhaustTip", tip_mesh, mat, Vector3(side * (SILL_OUT_X + 0.12), -0.12, 1.3))
	tip.rotation_degrees = Vector3(60.0, 0.0, side * 25.0)

	for i: int in range(2):
		var z: float = -0.6 if i == 0 else 0.7
		_wheels._add_mesh("ExhaustHanger%d" % i, _wheels._box(Vector3(0.10, 0.08, 0.04)), mat,
				Vector3(side * (SILL_OUT_X + 0.02), -0.05, z))


func _build_spare(side: float, label: String, rubber: Material, mat: Material, zc: float) -> void:
	var tyre_mesh := CylinderMesh.new()
	tyre_mesh.top_radius = 0.42
	tyre_mesh.bottom_radius = 0.42
	tyre_mesh.height = 0.26
	tyre_mesh.radial_segments = 20
	var tyre := _wheels._add_mesh("Spare%s" % label, tyre_mesh, rubber,
			Vector3(side * (ADDON_X + 0.15), 0.55, zc))
	tyre.rotation_degrees.z = 90.0

	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.2
	hub_mesh.bottom_radius = 0.2
	hub_mesh.height = 0.08
	var hub := _wheels._add_mesh("SpareHub%s" % label, hub_mesh, mat,
			Vector3(side * (ADDON_X + 0.30), 0.55, zc))
	hub.rotation_degrees.z = 90.0

	_wheels._add_mesh("SpareMount%s" % label, _wheels._box(Vector3(0.04, 0.5, 0.5)), mat,
			Vector3(side * (ADDON_X + 0.02), 0.55, zc))

	# Two short segments per diagonal, ending inside the hub: the segments never cross, so no two
	# chain faces overlap.
	for k: int in range(4):
		var angle := 45.0 if k < 2 else -45.0
		var d := 0.29 if k % 2 == 0 else -0.29
		var chain := _wheels._add_mesh("SpareChain%s%d" % [label, k], _wheels._box(Vector3(0.02, 0.04, 0.20)),
				mat, Vector3(side * (ADDON_X + 0.31), 0.55, zc)
				+ Basis(Vector3.RIGHT, deg_to_rad(angle)) * Vector3(0.0, 0.0, d))
		chain.rotation_degrees.x = angle


func _build_rear_bumper(mat: Material) -> void:
	# Offsets are from the hull's rear end (REAR_Z), where the old 4.70 body ended; the caps sit
	# 7 cm inside the wall's bottom half width.
	var bumper_z := VanInteriorSize.REAR_Z + 0.22
	var cap_x := VanInteriorSize.BOTTOM_HALF - 0.07
	for side: float in [-1.0, 1.0]:
		var letter := "L" if side < 0.0 else "R"
		_wheels._add_mesh("FrameRail%s" % letter, _wheels._box(Vector3(0.16, 0.14, 0.92)), mat,
				Vector3(side * 1.05, -0.12, bumper_z - 0.56)) # ends 2 cm before the bumper (vanfix D12)
		_wheels._add_mesh("BumperHanger%s" % letter, _wheels._box(Vector3(0.06, 0.14, 0.18)), mat,
				Vector3(side * 1.02, -0.10, bumper_z - 0.13))
		_wheels._add_mesh("BumperCap%s" % letter, _wheels._box(Vector3(0.06, 0.2, 0.2)), mat,
				Vector3(side * cap_x, -0.10, bumper_z))

	_wheels._add_mesh("RearBumper", _wheels._box(Vector3(cap_x * 2.0 - 0.06, 0.18, 0.16)), mat,
			Vector3(0.0, -0.10, bumper_z))
