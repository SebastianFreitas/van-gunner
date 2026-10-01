class_name IronCross
extends Node3D

## Welded iron + on a window pane. Local XY is the glass face; +Z is outward.
## Bars span the full opening so the ends meet the frame.
## Optional side-wall curve: bars, center plate, and top/bottom pads follow VanSideWall.

const BrokenIronCrossScene := preload("res://scenes/van/broken_iron_cross.tscn")

@export var span_width := 2.2
@export var span_height := 1.23
@export var bar_width := 0.055
@export var bar_depth := 0.018
@export var plate_size := 0.18
@export var plate_depth := 0.018
@export var rivet_size := 0.02
@export var end_pad_size := 0.11
@export var curve_segments := 14
@export var rebuild_on_ready := true

## D7: the crossing bars, plate and pads step TRIM_LIFT apart in depth, over the audit's 1 cm FLICKER rule.
const TRIM_LIFT := 0.012

## D12: each end pad's outer edge stops 2 cm inside the bar span, so it stays inside the frame opening (which is >= the span) and never shares a plane with a bar's end face.
const PAD_END_CLEAR := 0.02

## D12: each bar ends 2 cm inside its end pad (4 cm inside the span), so its end face is buried in the pad and sits over 2 cm from both the pad's face and the frame opening.
const BAR_END_CLEAR := 0.04

## Back face of the inboard (vertical) bar: 1.2 cm outboard of the cabin glass at z -0.01.
const BACK_Z := 0.002
## Rivet head: a low cone, so no flat face over 1 cm² sits parallel to the exterior pane.
const RIVET_TOP_RADIUS := 0.004
const RIVET_HEIGHT := 0.006

static var _iron_mat: StandardMaterial3D = null
static var _rivet_mat: StandardMaterial3D = null

var _built := false
var _broken := false
## When true every built mesh sits on layers 1 and 2 (D15) and joins VanLighting.GROUP_EXTERIOR_LAYER so VanLighting doesn't force it back to layer 2.
var _street_lit := false
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


## Put the built bars on the street-lit layers (or back on the interior layer).
func set_street_lit(on: bool) -> void:
	_street_lit = on
	for n in find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if vi == null or vi is Light3D:
			continue
		if on:
			if not vi.is_in_group(VanLighting.GROUP_EXTERIOR_LAYER):
				vi.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
			VanLighting.retarget_layers(vi, VanLighting.LAYER_STREET_AND_INTERIOR)
		else:
			if vi.is_in_group(VanLighting.GROUP_EXTERIOR_LAYER):
				vi.remove_from_group(VanLighting.GROUP_EXTERIOR_LAYER)
			VanLighting.retarget_layers(vi, VanLighting.LAYER_VAN_INTERIOR)


func _apply_street_lit(mi: MeshInstance3D) -> void:
	if not _street_lit:
		return
	mi.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	mi.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)


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

	# Parts sit in z 0.002..0.044 (rivet tips 0.049): behind the exterior pane (0.055), before the glass.
	var zv := BACK_Z + bar_depth * 0.5
	var iron := iron_material()
	_add_horizontal_bar(zv + TRIM_LIFT, iron)  # D7: TRIM_LIFT apart so the bars share no plane.
	_add_vertical_bar(zv, iron)

	# Center weld plate: back 2 * TRIM_LIFT out, 1.2 cm clear of the horizontal bar's faces.
	var plate_front := BACK_Z + 2.0 * TRIM_LIFT + plate_depth
	_add_center_plate(plate_front - plate_depth * 0.5, iron)

	# Four rivets on the plate corners.
	var rs := plate_size * 0.28
	for corner in [Vector2(rs, rs), Vector2(-rs, rs), Vector2(rs, -rs), Vector2(-rs, -rs)]:
		_add_rivet("Rivet", corner, plate_front + _curve_z(corner.y), rivet_material())

	# Mounting pads where bars meet the frame, reaching from the bar's back to the plate's front.
	var half_w := span_width * 0.5 - PAD_END_CLEAR - end_pad_size * 0.5
	var half_h := span_height * 0.5 - PAD_END_CLEAR - end_pad_size * 0.5
	var pad_h := Vector3(end_pad_size, end_pad_size * 0.85, plate_front - BACK_Z)
	var pad_v := Vector3(end_pad_size * 0.85, end_pad_size, plate_front - BACK_Z - TRIM_LIFT)
	var z_h := plate_front - pad_h.z * 0.5
	var z_v := plate_front - pad_v.z * 0.5
	_add_box("EndPadR", pad_h, Vector3(half_w, 0.0, z_h), iron)
	_add_box("EndPadL", pad_h, Vector3(-half_w, 0.0, z_h), iron)
	_add_box("EndPadT", pad_v, Vector3(0.0, half_h, z_v + _curve_z(half_h)), iron)
	_add_box("EndPadB", pad_v, Vector3(0.0, -half_h, z_v + _curve_z(-half_h)), iron)

	# One rivet at the centre of each end pad, on the pad's front face.
	for tip in [Vector2(half_w, 0.0), Vector2(-half_w, 0.0), Vector2(0.0, half_h), Vector2(0.0, -half_h)]:
		_add_rivet("TipRivet", tip, plate_front + _curve_z(tip.y), rivet_material())


