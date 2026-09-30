extends RefCounted
## Steel stop strips round each side door bay on the cabin side, covering the leaf's clearance.

const _Cove := preload("res://scripts/van/van_ceiling_cove.gd")

## Copied from side_door_leaf.gd: the closed leaf's half length and its inset from the bay's edge.
const DOOR_HALF_Z := 1.105
const JAMB_CLEAR := 0.13

## Plate depths inboard of the wall's cabin face: 2 cm clear of the leaf's PerimeterFrame.
const _D_STREET := 0.075
const _D_CABIN := 0.09
## Return depths: the back sunk clear of the slide track's faces; the front against the plate.
const _D_BACK := -0.035
const _D_FRONT := 0.075
## Width of the return bands that fold into the bay along its top, bottom and rear edges.
const _R := 0.015

var _walls: VanSideWall


func _init(walls: VanSideWall) -> void:
	_walls = walls


func add_door_stops(wall_sign: float, mat: Material) -> void:
	var cz := _walls.door_center_z
	var hl := _walls.door_half_length
	var ji := _walls.door_jamb_inset
	var y0 := _walls.door_y_min
	var y1 := _walls.door_y_max
	var face_z := VanFrontWall.FACE_Z
	var parent := _walls.get_parent()
	var ceiling: VanCeiling = null
	if parent != null:
		ceiling = parent.get_node_or_null("Ceiling") as VanCeiling
	var yb := y1 - ji + 0.05
	if ceiling != null:
		yb = _Cove.join(_walls, ceiling).y - 0.05
	var zo0 := face_z - 0.02
	var zo1 := cz + hl - ji + 0.05
	var yo0 := y0 + ji - 0.05
	var yo1 := yb
	var zi0 := face_z + 0.07
	var zi1 := cz + DOOR_HALF_Z - 0.05
	var yi0 := y0 + JAMB_CLEAR + 0.05
	var yi1 := y1 - JAMB_CLEAR - 0.05
	if yo1 <= yi1 or zo1 <= zi1 or yo0 >= yi0 or zo0 >= zi0 or yi0 >= yi1 or zi0 >= zi1:
		return
	var node_name := "DoorStop_L" if wall_sign < 0.0 else "DoorStop_R"
	var old := _walls.get_node_or_null(node_name)
	if old != null:
		old.free()
	var rows: Array[float] = []
	for k in 17:
		var y := yo0 + (yo1 - yo0) * float(k) / 16.0
		if absf(y - yi0) >= 0.001 and absf(y - yi1) >= 0.001:
			rows.append(y)
	rows.append(yi0)
	rows.append(yi1)
	rows.sort()
	var cols: Array[float] = [zo0, zi0, zi1, zo1]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_plate(st, wall_sign, rows, cols, yi0, yi1)
	_build_returns(st, wall_sign, rows, zo0, zo1)
	st.generate_tangents()
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = st.commit()
	if mat != null:
		node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.layers = VanLighting.LAYER_VAN_INTERIOR
	_walls.add_child(node)


func _build_plate(st: SurfaceTool, s: float, rows: Array[float], cols: Array[float],
		yi0: float, yi1: float) -> void:
	var cabin := Vector3(-s, 0.0, 0.0)
	var street := Vector3(s, 0.0, 0.0)
	var yo0 := rows[0]
	var yo1 := rows[rows.size() - 1]
	var zo0 := cols[0]
	var zi0 := cols[1]
	var zi1 := cols[2]
	var zo1 := cols[3]
	for i in rows.size() - 1:
		var ya := rows[i]
		var yb := rows[i + 1]
		var inside := ya >= yi0 and yb <= yi1
		for j in cols.size() - 1:
			if inside and j == 1:
				continue
			_face_d(st, s, _D_CABIN, ya, yb, cols[j], cols[j + 1], cabin)
			_face_d(st, s, _D_STREET, ya, yb, cols[j], cols[j + 1], street)
		if inside:
			_face_z(st, s, zi0, _D_STREET, _D_CABIN, ya, yb, Vector3(0.0, 0.0, 1.0))
			_face_z(st, s, zi1, _D_STREET, _D_CABIN, ya, yb, Vector3(0.0, 0.0, -1.0))
		_face_z(st, s, zo1, _D_STREET, _D_CABIN, ya, yb, Vector3(0.0, 0.0, 1.0))
		_face_z(st, s, zo0, _D_STREET, _D_CABIN, ya, yb, Vector3(0.0, 0.0, -1.0))
	_face_y(st, s, yi0, _D_STREET, _D_CABIN, zi0, zi1, Vector3.UP)
	_face_y(st, s, yi1, _D_STREET, _D_CABIN, zi0, zi1, Vector3.DOWN)
	for j in cols.size() - 1:
		_face_y(st, s, yo1, _D_STREET, _D_CABIN, cols[j], cols[j + 1], Vector3.UP)
		_face_y(st, s, yo0, _D_STREET, _D_CABIN, cols[j], cols[j + 1], Vector3.DOWN)


