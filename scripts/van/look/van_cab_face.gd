extends RefCounted
## Dresses the cab-over face and sides: framed split windshield, A-pillar trims, grille,
## headlight housings and the two cab doors with windows.

var _cab: VanCab


func _init(cab: VanCab) -> void:
	_cab = cab


func build(mat: Material, _rng: RandomNumberGenerator) -> void:
	var f := VanCab.NOSE_Z
	_build_windshield(f, mat)
	_build_frame(f, mat)
	_build_a_pillars(f, mat)
	_build_grille(f, mat)
	_build_headlight_housings(f, mat)
	_build_doors(mat)


func _build_windshield(f: float, mat: Material) -> void:
	var glass_mat := VanCab.glass_material()
	var z := f + VanCab.WS_REVEAL
	var centre := Vector3(0.0, 1.5, -6.46)
	for s: float in [-1.0, 1.0]:
		var suffix := "L" if s < 0.0 else "R"
		var x_in := s * 0.04
		var x_out := s * VanCab.WS_HALF_W
		var x0 := minf(x_in, x_out)
		var x1 := maxf(x_in, x_out)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		VanCab._add_quad(st,
				Vector3(x0, VanCab.WS_BOT_Y, z), Vector3(x1, VanCab.WS_BOT_Y, z),
				Vector3(x1, VanCab.WS_TOP_Y, z), Vector3(x0, VanCab.WS_TOP_Y, z), centre)
		st.generate_normals()
		var pane := _cab._add_mesh("Windshield%s" % suffix, st.commit(), glass_mat)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mid_y := (VanCab.WS_BOT_Y + VanCab.WS_TOP_Y) * 0.5
	_cab._add_mesh("WindshieldPost",
			_cab._box(Vector3(0.08, VanCab.WS_TOP_Y - VanCab.WS_BOT_Y + 0.04, VanCab.WS_REVEAL)),
			mat,
			Vector3(0.0, mid_y, f + VanCab.WS_REVEAL * 0.5))


func _build_frame(f: float, mat: Material) -> void:
	# Back faces sit 2 cm behind the flat face and the pieces butt instead of overlapping, so
	# no two faces share a plane.
	var hw := VanCab.WS_HALF_W
	var ov := 0.02
	var z := f - 0.02
	_cab._add_mesh("WindshieldFrameTop", _cab._box(Vector3(2.0 * hw + 0.14, 0.07 + ov, 0.08)), mat,
			Vector3(0.0, VanCab.WS_TOP_Y + 0.025, z))
	_cab._add_mesh("WindshieldFrameBottom",
			_cab._box(Vector3(2.0 * hw + 0.14, 0.07 + ov, 0.08)), mat,
			Vector3(0.0, VanCab.WS_BOT_Y - 0.025, z))
	var h := VanCab.WS_TOP_Y - VanCab.WS_BOT_Y - 2.0 * ov
	var mid_y := (VanCab.WS_BOT_Y + VanCab.WS_TOP_Y) * 0.5
	_cab._add_mesh("WindshieldFrameL", _cab._box(Vector3(0.07 + ov, h, 0.08)), mat,
			Vector3(-(hw + 0.025), mid_y, z))
	_cab._add_mesh("WindshieldFrameR", _cab._box(Vector3(0.07 + ov, h, 0.08)), mat,
			Vector3(hw + 0.025, mid_y, z))


func _build_a_pillars(f: float, mat: Material) -> void:
	var bottom := VanCab.BASE_Y + 0.3
	var top := _cab.profile.wall_height()
	var mid_y := (bottom + top) * 0.5
	var h := top - bottom
	for s: float in [-1.0, 1.0]:
		var suffix := "L" if s < 0.0 else "R"
		# Outer face 3 cm inside the outline, so it clears the bumper's end face (x 2.55).
		var x := s * (_cab.profile.outer_x_at(VanCab.WS_BOT_Y) - 0.08)
		_cab._add_mesh("APillar%s" % suffix, _cab._box(Vector3(0.10, h, 0.12)), mat,
				Vector3(x, mid_y, f + 0.02))


