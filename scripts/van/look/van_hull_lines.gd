extends RefCounted
## Truck-body lines molded onto VanHull's outer skin: rub rails, belt line, drip rail and corner
## posts, all clear of the windows and side door so raiders can still breach through them.

var _hull: Node3D
var _profile: VanBodyProfile
var _walls: VanSideWall
var _mat: ShaderMaterial


func _init(hull: Node3D) -> void:
	_hull = hull


## Builds every body line for both sides of the van.
func build(profile: VanBodyProfile, walls: VanSideWall, mat: ShaderMaterial) -> void:
	_profile = profile
	_walls = walls
	_mat = mat

	for wall_sign: float in [-1.0, 1.0]:
		_build_body_lines(wall_sign)

	var half_len := profile.half_length()
	_build_corner_post("CornerPostFL", -1.0, -half_len + 0.06)
	_build_corner_post("CornerPostFR", 1.0, -half_len + 0.06)
	_build_corner_post("CornerPostRL", -1.0, half_len - 0.06)
	_build_corner_post("CornerPostRR", 1.0, half_len - 0.06)


## X of the skin at height `y`, matching where SideSkin/RoofSkin already sit.
func _skin_x(y: float) -> float:
	return _profile.inner_x_at(y) + VanHull.SKIN_OFFSET_M


## The rub rail, belt line and drip rail for one side, clear of that side's openings.
func _build_body_lines(side_sign: float) -> void:
	var suffix := "L" if side_sign < 0.0 else "R"
	var z_min := -_profile.half_length() + 0.05
	var z_max := _profile.half_length() - 0.05

	var rub_ranges := _clear_ranges(z_min, z_max, 0.95)
	for i in range(rub_ranges.size()):
		var r: Vector2 = rub_ranges[i]
		_build_strip("RubRail%s%d" % [suffix, i], 0.95, r.x, r.y, 0.09, 0.05, side_sign)

	var belt_ranges := _clear_ranges(z_min, z_max, 2.62)
	for i in range(belt_ranges.size()):
		var r: Vector2 = belt_ranges[i]
		_build_strip("BeltLine%s%d" % [suffix, i], 2.62, r.x, r.y, 0.05, 0.03, side_sign)

	var drip_y := _profile.wall_height() - 0.04
	var drip_ranges := _clear_ranges(z_min, z_max, drip_y)
	var single := drip_ranges.size() == 1
	for i in range(drip_ranges.size()):
		var r: Vector2 = drip_ranges[i]
		var drip_name := ("DripRail%s" % suffix) if single else ("DripRail%s%d" % [suffix, i])
		_build_strip(drip_name, drip_y, r.x, r.y, 0.06, 0.07, side_sign)


## The z-ranges within [z_min, z_max] at height `y` that clear every window and the side door
## (each padded by 6 cm). Pieces shorter than 0.15 m are dropped.
func _clear_ranges(z_min: float, z_max: float, y: float) -> Array[Vector2]:
	var pad := 0.06
	var blocks: Array[Vector2] = []
	for cz: float in _walls.window_centers_z:
		var wy0 := _walls.window_center_y - _walls.window_half_height - pad
		var wy1 := _walls.window_center_y + _walls.window_half_height + pad
		if y >= wy0 and y <= wy1:
			blocks.append(Vector2(cz - _walls.window_half_length - pad, cz + _walls.window_half_length + pad))
	if y >= _walls.door_y_min - pad and y <= _walls.door_y_max + pad:
		blocks.append(Vector2(
			_walls.door_center_z - _walls.door_half_length - pad,
			_walls.door_center_z + _walls.door_half_length + pad,
		))

	blocks.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var merged: Array[Vector2] = []
	for b: Vector2 in blocks:
		if merged.is_empty() or b.x > merged[merged.size() - 1].y:
			merged.append(b)
		else:
			var last: Vector2 = merged[merged.size() - 1]
			merged[merged.size() - 1] = Vector2(last.x, maxf(last.y, b.y))

	var ranges: Array[Vector2] = []
	var cursor := z_min
	for b: Vector2 in merged:
		var seg_end: float = clampf(b.x, z_min, z_max)
		if seg_end - cursor >= 0.15:
			ranges.append(Vector2(cursor, seg_end))
		cursor = maxf(cursor, clampf(b.y, z_min, z_max))
	if z_max - cursor >= 0.15:
		ranges.append(Vector2(cursor, z_max))
	return ranges