func _build_returns(st: SurfaceTool, s: float, rows: Array[float], zo0: float,
		zo1: float) -> void:
	var street := Vector3(s, 0.0, 0.0)
	var cabin := Vector3(-s, 0.0, 0.0)
	var yo0 := rows[0]
	var yo1 := rows[rows.size() - 1]
	var back := Vector3(0.0, 0.0, -1.0)
	var rear := Vector3(0.0, 0.0, 1.0)
	# Bottom and top bands: closed boxes along the whole bay length.
	for band in 2:
		var lo := yo0 if band == 0 else yo1 - _R
		var hi := yo0 + _R if band == 0 else yo1
		_face_y(st, s, yo0 if band == 0 else yo1, _D_BACK, _D_FRONT, zo0, zo1,
			Vector3.DOWN if band == 0 else Vector3.UP)
		_face_y(st, s, hi if band == 0 else lo, _D_BACK, _D_FRONT, zo0, zo1,
			Vector3.UP if band == 0 else Vector3.DOWN)
		_face_d(st, s, _D_BACK, lo, hi, zo0, zo1, street)
		_face_d(st, s, _D_FRONT, lo, hi, zo0, zo1, cabin)
		_face_z(st, s, zo0, _D_BACK, _D_FRONT, lo, hi, back)
		_face_z(st, s, zo1, _D_BACK, _D_FRONT, lo, hi, rear)
	# Rear band: rows are the band's ends plus every plate row between them.
	var rrows: Array[float] = [yo0 + _R]
	for y in rows:
		if y > yo0 + _R and y < yo1 - _R:
			rrows.append(y)
	rrows.append(yo1 - _R)
	for i in rrows.size() - 1:
		var ya := rrows[i]
		var yb := rrows[i + 1]
		_face_z(st, s, zo1, _D_BACK, _D_FRONT, ya, yb, rear)
		_face_z(st, s, zo1 - _R, _D_BACK, _D_FRONT, ya, yb, back)
		_face_d(st, s, _D_BACK, ya, yb, zo1 - _R, zo1, street)
		_face_d(st, s, _D_FRONT, ya, yb, zo1 - _R, zo1, cabin)
	_face_y(st, s, yo0 + _R, _D_BACK, _D_FRONT, zo1 - _R, zo1, Vector3.DOWN)
	_face_y(st, s, yo1 - _R, _D_BACK, _D_FRONT, zo1 - _R, zo1, Vector3.UP)


## A point at depth d inboard of the wall's cabin face, height y, length z.
func _p(s: float, d: float, y: float, z: float) -> Vector3:
	return Vector3(s * (_walls.wall_x_at(y) - d), y, z)


## Quad lying at one depth, spanning rows ya..yb and z za..zb.
func _face_d(st: SurfaceTool, s: float, d: float, ya: float, yb: float, za: float,
		zb: float, out: Vector3) -> void:
	_quad(st, _p(s, d, ya, za), _p(s, d, ya, zb), _p(s, d, yb, zb), _p(s, d, yb, za), out)


## Quad at one z, spanning depths d0..d1 and y ya..yb.
func _face_z(st: SurfaceTool, s: float, z: float, d0: float, d1: float, ya: float,
		yb: float, out: Vector3) -> void:
	_quad(st, _p(s, d0, ya, z), _p(s, d1, ya, z), _p(s, d1, yb, z), _p(s, d0, yb, z), out)


## Quad at one height, spanning depths d0..d1 and z za..zb.
func _face_y(st: SurfaceTool, s: float, y: float, d0: float, d1: float, za: float,
		zb: float, out: Vector3) -> void:
	_quad(st, _p(s, d0, y, za), _p(s, d1, y, za), _p(s, d1, y, zb), _p(s, d0, y, zb), out)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		out: Vector3) -> void:
	_tri(st, a, b, c, out)
	_tri(st, a, c, d, out)


## Godot front faces are clockwise seen from outside, so flip any triangle that isn't.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var second := b
	var third := c
	if (c - a).cross(b - a).dot(out) < 0.0:
		second = c
		third = b
	var n := (third - a).cross(second - a).normalized()
	for p in [a, second, third]:
		var v: Vector3 = p
		st.set_normal(n)
		st.set_uv(Vector2(v.z, v.y))
		st.add_vertex(v)
