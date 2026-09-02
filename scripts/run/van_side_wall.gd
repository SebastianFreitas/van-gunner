class_name VanSideWall
extends Node3D

## Curved cargo-van side liners: wider at the floor, bowed out at the waist,
## tapering in toward the roof — with punched openings for windows / side doors.

@export var wall_height := 3.08
@export var span_z := 9.4
@export var bottom_half_width := 2.42
@export var top_half_width := 2.00
## Extra outward bulge at mid-height (meters). Makes the body read as curved, not a flat lean.
@export var bow_out := 0.18
@export var thickness := 0.10
@export var y_segments := 32
@export var z_segments := 64
@export var wall_material: Material
@export var rebuild_on_ready := true

## Window openings (match SideWindows layout).
@export var window_half_height := 0.84
@export var window_half_length := 1.46
@export var window_center_y := 1.775
@export var window_centers_z: PackedFloat32Array = PackedFloat32Array([2.835, -0.375])

## Side-door openings (match SideDoors layout).
@export var door_half_length := 1.30
@export var door_center_z := -3.485
@export var door_y_min := 0.02
@export var door_y_max := 3.05

var _built := false


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_build()


func wall_x_at(y: float) -> float:
	return _profile_x(y)


func lean_angle_at(y: float) -> float:
	## Radians: rotation around Z for a right-side panel at height y (left uses negative).
	var eps := 0.02
	var x0 := _profile_x(y - eps)
	var x1 := _profile_x(y + eps)
	return atan2(x0 - x1, eps * 2.0)


func _build() -> void:
	if _built:
		return
	_built = true

	var mat := wall_material if wall_material else _default_wall_material()
	_add_side(&"LeftWall", -1.0, mat)
	_add_side(&"RightWall", 1.0, mat)
	_add_cargo_rails(mat)


