class_name VanInnerShell
extends Node3D
## Seeded welded ribs over the ceiling bays and down the walls, bolted scrap plates on the lower
## walls and welded patches over bullet holes, dressing the inside of the van shell.

const WALL_PATH := ^"../Interior/Shell/SideWalls"

const RIB_Z0 := -4.05
const RIB_STEP := 1.35
const RIB_COUNT := 7
const CEIL_SEGMENTS := 8
const CEIL_X_HALF := 2.3

const WALL_Y_TOP := 2.95
const WALL_Y_BOT := 0.1
const WALL_SEGMENTS := 6

const DOOR_Z_MIN := -4.785
const DOOR_Z_MAX := -2.185
const WINDOW_SPANS: Array[Vector2] = [Vector2(-1.60, 0.85), Vector2(1.61, 4.06)]
const Z_MIN := -4.5
const Z_MAX := 4.55

const PLATE_COUNT := 8
const PLATE_TRIES := 20
const PATCH_WALL_COUNT := 7
const PATCH_CEIL_COUNT := 3

var _wall: VanSideWall
var _weld_bead_mesh: BoxMesh


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_wall = get_node_or_null(WALL_PATH) as VanSideWall
	_weld_bead_mesh = BoxMesh.new()
	_weld_bead_mesh.size = Vector3(0.05, 0.05, 0.05)

	var weld := MachineParts.dark(Color(0.2, 0.19, 0.17), 0.8)
	var plate_a := MachineParts.dark(Color(0.24, 0.2, 0.15), 0.88)
	var plate_b := MachineParts.dark(Color(0.17, 0.18, 0.16), 0.9)
	var patch := MachineParts.dark(Color(0.13, 0.12, 0.11), 0.85)
	var bolt := MachineParts.dark(Color(0.3, 0.29, 0.26), 0.78)

	var rng := look.rng_for(&"inner_shell")

	_build_ribs(weld)
	_build_plates(rng, plate_a, plate_b, bolt)
	_build_patches(rng, patch, weld)


func _wall_x(side: float, y: float) -> float:
	if _wall == null:
		return side * 2.3
	return side * (_wall.wall_x_at(y) - 0.015)


func _ceiling_y(x: float) -> float:
	return 3.02 + 0.38 * (1.0 - pow(x / 2.36, 2.0)) - 0.015


func _in_span(z: float, z_min: float, z_max: float) -> bool:
	return z >= z_min and z <= z_max


func _in_window_span(z: float) -> bool:
	for span: Vector2 in WINDOW_SPANS:
		if _in_span(z, span.x, span.y):
			return true
	return false


func _build_ribs(weld_mat: Material) -> void:
	for i: int in range(RIB_COUNT):
		var z := RIB_Z0 + float(i) * RIB_STEP
		_build_ceiling_rib(i, z, weld_mat)
		_build_wall_rib(i, z, -1.0, weld_mat)
		_build_wall_rib(i, z, 1.0, weld_mat)


func _build_ceiling_rib(idx: int, z: float, mat: Material) -> void:
	var pts := PackedVector3Array()
	for s: int in range(CEIL_SEGMENTS + 1):
		var t := float(s) / float(CEIL_SEGMENTS)
		var x := lerpf(-CEIL_X_HALF, CEIL_X_HALF, t)
		pts.append(Vector3(x, _ceiling_y(x), z))
	_build_rib_chain(pts, "CeilRib%d" % idx, mat)


func _build_wall_rib(idx: int, z: float, side: float, mat: Material) -> void:
	if _in_span(z, DOOR_Z_MIN, DOOR_Z_MAX):
		return
	var start_i := 0
	if _in_window_span(z):
		start_i = 4
	var pts := PackedVector3Array()
	for s: int in range(start_i, WALL_SEGMENTS + 1):
		var y := WALL_Y_TOP - float(s) * (WALL_Y_TOP - WALL_Y_BOT) / float(WALL_SEGMENTS)
		pts.append(Vector3(_wall_x(side, y), y, z))
	var rib_name := "WallRib%s%d" % ["L" if side < 0.0 else "R", idx]
	_build_rib_chain(pts, rib_name, mat)


func _build_rib_chain(pts: PackedVector3Array, base_name: String, mat: Material) -> void:
	if pts.size() < 2:
		return
	for i: int in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		_add_rib_segment(a, b, "%s_%d" % [base_name, i], mat)
		if i > 0:
			_add_mesh("%s_Weld%d" % [base_name, i], _weld_bead_mesh, mat, a)


