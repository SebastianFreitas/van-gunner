class_name VanSideWall
extends Node3D

## Curved cargo-van side liners: wider at the floor, bowed out at the waist,
## tapering in toward the roof — with punched openings for windows / side doors.

const _Shell := preload("res://scripts/van/van_side_wall_shell.gd")
const _Panel := preload("res://scripts/van/van_side_wall_panel.gd")

@export var wall_height := 3.08
@export var span_z := 9.4
@export var bottom_half_width := 2.42
@export var top_half_width := 2.00
## Extra outward bulge at mid-height (meters). Makes the body read as curved, not a flat lean.
@export var bow_out := 0.18
@export var thickness := 0.16
@export var y_segments := 56
@export var z_segments := 112
@export var wall_material: Material
@export var rebuild_on_ready := true

## Window cut AABB (CSG WindowCut) — used for rails / broad checks.
@export var window_half_height := 0.707
@export var window_half_length := 1.222
@export var window_center_y := 1.775
@export var window_centers_z: PackedFloat32Array = PackedFloat32Array([2.835, -0.375])

## Exact CSG WindowCut outline (z_off, y_off from window center). Wall metal
## forms the surround; the dark frame outer sits over this lip like rear doors.
var WINDOW_CUT_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-0.983, -0.707), Vector2(-1.142, -0.636), Vector2(-1.222, -0.519),
	Vector2(-1.222, 0.519), Vector2(-1.142, 0.636), Vector2(-0.983, 0.707),
	Vector2(0.983, 0.707), Vector2(1.142, 0.636), Vector2(1.222, 0.519),
	Vector2(1.222, -0.519), Vector2(1.142, -0.636), Vector2(0.983, -0.707),
])

## Side-door openings (match SideDoors layout).
@export var door_half_length := 1.30
@export var door_center_z := -3.485
@export var door_y_min := 0.02
@export var door_y_max := 3.05
## Inset of the door-jamb ring inner edge from the wall opening (meters).
@export var door_jamb_inset := 0.11
@export var door_jamb_material: Material

var _built := false

var _shell: _Shell
var _panel: _Panel


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


## Local X so a child of a node at (±x_ref, y_ref, z_ref) sits on the interior face.
func local_x_on_wall(wall_sign: float, world_y: float, x_ref: float) -> float:
	return wall_sign * (_profile_x(world_y) - x_ref)


## Point-in-polygon for window outlines. Poly is Vector2(z_off, y_off) from the
## window/door-window center — same coords as the original CSGPolygon2D shapes.
func point_in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
	var n := poly.size()
	if n < 3:
		return false
	var inside := false
	var j := n - 1
	for i in range(n):
		var pi: Vector2 = poly[i]
		var pj: Vector2 = poly[j]
		if ((pi.y > p.y) != (pj.y > p.y)) and (
			p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y + 0.0000001) + pi.x
		):
			inside = not inside
		j = i
	return inside


## Curved YZ shell following the cargo profile.
## Optional rectangular hole, or packed polys (Vector2(z_off, y_off) from z_ref /
## poly_center_y) for rounded outer silhouette + rounded glass cut.
## Vertex space: local_x = wall_sign*(profile(y)-x_ref) + x_shift, local_y = y-y_ref, local_z = z-z_ref.
func build_curved_shell_mesh(
	wall_sign: float,
	y_min: float,
	y_max: float,
	z_min: float,
	z_max: float,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	shell_thickness: float,
	x_shift: float = 0.0,
	seg_y: int = 16,
	seg_z: int = 12,
	hole_y_min: float = INF,
	hole_y_max: float = -INF,
	hole_z_min: float = INF,
	hole_z_max: float = -INF,
	outer_poly: PackedVector2Array = PackedVector2Array(),
	hole_poly: PackedVector2Array = PackedVector2Array(),
	poly_center_y: float = INF
) -> ArrayMesh:
	return _shell_helper().build_curved_shell_mesh(
		wall_sign, y_min, y_max, z_min, z_max, x_ref, y_ref, z_ref, shell_thickness,
		x_shift, seg_y, seg_z,
		hole_y_min, hole_y_max, hole_z_min, hole_z_max,
		outer_poly, hole_poly, poly_center_y
	)


## Curved glass pane clipped to a rounded CSG-style polygon (Vector2(z_off, y_off)).
func build_curved_pane_from_poly(
	wall_sign: float,
	poly: PackedVector2Array,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	poly_center_y: float,
	x_shift: float = 0.0,
	edge_subdiv: int = 4
) -> ArrayMesh:
	return _shell_helper().build_curved_pane_from_poly(
		wall_sign, poly, x_ref, y_ref, z_ref, poly_center_y, x_shift, edge_subdiv
	)


## Thin CSG-style frame ring: loft outer→inner polys onto the wall curve.
## Matches the extruded WindowFrame (Outer − InnerCut) silhouette.
## Each spoke keeps a flat cross-section (same face X for outer+inner) so the
## border reads like rear CSG — slim, sharp — not a bowed "inflated tire".
func build_curved_frame_ring_mesh(
	wall_sign: float,
	outer_poly: PackedVector2Array,
	inner_poly: PackedVector2Array,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	poly_center_y: float,
	shell_thickness: float,
	x_shift: float = 0.0,
	edge_subdiv: int = 8
) -> ArrayMesh:
	return _shell_helper().build_curved_frame_ring_mesh(
		wall_sign, outer_poly, inner_poly, x_ref, y_ref, z_ref, poly_center_y,
		shell_thickness, x_shift, edge_subdiv
	)


