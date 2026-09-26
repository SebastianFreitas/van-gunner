extends RefCounted
## Appends armour piece geometry (plates, bars, spikes, signs, a car door) into per-material SurfaceTools for VanArmour.

const FACE_X := 2.6

## SurfaceTool per material key: &"plate", &"rebar", &"sign", &"glass".
var tools: Dictionary = {}
## Whether each key has received any geometry yet.
var _used: Dictionary = {}


func _init() -> void:
	for key: StringName in [&"plate", &"rebar", &"sign", &"glass"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = st


func has_geometry(key: StringName) -> bool:
	return _used.get(key, false)


func add_box(key: StringName, size: Vector3, xform: Transform3D) -> void:
	var m := BoxMesh.new()
	m.size = size
	tools[key].append_from(m, 0, xform)
	_used[key] = true


func add_plate(side: float, z: float, y: float, w: float, h: float, tilt_deg: float, layer: int) -> void:
	var x := side * (FACE_X + 0.035 * float(layer))
	var m := BoxMesh.new()
	m.size = Vector3(0.04, h, w)
	var basis := Basis(Vector3.RIGHT, deg_to_rad(tilt_deg))
	tools[&"plate"].append_from(m, 0, Transform3D(basis, Vector3(x, y, z)))
	_used[&"plate"] = true


func add_bar(key: StringName, from: Vector3, to: Vector3, thickness: float) -> void:
	var dir := to - from
	var length := dir.length()
	if length < 0.0001:
		return
	var up := Vector3.UP
	if absf(dir.normalized().y) > 0.95:
		up = Vector3.RIGHT
	var basis := Basis.looking_at(dir, up)
	var mid := (from + to) * 0.5
	var m := BoxMesh.new()
	m.size = Vector3(thickness, thickness, length)
	tools[key].append_from(m, 0, Transform3D(basis, mid))
	_used[key] = true


## Builds an orthonormal basis whose +Y column points along dir.
func _basis_from_y(dir: Vector3) -> Basis:
	var y_axis := dir.normalized()
	var ref_axis := Vector3.FORWARD
	if absf(y_axis.dot(Vector3.FORWARD)) > 0.95:
		ref_axis = Vector3.RIGHT
	var x_axis := ref_axis.cross(y_axis).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func add_spike(side: float, pos: Vector3, length: float) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = 0.045
	cyl.height = length
	cyl.radial_segments = 6
	var dir := Vector3(side, tan(deg_to_rad(25.0)), 0.0).normalized()
	var basis := _basis_from_y(dir)
	var origin := pos + dir * (length * 0.5)
	tools[&"rebar"].append_from(cyl, 0, Transform3D(basis, origin))
	_used[&"rebar"] = true


func add_sign(side: float, z: float, y: float, size: float, shape: int) -> void:
	var x := side * (FACE_X + 0.07)
	match shape:
		0:
			var m := BoxMesh.new()
			m.size = Vector3(0.03, size, size)
			var basis := Basis(Vector3.RIGHT, deg_to_rad(45.0))
			tools[&"sign"].append_from(m, 0, Transform3D(basis, Vector3(x, y, z)))
		1:
			var wide := BoxMesh.new()
			wide.size = Vector3(0.03, size * 0.42, size)
			tools[&"sign"].append_from(wide, 0, Transform3D(Basis(), Vector3(x, y, z)))
			var tall := BoxMesh.new()
			tall.size = Vector3(0.03, size, size * 0.42)
			tools[&"sign"].append_from(tall, 0, Transform3D(Basis(), Vector3(x, y, z)))
		_:
			var rect := BoxMesh.new()
			rect.size = Vector3(0.03, size * 0.7, size * 1.2)
			tools[&"sign"].append_from(rect, 0, Transform3D(Basis(), Vector3(x, y, z)))
	_used[&"sign"] = true
	add_box(&"rebar", Vector3(0.04, 0.04, 0.04), Transform3D(Basis(), Vector3(x, y + size * 0.3, z)))
	add_box(&"rebar", Vector3(0.04, 0.04, 0.04), Transform3D(Basis(), Vector3(x, y - size * 0.3, z)))


func add_car_door(side: float, z: float, y: float) -> void:
	var x := side * (FACE_X + 0.06)
	var lower_y := y - 0.2
	var window_bottom := lower_y + 0.225
	var window_top := window_bottom + 0.4
	var window_center := (window_bottom + window_top) * 0.5
	var half_w := 0.55
	add_box(&"plate", Vector3(0.05, 0.45, 1.1), Transform3D(Basis(), Vector3(x, lower_y, z)))
	add_bar(&"plate", Vector3(x, window_bottom, z - half_w), Vector3(x, window_top, z - half_w), 0.05)
	add_bar(&"plate", Vector3(x, window_bottom, z + half_w), Vector3(x, window_top, z + half_w), 0.05)
	add_bar(&"plate", Vector3(x, window_top, z - half_w), Vector3(x, window_top, z + half_w), 0.05)
	add_box(&"glass", Vector3(0.02, 0.36, 0.96), Transform3D(Basis(), Vector3(x, window_center, z)))
	add_box(&"rebar", Vector3(0.03, 0.04, 0.14), Transform3D(Basis(), Vector3(x, lower_y, z + 0.4)))
