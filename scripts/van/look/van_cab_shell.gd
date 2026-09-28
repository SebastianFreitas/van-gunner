extends RefCounted
## Builds the cab-over shell on VanBodyProfile: skin, dark liner, back lip, back wall and the flat
## face with its windshield opening.

var _cab: VanCab


func _init(cab: VanCab) -> void:
	_cab = cab


func build(mat: Material) -> void:
	var outline := _cab.profile.section_points(VanCab.SECTION_STEPS, true)
	outline[0] = Vector2(outline[0].x, VanCab.BASE_Y)
	outline[1] = Vector2(outline[1].x, VanCab.BASE_Y)

	_build_skin(outline, mat)
	_build_liner(outline)
	_build_back_lip(outline, mat)
	_build_back_wall(outline)
	_build_floor()
	_build_face(outline, mat)
	_build_windshield_reveal()


## The outer skin, swept along Z from the body's back edge to the flat face.
func _build_skin(outline: PackedVector2Array, mat: Material) -> void:
	var centre := Vector3(0.0, 1.5, -6.46)
	var z_back := VanCab.CAB_BACK_Z + 0.04
	var z_front := VanCab.NOSE_Z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	for i in range(n):
		var p0 := outline[i]
		var p1 := outline[(i + 1) % n]
		var a := Vector3(p0.x, p0.y, z_back)
		var b := Vector3(p1.x, p1.y, z_back)
		var c := Vector3(p1.x, p1.y, z_front)
		var d := Vector3(p0.x, p0.y, z_front)
		VanCab._add_quad(st, a, b, c, d, centre)
	st.generate_normals()
	_cab._add_mesh("CabSkin", st.commit(), mat)


## A dark liner just inside the skin, so the cab reads solid from outside the glass.
func _build_liner(outline: PackedVector2Array) -> void:
	var mat := VanCab._dark_material(Color(0.03, 0.03, 0.03), 0.9)
	var centre := Vector3(0.0, 1.5, -6.46)
	var z_back := VanCab.CAB_BACK_Z
	var z_front := VanCab.NOSE_Z + 0.05
	var pull := Vector2(0.0, 1.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	for i in range(n):
		var p0 := outline[i] + (pull - outline[i]).normalized() * 0.05
		var p1 := outline[(i + 1) % n] + (pull - outline[(i + 1) % n]).normalized() * 0.05
		var a := Vector3(p0.x, p0.y, z_back)
		var b := Vector3(p1.x, p1.y, z_back)
		var c := Vector3(p1.x, p1.y, z_front)
		var d := Vector3(p0.x, p0.y, z_front)
		VanCab._add_quad(st, a, b, c, d, centre, true)
	st.generate_normals()
	var mi := _cab._add_mesh("CabLiner", st.commit(), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Closes the step between the body skin (proud 6 cm) and the cab skin (proud 12 cm).
func _build_back_lip(outline: PackedVector2Array, mat: Material) -> void:
	var centre := Vector3(0.0, 1.5, -6.46)
	var z := VanCab.CAB_BACK_Z + 0.04
	var pull := Vector2(0.0, 1.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	for i in range(n):
		var p0 := outline[i]
		var p1 := outline[(i + 1) % n]
		var p0i := p0 + (pull - p0).normalized() * 0.10
		var p1i := p1 + (pull - p1).normalized() * 0.10
		var a := Vector3(p0.x, p0.y, z)
		var b := Vector3(p1.x, p1.y, z)
		var c := Vector3(p1i.x, p1i.y, z)
		var d := Vector3(p0i.x, p0i.y, z)
		VanCab._add_quad(st, a, b, c, d, centre)
	st.generate_normals()
	_cab._add_mesh("CabBackLip", st.commit(), mat)


## Hides the body's rounded front end from the windshield.
func _build_back_wall(outline: PackedVector2Array) -> void:
	var mat := VanCab._dark_material(Color(0.03, 0.03, 0.03), 0.9)
	# Two-sided so the cab's back end reads closed from the body side too.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var centre := Vector3(0.0, 1.5, -4.0)
	var z := VanCab.CAB_BACK_Z - 0.02
	var indices := Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var a := Vector3(outline[indices[i]].x, outline[indices[i]].y, z)
		var b := Vector3(outline[indices[i + 1]].x, outline[indices[i + 1]].y, z)
		var c := Vector3(outline[indices[i + 2]].x, outline[indices[i + 2]].y, z)
		VanCab._add_tri(st, a, b, c, centre)
	st.generate_normals()
	_cab._add_mesh("CabBackWall", st.commit(), mat)


func _build_floor() -> void:
	var mat := VanCab._dark_material(Color(0.03, 0.03, 0.03), 0.9)
	var w := 2.0 * _cab.profile.outer_x_at(VanCab.CAB_FLOOR_Y) - 0.2
	_cab._add_mesh("CabFloor", _cab._box(Vector3(w, 0.06, 3.3)), mat,
			Vector3(0.0, VanCab.CAB_FLOOR_Y, -6.46))


## The flat face, cut into four rects around the windshield opening.
func _build_face(outline: PackedVector2Array, mat: Material) -> void:
	var centre := Vector3(0.0, 1.5, -6.46)
	var z := VanCab.NOSE_Z
	var rects: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-10.0, -10.0), Vector2(10.0, -10.0),
				Vector2(10.0, VanCab.WS_BOT_Y), Vector2(-10.0, VanCab.WS_BOT_Y)]),
		PackedVector2Array([Vector2(-10.0, VanCab.WS_TOP_Y), Vector2(10.0, VanCab.WS_TOP_Y),
				Vector2(10.0, 10.0), Vector2(-10.0, 10.0)]),
		PackedVector2Array([Vector2(-10.0, VanCab.WS_BOT_Y), Vector2(-VanCab.WS_HALF_W, VanCab.WS_BOT_Y),
				Vector2(-VanCab.WS_HALF_W, VanCab.WS_TOP_Y), Vector2(-10.0, VanCab.WS_TOP_Y)]),
		PackedVector2Array([Vector2(VanCab.WS_HALF_W, VanCab.WS_BOT_Y), Vector2(10.0, VanCab.WS_BOT_Y),
				Vector2(10.0, VanCab.WS_TOP_Y), Vector2(VanCab.WS_HALF_W, VanCab.WS_TOP_Y)]),
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rect in rects:
		var polys := Geometry2D.intersect_polygons(outline, rect)
		for poly in polys:
			if poly.size() < 3:
				continue
			var indices := Geometry2D.triangulate_polygon(poly)
			if indices.is_empty():
				continue
			for i in range(0, indices.size(), 3):
				var a := Vector3(poly[indices[i]].x, poly[indices[i]].y, z)
				var b := Vector3(poly[indices[i + 1]].x, poly[indices[i + 1]].y, z)
				var c := Vector3(poly[indices[i + 2]].x, poly[indices[i + 2]].y, z)
				VanCab._add_tri(st, a, b, c, centre)
	st.generate_normals()
	_cab._add_mesh("CabFace", st.commit(), mat)


