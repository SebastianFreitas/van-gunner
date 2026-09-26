class_name VanCab
extends Node3D

## The van's cab and front: hood, windshield, a dim cab interior seen through it, mirrors and two
## real headlights, rebuilt from the look seed.

const HULL_PATH := ^"../Hull"
const VanCabParts := preload("res://scripts/van/look/van_cab_parts.gd")

const CAB_BACK_Z := -4.72
## Windshield foot.
const CAB_FRONT_Z := -6.3
## Grille face.
const NOSE_Z := -8.2
const CAB_HALF_W := 2.45
const CAB_ROOF_Y := 2.7
const HOOD_Y := 1.5
const BASE_Y := -0.25

const HEADLIGHT_ENERGY := 3.0
const HEADLIGHT_RANGE := 26.0
const HEADLIGHT_ANGLE := 30.0

## The two road lights; step 5b's kit may cage them.
var headlights: Array[SpotLight3D] = []

## Where the front kit (step 5b) bolts its ram and bumper.
var nose_z := NOSE_Z


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	headlights.clear()

	var hull := get_node_or_null(HULL_PATH) as VanHull
	if hull == null or hull.material == null:
		push_warning("VanCab: no Hull material at %s" % HULL_PATH)
		return

	var rng := look.rng_for(&"cab")
	var parts := VanCabParts.new(self)
	_build_body(hull.material, rng)
	_build_front_header(hull.material)
	_build_windshield()
	parts.build_interior()
	parts.build_mirrors(hull.material, rng)
	_build_headlights(rng)


func _build_body(mat: Material, rng: RandomNumberGenerator) -> void:
	var centre := Vector3(0.0, 1.0, -6.4)
	var profile: Array[Vector2] = [
		Vector2(CAB_BACK_Z, BASE_Y),
		Vector2(CAB_BACK_Z, CAB_ROOF_Y),
		Vector2(-5.5, CAB_ROOF_Y),
		Vector2(CAB_FRONT_Z, HOOD_Y + 0.1),
		Vector2(NOSE_Z + 0.2, HOOD_Y),
		Vector2(NOSE_Z, HOOD_Y - 0.15),
		Vector2(NOSE_Z, BASE_Y),
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Top/front skin: a quad strip between the two x ends along each profile edge.
	for i in range(profile.size() - 1):
		var z0: float = profile[i].x
		var y0: float = profile[i].y
		var z1: float = profile[i + 1].x
		var y1: float = profile[i + 1].y
		var l0 := Vector3(-CAB_HALF_W, y0, z0)
		var l1 := Vector3(-CAB_HALF_W, y1, z1)
		var r0 := Vector3(CAB_HALF_W, y0, z0)
		var r1 := Vector3(CAB_HALF_W, y1, z1)
		_add_quad(st, l0, l1, r1, r0, centre)

	# Side faces: triangulate the profile polygon and wind outward on each side.
	var poly := PackedVector2Array(profile)
	var indices := Geometry2D.triangulate_polygon(poly)
	for s: float in [-1.0, 1.0]:
		var x := s * CAB_HALF_W
		for i in range(0, indices.size(), 3):
			var a := Vector3(x, profile[indices[i]].y, profile[indices[i]].x)
			var b := Vector3(x, profile[indices[i + 1]].y, profile[indices[i + 1]].x)
			var c := Vector3(x, profile[indices[i + 2]].y, profile[indices[i + 2]].x)
			_add_tri(st, a, b, c, centre)

	st.generate_normals()
	# No tangents: the exterior shader projects in model space and this mesh carries no UVs.
	_add_mesh("CabBody", st.commit(), mat)

	var bulge_mesh := _box(Vector3(1.1, 0.16, 1.6))
	var bulge := _add_mesh("HoodBulge", bulge_mesh, mat, Vector3(0.0, HOOD_Y + 0.1, -7.2))
	bulge.scale = Vector3(1.0, rng.randf_range(0.8, 1.4), 1.0)


func _build_front_header(mat: Material) -> void:
	var z := CAB_BACK_Z - 0.06
	var w := 2.55
	var centre := Vector3(0.0, 2.0, z + 0.1)
	var x_steps := 16

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top_row: Array[Vector3] = []
	for ix in range(x_steps + 1):
		var t := float(ix) / float(x_steps)
		var x := lerpf(-w, w, t)
		var xt := x / w
		var y_top := 3.11 + 0.38 * (1.0 - xt * xt)
		top_row.append(Vector3(x, y_top, z))
	for ix in range(x_steps):
		var b0 := Vector3(top_row[ix].x, CAB_ROOF_Y, z)
		var b1 := Vector3(top_row[ix + 1].x, CAB_ROOF_Y, z)
		var t0 := top_row[ix]
		var t1 := top_row[ix + 1]
		_add_quad(st, b0, b1, t1, t0, centre)

	for s: float in [-1.0, 1.0]:
		var x_in := s * CAB_HALF_W
		var x_out := s * w
		var a := Vector3(x_in, BASE_Y, z)
		var b := Vector3(x_out, BASE_Y, z)
		var c := Vector3(x_out, CAB_ROOF_Y, z)
		var d := Vector3(x_in, CAB_ROOF_Y, z)
		_add_quad(st, a, b, c, d, centre)

	st.generate_normals()
	_add_mesh("FrontHeader", st.commit(), mat)


func _build_windshield() -> void:
	var hull := get_node_or_null(HULL_PATH) as VanHull
	if hull == null or hull.material == null:
		return
	var frame_mat := hull.material

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.02, 0.025, 0.03, 0.45)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.35
	glass_mat.metallic = 0.0
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var top_z := -5.5
	var top_y := CAB_ROOF_Y - 0.05
	var bot_z := CAB_FRONT_Z + 0.02
	var bot_y := HOOD_Y + 0.15
	var x := CAB_HALF_W - 0.15
	var centre := Vector3(0.0, 1.5, -6.0)

	var top_l := Vector3(-x, top_y, top_z)
	var top_r := Vector3(x, top_y, top_z)
	var bot_l := Vector3(-x, bot_y, bot_z)
	var bot_r := Vector3(x, bot_y, bot_z)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st, bot_l, bot_r, top_r, top_l, centre)
	st.generate_normals()
	var glass := _add_mesh("Windshield", st.commit(), glass_mat)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Four dark frame bars around the glass, on the hull material.
	var thickness := 0.08
	var top_len := top_l.distance_to(top_r)
	_add_mesh("WindshieldFrameTop", _box(Vector3(top_len, thickness, thickness)), frame_mat,
			(top_l + top_r) * 0.5)

	var bot_len := bot_l.distance_to(bot_r)
	_add_mesh("WindshieldFrameBottom", _box(Vector3(bot_len, thickness, thickness)), frame_mat,
			(bot_l + bot_r) * 0.5)

	var left_height := top_l.distance_to(bot_l)
	var left_bar := _add_mesh("WindshieldFrameLeft", _box(Vector3(thickness, left_height, thickness)),
			frame_mat, (top_l + bot_l) * 0.5)
	left_bar.rotation.x = atan2(top_l.y - bot_l.y, top_l.z - bot_l.z) - PI / 2.0

	var right_height := top_r.distance_to(bot_r)
	var right_bar := _add_mesh("WindshieldFrameRight", _box(Vector3(thickness, right_height, thickness)),
			frame_mat, (top_r + bot_r) * 0.5)
	right_bar.rotation.x = atan2(top_r.y - bot_r.y, top_r.z - bot_r.z) - PI / 2.0