## A horizontal box-section strip hugging the skin from z0 to z1 at height y, leaning with the
## wall's bow so it stays flush against the skin.
func _build_strip(node_name: String, y: float, z0: float, z1: float, height: float, proud: float, side_sign: float) -> void:
	var length := z1 - z0
	if length < 0.15:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(proud, height, length)

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = _mat
	mi.position = Vector3(side_sign * (_skin_x(y) + proud * 0.5), y, (z0 + z1) * 0.5)
	mi.rotation.z = _walls.lean_angle_at(y) * side_sign
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hull.add_child(mi)


## A vertical corner post at box corner `z`, following the bow from floor to roof: an outer face
## plus two end-cap faces so it reads as a proud edge rather than a flat decal.
func _build_corner_post(node_name: String, side_sign: float, z: float) -> void:
	var z0 := z - 0.06
	var z1 := z + 0.06
	var steps := 12
	var rows: Array[Array] = []
	for i in range(steps + 1):
		var y := lerpf(0.0, _profile.wall_height(), float(i) / float(steps))
		var x_in := side_sign * _skin_x(y)
		var x_out := side_sign * (_skin_x(y) + 0.06)
		rows.append([
			Vector3(x_in, y, z0), Vector3(x_in, y, z1),
			Vector3(x_out, y, z0), Vector3(x_out, y, z1),
		])

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(steps):
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var a_in0: Vector3 = a[0]
		var a_in1: Vector3 = a[1]
		var a_out0: Vector3 = a[2]
		var a_out1: Vector3 = a[3]
		var b_in0: Vector3 = b[0]
		var b_in1: Vector3 = b[1]
		var b_out0: Vector3 = b[2]
		var b_out1: Vector3 = b[3]

		# Outer face (normal outward along X); winding flips with sign, as the roof lip does.
		if side_sign > 0.0:
			_tri_uv(st, a_out0, a_out1, b_out0, Vector2(0, t0), Vector2(1, t0), Vector2(0, t1))
			_tri_uv(st, a_out1, b_out1, b_out0, Vector2(1, t0), Vector2(1, t1), Vector2(0, t1))
		else:
			_tri_uv(st, a_out0, b_out0, a_out1, Vector2(0, t0), Vector2(0, t1), Vector2(1, t0))
			_tri_uv(st, a_out1, b_out0, b_out1, Vector2(1, t0), Vector2(0, t1), Vector2(1, t1))

		# z0 end cap (normal -Z); winding flips with sign, as the rear posts do.
		if side_sign < 0.0:
			_tri_uv(st, a_in0, a_out0, b_in0, Vector2(0, t0), Vector2(1, t0), Vector2(0, t1))
			_tri_uv(st, a_out0, b_out0, b_in0, Vector2(1, t0), Vector2(1, t1), Vector2(0, t1))
		else:
			_tri_uv(st, a_in0, b_in0, a_out0, Vector2(0, t0), Vector2(0, t1), Vector2(1, t0))
			_tri_uv(st, a_out0, b_in0, b_out0, Vector2(1, t0), Vector2(0, t1), Vector2(1, t1))

		# z1 end cap (normal +Z).
		if side_sign > 0.0:
			_tri_uv(st, a_in1, a_out1, b_in1, Vector2(0, t0), Vector2(1, t0), Vector2(0, t1))
			_tri_uv(st, a_out1, b_out1, b_in1, Vector2(1, t0), Vector2(1, t1), Vector2(0, t1))
		else:
			_tri_uv(st, a_in1, b_in1, a_out1, Vector2(0, t0), Vector2(0, t1), Vector2(1, t0))
			_tri_uv(st, a_out1, b_in1, b_out1, Vector2(1, t0), Vector2(0, t1), Vector2(1, t1))

	st.generate_normals()
	st.generate_tangents()

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = _mat
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hull.add_child(mi)


## Adds one triangle with per-vertex UVs (needed so generate_tangents has something to work from).
func _tri_uv(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2) -> void:
	st.set_uv(uv0)
	st.add_vertex(p0)
	st.set_uv(uv1)
	st.add_vertex(p1)
	st.set_uv(uv2)
	st.add_vertex(p2)