func _build_grille(f: float, mat: Material) -> void:
	var dark := VanCab._dark_material(Color(0.02, 0.02, 0.02), 0.9)
	var hw := VanCab.GRILLE_HALF_W
	var bot := VanCab.GRILLE_BOT_Y
	var top := VanCab.GRILLE_TOP_Y
	_cab._add_mesh("GrilleBack", _cab._box(Vector3(2.0 * hw, top - bot, 0.04)), dark,
			Vector3(0.0, (bot + top) * 0.5, f - 0.005))

	var slat_count := 6
	for i in range(slat_count):
		var t := (float(i) + 0.5) / float(slat_count)
		var y := lerpf(bot, top, t)
		_cab._add_mesh("GrilleSlat%d" % i, _cab._box(Vector3(2.0 * hw - 0.1, 0.06, 0.08)), mat,
				Vector3(0.0, y, f - 0.05))

	var surround_t := 0.08
	var outer_w := 2.0 * hw + 2.0 * surround_t
	_cab._add_mesh("GrilleSurroundTop",
			_cab._box(Vector3(outer_w, surround_t, surround_t)), mat,
			Vector3(0.0, top + surround_t * 0.5, f - 0.05))
	_cab._add_mesh("GrilleSurroundBottom",
			_cab._box(Vector3(outer_w, surround_t, surround_t)), mat,
			Vector3(0.0, bot - surround_t * 0.5, f - 0.05))
	var side_h := top - bot
	_cab._add_mesh("GrilleSurroundL", _cab._box(Vector3(surround_t, side_h, surround_t)), mat,
			Vector3(-hw - surround_t * 0.5, (bot + top) * 0.5, f - 0.05))
	_cab._add_mesh("GrilleSurroundR", _cab._box(Vector3(surround_t, side_h, surround_t)), mat,
			Vector3(hw + surround_t * 0.5, (bot + top) * 0.5, f - 0.05))


func _build_headlight_housings(f: float, mat: Material) -> void:
	var bezel_mat := VanCab._dark_material(Color(0.02, 0.02, 0.02), 0.9)
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.9, 0.85, 0.7)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(1.0, 0.9, 0.7)
	lens_mat.emission_energy_multiplier = 2.0

	for s: float in [-1.0, 1.0]:
		var suffix := "L" if s < 0.0 else "R"
		var x := s * VanCab.HEADLIGHT_X
		_cab._add_mesh("HeadlightHousing%s" % suffix, _cab._box(Vector3(0.62, 0.44, 0.22)), mat,
				Vector3(x, VanCab.HEADLIGHT_Y, f - 0.08))
		_cab._add_mesh("HeadlightBezel%s" % suffix, _cab._box(Vector3(0.46, 0.34, 0.04)), bezel_mat,
				Vector3(x, VanCab.HEADLIGHT_Y, f - 0.20))

		var lens_mesh := CylinderMesh.new()
		lens_mesh.top_radius = 0.14
		lens_mesh.bottom_radius = 0.14
		lens_mesh.height = 0.04
		var lens := _cab._add_mesh("HeadlightLens%s" % suffix, lens_mesh, lens_mat,
				Vector3(x, VanCab.HEADLIGHT_Y, f - 0.225), Vector3(deg_to_rad(90.0), 0.0, 0.0))
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		_cab._add_mesh("HeadlightVisor%s" % suffix, _cab._box(Vector3(0.66, 0.05, 0.14)), mat,
				Vector3(x, VanCab.HEADLIGHT_Y + 0.245, f - 0.14))