func _build_headlights(_rng: RandomNumberGenerator) -> void:
	var hull := get_node_or_null(HULL_PATH) as VanHull
	if hull == null or hull.material == null:
		return
	var mat := hull.material

	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.9, 0.85, 0.7)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(1.0, 0.9, 0.7)
	lens_mat.emission_energy_multiplier = 2.0

	for s: float in [-1.0, 1.0]:
		var suffix := "L" if s < 0.0 else "R"

		_add_mesh("HeadlightHousing%s" % suffix, _box(Vector3(0.5, 0.32, 0.12)), mat,
				Vector3(s * 1.75, 0.95, NOSE_Z - 0.06))

		var lens_mesh := CylinderMesh.new()
		lens_mesh.top_radius = 0.13
		lens_mesh.bottom_radius = 0.13
		lens_mesh.height = 0.04
		var lens := _add_mesh("HeadlightLens%s" % suffix, lens_mesh, lens_mat,
				Vector3(s * 1.75, 0.95, NOSE_Z - 0.13), Vector3(deg_to_rad(90.0), 0.0, 0.0))
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var light := SpotLight3D.new()
		light.name = "Headlight%s" % suffix
		light.position = Vector3(s * 1.75, 0.95, NOSE_Z - 0.2)
		light.rotation_degrees = Vector3(-7.0, 0.0, 0.0)
		light.light_energy = HEADLIGHT_ENERGY
		light.spot_range = HEADLIGHT_RANGE
		light.spot_angle = HEADLIGHT_ANGLE
		light.spot_attenuation = 1.0
		light.spot_angle_attenuation = 0.9
		light.light_color = Color(1.0, 0.92, 0.78)
		light.shadow_enabled = false
		light.light_cull_mask = 1
		add_child(light)
		headlights.append(light)


func _add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _dark_material(albedo: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = 0.0
	return mat


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		centre: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var to_face := ((a + b + c + d) * 0.25 - centre).normalized()
	if normal.dot(to_face) < 0.0:
		st.add_vertex(a)
		st.add_vertex(d)
		st.add_vertex(c)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(d)


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var to_face := ((a + b + c) / 3.0 - centre).normalized()
	if normal.dot(to_face) < 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