func _add_rib_segment(a: Vector3, b: Vector3, seg_name: String, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(a.distance_to(b), 0.03, 0.07)
	var angle := atan2(b.y - a.y, b.x - a.x)
	_add_mesh(seg_name, mesh, mat, (a + b) * 0.5, angle)


func _build_plates(rng: RandomNumberGenerator, mat_a: Material, mat_b: Material, bolt_mat: Material) -> void:
	for side: float in [-1.0, 1.0]:
		var placed: Array[Rect2] = []
		for idx: int in range(PLATE_COUNT):
			_place_plate(rng, side, idx, placed, mat_a, mat_b, bolt_mat)


func _place_plate(rng: RandomNumberGenerator, side: float, idx: int, placed: Array[Rect2],
		mat_a: Material, mat_b: Material, bolt_mat: Material) -> void:
	for _try: int in range(PLATE_TRIES):
		var w := rng.randf_range(0.3, 0.7)
		var h := rng.randf_range(0.25, 0.5)
		var y := rng.randf_range(0.2 + h * 0.5, 1.0 - h * 0.5)
		var z := rng.randf_range(Z_MIN, Z_MAX)
		if _in_span(z, DOOR_Z_MIN, DOOR_Z_MAX):
			continue
		var rect := Rect2(z - w * 0.5, y - h * 0.5, w, h)
		var overlaps := false
		for other: Rect2 in placed:
			if rect.intersects(other):
				overlaps = true
				break
		if overlaps:
			continue
		placed.append(rect)
		_build_plate_mesh(side, y, z, w, h, idx, rng, mat_a, mat_b, bolt_mat)
		return


func _build_plate_mesh(side: float, y: float, z: float, w: float, h: float, idx: int,
		rng: RandomNumberGenerator, mat_a: Material, mat_b: Material, bolt_mat: Material) -> void:
	var mat: Material = mat_a if rng.randf() < 0.5 else mat_b
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, h, w)
	var angle := atan2(_wall_x(side, y + 0.1) - _wall_x(side, y - 0.1), 0.2)
	var plate_name := "Plate%s%d" % ["L" if side < 0.0 else "R", idx]
	var mi := _add_mesh(plate_name, mesh, mat, Vector3(_wall_x(side, y), y, z), angle)

	var bolt_mesh := CylinderMesh.new()
	bolt_mesh.top_radius = 0.012
	bolt_mesh.bottom_radius = 0.012
	bolt_mesh.height = 0.01
	bolt_mesh.radial_segments = 6
	var bz := w * 0.5 - 0.05
	var by := h * 0.5 - 0.05
	var corners: Array[Vector2] = [Vector2(-bz, -by), Vector2(bz, -by), Vector2(-bz, by), Vector2(bz, by)]
	for c: int in range(4):
		var corner: Vector2 = corners[c]
		var bolt_mi := MeshInstance3D.new()
		bolt_mi.name = "%s_Bolt%d" % [plate_name, c]
		bolt_mi.mesh = bolt_mesh
		bolt_mi.material_override = bolt_mat
		bolt_mi.rotation.z = PI * 0.5
		bolt_mi.position = Vector3(0.011, corner.y, corner.x)
		bolt_mi.layers = 2
		bolt_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(bolt_mi)


func _build_patches(rng: RandomNumberGenerator, patch_mat: Material, weld_mat: Material) -> void:
	for i: int in range(PATCH_WALL_COUNT):
		_build_wall_patch(rng, i, patch_mat, weld_mat)
	for i: int in range(PATCH_CEIL_COUNT):
		_build_ceiling_patch(rng, i, patch_mat, weld_mat)


func _build_wall_patch(rng: RandomNumberGenerator, idx: int, patch_mat: Material, weld_mat: Material) -> void:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var y := 0.3
	var z := 0.0
	for _try: int in range(30):
		y = rng.randf_range(0.3, 2.6)
		z = rng.randf_range(Z_MIN, Z_MAX)
		if _in_span(z, DOOR_Z_MIN, DOOR_Z_MAX):
			continue
		if y > 1.05 and _in_window_span(z):
			continue
		break

	var r := rng.randf_range(0.04, 0.07)
	var angle := side * (PI * 0.5) + atan2(_wall_x(side, y + 0.1) - _wall_x(side, y - 0.1), 0.2)
	var patch_name := "PatchWall%d" % idx

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = r + 0.015
	ring_mesh.bottom_radius = r + 0.015
	ring_mesh.height = 0.004
	ring_mesh.radial_segments = 8
	_add_mesh("%s_Ring" % patch_name, ring_mesh, weld_mat, Vector3(_wall_x(side, y), y, z), angle)

	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = r
	disc_mesh.bottom_radius = r
	disc_mesh.height = 0.008
	disc_mesh.radial_segments = 8
	var pos := Vector3(_wall_x(side, y) + side * 0.006, y, z)
	_add_mesh(patch_name, disc_mesh, patch_mat, pos, angle)


func _build_ceiling_patch(rng: RandomNumberGenerator, idx: int, patch_mat: Material, weld_mat: Material) -> void:
	var x := rng.randf_range(-1.8, 1.8)
	var z := rng.randf_range(Z_MIN, Z_MAX)
	var r := rng.randf_range(0.04, 0.07)
	var angle := atan2(_ceiling_y(x + 0.1) - _ceiling_y(x - 0.1), 0.2)
	var patch_name := "PatchCeil%d" % idx

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = r + 0.015
	ring_mesh.bottom_radius = r + 0.015
	ring_mesh.height = 0.004
	ring_mesh.radial_segments = 8
	_add_mesh("%s_Ring" % patch_name, ring_mesh, weld_mat, Vector3(x, _ceiling_y(x), z), angle)

	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = r
	disc_mesh.bottom_radius = r
	disc_mesh.height = 0.008
	disc_mesh.radial_segments = 8
	var pos := Vector3(x, _ceiling_y(x) - 0.006, z)
	_add_mesh(patch_name, disc_mesh, patch_mat, pos, angle)


func _add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3, rot_z: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.z = rot_z
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
