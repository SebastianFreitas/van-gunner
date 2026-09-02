class_name IronCross
extends Node3D

## Welded iron + on a window pane. Local XY is the glass face; +Z is outward.
## Bars span the full opening so the ends meet the frame.
## Optional side-wall curve: bars, center plate, and top/bottom pads follow VanSideWall.

const BrokenIronCrossScene := preload("res://scenes/van/broken_iron_cross.tscn")

@export var span_width := 2.2
@export var span_height := 1.23
@export var bar_width := 0.09
@export var bar_depth := 0.055
@export var plate_size := 0.28
@export var plate_depth := 0.07
@export var rivet_size := 0.045
@export var end_pad_size := 0.16
@export var curve_segments := 14
@export var rebuild_on_ready := true

var _built := false
var _broken := false
## When set, vertical elements bend with the cargo side-wall profile.
var _curve_walls: VanSideWall = null
var _curve_mid_y := 0.0


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


## Bend the + to match a bowed side wall. mid_y is the window center in wall space.
func follow_side_wall_curve(walls: VanSideWall, mid_y: float) -> void:
	_curve_walls = walls
	_curve_mid_y = mid_y
	rebuild()


## Swap intact bars for a randomized blown-out stub set after a window breach.
func break_bars() -> void:
	if _broken:
		return
	_broken = true
	visible = false

	var parent := get_parent()
	if parent == null:
		return

	var broken := BrokenIronCrossScene.instantiate() as BrokenIronCross
	broken.name = "BrokenIronCross"
	broken.span_width = span_width
	broken.span_height = span_height
	broken.bar_width = bar_width
	broken.bar_depth = bar_depth
	broken.rivet_size = rivet_size
	broken.end_pad_size = end_pad_size
	broken.curve_segments = curve_segments
	broken.break_seed = 0
	broken.rebuild_on_ready = false
	broken.transform = transform
	parent.add_child(broken)
	if _curve_walls != null:
		broken.follow_side_wall_curve(_curve_walls, _curve_mid_y)
	else:
		broken.rebuild()


## Restore intact bars after a repair. Removes any BrokenIronCross sibling.
func repair_bars() -> void:
	if _broken:
		var parent := get_parent()
		if parent:
			for child in parent.get_children():
				if child is BrokenIronCross:
					child.queue_free()
		_broken = false
	visible = true


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

	_add_horizontal_bar(z, iron)
	_add_vertical_bar(z, iron)

	# Center weld plate — thicker, sits proud of the bars.
	var plate_z := z + (plate_depth - bar_depth) * 0.5 + 0.008
	_add_center_plate(plate_z, iron)

	# Four rivets on the plate corners.
	var rivet_spread := plate_size * 0.28
	var rivet_z := plate_z + plate_depth * 0.5 + rivet_size * 0.35
	for offset in [
		Vector3(rivet_spread, rivet_spread, rivet_z + _curve_z(rivet_spread)),
		Vector3(-rivet_spread, rivet_spread, rivet_z + _curve_z(rivet_spread)),
		Vector3(rivet_spread, -rivet_spread, rivet_z + _curve_z(-rivet_spread)),
		Vector3(-rivet_spread, -rivet_spread, rivet_z + _curve_z(-rivet_spread)),
	]:
		_add_box("Rivet", Vector3(rivet_size, rivet_size, rivet_size * 0.7), offset, rivet_mat)

	# Mounting pads where bars meet the frame.
	var pad_depth := bar_depth * 1.15
	var pad_z := pad_depth * 0.5
	var half_w := span_width * 0.5 - end_pad_size * 0.15
	var half_h := span_height * 0.5 - end_pad_size * 0.15
	_add_box("EndPad", Vector3(end_pad_size, end_pad_size * 0.85, pad_depth), Vector3(half_w, 0.0, pad_z), iron)
	_add_box("EndPad", Vector3(end_pad_size, end_pad_size * 0.85, pad_depth), Vector3(-half_w, 0.0, pad_z), iron)
	_add_box(
		"EndPad",
		Vector3(end_pad_size * 0.85, end_pad_size, pad_depth),
		Vector3(0.0, half_h, pad_z + _curve_z(half_h)),
		iron
	)
	_add_box(
		"EndPad",
		Vector3(end_pad_size * 0.85, end_pad_size, pad_depth),
		Vector3(0.0, -half_h, pad_z + _curve_z(-half_h)),
		iron
	)

	# Small corner rivets on each end pad.
	var tip_rivet := rivet_size * 0.75
	var tip_z := pad_z + pad_depth * 0.5 + tip_rivet * 0.3
	for tip in [
		Vector3(half_w, 0.0, tip_z),
		Vector3(-half_w, 0.0, tip_z),
		Vector3(0.0, half_h, tip_z + _curve_z(half_h)),
		Vector3(0.0, -half_h, tip_z + _curve_z(-half_h)),
	]:
		_add_box("TipRivet", Vector3(tip_rivet, tip_rivet, tip_rivet * 0.65), tip, rivet_mat)