func _shell_helper() -> _Shell:
	if _shell == null:
		_shell = _Shell.new(self)
	return _shell


func _panel_helper() -> _Panel:
	if _panel == null:
		_panel = _Panel.new(self)
	return _panel


func _build() -> void:
	if _built:
		return
	_built = true

	var mat := wall_material if wall_material else _default_wall_material()
	var jamb_mat := door_jamb_material if door_jamb_material else mat
	_add_side(&"LeftWall", -1.0, mat)
	_add_side(&"RightWall", 1.0, mat)
	_add_door_jambs(-1.0, jamb_mat)
	_add_door_jambs(1.0, jamb_mat)
	_add_door_slide_tracks(jamb_mat)
	_add_cargo_rails(mat)
	_add_floor_seal_strips(jamb_mat)


func _add_side(side_name: StringName, wall_sign: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = String(side_name)
	mi.mesh = _panel_helper().build_side_mesh(wall_sign)
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _door_jamb_outer_poly() -> PackedVector2Array:
	var hz := door_half_length
	var hy := (door_y_max - door_y_min) * 0.5
	return PackedVector2Array([
		Vector2(-hz, -hy), Vector2(hz, -hy), Vector2(hz, hy), Vector2(-hz, hy),
	])


func _door_jamb_inner_poly() -> PackedVector2Array:
	var hz := door_half_length - door_jamb_inset
	var hy := (door_y_max - door_y_min) * 0.5 - door_jamb_inset
	if hz <= 0.05 or hy <= 0.05:
		return PackedVector2Array()
	return PackedVector2Array([
		Vector2(-hz, -hy), Vector2(hz, -hy), Vector2(hz, hy), Vector2(-hz, hy),
	])


func _add_door_jambs(wall_sign: float, mat: Material) -> void:
	var inner := _door_jamb_inner_poly()
	if inner.size() < 3:
		return
	var mid_y := (door_y_min + door_y_max) * 0.5
	var x_ref := _profile_x(mid_y)
	var mi := MeshInstance3D.new()
	mi.name = "DoorJamb_%s" % ("L" if wall_sign < 0.0 else "R")
	mi.mesh = build_curved_frame_ring_mesh(
		wall_sign, _door_jamb_outer_poly(), inner,
		x_ref, mid_y, door_center_z, mid_y, thickness, 0.0, 8
	)
	# Mesh is built around local origin — parent must sit on the wall (same as SideDoors leaves).
	mi.position = Vector3(wall_sign * x_ref, mid_y, door_center_z)
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _add_door_slide_tracks(mat: Material) -> void:
	# Horizontal rail above each sliding side door (cargo-van track).
	var track_y := door_y_max - 0.04
	var z0 := door_center_z - door_half_length + 0.08
	var z1 := door_center_z + door_half_length - 0.08
	var length := z1 - z0
	if length < 0.4:
		return
	var x := _profile_x(track_y)
	var lean := lean_angle_at(track_y)
	var z_mid := (z0 + z1) * 0.5
	for wall_sign in [-1.0, 1.0]:
		var track := MeshInstance3D.new()
		track.name = "DoorSlideTrack_%s" % ("L" if wall_sign < 0.0 else "R")
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.085, length)
		track.mesh = box
		track.material_override = mat
		track.position = Vector3(wall_sign * (x - wall_sign * 0.035), track_y, z_mid)
		track.rotation.z = wall_sign * lean
		track.layers = VanLighting.LAYER_VAN_INTERIOR
		track.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(track)


func _add_floor_seal_strips(mat: Material) -> void:
	# Dark rubber/finish bead where the liner meets the deck — covers the small
	# floor-wall gap and reads like real van corner isolation trim.
	const FLOOR_HALF_WIDTH := 2.4  # van_floor span_x * 0.5
	var seal_y := 0.025
	var wall_x := _profile_x(seal_y)
	var lean := lean_angle_at(seal_y)
	var seal_depth := maxf(wall_x - FLOOR_HALF_WIDTH + 0.03, 0.04)
	var seal_center_x := (wall_x + FLOOR_HALF_WIDTH) * 0.5
	var half := span_z * 0.5
	var z0 := -half + 0.05
	var z1 := half - 0.05
	var length := z1 - z0
	var z_mid := (z0 + z1) * 0.5
	for wall_sign in [-1.0, 1.0]:
		var seal := MeshInstance3D.new()
		seal.name = "FloorSeal_%s" % ("L" if wall_sign < 0.0 else "R")
		var box := BoxMesh.new()
		box.size = Vector3(seal_depth, 0.05, length)
		seal.mesh = box
		seal.material_override = mat
		seal.position = Vector3(wall_sign * seal_center_x, seal_y, z_mid)
		seal.rotation.z = wall_sign * lean
		seal.layers = VanLighting.LAYER_VAN_INTERIOR
		seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(seal)


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
		for wall_sign in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			rail.name = "CargoRail_%s_%d" % ["L" if wall_sign < 0.0 else "R", idx]
			var box := BoxMesh.new()
			box.size = Vector3(0.045, 0.06, length)
			rail.mesh = box
			rail.material_override = mat
			# Sit just proud of the interior face.
			rail.position = Vector3(wall_sign * (x - wall_sign * 0.025), rail_y, z_mid)
			rail.rotation.z = wall_sign * lean
			rail.layers = VanLighting.LAYER_VAN_INTERIOR
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


func _default_wall_material() -> ShaderMaterial:
	var sh := load("res://scenes/van/van_wall.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("wall_size_m", Vector2(span_z, wall_height))
	return mat