func _build_doors(mat: Material) -> void:
	var seam_mat := VanCab._dark_material(Color(0.02, 0.02, 0.02), 0.9)
	var win_mat := VanCab._dark_material(Color(0.015, 0.018, 0.02), 0.3)

	for s: float in [-1.0, 1.0]:
		var suffix := "L" if s < 0.0 else "R"
		var x_at := func(y: float) -> float: return s * (_cab.profile.outer_x_at(y) + 0.012)

		var mid_y := (VanCab.DOOR_BOT_Y + VanCab.DOOR_TOP_Y) * 0.5
		var mid_z := (VanCab.DOOR_BACK_Z + VanCab.DOOR_FRONT_Z) * 0.5
		var door_len_z := VanCab.DOOR_BACK_Z - VanCab.DOOR_FRONT_Z
		var door_h := VanCab.DOOR_TOP_Y - VanCab.DOOR_BOT_Y

		_cab._add_mesh("CabDoorSeam%s0" % suffix, _cab._box(Vector3(0.03, door_h, 0.03)), seam_mat,
				Vector3(x_at.call(mid_y), mid_y, VanCab.DOOR_BACK_Z))
		_cab._add_mesh("CabDoorSeam%s1" % suffix, _cab._box(Vector3(0.03, door_h, 0.03)), seam_mat,
				Vector3(x_at.call(mid_y), mid_y, VanCab.DOOR_FRONT_Z))
		_cab._add_mesh("CabDoorSeam%s2" % suffix, _cab._box(Vector3(0.03, 0.03, door_len_z)),
				seam_mat, Vector3(x_at.call(VanCab.DOOR_BOT_Y), VanCab.DOOR_BOT_Y, mid_z))
		_cab._add_mesh("CabDoorSeam%s3" % suffix, _cab._box(Vector3(0.03, 0.03, door_len_z)),
				seam_mat, Vector3(x_at.call(VanCab.DOOR_TOP_Y), VanCab.DOOR_TOP_Y, mid_z))

		_build_door_window(suffix, s, x_at, win_mat, mat)

		_cab._add_mesh("CabDoorHandle%s" % suffix, _cab._box(Vector3(0.05, 0.06, 0.22)), mat,
				Vector3(x_at.call(1.4) + s * 0.03, 1.4, VanCab.DOOR_BACK_Z - 0.3))

		_cab._add_mesh("CabDoorHinge%s0" % suffix, _cab._box(Vector3(0.06, 0.16, 0.08)), mat,
				Vector3(x_at.call(0.7) + s * 0.03, 0.7, VanCab.DOOR_FRONT_Z + 0.02))
		_cab._add_mesh("CabDoorHinge%s1" % suffix, _cab._box(Vector3(0.06, 0.16, 0.08)), mat,
				Vector3(x_at.call(2.3) + s * 0.03, 2.3, VanCab.DOOR_FRONT_Z + 0.02))


func _build_door_window(suffix: String, s: float, x_at: Callable, win_mat: Material,
		frame_mat: Material) -> void:
	var back_z := VanCab.DOOR_BACK_Z - 0.2
	var front_z := VanCab.DOOR_FRONT_Z + 0.2
	var bot_y := VanCab.DOOR_WIN_BOT_Y
	var top_y := VanCab.DOOR_WIN_TOP_Y
	var centre := Vector3(0.0, 1.5, -5.7)

	var a := Vector3(x_at.call(bot_y), bot_y, back_z)
	var b := Vector3(x_at.call(bot_y), bot_y, front_z)
	var c := Vector3(x_at.call(top_y), top_y, front_z)
	var d := Vector3(x_at.call(top_y), top_y, back_z)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	VanCab._add_quad(st, a, b, c, d, centre)
	st.generate_normals()
	_cab._add_mesh("CabDoorWindow%s" % suffix, st.commit(), win_mat)

	var thickness := 0.05
	var mid_y := (bot_y + top_y) * 0.5
	var mid_z := (back_z + front_z) * 0.5
	var len_z := back_z - front_z
	var h := top_y - bot_y

	_cab._add_mesh("CabDoorWindowFrame%sTop" % suffix, _cab._box(Vector3(thickness, thickness, len_z)),
			frame_mat, Vector3(x_at.call(top_y) + s * 0.01, top_y, mid_z))
	_cab._add_mesh("CabDoorWindowFrame%sBottom" % suffix,
			_cab._box(Vector3(thickness, thickness, len_z)), frame_mat,
			Vector3(x_at.call(bot_y) + s * 0.01, bot_y, mid_z))
	_cab._add_mesh("CabDoorWindowFrame%sBack" % suffix, _cab._box(Vector3(thickness, h, thickness)),
			frame_mat, Vector3(x_at.call(mid_y) + s * 0.01, mid_y, back_z))
	_cab._add_mesh("CabDoorWindowFrame%sFront" % suffix, _cab._box(Vector3(thickness, h, thickness)),
			frame_mat, Vector3(x_at.call(mid_y) + s * 0.01, mid_y, front_z))
