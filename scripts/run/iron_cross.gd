class_name IronCross
extends Node3D

## Welded iron + on a window pane. Local XY is the glass face; +Z is outward.
## Bars span the full opening so the ends meet the frame.

@export var span_width := 2.2
@export var span_height := 1.23
@export var bar_width := 0.09
@export var bar_depth := 0.055
@export var plate_size := 0.28
@export var plate_depth := 0.07
@export var rivet_size := 0.045
@export var end_pad_size := 0.16
@export var rebuild_on_ready := true

var _built := false


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_build()


func _build() -> void:
	if _built:
		return
	_built = true

	var iron := _iron_material()
	var rivet_mat := _rivet_material()

	# Slight outward bias so bars sit on the exterior glass face.
	var z := bar_depth * 0.5

	_add_box(
		"HorizontalBar",
		Vector3(span_width, bar_width, bar_depth),
		Vector3(0.0, 0.0, z),
		iron
	)
	_add_box(
		"VerticalBar",
		Vector3(bar_width, span_height, bar_depth),
		Vector3(0.0, 0.0, z),
		iron
	)

	# Center weld plate — thicker, sits proud of the bars.
	var plate_z := z + (plate_depth - bar_depth) * 0.5 + 0.008
	_add_box(
		"CenterPlate",
		Vector3(plate_size, plate_size, plate_depth),
		Vector3(0.0, 0.0, plate_z),
		iron
	)

	# Four rivets on the plate corners.
	var rivet_spread := plate_size * 0.28
	var rivet_z := plate_z + plate_depth * 0.5 + rivet_size * 0.35
	for offset in [
		Vector3(rivet_spread, rivet_spread, rivet_z),
		Vector3(-rivet_spread, rivet_spread, rivet_z),
		Vector3(rivet_spread, -rivet_spread, rivet_z),
		Vector3(-rivet_spread, -rivet_spread, rivet_z),
	]:
		_add_box("Rivet", Vector3(rivet_size, rivet_size, rivet_size * 0.7), offset, rivet_mat)

	# Mounting pads where bars meet the frame.
	var pad_depth := bar_depth * 1.15
	var pad_z := pad_depth * 0.5
	var half_w := span_width * 0.5 - end_pad_size * 0.15
	var half_h := span_height * 0.5 - end_pad_size * 0.15
	_add_box("EndPad", Vector3(end_pad_size, end_pad_size * 0.85, pad_depth), Vector3(half_w, 0.0, pad_z), iron)
	_add_box("EndPad", Vector3(end_pad_size, end_pad_size * 0.85, pad_depth), Vector3(-half_w, 0.0, pad_z), iron)
	_add_box("EndPad", Vector3(end_pad_size * 0.85, end_pad_size, pad_depth), Vector3(0.0, half_h, pad_z), iron)
	_add_box("EndPad", Vector3(end_pad_size * 0.85, end_pad_size, pad_depth), Vector3(0.0, -half_h, pad_z), iron)

	# Small corner rivets on each end pad.
	var tip_rivet := rivet_size * 0.75
	var tip_z := pad_z + pad_depth * 0.5 + tip_rivet * 0.3
	for tip in [
		Vector3(half_w, 0.0, tip_z),
		Vector3(-half_w, 0.0, tip_z),
		Vector3(0.0, half_h, tip_z),
		Vector3(0.0, -half_h, tip_z),
	]:
		_add_box("TipRivet", Vector3(tip_rivet, tip_rivet, tip_rivet * 0.65), tip, rivet_mat)


func _add_box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _iron_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.075, 0.08, 1.0)
	mat.metallic = 0.72
	mat.roughness = 0.48
	return mat


func _rivet_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.17, 0.15, 1.0)
	mat.metallic = 0.85
	mat.roughness = 0.35
	return mat
