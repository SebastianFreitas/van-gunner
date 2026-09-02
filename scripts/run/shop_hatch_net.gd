extends Node3D

## Cargo-net screen on the shop hatch — thin diamond mesh, not solid bars.

@export var net_height := 5.5
@export var net_width := 7.6
@export var mesh_spacing := 0.38
@export var wire_size := 0.022
@export var wire_depth := 0.032
@export var net_offset_x := -0.06
@export var frame_thickness := 0.07
@export var frame_depth := 0.1


func _ready() -> void:
	_build()


func _build() -> void:
	var steel := _steel_material()
	var mesh_mat := _mesh_material()

	var half_h := net_height * 0.5
	var half_w := net_width * 0.5
	var inset := frame_thickness * 0.55
	var bottom_y := -half_h + inset
	var top_y := half_h - inset
	var left_z := -half_w + inset
	var right_z := half_w - inset

	_add_frame_rail(
		"FrameTop",
		Vector3(frame_depth, frame_thickness, right_z - left_z),
		Vector3(net_offset_x, top_y, 0.0),
		steel
	)
	_add_frame_rail(
		"FrameBottom",
		Vector3(frame_depth, frame_thickness, right_z - left_z),
		Vector3(net_offset_x, bottom_y, 0.0),
		steel
	)
	_add_frame_rail(
		"FrameLeft",
		Vector3(frame_depth, top_y - bottom_y, frame_thickness),
		Vector3(net_offset_x, (bottom_y + top_y) * 0.5, left_z),
		steel
	)
	_add_frame_rail(
		"FrameRight",
		Vector3(frame_depth, top_y - bottom_y, frame_thickness),
		Vector3(net_offset_x, (bottom_y + top_y) * 0.5, right_z),
		steel
	)

	var width := right_z - left_z
	var height := top_y - bottom_y
	if width <= 0.08 or height <= 0.08:
		return

	var cols := maxi(2, int(ceil(width / mesh_spacing)))
	var rows := maxi(2, int(ceil(height / mesh_spacing)))
	var cell_w := width / float(cols)
	var cell_h := height / float(rows)
	var index := 0

	for col in range(cols):
		for row in range(rows):
			var z0 := left_z + float(col) * cell_w
			var z1 := z0 + cell_w
			var y0 := bottom_y + float(row) * cell_h
			var y1 := y0 + cell_h
			var x := net_offset_x
			_add_wire(Vector3(x, y0, z0), Vector3(x, y1, z1), mesh_mat, index)
			index += 1
			_add_wire(Vector3(x, y0, z1), Vector3(x, y1, z0), mesh_mat, index)
			index += 1


func _add_wire(a: Vector3, b: Vector3, material: Material, index: int) -> void:
	var delta := b - a
	var length := Vector2(delta.y, delta.z).length()
	if length < 0.02:
		return
	var mid := (a + b) * 0.5
	var angle := atan2(delta.z, delta.y)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(wire_depth, length, wire_size)
	var mi := MeshInstance3D.new()
	mi.name = "Wire_%d" % index
	mi.mesh = mesh
	mi.position = mid
	mi.rotation.x = angle
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _add_frame_rail(node_name: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	add_child(mi)


func _steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.09, 0.085, 1.0)
	mat.metallic = 0.85
	mat.roughness = 0.42
	return mat


func _mesh_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.125, 0.13, 1.0)
	mat.metallic = 0.88
	mat.roughness = 0.38
	return mat