func _add_vertical_bar(z: float, iron: Material) -> void:
	if _curve_walls == null:
		_add_box(
			"VerticalBar",
			Vector3(bar_width, span_height - 2.0 * BAR_END_CLEAR, bar_depth),
			Vector3(0.0, 0.0, z),
			iron
		)
		return

	var half_h := span_height * 0.5 - BAR_END_CLEAR
	var half_w := bar_width * 0.5
	var half_d := bar_depth * 0.5
	var segs := maxi(curve_segments, 2)
	var rings: Array = []
	for i in range(segs + 1):
		var y := lerpf(-half_h, half_h, float(i) / float(segs))
		var cz := z + _curve_z(y)
		rings.append([  # x mirrored vs the horizontal bar: lofting along +y flips handedness.
			Vector3(half_w, y, cz - half_d),
			Vector3(-half_w, y, cz - half_d),
			Vector3(-half_w, y, cz + half_d),
			Vector3(half_w, y, cz + half_d),
		])
	_commit_lofted_bar("VerticalBar", rings, iron)


func _add_horizontal_bar(z: float, iron: Material) -> void:
	if _curve_walls == null:
		_add_box(
			"HorizontalBar",
			Vector3(span_width - 2.0 * BAR_END_CLEAR, bar_width, bar_depth),
			Vector3(0.0, 0.0, z),
			iron
		)
		return

	# Cross-section spans local Y; each corner follows the wall bow at its height.
	var half_w := span_width * 0.5 - BAR_END_CLEAR
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
			_add_quad(st, f00, f01, f11, f10)  # Clockwise from outside (Godot's front face).
			var b00: Vector3 = back[iy][ix]
			var b10: Vector3 = back[iy][ix + 1]
			var b11: Vector3 = back[iy + 1][ix + 1]
			var b01: Vector3 = back[iy + 1][ix]
			_add_quad(st, b00, b10, b11, b01)

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
	_apply_street_lit(mi)
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
	_apply_street_lit(mi)
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
	_apply_street_lit(mi)
	add_child(mi)


## Adds one cone rivet head whose base sits on a face at local z `base_z` (1 mm sunk).
func _add_rivet(node_name: String, pos_xy: Vector2, base_z: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = rivet_size * 0.5
	mesh.top_radius = RIVET_TOP_RADIUS
	mesh.height = RIVET_HEIGHT
	mesh.radial_segments = 8
	mesh.rings = 0
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	mi.position = Vector3(pos_xy.x, pos_xy.y, base_z + RIVET_HEIGHT * 0.5 - 0.001)
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_street_lit(mi)
	add_child(mi)


## Shared matte dark steel for every bar, plate and pad (intact and broken crosses).
static func iron_material() -> StandardMaterial3D:
	if _iron_mat == null:
		_iron_mat = StandardMaterial3D.new()
		_iron_mat.albedo_color = Color(0.07, 0.075, 0.08, 1.0)
		_iron_mat.metallic = 0.3
		_iron_mat.roughness = 0.75
	return _iron_mat


## Shared rivet steel.
static func rivet_material() -> StandardMaterial3D:
	if _rivet_mat == null:
		_rivet_mat = StandardMaterial3D.new()
		_rivet_mat.albedo_color = Color(0.16, 0.15, 0.13, 1.0)
		_rivet_mat.metallic = 0.3
		_rivet_mat.roughness = 0.7
	return _rivet_mat