## Dark reveal lining the windshield opening so the glass sits in a real cut, not a hole.
func _build_windshield_reveal() -> void:
	var mat := VanCab._dark_material(Color(0.03, 0.03, 0.03), 0.9)
	var z0 := VanCab.NOSE_Z
	var z1 := VanCab.NOSE_Z + VanCab.WS_REVEAL
	var centre := Vector3(0.0, (VanCab.WS_BOT_Y + VanCab.WS_TOP_Y) * 0.5, VanCab.NOSE_Z + 0.06)
	var hw := VanCab.WS_HALF_W

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	VanCab._add_quad(st,
			Vector3(-hw, VanCab.WS_BOT_Y, z0), Vector3(hw, VanCab.WS_BOT_Y, z0),
			Vector3(hw, VanCab.WS_BOT_Y, z1), Vector3(-hw, VanCab.WS_BOT_Y, z1), centre, true)
	VanCab._add_quad(st,
			Vector3(-hw, VanCab.WS_TOP_Y, z0), Vector3(hw, VanCab.WS_TOP_Y, z0),
			Vector3(hw, VanCab.WS_TOP_Y, z1), Vector3(-hw, VanCab.WS_TOP_Y, z1), centre, true)
	VanCab._add_quad(st,
			Vector3(-hw, VanCab.WS_BOT_Y, z0), Vector3(-hw, VanCab.WS_TOP_Y, z0),
			Vector3(-hw, VanCab.WS_TOP_Y, z1), Vector3(-hw, VanCab.WS_BOT_Y, z1), centre, true)
	VanCab._add_quad(st,
			Vector3(hw, VanCab.WS_BOT_Y, z0), Vector3(hw, VanCab.WS_TOP_Y, z0),
			Vector3(hw, VanCab.WS_TOP_Y, z1), Vector3(hw, VanCab.WS_BOT_Y, z1), centre, true)

	st.generate_normals()
	var mi := _cab._add_mesh("WindshieldReveal", st.commit(), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
