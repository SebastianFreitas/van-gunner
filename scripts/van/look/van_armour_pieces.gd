extends RefCounted
## Appends armour piece geometry (leaned plates, bars, spikes) into per-material SurfaceTools for VanArmour.

## SurfaceTool per material key: &"plate", &"rebar".
var tools: Dictionary = {}
## Whether each key has received any geometry yet.
var _used: Dictionary = {}


func _init() -> void:
	for key: StringName in [&"plate", &"rebar"]:
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


## Plate whose inner face runs from x0 (at y - h/2) to x1 (at y + h/2), mirrored by side, then
## tilted about X. Each layer stands 2 cm further out so stacked faces are 2 cm apart.
func add_plate(side: float, z: float, y: float, w: float, h: float, tilt_deg: float, layer: int,
		x0: float, x1: float) -> void:
	var lift := 0.02 * float(layer)
	var dx := side * (x1 - x0)
	var length := sqrt(dx * dx + h * h)
	var lean_rad := atan2(-dx, h)
	var lean := Basis(Vector3.BACK, lean_rad)
	var normal := side * Vector3(cos(lean_rad), sin(lean_rad), 0.0)
	var mid := Vector3(side * (x0 + x1 + 2.0 * lift) * 0.5, y, z)
	var m := BoxMesh.new()
	m.size = Vector3(0.04, length, w)
	var basis := lean * Basis(Vector3.RIGHT, deg_to_rad(tilt_deg))
	tools[&"plate"].append_from(m, 0, Transform3D(basis, mid + normal * 0.02))
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