func _add_side(side_name: StringName, sign: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = String(side_name)
	mi.mesh = _build_side_mesh(sign)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _build_side_mesh(sign: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_z := span_z * 0.5
	var verts: Array = []
	var uvs: Array = []
	var solid: Array = []

	for iy in range(y_segments + 1):
		var row_v: Array = []
		var row_uv: Array = []
		var row_solid: Array = []
		var ty := float(iy) / float(y_segments)
		var y := ty * wall_height
		var x_inner := sign * _profile_x(y)
		for iz in range(z_segments + 1):
			var tz := float(iz) / float(z_segments)
			var z := lerpf(-half_z, half_z, tz)
			row_v.append(Vector3(x_inner, y, z))
			row_uv.append(Vector2(tz, ty))
			row_solid.append(not _is_open(y, z))
		verts.append(row_v)
		uvs.append(row_uv)
		solid.append(row_solid)

	# Interior face (normals toward cabin).
	for iy in range(y_segments):
		for iz in range(z_segments):
			# Keep a cell if its center is solid — cleaner punched openings.
			var y_mid := (float(iy) + 0.5) / float(y_segments) * wall_height
			var z_mid := lerpf(-half_z, half_z, (float(iz) + 0.5) / float(z_segments))
			if _is_open(y_mid, z_mid):
				continue
			var v00: Vector3 = verts[iy][iz]
			var v10: Vector3 = verts[iy][iz + 1]
			var v01: Vector3 = verts[iy + 1][iz]
			var v11: Vector3 = verts[iy + 1][iz + 1]
			var uv00: Vector2 = uvs[iy][iz]
			var uv10: Vector2 = uvs[iy][iz + 1]
			var uv01: Vector2 = uvs[iy + 1][iz]
			var uv11: Vector2 = uvs[iy + 1][iz + 1]
			if sign > 0.0:
				# Right wall: wind so normals face -X (into room).
				_add_tri(st, v00, uv00, v01, uv01, v10, uv10)
				_add_tri(st, v10, uv10, v01, uv01, v11, uv11)
			else:
				_add_tri(st, v00, uv00, v10, uv10, v01, uv01)
				_add_tri(st, v10, uv10, v11, uv11, v01, uv01)

	# Outer skin (thin shell so openings have depth).
	var outer: Array = []
	for iy in range(y_segments + 1):
		var row: Array = []
		var y := float(iy) / float(y_segments) * wall_height
		var x_inner := sign * _profile_x(y)
		var x_outer := x_inner + sign * thickness
		for iz in range(z_segments + 1):
			var z := lerpf(-half_z, half_z, float(iz) / float(z_segments))
			row.append(Vector3(x_outer, y, z))
		outer.append(row)

	for iy in range(y_segments):
		for iz in range(z_segments):
			var y_mid := (float(iy) + 0.5) / float(y_segments) * wall_height
			var z_mid := lerpf(-half_z, half_z, (float(iz) + 0.5) / float(z_segments))
			if _is_open(y_mid, z_mid):
				continue
			var v00: Vector3 = outer[iy][iz]
			var v10: Vector3 = outer[iy][iz + 1]
			var v01: Vector3 = outer[iy + 1][iz]
			var v11: Vector3 = outer[iy + 1][iz + 1]
			var uv00: Vector2 = uvs[iy][iz]
			var uv10: Vector2 = uvs[iy][iz + 1]
			var uv01: Vector2 = uvs[iy + 1][iz]
			var uv11: Vector2 = uvs[iy + 1][iz + 1]
			if sign > 0.0:
				_add_tri(st, v00, uv00, v10, uv10, v01, uv01)
				_add_tri(st, v10, uv10, v11, uv11, v01, uv01)
			else:
				_add_tri(st, v00, uv00, v01, uv01, v10, uv10)
				_add_tri(st, v10, uv10, v01, uv01, v11, uv11)

	# Opening returns (thickness around cutouts).
	_add_opening_returns(st, sign, verts, outer, uvs, solid)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _add_opening_returns(
	st: SurfaceTool,
	sign: float,
	inner: Array,
	outer: Array,
	uvs: Array,
	solid: Array
) -> void:
	for iy in range(y_segments):
		for iz in range(z_segments):
			var s00: bool = solid[iy][iz]
			var s10: bool = solid[iy][iz + 1]
			var s01: bool = solid[iy + 1][iz]
			# Vertical edge along +Z of cell when solidity changes across z.
			if s00 != s10:
				_add_return_quad(
					st, sign,
					inner[iy][iz + 1], outer[iy][iz + 1],
					inner[iy + 1][iz + 1], outer[iy + 1][iz + 1],
					uvs[iy][iz + 1], uvs[iy + 1][iz + 1],
					s00
				)
			# Horizontal edge along +Y of cell when solidity changes across y.
			if s00 != s01:
				_add_return_quad(
					st, sign,
					inner[iy + 1][iz], outer[iy + 1][iz],
					inner[iy + 1][iz + 1], outer[iy + 1][iz + 1],
					uvs[iy + 1][iz], uvs[iy + 1][iz + 1],
					s00
				)


func _add_return_quad(
	st: SurfaceTool,
	sign: float,
	i_a: Vector3, o_a: Vector3,
	i_b: Vector3, o_b: Vector3,
	uv_a: Vector2, uv_b: Vector2,
	solid_on_neg: bool
) -> void:
	# Bridge inner→outer along the cut. Winding depends on which side is solid.
	if solid_on_neg == (sign > 0.0):
		_add_tri(st, i_a, uv_a, o_a, uv_a, i_b, uv_b)
		_add_tri(st, i_b, uv_b, o_a, uv_a, o_b, uv_b)
	else:
		_add_tri(st, i_a, uv_a, i_b, uv_b, o_a, uv_a)
		_add_tri(st, i_b, uv_b, o_b, uv_b, o_a, uv_a)


func _add_cargo_rails(mat: Material) -> void:
	# Lower tie rail sits under the windows — run full length except the door bay.
	_add_rail_segments(mat, 0.72, _solid_z_ranges_below_windows())
	# Mid belt rail only on solid spans between openings.
	_add_rail_segments(mat, 1.52, _solid_z_ranges_mid())


func _add_rail_segments(mat: Material, rail_y: float, ranges: Array) -> void:
	var x := _profile_x(rail_y)
	var lean := lean_angle_at(rail_y)
	var idx := 0
	for span in ranges:
		var z0: float = span[0]
		var z1: float = span[1]
		var length: float = z1 - z0
		if length < 0.35:
			continue
		var z_mid := (z0 + z1) * 0.5
		for sign in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			rail.name = "CargoRail_%s_%d" % ["L" if sign < 0.0 else "R", idx]
			var box := BoxMesh.new()
			box.size = Vector3(0.045, 0.06, length)
			rail.mesh = box
			rail.material_override = mat
			# Sit just proud of the interior face.
			rail.position = Vector3(sign * (x - sign * 0.025), rail_y, z_mid)
			rail.rotation.z = sign * lean
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(rail)
		idx += 1


func _solid_z_ranges_below_windows() -> Array:
	# Full cargo length minus side-door bay.
	var half := span_z * 0.5
	var door0 := door_center_z - door_half_length
	var door1 := door_center_z + door_half_length
	return [[-half + 0.1, door0 - 0.04], [door1 + 0.04, half - 0.1]]


func _solid_z_ranges_mid() -> Array:
	var half := span_z * 0.5
	var cuts: Array = []
	for cz in window_centers_z:
		cuts.append([cz - window_half_length, cz + window_half_length])
	cuts.append([door_center_z - door_half_length, door_center_z + door_half_length])
	cuts.sort_custom(func(a, b): return a[0] < b[0])

	var ranges: Array = []
	var cursor := -half + 0.1
	for cut in cuts:
		var c0: float = cut[0]
		var c1: float = cut[1]
		if c0 > cursor + 0.3:
			ranges.append([cursor, c0 - 0.03])
		cursor = maxf(cursor, c1 + 0.03)
	if cursor < half - 0.4:
		ranges.append([cursor, half - 0.1])
	return ranges


func _profile_x(y: float) -> float:
	var t := clampf(y / maxf(wall_height, 0.001), 0.0, 1.0)
	# Ease taper toward the roof so the upper third reads clearly narrower.
	var taper_t := t * t
	var taper := lerpf(bottom_half_width, top_half_width, taper_t)
	var bow := bow_out * sin(PI * t)
	return taper + bow


func _is_open(y: float, z: float) -> bool:
	# Side door bay (full height).
	if y >= door_y_min and y <= door_y_max and absf(z - door_center_z) <= door_half_length:
		return true
	# Window bays.
	if absf(y - window_center_y) <= window_half_height:
		for cz in window_centers_z:
			if absf(z - cz) <= window_half_length:
				return true
	return false


func _add_tri(
	st: SurfaceTool,
	a: Vector3, uva: Vector2,
	b: Vector3, uvb: Vector2,
	c: Vector3, uvc: Vector2
) -> void:
	st.set_uv(uva)
	st.add_vertex(a)
	st.set_uv(uvb)
	st.add_vertex(b)
	st.set_uv(uvc)
	st.add_vertex(c)


func _default_wall_material() -> ShaderMaterial:
	var sh := load("res://scenes/van/van_wall.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("wall_size_m", Vector2(span_z, wall_height))
	return mat