func _add_vertical_bar(z: float, iron: Material) -> void:
	if _curve_walls == null:
		_add_box(
			"VerticalBar",
			Vector3(bar_width, span_height, bar_depth),
			Vector3(0.0, 0.0, z),
			iron
		)
		return

	var half_h := span_height * 0.5
	var half_w := bar_width * 0.5
	var half_d := bar_depth * 0.5
	var segs := maxi(curve_segments, 2)
	var rings: Array = []
	for i in range(segs + 1):
		var y := lerpf(-half_h, half_h, float(i) / float(segs))
		var cz := z + _curve_z(y)
		rings.append([
			Vector3(-half_w, y, cz - half_d),
			Vector3(half_w, y, cz - half_d),
			Vector3(half_w, y, cz + half_d),
			Vector3(-half_w, y, cz + half_d),
		])
	_commit_lofted_bar("VerticalBar", rings, iron)


func _add_horizontal_bar(z: float, iron: Material) -> void:
	if _curve_walls == null:
		_add_box(
			"HorizontalBar",
			Vector3(span_width, bar_width, bar_depth),
			Vector3(0.0, 0.0, z),
			iron
		)
		return

	# Cross-section spans local Y; each corner follows the wall bow at its height.
	var half_w := span_width * 0.5
	var half_y := bar_width * 0.5
	var half_d := bar_depth * 0.5
	var segs := maxi(curve_segments, 2)
	var rings: Array = []
	for i in range(segs + 1):
		var x := lerpf(-half_w, half_w, float(i) / float(segs))
		rings.append([
			Vector3(x, -half_y, z + _curve_z(-half_y) - half_d),
			Vector3(x, half_y, z + _curve_z(half_y) - half_d),
			Vector3(x, half_y, z + _curve_z(half_y) + half_d),
			Vector3(x, -half_y, z + _curve_z(-half_y) + half_d),
		])
	_commit_lofted_bar("HorizontalBar", rings, iron)


func _add_center_plate(plate_z: float, iron: Material) -> void:
	if _curve_walls == null:
		_add_box(
			"CenterPlate",
			Vector3(plate_size, plate_size, plate_depth),
			Vector3(0.0, 0.0, plate_z),
			iron
		)
		return

	var half := plate_size * 0.5
	var half_d := plate_depth * 0.5
	var segs := maxi(curve_segments >> 1, 2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var front: Array = []
	var back: Array = []
	for iy in range(segs + 1):
		var py := lerpf(-half, half, float(iy) / float(segs))
		var cz := plate_z + _curve_z(py)
		var row_f: Array = []
		var row_b: Array = []
		for ix in range(segs + 1):
			var px := lerpf(-half, half, float(ix) / float(segs))
			row_f.append(Vector3(px, py, cz + half_d))
			row_b.append(Vector3(px, py, cz - half_d))
		front.append(row_f)
		back.append(row_b)

	for iy in range(segs):
		for ix in range(segs):
			var f00: Vector3 = front[iy][ix]
			var f10: Vector3 = front[iy][ix + 1]
			var f11: Vector3 = front[iy + 1][ix + 1]
			var f01: Vector3 = front[iy + 1][ix]
			_add_quad(st, f00, f10, f11, f01)
			var b00: Vector3 = back[iy][ix]
			var b10: Vector3 = back[iy][ix + 1]
			var b11: Vector3 = back[iy + 1][ix + 1]
			var b01: Vector3 = back[iy + 1][ix]
			_add_quad(st, b00, b01, b11, b10)

	for ix in range(segs):
		_add_quad(st, front[0][ix], front[0][ix + 1], back[0][ix + 1], back[0][ix])
		_add_quad(
			st,
			front[segs][ix],
			back[segs][ix],
			back[segs][ix + 1],
			front[segs][ix + 1]
		)
	for iy in range(segs):
		_add_quad(st, front[iy][0], back[iy][0], back[iy + 1][0], front[iy + 1][0])
		_add_quad(
			st,
			front[iy][segs],
			front[iy + 1][segs],
			back[iy + 1][segs],
			back[iy][segs]
		)

	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "CenterPlate"
	mi.mesh = st.commit()
	mi.material_override = iron
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _commit_lofted_bar(node_name: String, rings: Array, iron: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var segs := rings.size() - 1

	for i in range(segs):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		# Cabin face (-Z), exterior (+Z), then the two side faces.
		_add_quad(st, a[0], b[0], b[1], a[1])
		_add_quad(st, a[3], a[2], b[2], b[3])
		_add_quad(st, a[0], a[3], b[3], b[0])
		_add_quad(st, a[1], b[1], b[2], a[2])

	var start: Array = rings[0]
	var end: Array = rings[segs]
	_add_quad(st, start[0], start[1], start[2], start[3])
	_add_quad(st, end[0], end[3], end[2], end[1])

	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = iron
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


## Local +Z offset so a point at local_y sits on the side-wall profile.
func _curve_z(local_y: float) -> float:
	if _curve_walls == null:
		return 0.0
	return _curve_walls.wall_x_at(_curve_mid_y + local_y) - _curve_walls.wall_x_at(_curve_mid_y)


func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(a)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(b)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(c)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(a)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(c)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(d)


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
